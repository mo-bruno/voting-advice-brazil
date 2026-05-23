#include "LedStatus.h"

static LedColor currentColor = BLUE;

void initLed() {
    pinMode(LED_PIN_R, OUTPUT);
    pinMode(LED_PIN_G, OUTPUT);
    pinMode(LED_PIN_B, OUTPUT);
    setLed(BLUE);
}

void setLed(LedColor color) {
    currentColor = color;
    switch (color) {
        case GREEN:
            analogWrite(LED_PIN_R, 0);
            analogWrite(LED_PIN_G, 255);
            analogWrite(LED_PIN_B, 0);
            break;
        case YELLOW:
            analogWrite(LED_PIN_R, 255);
            analogWrite(LED_PIN_G, 200);
            analogWrite(LED_PIN_B, 0);
            break;
        case RED:
            analogWrite(LED_PIN_R, 255);
            analogWrite(LED_PIN_G, 0);
            analogWrite(LED_PIN_B, 0);
            break;
        case BLUE:
            analogWrite(LED_PIN_R, 0);
            analogWrite(LED_PIN_G, 0);
            analogWrite(LED_PIN_B, 200);
            break;
    }
}

void updateLed() {
    if (currentColor != BLUE) return;
    uint32_t t = millis() % 1000;
    uint8_t b = (t < 500)
        ? static_cast<uint8_t>(t * 255 / 500)
        : static_cast<uint8_t>((1000 - t) * 255 / 500);
    analogWrite(LED_PIN_B, b);
}

LedColor ledColorFromString(const String& color) {
    if (color == "green") return GREEN;
    if (color == "yellow") return YELLOW;
    if (color == "red") return RED;
    return BLUE;
}
