#include "DisplayUart.h"
#include "config.h"

static String sanitize(const String& value) {
    String out = value;
    out.replace("|", "/");
    return out;
}

static String utf8ToLatin1(const String& s) {
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

static void wrapText(const String& text, String lines[3], int maxLen = 28) {
    String remaining = text;
    for (int i = 0; i < 3; i++) {
        if (remaining.length() == 0) {
            lines[i] = "";
        } else if (static_cast<int>(remaining.length()) <= maxLen) {
            lines[i] = remaining;
            remaining = "";
        } else {
            int cut = maxLen;
            while (cut > 0 && remaining.charAt(cut) != ' ') cut--;
            if (cut == 0) cut = maxLen;
            lines[i] = remaining.substring(0, cut);
            remaining = remaining.substring(cut);
            remaining.trim();
        }
    }
}

static String colorLabel(const String& color) {
    if (color == "green") return "CONECTADO";
    if (color == "yellow") return "ABSTENCAO";
    if (color == "red") return "DIVERGENTE";
    return "PENDENTE";
}

static String formatTimestamp(const String& ts) {
    if (ts.length() < 16) return ts;
    return ts.substring(8, 10) + "/" + ts.substring(5, 7) + " " +
           ts.substring(11, 13) + ":" + ts.substring(14, 16);
}

void initDisplayUart() {
    Serial2.begin(UART_BAUD, SERIAL_8N1, UART_RX_PIN, UART_TX_PIN);
}

void sendStatusToDisplay(const String& title, const String& line1, const String& line2) {
    String frame = "V|" + sanitize(title) + "|||INFO|" +
                   sanitize(line1) + "|" + sanitize(line2) + "||\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}

void sendEventToDisplay(const FarolEvent& event) {
    String summary = sanitize(utf8ToLatin1(event.voteSummary));
    String lines[3];
    wrapText(summary, lines);
    String frame = "V|" + sanitize(utf8ToLatin1(event.deputyName)) + "|" +
                   colorLabel(event.color) + "|1/1|" + event.color + "|" +
                   lines[0] + "|" + lines[1] + "|" + lines[2] + "|" +
                   formatTimestamp(event.timestampUtc) + "\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}

void sendPairingToDisplay(const String& title, const String& qrPayload, const String& code, const String& shortId) {
    String frame = "Q|" + sanitize(title) + "|" + sanitize(qrPayload) + "|" +
                   sanitize(code) + "|" + sanitize(shortId) + "\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}
