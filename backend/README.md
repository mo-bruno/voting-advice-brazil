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

# 4. Popular banco com a edição presidencial de 2026
uv run python -m app.infrastructure.database.seed

# 5. Rodar servidor
uv run fastapi dev app/main.py
```

API disponível em `http://localhost:8000`. Docs interativas em `/docs`.

## Edição eleitoral ativa

A API serve, por padrão, apenas `2026` e o cargo `presidente`. Configure o
recorte em `.env` quando necessário:

```dotenv
ACTIVE_ELECTION_YEAR=2026
ACTIVE_ELECTION_OFFICE=presidente
```

O seed lê `data/propostas/2026/candidates.json` e
`data/theses/2026/theses.json`, convive com dados anteriores e pode ser
executado novamente para reconciliar a edição. Candidaturas que saem do
snapshot tornam-se inativas; seus registros históricos permanecem no banco.
Teses usam identidade e versão editorial: mudar a formulação exige incrementar
`version`, criando uma nova tese e preservando as respostas ligadas à anterior.
Status, posições e evidências da versão atual são sincronizados a cada carga.
Uma versão antiga não pode substituir uma mais recente. Teses com `status: draft` ficam
armazenadas, mas não são retornadas pelo quiz. As fotos oficiais do TSE são
servidas localmente em `/data/fotos/2026/BR/<SQ_CANDIDATO>.jpg`.

Execute `alembic upgrade head` antes de carregar os dados. A migração
`0007_election_refresh` acrescenta os campos de versão, candidatura ativa e
proveniência. Em produção, o Cloud Build aplica a migração aditiva, publica uma
revisão intermediária com o ano que já recebe 100% do tráfego, carrega 2026 e
então publica a revisão final de 2026. A revisão intermediária lê a configuração
da revisão efetivamente publicada: ausência de `ACTIVE_ELECTION_YEAR` no legado
significa 2022; implantações seguintes preservam 2026. Assim, o código antigo
sem filtro eleitoral nunca recebe o banco com as duas edições. O início de uma
instância não reimporta dados: isso impede que uma
revisão antiga restaure seu snapshot após uma atualização. Seeds concorrentes
em PostgreSQL são serializados por um lock transacional.

Essa transição é automática em `cloudbuild.yaml`, por meio de
`scripts/deploy_presidential_backend.py`. O serviço deve existir e ter uma
única revisão recebendo 100% do tráfego. Falhas ao ler serviço/revisão,
configuração eleitoral desconhecida ou tráfego dividido interrompem a execução
antes do seed. O script publica sem tráfego e só encaminha as requisições após
a nova revisão ficar pronta. Se a carga de dados falhar, a revisão intermediária
continua atendendo e a transação é revertida; pode-se executar o build novamente.
Se a ativação final falhar na primeira transição, a revisão intermediária
continua servindo 2022 com filtros, mesmo com 2026 já armazenado. Não restaure
uma imagem anterior aos filtros eleitorais depois de carregar 2026.

O resultado inclui `counted_theses` (base efetivamente comparada) e
`answered_theses` (respostas não puladas). Sem nenhuma tese comparável, a
candidatura fica ao fim, com `rank: 0`; `score_percent: 0` é apenas uma sentinela
de compatibilidade com clientes antigos e não representa discordância.
O app exibe **Sem base comparável** nesse caso. A rota de justificativas expõe
também `quote`, `source_ref` e `source_url` para conferir a evidência.

As rotas eleitorais consultam o banco a cada leitura. O antigo cache local de
uma a seis horas foi retirado desse conjunto pequeno para não reexibir uma
candidatura removida, pergunta arquivada ou justificativa corrigida após a carga.
O cache de notícias e os demais serviços não foram alterados.

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
| `ACTIVE_ELECTION_YEAR` | `2026` | `2026` |
| `ACTIVE_ELECTION_OFFICE` | `presidente` | `presidente` |
| `DATABASE_URL` | `sqlite:///./voting_advice.db` | `postgresql+psycopg://...` |
| `GROQ_API_KEY` | opcional | obrigatório |
| `MQTT_BROKER_URL` | default HiveMQ | configurável |

Ver `.env.example` para lista completa.
