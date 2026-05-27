#pragma once
#include <Arduino.h>
#include "PayloadParser.h"

void initDisplayUart();
void sendEventToDisplay(const FarolEvent& event);
void sendPairingToDisplay(const String& qrPayload, const String& code, const String& shortId);
void sendStatusToDisplay(const String& title, const String& line1, const String& line2);
void sendQuizToDisplay(int current, int total, const String& answer);
void sendNewsToDisplay(int index, int total, const String& title,
                       const String& source, const String& date);
void sendIdleToDisplay(const String& shortId);
