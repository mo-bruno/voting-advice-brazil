#pragma once
#include <Arduino.h>

struct FarolEvent {
    String type;
    String color;
    String deputyName;
    String voteSummary;
    String timestampUtc;
};

bool parseFarolEvent(const char* json, FarolEvent& out);
