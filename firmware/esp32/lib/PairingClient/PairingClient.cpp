#include "PairingClient.h"
#include "config.h"
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <esp_random.h>

String generatePairingCode() {
    uint32_t value = PAIRING_CODE_MIN + (esp_random() % (PAIRING_CODE_MAX - PAIRING_CODE_MIN + 1));
    char code[7];
    snprintf(code, sizeof(code), "%06lu", static_cast<unsigned long>(value));
    return String(code);
}

PairingSessionResponse createPairingSession(const String& deviceToken, const String& pairingCode) {
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    String url = String(API_BASE_URL) + "/iot-devices/" + deviceToken + "/pairing-session";
    http.begin(client, url);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Accept", "application/json");

    JsonDocument body;
    body["pairing_code"] = pairingCode;
    body["firmware_version"] = "0.1.0";
    String serialized;
    serializeJson(body, serialized);

    int code = http.POST(serialized);
    if (code != 201) {
        Serial.print("[Pairing] HTTP ");
        Serial.println(code);
        http.end();
        return {false, "", pairingCode};
    }

    String payload = http.getString();
    http.end();
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, payload);
    if (err || !doc["qr_payload"].is<const char*>()) {
        Serial.println("[Pairing] Resposta invalida.");
        return {false, "", pairingCode};
    }
    return {true, doc["qr_payload"].as<String>(), pairingCode};
}

PairingStatusResponse getPairingStatus(const String& deviceToken) {
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    String url = String(API_BASE_URL) + "/iot-devices/" + deviceToken + "/pairing-status";
    http.begin(client, url);
    http.addHeader("Accept", "application/json");

    int code = http.GET();
    if (code != 200) {
        Serial.print("[Pairing] Status HTTP ");
        Serial.println(code);
        http.end();
        return {false, false, ""};
    }

    String payload = http.getString();
    http.end();

    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, payload);
    if (err || !doc["paired"].is<bool>() || !doc["status"].is<const char*>()) {
        Serial.println("[Pairing] Status invalido.");
        return {false, false, ""};
    }

    return {true, doc["paired"].as<bool>(), doc["status"].as<String>()};
}
