#include <Adafruit_GFX.h>
#include <MCUFRIEND_kbv.h>
#include <qrcode.h>

MCUFRIEND_kbv tft;

#define BLACK   0x0000
#define WHITE   0xFFFF
#define BLUE    0x041F
#define YELLOW  0xFFE0
#define GRAY    0x4208
#define GREEN   0x07E0
#define RED     0xF800

static uint16_t statusColor(const String& status) {
    if (status == "green" || status == "CONECTADO") return GREEN;
    if (status == "red" || status == "DIVERGENTE") return RED;
    if (status == "yellow" || status == "ABSTENCAO") return YELLOW;
    return GRAY;
}

static void splitFields(const String& msg, String fields[], int maxFields, int start) {
    int index = 0;
    int begin = start;
    for (int i = start; i < static_cast<int>(msg.length()) && index < maxFields - 1; i++) {
        if (msg[i] == '|') {
            fields[index++] = msg.substring(begin, i);
            begin = i + 1;
        }
    }
    if (index < maxFields) {
        fields[index] = msg.substring(begin);
    }
}

static void showEventScreen(
    const String& header,
    const String& subtitle,
    const String& pageInfo,
    const String& status,
    const String& l1,
    const String& l2,
    const String& l3,
    const String& l4
) {
    tft.fillScreen(BLACK);
    tft.fillRect(0, 0, 480, 45, BLUE);
    tft.setTextColor(WHITE);
    tft.setTextSize(3);
    tft.setCursor(10, 12);
    tft.print(header);

    if (pageInfo.length() > 0) {
        tft.setTextSize(2);
        int x = 480 - (pageInfo.length() * 12) - 10;
        tft.setCursor(x, 17);
        tft.print(pageInfo);
    }

    if (subtitle.length() > 0) {
        tft.setTextColor(YELLOW);
        tft.setTextSize(2);
        tft.setCursor(10, 55);
        tft.print(subtitle);
    }

    if (status.length() > 0) {
        uint16_t color = statusColor(status);
        int width = status.length() * 14 + 16;
        tft.fillRoundRect(10, 82, width, 28, 4, color);
        tft.setTextColor((color == YELLOW || color == GREEN) ? BLACK : WHITE);
        tft.setTextSize(2);
        tft.setCursor(18, 89);
        tft.print(status);
    }

    tft.setTextColor(WHITE);
    tft.setTextSize(2);
    int y = 130;
    if (l1.length() > 0) { tft.setCursor(10, y); tft.print(l1); }
    y += 32;
    if (l2.length() > 0) { tft.setCursor(10, y); tft.print(l2); }
    y += 32;
    if (l3.length() > 0) { tft.setCursor(10, y); tft.print(l3); }
    y += 32;
    if (l4.length() > 0) { tft.setCursor(10, y); tft.print(l4); }
}

static void drawQr(const String& payload) {
    const uint8_t QR_VERSION = 5;
    QRCode qrcode;
    uint8_t qrcodeData[qrcode_getBufferSize(QR_VERSION)];
    qrcode_initText(&qrcode, qrcodeData, QR_VERSION, ECC_LOW, payload.c_str());

    int moduleSize = 4;
    int qrSize = qrcode.size * moduleSize;
    int startX = (480 - qrSize) / 2;
    int startY = 68;

    tft.fillRect(startX - 8, startY - 8, qrSize + 16, qrSize + 16, WHITE);
    for (uint8_t y = 0; y < qrcode.size; y++) {
        for (uint8_t x = 0; x < qrcode.size; x++) {
            uint16_t color = qrcode_getModule(&qrcode, x, y) ? BLACK : WHITE;
            tft.fillRect(startX + x * moduleSize, startY + y * moduleSize, moduleSize, moduleSize, color);
        }
    }
}

static void showPairingScreen(const String& title, const String& qrPayload, const String& code) {
    tft.fillScreen(BLACK);
    tft.fillRect(0, 0, 480, 45, BLUE);
    tft.setTextColor(WHITE);
    tft.setTextSize(3);
    tft.setCursor(10, 12);
    tft.print(title);

    drawQr(qrPayload);

    tft.setTextColor(YELLOW);
    tft.setTextSize(2);
    tft.setCursor(10, 290);
    tft.print("Codigo: ");
    tft.print(code);
}

void setup() {
    Serial.begin(115200);
    Serial1.begin(115200);

    tft.begin(0x9486);
    tft.setRotation(1);
    tft.fillScreen(RED);
    delay(250);
    tft.fillScreen(GREEN);
    delay(250);
    tft.fillScreen(BLUE);
    delay(250);
    tft.fillScreen(BLACK);
    tft.setTextColor(WHITE);
    tft.setTextSize(3);
    tft.setCursor(10, 140);
    tft.print("Aguardando ESP32...");
    Serial.println("[Mega] pronto");
}

void loop() {
    if (!Serial1.available()) return;
    String msg = Serial1.readStringUntil('\n');
    msg.trim();
    Serial.print("[Mega] recebi: ");
    Serial.println(msg.substring(0, 80));

    if (msg.startsWith("V|")) {
        String fields[8];
        splitFields(msg, fields, 8, 2);
        showEventScreen(
            fields[0], fields[1], fields[2], fields[3],
            fields[4], fields[5], fields[6], fields[7]
        );
    } else if (msg.startsWith("Q|")) {
        String fields[3];
        splitFields(msg, fields, 3, 2);
        showPairingScreen(fields[0], fields[1], fields[2]);
    }
}
