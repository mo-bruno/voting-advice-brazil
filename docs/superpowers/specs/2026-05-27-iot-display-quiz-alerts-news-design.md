# IoT Display Redesign + Quiz Feedback + Vote Alerts + News Feed

**Data:** 2026-05-27
**Branch:** nova a partir de `main` (sem cherry-pick de outras branches)
**Escopo:** firmware (Mega + ESP32), backend (FastAPI), mobile (Flutter)

---

## Contexto

O Farol Político é um gadget ESP32 + Arduino Mega com TFT 480×320 (MCUFRIEND_kbv). O ESP32 gerencia WiFi/MQTT e se comunica com o Mega via UART usando frames pipe-delimited. O app Flutter já tem pareamento, vinculação e desvinculação do dispositivo implementados. Este spec cobre quatro funcionalidades novas, todas numa branch limpa da `main`.

---

## 1. Redesign Visual do Display (Mega)

### Palette de cores (RGB565)

| Token Flutter       | Hex       | RGB565   | Uso                          |
|---------------------|-----------|----------|------------------------------|
| `background`        | `#131313` | `0x1082` | `tft.fillScreen()`           |
| `primaryContainer`  | `#0C2B6E` | `0x0156` | Header bar                   |
| `primary`           | `#FFFFFF` | `0xFFFF` | Títulos e labels             |
| `onSurface`         | `#E2E2E2` | `0xE71C` | Texto de corpo               |
| `onSurfaceVariant`  | `#9E9E9E` | `0x9CF3` | Texto secundário, timestamps |
| `outlineVariant`    | `#393939` | `0x39C7` | Linhas divisórias            |
| Alinhado (verde)    | `#1B6D24` | `0x1364` | Badge ALINHADO / CONCORDO    |
| Divergente (vermelho)| `#BA1A1A`| `0xB8C3` | Badge DIVERGENTE / DISCORDO  |
| Neutro (amarelo)    | `#FFE000` | `0xFEC0` | Badge ABSTENCAO / NEUTRO     |

### Princípios de layout

- Fundo escuro `0x1082` em toda a tela
- Header de 50px com fundo `0x0156`, texto branco bold, barra de acento branca de 4px na borda esquerda
- Cantos retos (sem border-radius) — alinhado ao estilo do Flutter
- Adafruit GFX Free Fonts para tipografia melhor (FreeSansBold9pt7b para corpo, FreeSansBold12pt7b para títulos)
- Linha divisória `0x39C7` entre zonas do layout
- Badges: retângulo preenchido + texto contrastante (preto sobre amarelo/verde, branco sobre vermelho)

### Telas

#### Tela: Vote Alert (`V|`)
```
[Header #0C2B6E, 50px]
  ▐ FAROL POLÍTICO                    [BADGE: ALINHADO/DIVERGENTE/ABSTENCAO]

[Barra 4px branca + nome do deputado grande]
  PT • SP                              ← #9E9E9E pequeno

[Linha divisória #393939]

  Votou SIM                            ← cor do alinhamento, grande
  Descrição da votação...              ← #E2E2E2 corpo

                          23/05 14:32  ← #9E9E9E direita, rodapé
```

#### Tela: Quiz Feedback (`Z|`)
```
[Header #0C2B6E]
  ▐ QUIZ                                    7 / 30

[Progress bar - largura proporcional, cor = resposta, altura 8px]

[Badge grande centralizado, fundo colorido]
  ✓  CONCORDO   (ou ✗ DISCORDO  ou —  NEUTRO)

                           Resposta registrada  ← #9E9E9E direita
```

#### Tela: Notícia (`N|`)
```
[Header #0C2B6E]
  ▐ NOTÍCIAS                                2 / 5

[Barra 4px branca + título da notícia, wrap em 2 linhas máx]

[Linha divisória]

  Agência Câmara  •  23/05/2026              ← #9E9E9E
```

