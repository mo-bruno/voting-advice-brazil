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
    drawHeader("QUIZ", current + "/" + total);

    int cur = current.toInt();
    int tot = total.toInt();
    if (tot <= 0) tot = 1;
    uint16_t barColor = answerColor(answer);

    // Barra de progresso (fina, discreta)
    tft.fillRect(0, 50, 480, 4, C_DIVIDER);
    tft.fillRect(0, 50, (int)(480.0f * cur / tot), 4, barColor);

    // Numero da pergunta
    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(C_MUTED);
    String prog = "Pergunta " + current + " de " + total;
    tft.setCursor((480 - (int)prog.length() * 9) / 2, 74);
    tft.print(prog);

    // Badge de resposta — maior e mais centralizado (420x100px)
    String label = answer == "agree"    ? "CONCORDO"
                 : answer == "disagree" ? "DISCORDO" : "NEUTRO";
    int bw = 420, bh = 100;
    int bx = (480 - bw) / 2;
    int by = 90;
    tft.fillRect(bx, by, bw, bh, barColor);
    // Borda interna sutil
    tft.drawRect(bx + 2, by + 2, bw - 4, bh - 4,
                 isLightColor(barColor) ? C_BG : C_WHITE);
    tft.setFont(&FreeSansBold12pt7b);
    tft.setTextColor(isLightColor(barColor) ? C_BLACK : C_WHITE);
    int textW = label.length() * 14;
    tft.setCursor(bx + (bw - textW) / 2, by + bh / 2 + 8);
    tft.print(label);

    drawDivider(210);

    // Confirmacao + icone checkmark
    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(barColor);
    tft.setCursor(14, 234);
    tft.print("Resposta registrada");

    // Percentual de conclusao
    int pct = (int)(100.0f * cur / tot);
    tft.setTextColor(C_MUTED);
    String pctStr = String(pct) + "% concluido";
    tft.setCursor(480 - (int)pctStr.length() * 9 - 14, 234);
    tft.print(pctStr);
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

// Q|qrPayload|code|shortId
static void showPairingScreen(const String& qrPayload, const String& code, const String& shortId) {
    tft.fillScreen(C_BG);
    drawHeader("CONECTAR FAROL");

    // QR: version 5 = 37 modules, moduleSize=4 → 148px, quietZone=16px (4 modulos, padrao ISO)
    const uint8_t QR_VERSION = 5;
    const int moduleSize = 4;
    const int quietZone  = moduleSize * 4;  // 16px — minimo exigido pelo padrao
    QRCode qrcode;
    uint8_t qrcodeData[qrcode_getBufferSize(QR_VERSION)];
    qrcode_initText(&qrcode, qrcodeData, QR_VERSION, ECC_LOW, qrPayload.c_str());
    int qrPx  = qrcode.size * moduleSize;            // 37*4 = 148
    int bgSize = qrPx + quietZone * 2;               // 148+32 = 180
    int bgX   = (480 - bgSize) / 2;                  // (480-180)/2 = 150
    int bgY   = 52;
    int qrX   = bgX + quietZone;                     // 150+16 = 166
    int qrY   = bgY + quietZone;                     // 52+16  = 68
    // Fundo branco com zona silenciosa correta
    tft.fillRect(bgX, bgY, bgSize, bgSize, C_WHITE);
    for (uint8_t row = 0; row < qrcode.size; row++) {
        for (uint8_t col = 0; col < qrcode.size; col++) {
            tft.fillRect(
                qrX + col * moduleSize,
                qrY + row * moduleSize,
                moduleSize, moduleSize,
                qrcode_getModule(&qrcode, col, row) ? C_BLACK : C_WHITE
            );
        }
    }
    // bgY + bgSize = 52+180 = 232 — tudo abaixo daqui e livre

    // Instrucao de escaneamento
    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(C_MUTED);
    const char* instr = "Escaneie com o app Farol";
    int instrX = (480 - (int)strlen(instr) * 9) / 2;
    tft.setCursor(instrX, 248);
    tft.print(instr);

    // Badge do codigo (y=255..287)
    int badgeW = code.length() * 14 + 20;
    int badgeX = (480 - badgeW) / 2;
    tft.fillRect(badgeX, 255, badgeW, 32, C_YELLOW);
    tft.setFont(&FreeSansBold12pt7b);
    tft.setTextColor(C_BLACK);
    tft.setCursor(badgeX + 10, 275);
    tft.print(code);

    // ID curto — bem abaixo do badge, sem sobreposicao
    tft.setFont(&FreeSansBold9pt7b);
    tft.setTextColor(C_DIVIDER);
    String idLabel = "ID: " + shortId;
    int idX = (480 - (int)idLabel.length() * 9) / 2;
    tft.setCursor(idX, 307);
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
