#include <Adafruit_GFX.h>
#include <MCUFRIEND_kbv.h>
#include <Fonts/FreeSansBold9pt7b.h>
#include <Fonts/FreeSansBold12pt7b.h>
#include <qrcode.h>

MCUFRIEND_kbv tft;

// Palette alinhada ao AppTheme Flutter
#define C_BG        0x1082  // #131313
#define C_HEADER    0x0156  // #0C2B6E
#define C_WHITE     0xFFFF  // #FFFFFF
#define C_BODY      0xE71C  // #E2E2E2
#define C_MUTED     0x9CF3  // #9E9E9E
#define C_DIVIDER   0x39C7  // #393939
#define C_GREEN     0x1364  // #1B6D24
#define C_RED       0xB8C3  // #BA1A1A
#define C_YELLOW    0xFEC0  // #FFE000
#define C_BLACK     0x0000

static uint16_t alignmentColor(const String& alignment) {
    if (alignment == "aligned")   return C_GREEN;
    if (alignment == "divergent") return C_RED;
    return C_YELLOW;
}

static uint16_t answerColor(const String& answer) {
    if (answer == "agree")    return C_GREEN;
    if (answer == "disagree") return C_RED;
    return C_YELLOW;
}

static bool isLightColor(uint16_t color) {
    return color == C_GREEN || color == C_YELLOW;
}

static void drawHeader(const String& title, const String& right = "") {
    tft.fillRect(0, 0, 480, 50, C_HEADER);
    tft.fillRect(0, 0, 4, 50, C_WHITE);  // accent bar
    tft.setFont(&FreeSansBold12pt7b);
    tft.setTextColor(C_WHITE);
    tft.setCursor(14, 34);
    tft.print(title);
    if (right.length() > 0) {
        tft.setFont(&FreeSansBold9pt7b);
        tft.setTextColor(C_MUTED);
        int16_t x = 480 - (int16_t)(right.length() * 11) - 12;
        tft.setCursor(x, 33);
        tft.print(right);
    }
}

static void drawDivider(int y) {
    tft.fillRect(0, y, 480, 1, C_DIVIDER);
}

static void drawBadge(int x, int y, int w, int h, uint16_t color, const String& label) {
    tft.fillRect(x, y, w, h, color);
    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(isLightColor(color) ? C_BLACK : C_WHITE);
    tft.setCursor(x + 10, y + h - 8);
    tft.print(label);
}

static void splitFields(const String& msg, String fields[], int maxFields, int start) {
    int index = 0;
    int begin = start;
    for (int i = start; i < (int)msg.length() && index < maxFields - 1; i++) {
        if (msg[i] == '|') {
            fields[index++] = msg.substring(begin, i);
            begin = i + 1;
        }
    }
    if (index < maxFields) fields[index] = msg.substring(begin);
}

// V|deputyName|party|state|vote|alignment|description|timestamp
static void showEventScreen(const String& deputyName, const String& party,
                             const String& state, const String& vote,
                             const String& alignment, const String& description,
                             const String& timestamp) {
    tft.fillScreen(C_BG);
    drawHeader("FAROL POLITICO");

    String badge = alignment == "aligned" ? "ALINHADO"
                 : alignment == "divergent" ? "DIVERGENTE" : "ABSTENCAO";
    uint16_t bColor = alignmentColor(alignment);
    int bw = badge.length() * 11 + 20;
    drawBadge(480 - bw - 8, 8, bw, 34, bColor, badge);

    // Nome do deputado com accent bar
    tft.fillRect(0, 58, 4, 22, C_WHITE);
    tft.setFont(&FreeSansBold12pt7b);
    tft.setTextColor(C_WHITE);
    tft.setCursor(14, 75);
    tft.print(deputyName.substring(0, 28));

    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(C_MUTED);
    tft.setCursor(14, 97);
    tft.print(party + " • " + state);

    drawDivider(110);

    // Tipo de voto
    tft.setFont(&FreeSansBold12pt7b);
    tft.setTextColor(bColor);
    tft.setCursor(14, 140);
    tft.print("Votou " + vote);

    // Descricao
    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(C_BODY);
    String desc = description.substring(0, 60);
    tft.setCursor(14, 165);
    tft.print(desc);
    if (description.length() > 60) {
        tft.setCursor(14, 185);
        tft.print(description.substring(60, 110));
    }

    // Timestamp alinhado a direita
    tft.setTextColor(C_MUTED);
    tft.setCursor(480 - (int)(timestamp.length() * 9) - 8, 310);
    tft.print(timestamp);
}

