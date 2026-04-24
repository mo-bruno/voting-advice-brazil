# Farol Político — Backend API

API FastAPI para o app de Voting Advice da Fase 1.

## Setup local

```bash
# 1. Instalar deps
uv sync

# 2. Copiar template de ambiente
cp .env.example .env
# (editar .env se necessário — defaults funcionam para dev)

# 3. Rodar migrations
uv run alembic upgrade head

# 4. Popular banco com dados 2022
uv run python -m app.infrastructure.database.seed

# 5. Rodar servidor
uv run fastapi dev app/main.py
```

API disponível em `http://localhost:8000`. Docs interativas em `/docs`.

## Comandos úteis

```bash
# Testes + cobertura
uv run pytest --cov=app --cov-report=term-missing

# Lint
uv run ruff check .

# Type check
uv run mypy app/

# Nova migration (depois de mudar models.py)
uv run alembic revision --autogenerate -m "descricao"

# Reverter última migration
uv run alembic downgrade -1
```

## Ambientes

| Variável | dev | staging/prod |
|---|---|---|
| `APP_ENV` | `dev` | `staging` ou `prod` |
| `DATABASE_URL` | `sqlite:///./voting_advice.db` | `postgresql+psycopg://...` |
| `GROQ_API_KEY` | opcional | obrigatório |
| `MQTT_BROKER_URL` | default HiveMQ | configurável |

Ver `.env.example` para lista completa.
