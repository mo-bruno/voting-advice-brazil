#include "DeviceToken.h"
#include <Preferences.h>
#include <esp_random.h>
#include "config.h"

static String generateUuidV4() {
    uint8_t raw[16];
    esp_fill_random(raw, sizeof(raw));
    raw[6] = (raw[6] & 0x0F) | 0x40;
    raw[8] = (raw[8] & 0x3F) | 0x80;

    char buf[37];
    snprintf(buf, sizeof(buf),
        "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        raw[0], raw[1], raw[2], raw[3],
        raw[4], raw[5],
        raw[6], raw[7],
        raw[8], raw[9],
        raw[10], raw[11], raw[12], raw[13], raw[14], raw[15]);
    return String(buf);
}

String getOrCreateDeviceToken() {
    Preferences prefs;
    prefs.begin(NVS_NAMESPACE, false);
    String token = prefs.getString(NVS_TOKEN_KEY, "");
    if (token.isEmpty()) {
        token = generateUuidV4();
        prefs.putString(NVS_TOKEN_KEY, token);
        Serial.println("[DeviceToken] Novo token gerado: " + token);
    } else {
        Serial.println("[DeviceToken] Token recuperado: " + token);
    }
    prefs.end();
    return token;
}
