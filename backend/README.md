# Farol Político — Backend API

FastAPI para quiz de planos presidenciais de 2026, validação da demanda por acompanhamento político sem nome ou contato, comunidade sob aliases pseudônimos e notícias semanais da Câmara. A busca, as evidências e o acompanhamento pessoal permanecem implementados, mas o follow público fica retido por feature flag. O score do quiz compara respostas ponderadas com propostas curadas; votos legislativos não compõem esse score.

## Setup local

Execute em `backend/` com Python 3.12+ e uv:

```bash
uv sync --extra dev
cp .env.example .env
uv run alembic upgrade head
uv run python -m app.infrastructure.database.seed
uv run fastapi dev app/main.py
```

API em [localhost:8000](http://localhost:8000); contrato em [/docs](http://localhost:8000/docs), [/redoc](http://localhost:8000/redoc) e [/openapi.json](http://localhost:8000/openapi.json). Alembic gerencia o schema. O startup faz seed apenas em desenvolvimento; produção é carregada explicitamente pelo processo de implantação. Não inicia jobs periódicos.

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
`0009_election_refresh`, após as migrações 0007/0008 de IoT e comunidade, acrescenta os campos de versão, candidatura ativa e
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

## Configuração

`app/config.py` carrega variáveis de ambiente e `.env` via Pydantic Settings. `app/core/` permanece livre de frameworks. O arquivo [.env.example](.env.example) é um exemplo de desenvolvimento, com moderação explicitamente desativada; os padrões abaixo são os da classe `Settings`.

| Variável | Padrão | Uso |
|---|---|---|
| `APP_NAME` | `Farol Político API` | Título da aplicação |
| `APP_VERSION` | `0.1.0` | Versão informada pela aplicação |
| `APP_ENV` | `dev` | `dev`, `test`, `staging` ou `prod` |
| `DEBUG` | `false` | Configuração disponível; não substitui as opções do servidor |
| `DATABASE_URL` | `sqlite:///./voting_advice.db` | SQLite local; produção usa `postgresql+psycopg://...` |
| `DATA_DIR` | `../data` | Seed e arquivos estáticos; `/data` no container |
| `ALLOWED_ORIGINS` | `https://farol-politico-495210.web.app` | Origens CORS separadas por vírgulas |
| `MODERATION_MODE` | `enforce` | `enforce` chama NVIDIA NIM; `disabled` aprova sem modelo, para desenvolvimento |
| `NVIDIA_API_KEY` | ausente | Necessária para aprovar publicações em modo `enforce` |
| `NVIDIA_MODERATION_MODEL` | `nvidia/nemotron-3-super-120b-a12b` | Modelo hospedado usado pelo gate de moderação |
| `IOT_FEATURE_ENABLED` | `false` | Mantém rotas e efeitos do hardware dormentes |
| `POLITICIAN_FOLLOW_ENABLED` | `false` | Retém o acompanhamento real e mantém disponível somente o registro de interesse sem nome ou contato |
| `MQTT_BROKER_URL` | `mqtts://broker.hivemq.com:8883` | Broker da integração IoT histórica |
| `GNEWS_API_KEY` | ausente | Notícias temáticas do fluxo IoT histórico; não alimenta `/news/weekly` |

## Identidade e persistência

O Flutter gera um UUID v4 local chamado `anonymous_id`. Esse UUID é uma credencial privada de posse, enviada no header `X-Farol-Anonymous-Id` nas rotas `/me/...` e nas escritas da comunidade. Não há login, recuperação de conta ou garantia de que uma pessoa use uma única identidade. Não exponha o UUID em URLs, aliases ou conteúdo público.

Leituras da comunidade aceitam o mesmo header opcional para calcular `is_mine`. Respostas públicas de posts/comentários contêm `author_alias` (`u/` mais dez caracteres do SHA-256 do UUID) e `is_mine`, e não retornam o UUID do autor. O alias público é estável e pseudônimo; não serve como credencial. Headers obrigatórios ausentes ou UUIDs inválidos retornam 422. O Flutter exige os campos do contrato atual e não usa um UUID público legado como fallback. O hash contextualizado da validação de interesse é unidirecional; o navegador que mantém o UUID pode reproduzir o hash para consultar o registro. A API aceita retirada por esse identificador, mas a interface pública atual não oferece o botão; pedidos podem ser encaminhados ao canal de privacidade. A linha ativa deduplicada no banco é a fonte de verdade da demanda; eventos GA opcionais representam somente visitantes que aceitaram métricas. A retenção operacional máxima do interesse é de 180 dias.

`POST /quiz/submit` mantém o campo opcional `device_id` por compatibilidade com clientes antigos. Com `IOT_FEATURE_ENABLED=false`, a API usa as respostas enviadas somente para calcular o ranking e não cria nem atualiza `devices` ou `quiz_responses`, mesmo quando um cliente antigo envia `device_id`. Com a flag verdadeira, a persistência e o efeito histórico de IoT permanecem habilitados juntos. A API não exige esse identificador para calcular o resultado.

## Endpoints ativos

Todos os caminhos da tabela usam `/api/v1`.

| Método | Caminho | Comportamento |
|---|---|---|
| GET | `/quiz/questions` | Teses, com filtros de temas e limite |
| POST | `/quiz/submit` | Comparação documental presidencial de 2026, cobertura por candidatura e persistência somente com IoT habilitado e `device_id` |
| GET | `/candidates` | Candidatos com filtros e paginação |
| GET | `/candidates/{candidate_id}` | Perfil de candidato |
| GET | `/candidates/{candidate_id}/positions` | Posições nas teses |
| GET | `/candidates/{candidate_id}/justifications` | Posições e justificativas |
| GET | `/themes` | Temas disponíveis |
| GET | `/political-actors` | Índice de deputados atuais, busca/filtros/paginação |
| GET | `/political-actors/trending` | Ranking com mínimo de dois seguidores, sem contagem pública |
| GET | `/political-actors/{actor_id}` | Perfil de deputado |
| GET | `/political-actors/{actor_id}/evidence` | Evidências oficiais e estado do cache |
| GET, PUT, DELETE | `/me/politician-follow-interest` | Consultar, registrar idempotentemente ou retirar interesse; persiste apenas o hash contextualizado do UUID exclusivo do experimento |
| GET, PUT, DELETE | `/me/followed-actor` | Acompanhamento retido; responde 404 quando `POLITICIAN_FOLLOW_ENABLED=false` |
| GET, POST | `/community/posts` | Feed e publicação; filtros por político/tema e ordenação `score` ou `recent` |
| GET, DELETE | `/community/posts/{post_id}` | Detalhe com comentários; remoção pelo próprio autor |
| POST | `/community/posts/{post_id}/votes` | Voto `-1`, `0` ou `1`; zero desfaz o voto |
| POST | `/community/posts/{post_id}/comments` | Comentário com moderação síncrona |
| POST | `/community/posts/{post_id}/reports` | Denúncia; retorna 204 inclusive quando repetida |
| GET | `/news/weekly` | Notícias oficiais dos últimos sete dias, limite de 1 a 20 |
| GET | `/news/image?url=...` | Proxy de imagem da Câmara com allowlist e sem seguir redirects |

Fora do prefixo: `GET /health`, `/docs`, `/redoc`, `/openapi.json` e arquivos `/data/...` quando `DATA_DIR` existe. A Câmara fornece o índice e as evidências com cache/fallback e fornece também o feed oficial. GNews é uma integração histórica separada, desnecessária para essas consultas ativas.

## Integridade da comunidade

Posts (até 500 caracteres) e comentários (até 300) passam pelo NVIDIA NIM de forma síncrona antes da publicação em modo `enforce`. A política rejeita conteúdo fora do tema, alegações claramente inventadas ou manipuladoras e ataques contra pessoas ou grupos — incluindo xingamentos direcionados, humilhação sexual, ameaças, incentivo à violência, assédio e discurso de ódio. Críticas duras a projetos, governos e atos públicos continuam permitidas quando não atacam pessoas. O modelo padrão é `nvidia/nemotron-3-super-120b-a12b` e pode ser trocado por configuração. Aprovações e rejeições são auditadas com hash do conteúdo. Rejeição retorna 422; chave ausente, timeout, resposta inválida ou erro do provedor retorna 503 e impede a publicação. Em `disabled`, o gate aprova sem consultar o modelo; essa opção não é o padrão de produção.

Há limite persistido no banco por `anonymous_id`: cinco posts a cada dez minutos e dez comentários a cada dez minutos. Excesso retorna 429 com `Retry-After: 600`. Posts removidos continuam contando para a cota. O limite geral por IP de 60 requisições/minuto usa memória do processo; ele não é uma cota distribuída entre instâncias.

Posts e comentários podem revelar opinião política. A interface avisa antes de publicar que o texto é armazenado, exibido publicamente sob alias pseudônimo estável e enviado à NVIDIA NIM para moderação. O autor pode remover o conteúdo do próprio post; outro UUID recebe 403. O detalhe informa que o post foi removido, e ele não recebe novos votos ou comentários (410); IDs inexistentes retornam 404. A remoção é lógica: deixa uma lápide e preserva comentários da discussão. Pedidos de remoção de comentário e outros direitos usam `privacidade@fpolitico.com.br`. Os dados funcionais permanecem enquanto necessários à função, segurança, obrigação legal ou exercício de direitos; não há prazo fixo prometido para todos os registros da comunidade. Denúncias são deduplicadas por autor e podem disparar nova moderação. Não há painel de moderação humana ou edição de conteúdo.

## IoT histórico, desativado

`IOT_FEATURE_ENABLED=false` e `POLITICIAN_FOLLOW_ENABLED=false` são os padrões e são passados explicitamente pelo deploy Cloud Run iniciado em [cloudbuild.yaml](../cloudbuild.yaml). O Flutter também é compilado com ambas desativadas no workflow Firebase. Nessas condições, as rotas `/iot-devices/...` e `/me/iot-device...` não entram no OpenAPI, a submissão de quiz não dispara MQTT/GNews e o follow legado responde 404 sem apagar dados existentes.

As fontes GNews, o publisher MQTT, o firmware e o módulo `app/infrastructure/scheduler.py` foram retidos como código dormente. Esse módulo agora oferece uma única execução protegida pela flag: `uv run python -m app.infrastructure.scheduler`. Ele não agenda próximas execuções e não faz trabalho externo com a flag desativada. Não há scheduler no lifespan da API nem agendamento automático no deploy.

Ativar backend e Flutter é apenas desenvolvimento histórico sem suporte, com vínculo físico e invocação externa do job quando necessária. O job trata abstenção como `abstained`; outros votos permanecem `pending`, sem inferir alinhamento pela resposta “Sim”/“Não”. Reserva eventos no banco antes de publicar para deduplicar; uma falha do broker após a reserva suprime nova tentativa, portanto não garante entrega. Ativar as flags não conclui um motor de alinhamento nem um scheduler de produção. Veja [firmware/README.md](../firmware/README.md).

## Verificação e migrations

```bash
uv sync --extra dev
uv lock --check
uv run pytest
uv run ruff check .
uv run mypy app/
# Um teste focado não deve exigir a cobertura global de 80%:
uv run pytest tests/test_config.py -q --no-cov
uv run ruff check app/config.py tests/test_config.py
uv run mypy app/config.py
```

A suíte completa aplica o mínimo de cobertura global definido no `pyproject.toml`. Para mudanças no schema, gere e revise uma migration com `uv run alembic revision --autogenerate -m "descricao"` e aplique `uv run alembic upgrade head`. O Cloud Build aplica migrations antes de publicar a revisão.