#### Tela: Idle
```
[Header #0C2B6E]
  ▐ FAROL POLÍTICO

  ◉ Conectado ao app                    ← ponto verde + branco centralizado
  Aguardando proxima votacao...          ← #9E9E9E centralizado

                              ID: ABCD1234  ← bottom-right, #39C7 pequeno
```

#### Tela: Pareamento (`Q|`)
- Mantém QR code central
- Header novo padrão
- Código de pareamento em badge amarelo no rodapé (sem label "Código:")
- Short ID em #9E9E9E abaixo do badge

#### Tela: Status (`S|`)
- Header + título grande + 2 linhas de corpo — mesma estrutura, novas cores

### Protocolo UART — frames atualizados

| Frame | Campos | Descrição |
|-------|--------|-----------|
| `V\|` | header\|subtitle\|pageInfo\|status\|l1\|l2\|l3\|l4 | Vote alert (existente, redesenhado) |
| `Q\|` | qrPayload\|code\|shortId | Pareamento (simplificado — título fixo) |
| `S\|` | title\|line1\|line2 | Status genérico |
| `Z\|` | current\|total\|answer | **NOVO** — quiz feedback |
| `N\|` | index\|total\|title\|source\|date | **NOVO** — notícia |

---

## 2. Quiz Feedback (Flutter → Backend → MQTT → Display)

### Fluxo

```
quiz_page.dart
  → unawaited(IotDeviceSession.sendQuizPulse(answer, current, total))
    → POST /me/iot-device/quiz-pulse  {answer, current, total}
      → backend: busca device_token pelo anonymous_id
      → MQTT: {"type":"quiz_answer","answer":"agree","current":7,"total":30}
        → ESP32: parseia type == "quiz_answer"
        → sendQuizToDisplay(current, total, answer)   [DisplayUart]
        → LED pulsa cor por 1500ms, restaura estado anterior
          → Mega: Z|7|30|agree → showQuizScreen()
```

### Backend

**Endpoint:** `POST /me/iot-device/quiz-pulse`
- Header: `X-Farol-Anonymous-Id`
- Body: `{"answer": "agree"|"neutral"|"disagree", "current": int, "total": int}`
- Se não houver device vinculado → `204 No Content` silencioso (não bloqueia o quiz)
- Reutiliza `IotMqttPublisher` existente

### Flutter

- `IotDeviceSession` ganha `sendQuizPulse(ThesisAnswer answer, int current, int total)`
- `quiz_page.dart`: após cada `controller.answer()`, se `IotDeviceSession.instance.device != null`, chama `unawaited(IotDeviceSession.instance.sendQuizPulse(...))`
- `QuizController` não é alterado
- Falhas no pulse são ignoradas silenciosamente (fire-and-forget)

### Firmware ESP32

- `onMqttMessage`: novo branch `type == "quiz_answer"` → chama `sendQuizToDisplay()`
- Nova função em `DisplayUart`: `sendQuizToDisplay(int current, int total, const String& answer)`
  - Envia frame `Z|current|total|answer\n` para o Mega via Serial2
- LED: `setLed(answerColor)`, flag `ledRestoreAt = millis() + 1500`, restaurado no `loop()`

### Firmware Mega

- `loop()`: novo branch `msg.startsWith("Z|")` → parseia e chama `showQuizScreen(current, total, answer)`
- `showQuizScreen()`: renderiza tela de quiz feedback conforme layout da Seção 1

---

## 3. Vote Alerts (Backend Job → MQTT → Display)

### Backend — vote_notifier job

- APScheduler dentro do processo FastAPI, intervalo 30 minutos
- Para cada ator político com seguidores ativos:
  - Busca votações na Câmara API desde `last_checked_at` do ator
  - Para cada voto novo:
    - Calcula alinhamento com respostas do quiz do seguidor (`anonymous_id`)
    - Se o seguidor não tiver respostas de quiz: pula a publicação MQTT para esse device (não envia evento)
    - Alinhamento: `aligned` (mesmo sentido), `divergent` (sentido oposto), `abstained` (abstencao/ausência)
    - Persiste evento na tabela `iot_device_events` (device_token, payload JSON, published_at)
    - Publica MQTT: `{"type":"vote_alert","deputy_name":"...","party":"...","state":"...","vote":"Sim","alignment":"aligned","description":"...","timestamp_utc":"..."}`
  - Atualiza `last_checked_at` do ator
