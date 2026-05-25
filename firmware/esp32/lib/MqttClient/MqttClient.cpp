#include "MqttClient.h"
#include "config.h"
#include <WiFiClientSecure.h>
#include <esp_random.h>

static WiFiClientSecure wifiClient;
static PubSubClient client(wifiClient);
static String topic;
static MqttMessageCallback userCallback = nullptr;

static void dispatch(char* incomingTopic, byte* payload, unsigned int length) {
    if (userCallback) userCallback(incomingTopic, payload, length);
}

static bool tryConnectOnce() {
    Serial.print("[MQTT] Conectando...");
    char clientId[24];
    snprintf(clientId, sizeof(clientId), "farol-%08lx", static_cast<unsigned long>(esp_random()));
    if (client.connect(clientId)) {
        client.subscribe(topic.c_str());
        Serial.println("[MQTT] Conectado em " + topic);
        return true;
    }
    Serial.print("[MQTT] Falhou rc=");
    Serial.println(client.state());
    return false;
}

void mqttInit(const String& subscribeTopic, MqttMessageCallback callback) {
    topic = subscribeTopic;
    userCallback = callback;
    wifiClient.setInsecure();
    client.setServer(MQTT_BROKER, MQTT_PORT);
    client.setCallback(dispatch);
    tryConnectOnce();
}

void mqttLoop() {
    if (!client.connected()) {
        static uint32_t lastAttempt = 0;
        uint32_t now = millis();
        if (now - lastAttempt >= 5000) {
            lastAttempt = now;
            tryConnectOnce();
        }
        return;
    }
    client.loop();
}
