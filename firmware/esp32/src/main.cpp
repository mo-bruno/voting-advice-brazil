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

static String deviceToken;
static String mqttTopic;
static bool previousButtonState = HIGH;
static uint32_t buttonPressedAt = 0;

static void onMqttMessage(char* topic, byte* payload, unsigned int length) {
    char buffer[512];
    if (length >= sizeof(buffer)) {
        Serial.println("[MQTT] Payload truncado (>= 512 bytes), descartado.");
        return;
    }
    memcpy(buffer, payload, length);
    buffer[length] = '\0';

    FarolEvent event;
    if (!parseFarolEvent(buffer, event)) {
        return;
    }
    setLed(ledColorFromString(event.color));
    sendEventToDisplay(event);
}

static void startPairing() {
    setLed(BLUE);
    sendStatusToDisplay("Pareamento", "Registrando sessao", "Aguarde...");
    delay(800);
    String code = generatePairingCode();
    PairingSessionResponse response = createPairingSession(deviceToken, code);
    if (!response.ok) {
        setLed(YELLOW);
        sendStatusToDisplay("Erro", "Falha ao parear", "Tente novamente");
        return;
    }
    sendPairingToDisplay("Conectar Farol", response.qrPayload, response.pairingCode);
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
