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

    if (!doc["type"].is<const char*>()) {
        return false;
    }

    out.type        = doc["type"].as<String>();
    out.color       = doc["color"] | "yellow";
    out.alignment   = doc["alignment"] | "abstained";
    out.deputyName  = doc["deputy_name"] | "";
    out.party       = doc["party"] | "";
    out.state       = doc["state"] | "";
    out.vote        = doc["vote"] | "";
    out.description = doc["description"] | "";
    out.voteSummary = doc["vote_summary"] | out.description;
    out.timestampUtc = doc["timestamp_utc"] | "";
    return true;
}
