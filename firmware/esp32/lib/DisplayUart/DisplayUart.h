#pragma once
#include <Arduino.h>
#include "PayloadParser.h"

void initDisplayUart();
void sendEventToDisplay(const FarolEvent& event);
void sendPairingToDisplay(const String& title, const String& qrPayload, const String& code, const String& shortId);
void sendStatusToDisplay(const String& title, const String& line1, const String& line2);