// Z|current|total|answer
static void showQuizScreen(const String& current, const String& total, const String& answer) {
    tft.fillScreen(C_BG);
    drawHeader("QUIZ", current + " / " + total);

    int cur = current.toInt();
    int tot = total.toInt();
    if (tot <= 0) tot = 1;
    int barW = (int)(460.0f * cur / tot);
    uint16_t barColor = answerColor(answer);
    tft.fillRect(10, 60, 460, 8, C_DIVIDER);
    tft.fillRect(10, 60, barW, 8, barColor);

    // Badge grande centralizado
    String label = answer == "agree"    ? "CONCORDO"
                 : answer == "disagree" ? "DISCORDO" : "NEUTRO";
    int bw = 300, bh = 80;
    int bx = (480 - bw) / 2, by = 100;
    tft.fillRect(bx, by, bw, bh, barColor);
    tft.setFont(&FreeSansBold12pt7b);
    tft.setTextColor(isLightColor(barColor) ? C_BLACK : C_WHITE);
    int textW = label.length() * 14;
    tft.setCursor(bx + (bw - textW) / 2, by + bh - 20);
    tft.print(label);

    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(C_MUTED);
    String reg = "Resposta registrada";
    tft.setCursor(480 - (int)(reg.length() * 9) - 8, 210);
    tft.print(reg);
}

// N|index|total|title|source|date
static void showNewsScreen(const String& index, const String& total,
                            const String& title, const String& source,
                            const String& date) {
    tft.fillScreen(C_BG);
    drawHeader("NOTICIAS", index + " / " + total);

    tft.fillRect(0, 58, 4, 22, C_WHITE);
    tft.setFont(&FreeSansBold12pt7b);
    tft.setTextColor(C_WHITE);
    tft.setCursor(14, 75);
    int breakAt = 36;
    if ((int)title.length() > breakAt) {
        tft.print(title.substring(0, breakAt));
        tft.setCursor(14, 100);
        tft.print(title.substring(breakAt, breakAt + 36));
    } else {
        tft.print(title);
    }

    drawDivider(120);

    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(C_MUTED);
    tft.setCursor(14, 148);
    tft.print(source + "  •  " + date);
}

static void showIdleScreen(const String& shortId) {
    tft.fillScreen(C_BG);
    drawHeader("FAROL POLITICO");

    // Ponto verde + texto
    tft.fillCircle(50, 165, 8, C_GREEN);
    tft.setFont(&FreeSansBold12pt7b);
    tft.setTextColor(C_WHITE);
    tft.setCursor(68, 172);
    tft.print("Conectado ao app");

    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(C_MUTED);
    String waiting = "Aguardando proxima votacao...";
    tft.setCursor((480 - (int)waiting.length() * 9) / 2, 210);
    tft.print(waiting);

    // Short ID no canto inferior direito
    tft.setTextColor(C_DIVIDER);
    String idLabel = "ID: " + shortId;
    tft.setCursor(480 - (int)idLabel.length() * 9 - 8, 310);
    tft.print(idLabel);
}

