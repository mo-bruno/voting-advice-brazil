#pragma once
#include <Arduino.h>

bool connectWiFi(const char* ssid, const char* password, uint32_t timeoutMs = 20000);
