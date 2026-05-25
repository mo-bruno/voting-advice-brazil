#include "PayloadParser.h"
#include <ArduinoJson.h>

bool parseFarolEvent(const char* json, FarolEvent& out) {
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, json);
    if (err) {
        Serial.print("[Parser] JSON invalido: ");
        Serial.println(err.c_str());
        return false;
    }

    if (!doc["color"].is<const char*>() ||
        !doc["deputy_name"].is<const char*>() ||
        !doc["vote_summary"].is<const char*>() ||
        !doc["timestamp_utc"].is<const char*>()) {
        Serial.println("[Parser] Campos obrigatorios ausentes.");
        return false;
    }

    out.type = doc["type"].is<const char*>() ? doc["type"].as<String>() : "vote_event";
    out.color = doc["color"].as<String>();
    out.deputyName = doc["deputy_name"].as<String>();
    out.voteSummary = doc["vote_summary"].as<String>();
    out.timestampUtc = doc["timestamp_utc"].as<String>();
    return true;
}
