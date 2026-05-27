#include "DisplayUart.h"
#include "config.h"

static String sanitize(const String& value) {
    String out = value;
    out.replace("|", "/");
    out.replace("\n", " ");
    out.replace("\r", "");
    return out;
}

static String utf8ToAscii(const String& s) {
    String out;
    const uint8_t* p = reinterpret_cast<const uint8_t*>(s.c_str());
    while (*p) {
        if (*p < 0x80) {
            out += static_cast<char>(*p++);
        } else if (*p == 0xC2 && *(p + 1) >= 0x80 && *(p + 1) <= 0xBF) {
            out += static_cast<char>(*(p + 1));
            p += 2;
        } else if (*p == 0xC3 && *(p + 1) >= 0x80 && *(p + 1) <= 0xBF) {
            out += static_cast<char>(*(p + 1) + 0x40);
            p += 2;
        } else {
            out += '?';
            p++;
        }
    }
    return out;
}

static String formatTimestamp(const String& ts) {
    if (ts.length() < 16) return ts;
    return ts.substring(11, 16) + " " +
           ts.substring(8, 10) + "/" + ts.substring(5, 7);
}

void initDisplayUart() {
    Serial2.begin(UART_BAUD, SERIAL_8N1, UART_RX_PIN, UART_TX_PIN);
}

void sendStatusToDisplay(const String& title, const String& line1, const String& line2) {
    String frame = "S|" + sanitize(title) + "|" +
                   sanitize(line1) + "|" + sanitize(line2) + "\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}

// V|deputyName|party|state|vote|alignment|description|timestamp
void sendEventToDisplay(const FarolEvent& event) {
    String ts = formatTimestamp(event.timestampUtc);
    String frame = "V|" + sanitize(utf8ToAscii(event.deputyName)) + "|" +
                   sanitize(event.party) + "|" +
                   sanitize(event.state) + "|" +
                   sanitize(event.vote) + "|" +
                   sanitize(event.alignment) + "|" +
                   sanitize(utf8ToAscii(event.description.length() > 0 ? event.description : event.voteSummary)) + "|" +
                   sanitize(ts) + "\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}

// Q|qrPayload|code|shortId
void sendPairingToDisplay(const String& qrPayload, const String& code, const String& shortId) {
    String frame = "Q|" + sanitize(qrPayload) + "|" +
                   sanitize(code) + "|" + sanitize(shortId) + "\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}

// Z|current|total|answer
void sendQuizToDisplay(int current, int total, const String& answer) {
    String frame = "Z|" + String(current) + "|" + String(total) + "|" + sanitize(answer) + "\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}

// N|index|total|title|source|date
void sendNewsToDisplay(int index, int total, const String& title,
                       const String& source, const String& date) {
    String frame = "N|" + String(index) + "|" + String(total) + "|" +
                   sanitize(utf8ToAscii(title)) + "|" +
                   sanitize(source) + "|" + sanitize(date) + "\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}

// I|shortId
void sendIdleToDisplay(const String& shortId) {
    String frame = "I|" + sanitize(shortId) + "\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}
