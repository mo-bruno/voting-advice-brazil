# Farol Político

Aplicativo acadêmico de orientação eleitoral para o Brasil, da Universidade Presbiteriana Mackenzie.

O produto atual reúne uma comparação de planos presidenciais de 2026, consulta de deputados atuais e evidências oficiais da Câmara, acompanhamento de um político, comunidade anônima e notícias oficiais dos últimos sete dias. Os resultados usam respostas e pesos do quiz para comparar posições documentadas; as evidências legislativas são informativas e não compõem esse score. Não há índice de consistência implementado.

O app gera e guarda localmente um UUID v4 (`anonymous_id`). Ao enviar o quiz, transmite esse UUID no campo `device_id`, e as respostas são persistidas no backend por UUID. Na comunidade e no acompanhamento, `X-Farol-Anonymous-Id` funciona como credencial privada de posse; as respostas públicas mostram `author_alias` e `is_mine`, sem divulgar o UUID do autor. Não há conta autenticada ou recuperação dessa identidade.

## Stack e estrutura

- `backend/`: Python 3.12+, FastAPI, SQLAlchemy, Alembic, pytest e uv.
- `mobile/`: Flutter para web/mobile, HTTP API e Firebase Analytics.
- `data/`: planos, teses e fotos oficiais de 2026, além do acervo de 2022.
- `scripts/`: utilitários de apoio.
- `firmware/`: código histórico de hardware IoT, atualmente dormente.

## Rodar localmente

```bash
cd backend
uv sync --extra dev
cp .env.example .env
uv run alembic upgrade head
uv run python -m app.infrastructure.database.seed
uv run fastapi dev app/main.py
```

