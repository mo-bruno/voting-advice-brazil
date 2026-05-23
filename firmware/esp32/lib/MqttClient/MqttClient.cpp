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

static void reconnect() {
    while (!client.connected()) {
        Serial.print("[MQTT] Conectando...");
        char clientId[24];
        snprintf(clientId, sizeof(clientId), "farol-%08lx", static_cast<unsigned long>(esp_random()));
        if (client.connect(clientId)) {
            client.subscribe(topic.c_str());
            Serial.println("[MQTT] Conectado em " + topic);
        } else {
            Serial.print("[MQTT] Falhou rc=");
            Serial.println(client.state());
            delay(5000);
        }
    }
}

void mqttInit(const String& subscribeTopic, MqttMessageCallback callback) {
    topic = subscribeTopic;
    userCallback = callback;
    wifiClient.setInsecure();
    client.setServer(MQTT_BROKER, MQTT_PORT);
    client.setCallback(dispatch);
    reconnect();
}

void mqttLoop() {
    if (!client.connected()) reconnect();
    client.loop();
}