- Após processar votos: empurra batch de notícias atualizado para todos os devices com seguidores (ver Seção 4)

### Migrações Alembic necessárias

1. Nova tabela `iot_device_events`
2. Nova coluna `last_vote_checked_at TIMESTAMPTZ NULL` na tabela `political_actors`

### Tabela `iot_device_events`

```sql
id             SERIAL PRIMARY KEY
device_token   TEXT NOT NULL
event_type     TEXT NOT NULL   -- "vote_alert" | "news_batch"
payload        JSON NOT NULL
published_at   TIMESTAMPTZ NOT NULL
```

### Endpoint `GET /me/iot-device/last-event`

- Retorna o evento mais recente do tipo `vote_alert` para o device do usuário
- Usado pelo Flutter para exibir o último alerta na `iot_device_page`

### Flutter — `iot_device_page.dart`

- Quando device está vinculado: card "Último Evento" com nome do deputado, tipo de voto, badge de alinhamento colorido, timestamp
- `Timer.periodic(60s)` enquanto a página está aberta para atualizar o card
- `IotDeviceSession` ganha `loadLastEvent()` que chama o novo endpoint

### Firmware ESP32

- `onMqttMessage`: branch `type == "vote_alert"` → já existia estrutura `FarolEvent`, adaptar para novo payload
- LED muda para cor do alinhamento e permanece até próximo evento

---

## 4. Feed de Notícias no Display

### Quando o backend empurra notícias

1. **Ao finalizar o quiz**: endpoint `POST /me/quiz` (já existente) verifica se o usuário tem device vinculado; se sim, envia batch de notícias via MQTT imediatamente
2. **A cada ciclo do vote_notifier** (30min): atualiza batch para todos os devices com seguidores

### Backend — geração do batch

- Extrai temas das teses respondidas pelo `anonymous_id`
- Query para GNews API: `q={tema1} OR {tema2} Brasil` com `lang=pt` e `country=br`
- Cache de 1h por conjunto de temas (chave = hash SHA1 dos IDs dos temas ordenados)
- Se o `anonymous_id` não tiver respostas de quiz: não gera batch, não publica MQTT
- Seleciona os 5 artigos mais recentes
- Publica MQTT: `{"type":"news_batch","articles":[{"title":"...","source":"...","date":"DD/MM"},...]}` (máx 5 artigos)

### Firmware ESP32

- `onMqttMessage`: branch `type == "news_batch"` → armazena array de 5 structs `NewsArticle{title, source, date}` em memória
- No `loop()`: se `millis() - lastEventAt > 10000` (10s sem evento), entra em modo ciclo:
  - A cada 8s, avança índice e envia frame `N|index|total|title|source|date` ao Mega
- Quando chega novo `vote_alert` ou `quiz_answer`: interrompe ciclo, exibe evento, retoma ciclo após 10s

### Firmware Mega

- `loop()`: novo branch `msg.startsWith("N|")` → parseia e chama `showNewsScreen(index, total, title, source, date)`

---

## Dependências externas

| Dependência | Uso | Tier |
|-------------|-----|------|
| GNews API (`gnews.io`) | Fetch de notícias por tema | Free (100 req/dia) |
| HiveMQ Public Broker | MQTT (já em uso) | Free |
| APScheduler | Job 30min no FastAPI (já em uso) | — |

---

## O que NÃO está no escopo

- Push notifications FCM no app
- Histórico de alertas no Flutter (só último evento)
- Notícias no app Flutter (só no display)
- Múltiplos dispositivos por usuário
