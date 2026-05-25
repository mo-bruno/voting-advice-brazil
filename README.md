# Farol Político

Aplicativo de orientação eleitoral para o Brasil. O usuário responde teses políticas, escolhe pesos e recebe um ranking de candidatos por compatibilidade.

Projeto acadêmico da Universidade Presbiteriana Mackenzie.

## Stack

- Backend: Python 3.12, FastAPI, SQLAlchemy, Alembic, pytest, uv.
- Mobile/Web: Flutter, Firebase Analytics, HTTP API.
- Dados: propostas de governo de candidatos de 2022 e teses curadas em JSON.
- Deploy: Cloud Run para API e Firebase Hosting para o app web.

## Estrutura

```text
backend/   API, regra de scoring, banco e testes
mobile/    App Flutter para web/mobile
data/      Propostas, logos e teses do quiz
scripts/   Utilitários de apoio ao projeto
```

## Como rodar

### Backend

```bash
cd backend
uv sync
cp .env.example .env
uv run alembic upgrade head
uv run python -m app.infrastructure.database.seed
uv run fastapi dev app/main.py
```

API local: `http://localhost:8000`
Docs: `http://localhost:8000/docs`

### App Flutter

```bash
cd mobile
flutter pub get
flutter run
```

Para trocar a API em build/run:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

### Firmware

```bash
# ESP32
cp firmware/esp32/include/secrets.h.example firmware/esp32/include/secrets.h
# editar WIFI_SSID e WIFI_PASSWORD
pio run --project-dir firmware/esp32

# Arduino Mega
pio run --project-dir firmware/mega
```

O ESP32 gera um `device_token` persistente no primeiro boot, registra sessoes de pareamento no backend e assina `farol/{device_token}` via MQTT. O Mega recebe frames UART do ESP32 e renderiza telas `V|...` e QR de pareamento `Q|...`.

## Testes

```bash
cd backend
uv run pytest
uv run ruff check .
uv run mypy app/
```

```bash
cd mobile
flutter test
```

## API principal

- `GET /health`
- `GET /api/v1/quiz/questions`
- `POST /api/v1/quiz/submit`
- `GET /api/v1/candidates`
- `GET /api/v1/candidates/{id}/justifications`
- `GET /api/v1/themes`

## Contribuição

Leia [CONTRIBUTING.md](CONTRIBUTING.md). Abra PRs pequenos, com contexto claro e testes quando a mudança afetar comportamento.

## Licença

Licença ainda não definida.