// S|title|line1|line2
static void showStatusScreen(const String& title, const String& line1, const String& line2) {
    tft.fillScreen(C_BG);
    drawHeader(title);
    tft.setFont(&FreeSansBold12pt7b);
    tft.setTextColor(C_BODY);
    tft.setCursor(14, 130);
    tft.print(line1);
    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(C_MUTED);
    tft.setCursor(14, 160);
    tft.print(line2);
}

static void drawQr(const String& payload) {
    const uint8_t QR_VERSION = 5;
    QRCode qrcode;
    uint8_t qrcodeData[qrcode_getBufferSize(QR_VERSION)];
    qrcode_initText(&qrcode, qrcodeData, QR_VERSION, ECC_LOW, payload.c_str());
    int moduleSize = 4;
    int qrSize = qrcode.size * moduleSize;
    int startX = (480 - qrSize) / 2;
    int startY = 65;
    tft.fillRect(startX - 8, startY - 8, qrSize + 16, qrSize + 16, C_WHITE);
    for (uint8_t y = 0; y < qrcode.size; y++) {
        for (uint8_t x = 0; x < qrcode.size; x++) {
            tft.fillRect(
                startX + x * moduleSize,
                startY + y * moduleSize,
                moduleSize, moduleSize,
                qrcode_getModule(&qrcode, x, y) ? C_BLACK : C_WHITE
            );
        }
    }
}

// Q|qrPayload|code|shortId
static void showPairingScreen(const String& qrPayload, const String& code, const String& shortId) {
    tft.fillScreen(C_BG);
    drawHeader("CONECTAR FAROL");
    drawQr(qrPayload);
    int badgeW = code.length() * 14 + 20;
    int badgeX = (480 - badgeW) / 2;
    tft.fillRect(badgeX, 290, badgeW, 26, C_YELLOW);
    tft.setFont(&FreeSansBold12pt7b);
    tft.setTextColor(C_BLACK);
    tft.setCursor(badgeX + 10, 308);
    tft.print(code);
    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(C_MUTED);
    String idLabel = "ID: " + shortId;
    int idX = (480 - (int)idLabel.length() * 9) / 2;
    tft.setCursor(idX, 318);
    tft.print(idLabel);
}

void setup() {
    Serial.begin(115200);
    Serial1.begin(115200);
    tft.begin(0x9486);
    tft.setRotation(1);
    tft.fillScreen(C_RED);   delay(150);
    tft.fillScreen(C_GREEN); delay(150);
    tft.fillScreen(C_HEADER);delay(150);
    showIdleScreen("------");
    Serial.println("[Mega] pronto");
}

void loop() {
    if (!Serial1.available()) return;
    String msg = Serial1.readStringUntil('\n');
    msg.trim();
    Serial.print("[Mega] ");
    Serial.println(msg.substring(0, 80));

    if (msg.startsWith("V|")) {
        // V|deputyName|party|state|vote|alignment|description|timestamp
        String f[8];
        splitFields(msg, f, 8, 2);
        showEventScreen(f[0], f[1], f[2], f[3], f[4], f[5], f[6]);
    } else if (msg.startsWith("Q|")) {
        // Q|qrPayload|code|shortId
        String f[3];
        splitFields(msg, f, 3, 2);
        showPairingScreen(f[0], f[1], f[2]);
    } else if (msg.startsWith("S|")) {
        // S|title|line1|line2
        String f[3];
        splitFields(msg, f, 3, 2);
        showStatusScreen(f[0], f[1], f[2]);
    } else if (msg.startsWith("Z|")) {
        // Z|current|total|answer
        String f[3];
        splitFields(msg, f, 3, 2);
        showQuizScreen(f[0], f[1], f[2]);
    } else if (msg.startsWith("N|")) {
        // N|index|total|title|source|date
        String f[5];
        splitFields(msg, f, 5, 2);
        showNewsScreen(f[0], f[1], f[2], f[3], f[4]);
    } else if (msg.startsWith("I|")) {
        // I|shortId
        String shortId = msg.substring(2);
        showIdleScreen(shortId);
    }
}
