#include <Arduino.h>
#include "config.h"
#include "secrets.h"
#include "DeviceToken.h"
#include "WifiManager.h"
#include "MqttClient.h"
#include "PayloadParser.h"
#include "LedStatus.h"
#include "DisplayUart.h"
#include "PairingClient.h"
#include <ArduinoJson.h>

static String deviceToken;
static String mqttTopic;
static bool previousButtonState = HIGH;
static uint32_t buttonPressedAt = 0;
static bool pairingConfirmed = false;

// Noticias em memoria
struct NewsArticle {
    String title;
    String source;
    String date;
};
static const int MAX_NEWS = 5;
static NewsArticle newsArticles[MAX_NEWS];
static int newsCount = 0;
static int newsCurrentIndex = 0;

// Controle de estado
static uint32_t lastEventAt = 0;
static uint32_t nextNewsCycleAt = 0;
static uint32_t ledRestoreAt = 0;
static LedColor savedLedColor = BLUE;

// Controle de ordem do quiz: descarta mensagens atrasadas/fora de ordem
static int lastQuizCurrent = 0;
static int lastQuizTotal = 0;

static String shortDeviceId() {
    String id = deviceToken.substring(0, 8);
    id.toUpperCase();
    return id;
}

static bool isPairingConfirmation(const char* payload) {
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, payload);
    if (err || !doc["type"].is<const char*>()) {
        return false;
    }
    return doc["type"].as<String>() == "pairing_confirmed";
}

static void onMqttMessage(char* topic, byte* payload, unsigned int length) {
    char buffer[768];
    if (length >= sizeof(buffer)) {
        Serial.println("[MQTT] Payload truncado, descartado.");
        return;
    }
    memcpy(buffer, payload, length);
    buffer[length] = '\0';

    if (isPairingConfirmation(buffer)) {
        pairingConfirmed = true;
        setLed(GREEN);
        sendStatusToDisplay("Pareado", "Farol conectado", "Pronto para uso");
        return;
    }

    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, buffer);
    if (err || !doc["type"].is<const char*>()) {
        return;
    }

    String type = doc["type"].as<String>();

    if (type == "quiz_answer") {
        String answer  = doc["answer"] | "neutral";
        int current    = String(doc["current"] | "1").toInt();
        int total      = String(doc["total"]   | "1").toInt();

        // Reinicia contagem se for novo quiz (total diferente)
        if (total != lastQuizTotal) {
            lastQuizCurrent = 0;
            lastQuizTotal = total;
        }
        // Descarta mensagens atrasadas que chegaram fora de ordem
        if (current <= lastQuizCurrent) {
            Serial.printf("[MQTT] quiz ignorado (fora de ordem): %d/%d, ultimo visto: %d\n",
                          current, total, lastQuizCurrent);
            return;
        }
        lastQuizCurrent = current;

        LedColor color = (answer == "agree") ? GREEN
                       : (answer == "disagree") ? RED : YELLOW;
        savedLedColor = color;
        setLed(color);
        ledRestoreAt = millis() + 1500;
        sendQuizToDisplay(current, total, answer);
        lastEventAt = millis();

        if (current == total) {
            // Quiz completo: reseta guard para proximo quiz e mostra noticias em breve
            lastQuizCurrent = 0;
            lastQuizTotal   = 0;
            if (newsCount > 0) nextNewsCycleAt = millis() + 2000;
        } else if (newsCount > 0) {
            // Adia noticias enquanto o quiz esta ativo
            nextNewsCycleAt = millis() + 3000;
        }
        return;
    }

    if (type == "vote_alert") {
        FarolEvent event;
        if (!parseFarolEvent(buffer, event)) return;

        LedColor color = (event.alignment == "aligned")   ? GREEN
                       : (event.alignment == "divergent") ? RED : YELLOW;
        savedLedColor = color;
        setLed(color);
        sendEventToDisplay(event);
        lastEventAt = millis();
        // Reinicia ciclo de noticias apos 10s
        if (newsCount > 0) nextNewsCycleAt = millis() + 10000;
        return;
    }

    if (type == "news_batch") {
        // articles: "title1#source1#date1|title2#source2#date2|..."
        String articlesStr = doc["articles"] | "";
        newsCount = 0;
        newsCurrentIndex = 0;
        int start = 0;
        while (newsCount < MAX_NEWS) {
            int pipe = articlesStr.indexOf('|', start);
            String item = (pipe >= 0) ? articlesStr.substring(start, pipe)
                                      : articlesStr.substring(start);
            int h1 = item.indexOf('#');
            int h2 = item.indexOf('#', h1 + 1);
            if (h1 > 0 && h2 > h1) {
                newsArticles[newsCount].title  = item.substring(0, h1);
                newsArticles[newsCount].source = item.substring(h1 + 1, h2);
                newsArticles[newsCount].date   = item.substring(h2 + 1);
                newsCount++;
            }
            if (pipe < 0) break;
            start = pipe + 1;
        }
        // Começa a mostrar noticias apos 10s sem outro evento
        nextNewsCycleAt = millis() + 10000;
        Serial.printf("[MQTT] news_batch: %d artigos recebidos\n", newsCount);
        return;
    }
}

