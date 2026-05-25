#pragma once
#include <Arduino.h>

struct PairingSessionResponse {
    bool ok;
    String qrPayload;
    String pairingCode;
};

String generatePairingCode();
PairingSessionResponse createPairingSession(const String& deviceToken, const String& pairingCode);
