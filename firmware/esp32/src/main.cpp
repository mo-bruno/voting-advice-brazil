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
    char buffer[512];
    if (length >= sizeof(buffer)) {
        Serial.println("[MQTT] Payload truncado (>= 512 bytes), descartado.");
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

    FarolEvent event;
    if (!parseFarolEvent(buffer, event)) {
        return;
    }
    setLed(ledColorFromString(event.color));
    sendEventToDisplay(event);
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
    sendPairingToDisplay("Conectar Farol", response.qrPayload, response.pairingCode, shortDeviceId());

    if (waitForPairingConfirmation()) {
        setLed(GREEN);
        sendStatusToDisplay("Pareado", "Farol conectado", "Pronto para uso");
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
    sendStatusToDisplay("Aguardando", "Segure o botao", "para parear");
}

void loop() {
    handleButton();
    mqttLoop();
    updateLed();
}