static bool waitForPairingConfirmation() {
    uint32_t startedAt = millis();
    uint32_t lastPollAt = 0;
    while (millis() - startedAt < PAIRING_CONFIRM_TIMEOUT_MS) {
        mqttLoop();
        updateLed();
        if (pairingConfirmed) {
            return true;
        }

        uint32_t now = millis();
        if (lastPollAt == 0 || now - lastPollAt >= PAIRING_STATUS_POLL_MS) {
            lastPollAt = now;
            PairingStatusResponse status = getPairingStatus(deviceToken);
            if (status.ok && status.paired) {
                pairingConfirmed = true;
                return true;
            }
        }
        delay(50);
    }
    return false;
}

static void startPairing() {
    setLed(BLUE);
    mqttLoop();
    if (!mqttIsConnected()) {
        setLed(YELLOW);
        sendStatusToDisplay("MQTT offline", "Conectando broker", "Tente novamente");
        return;
    }

    pairingConfirmed = false;
    sendStatusToDisplay("Pareamento", "Registrando sessao", "Aguarde...");
    delay(800);
    String code = generatePairingCode();
    PairingSessionResponse response = createPairingSession(deviceToken, code);
    if (!response.ok) {
        setLed(YELLOW);
        sendStatusToDisplay("Erro", "Falha ao parear", "Tente novamente");
        return;
    }
    sendPairingToDisplay(response.qrPayload, response.pairingCode, shortDeviceId());

    if (waitForPairingConfirmation()) {
        setLed(GREEN);
        sendStatusToDisplay("Pareado", "Farol conectado", "Pronto para uso");
        sendIdleToDisplay(shortDeviceId());
    } else {
        setLed(YELLOW);
        sendStatusToDisplay("Pareamento", "Tempo esgotado", "Segure para tentar");
    }
}

static void handleButton() {
    bool current = digitalRead(BUTTON_PIN);
    if (previousButtonState == HIGH && current == LOW) {
        buttonPressedAt = millis();
    }
    if (previousButtonState == LOW && current == HIGH) {
        uint32_t duration = millis() - buttonPressedAt;
        if (duration >= PAIRING_HOLD_MS) {
            startPairing();
        }
    }
    previousButtonState = current;
}

void setup() {
    Serial.begin(UART_BAUD);
    initDisplayUart();
    initLed();
    pinMode(BUTTON_PIN, INPUT_PULLUP);

    deviceToken = getOrCreateDeviceToken();
    mqttTopic = String(MQTT_TOPIC_PREFIX) + deviceToken;
    Serial.println("[Farol] Device token: " + deviceToken);

    sendStatusToDisplay("Iniciando", "Conectando WiFi", WIFI_SSID);
    if (!connectWiFi(WIFI_SSID, WIFI_PASSWORD)) {
        setLed(YELLOW);
        sendStatusToDisplay("Falha WiFi", "Verifique rede", "Reinicie");
        return;
    }

    sendStatusToDisplay("WiFi OK", "Conectando MQTT", mqttTopic);
    mqttInit(mqttTopic, onMqttMessage);
    sendIdleToDisplay(shortDeviceId());
}

void loop() {
    // Restaurar LED apos quiz pulse
    if (ledRestoreAt > 0 && millis() >= ledRestoreAt) {
        ledRestoreAt = 0;
        setLed(savedLedColor);
        // Volta ao idle se nao houver evento recente
        if (millis() - lastEventAt > 5000) {
            sendIdleToDisplay(shortDeviceId());
        }
    }

    // Ciclo de noticias quando idle (>10s sem evento)
    if (newsCount > 0 && nextNewsCycleAt > 0 && millis() >= nextNewsCycleAt) {
        int displayIndex = newsCurrentIndex % newsCount;
        sendNewsToDisplay(
            displayIndex + 1,
            newsCount,
            newsArticles[displayIndex].title,
            newsArticles[displayIndex].source,
            newsArticles[displayIndex].date
        );
        newsCurrentIndex = (newsCurrentIndex + 1) % newsCount;
        nextNewsCycleAt = millis() + 8000;
    }

    handleButton();
    mqttLoop();
    updateLed();
}
