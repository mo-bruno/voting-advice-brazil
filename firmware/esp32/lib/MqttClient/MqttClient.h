#pragma once
#include <Arduino.h>
#include <PubSubClient.h>

using MqttMessageCallback = void (*)(char* topic, byte* payload, unsigned int length);

void mqttInit(const String& topic, MqttMessageCallback callback);
void mqttLoop();
