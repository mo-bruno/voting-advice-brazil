#pragma once
#include <Arduino.h>
#include "config.h"

enum LedColor { GREEN, YELLOW, RED, BLUE };

void initLed();
void setLed(LedColor color);
void updateLed();
LedColor ledColorFromString(const String& color);
