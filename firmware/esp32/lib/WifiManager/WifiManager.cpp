#include "WifiManager.h"
#include <WiFi.h>

bool connectWiFi(const char* ssid, const char* password, uint32_t timeoutMs) {
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, password);
    Serial.print("[WiFi] Conectando");
    const uint32_t start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
        delay(500);
        Serial.print(".");
    }
    Serial.println();
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[WiFi] Falha na conexao.");
        return false;
    }
    Serial.println("[WiFi] Conectado. IP: " + WiFi.localIP().toString());
    return true;
}