API: [localhost:8000](http://localhost:8000). Contrato interativo: [/docs](http://localhost:8000/docs), [/redoc](http://localhost:8000/redoc) e [/openapi.json](http://localhost:8000/openapi.json).

Por padrão, a API serve somente a eleição presidencial de 2026. O recorte é
explícito no ambiente:

```dotenv
ACTIVE_ELECTION_YEAR=2026
ACTIVE_ELECTION_OFFICE=presidente
```

O retrato de 20 de setembro de 2026 contém 13 candidaturas inseridas na urna e
as respectivas fotos oficiais. Das 36 teses editoriais recebidas, os itens 26
e 34 foram divididos em duas decisões cada: 38 registros são preservados, mas
somente nove com contraste e evidência suficientes ficam ativos no quiz. Os
demais permanecem como `draft` e não entram na pontuação. O conjunto continua
sem certificação ou validação editorial humana. A leitura integral automatizada
dos 13 planos (836 páginas) revisou as 117 combinações do núcleo: 37 posições
categóricas, quatro condicionais e 76 sem manifestação suficiente no escopo
exato. Nenhuma dessas 117 células está pendente. Em 47 dos 78 pares não existe
nenhuma tese categórica em comum. Consulte os limites e decisões em
[data/theses/2026/REVIEW.md](data/theses/2026/REVIEW.md) antes de interpretar
os resultados como uma comparação completa. A interface apresenta candidaturas
em ordem alfabética, sem destacar vencedor nem recomendar voto.

Cada resultado informa quantas respostas possuem evidência comparável no
plano. Ausência de evidência não equivale a discordância: candidaturas sem base
comparável não recebem colocação nem porcentagem na interface. As fontes e os
trechos dos planos podem ser consultados na comparação de respostas.

Atualizações de dados passam pelos testes do backend e acionam o deploy.
O carregamento reconcilia candidaturas, posições e evidências; preserva
respostas históricas e exige nova versão quando uma tese muda de significado.
Em produção, ele é executado uma vez pelo processo de implantação.

Os quatro pacotes oficiais usados — candidaturas, situação complementar,
planos e fotos — estão registrados com URL, horário, tamanho e SHA-256 em
`experimento-eleicoes-2026/fontes/recursos_oficiais.json`.

Para reconstruir os JSONs e retratos a partir dos pacotes preservados:

É necessário Python 3.12 e `pdfinfo` (pacote Poppler). As entradas editoriais
textuais são versionadas; os ZIPs grandes ficam fora do Git e devem ser os
mesmos snapshots identificados pelos hashes, pois os URLs do TSE são mutáveis.

```bash
python scripts/build_presidential_2026_data.py \
  --candidates-zip experimento-eleicoes-2026/fontes/arquivos/consulta_cand_2026_20260920.zip \
  --complement-zip experimento-eleicoes-2026/fontes/arquivos/consulta_cand_complementar_2026_20260920.zip \
  --plans-zip experimento-eleicoes-2026/fontes/arquivos/proposta_governo_2026_BR_20260919.zip \
  --photos-zip experimento-eleicoes-2026/fontes/arquivos/foto_cand2026_BR_div_20260919.zip \
  --experiment-dir experimento-eleicoes-2026 \
  --data-dir data
```

### App Flutter

O exemplo de ambiente usa `MODERATION_MODE=disabled` para desenvolvimento: posts e comentários são aprovados sem chamar o provedor. O padrão da aplicação é `enforce`, que exige uma chave NVIDIA Build/NIM válida para publicar. Consulte a [configuração do backend](backend/README.md).

Em outro terminal:

```bash
cd mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1 --dart-define=IOT_FEATURE_ENABLED=false
```

`API_BASE_URL` deve incluir `/api/v1`. Em emuladores/aparelhos, ajuste o host para alcançar sua máquina. Para web, inclua a origem/porta do app em `ALLOWED_ORIGINS` no backend.

## API ativa

Os caminhos abaixo usam o prefixo `/api/v1`, exceto saúde e documentação.

| Família | Métodos e caminhos |
|---|---|
| Saúde e contrato | `GET /health`, `GET /docs`, `GET /redoc`, `GET /openapi.json` |
| Quiz | `GET /quiz/questions`, `POST /quiz/submit` |
| Presidência 2026 | `GET /candidates`, `GET /candidates/{candidate_id}`, `GET /candidates/{candidate_id}/positions`, `GET /candidates/{candidate_id}/justifications` |
| Temas | `GET /themes` |
| Deputados atuais | `GET /political-actors`, `GET /political-actors/trending`, `GET /political-actors/{actor_id}`, `GET /political-actors/{actor_id}/evidence` |
| Acompanhamento pessoal | `GET`, `PUT`, `DELETE /me/followed-actor` |
| Comunidade | `GET`, `POST /community/posts`; `GET`, `DELETE /community/posts/{post_id}`; `POST /community/posts/{post_id}/votes`, `/comments`, `/reports` |
| Notícias oficiais | `GET /news/weekly`, `GET /news/image?url=...` |

Arquivos públicos em `/data/...` são servidos quando `DATA_DIR` existe. Notícias semanais vêm da Câmara; seu proxy de imagens aceita apenas hosts autorizados da Câmara. Detalhes de identidade, limites, moderação e erros estão no [README do backend](backend/README.md).

## IoT dormente e deploy

O Farol físico está desativado e invisível por padrão: `IOT_FEATURE_ENABLED=false` no backend e no build Flutter. As rotas de pareamento/eventos não são registradas na API desativada; o app não oferece pareamento nem consulta status do dispositivo. O quiz e o acompanhamento continuam disponíveis.

Cloud Build publica a API no Cloud Run com `IOT_FEATURE_ENABLED=false`; o workflow de Firebase Hosting compila o app com `--dart-define=IOT_FEATURE_ENABLED=false`. Nenhum scheduler é iniciado pelo processo da API.

A publicação automática da interface aguarda o sucesso do backend e usa o mesmo commit. Mudanças apenas na interface também acionam essa sequência para manter um único fluxo de release. A aprovação exigida por `main` não é contornada; consulte [PUBLICACAO_2026.md](PUBLICACAO_2026.md) para ordem, verificações e recuperação.

Ativar as duas flags é apenas uma opção de desenvolvimento histórico sem suporte. Isso não fornece um motor completo de alinhamento entre votos e respostas, nem um scheduler de produção. O código retido exige invocação externa do job de execução única e ainda possui limitações de entrega. MQTT e GNews permanecem como integrações históricas do fluxo físico. Consulte [firmware/README.md](firmware/README.md) e o [desenho de desativação](docs/superpowers/specs/2026-09-09-disable-iot-and-close-gaps-design.md).

## Verificação

```bash
cd backend
uv sync --extra dev
uv lock --check
uv run pytest
uv run ruff check .
uv run mypy app/
# Teste focado: não aplicar o mínimo de cobertura global a um único arquivo
uv run pytest tests/test_config.py -q --no-cov
```

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define=IOT_FEATURE_ENABLED=false
```

## Contribuição e licença

Leia [CONTRIBUTING.md](CONTRIBUTING.md). Abra PRs com contexto claro e testes proporcionais às mudanças de comportamento. Licença ainda não definida.
