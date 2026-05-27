#pragma once
#include <Arduino.h>

struct PairingSessionResponse {
    bool ok;
    String qrPayload;
    String pairingCode;
};

struct PairingStatusResponse {
    bool ok;
    bool paired;
    String status;
};

String generatePairingCode();
PairingSessionResponse createPairingSession(const String& deviceToken, const String& pairingCode);
PairingStatusResponse getPairingStatus(const String& deviceToken);
