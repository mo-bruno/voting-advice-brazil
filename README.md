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
as respectivas fotos oficiais. A edição classifica as 910 combinações de 70
formulações: as 38 derivadas das 36 teses recebidas e
32 escolhas adicionais de política pública extraídas do banco presidencial.
O questionário publica 30 perguntas, sendo 23 no núcleo e sete complementares.
As outras 40 ficam documentadas como `draft` por falta de ambos os polos,
redundância com outra pergunta ou inadequação de escopo.

Nas 30 perguntas publicadas há 116 posições categóricas, 20 condicionais ou
mistas e 254 casos sem manifestação suficiente no escopo exato. Nenhuma das
910 células está pendente. Em 20 dos 78 pares de candidaturas não existe tese
publicada com posição categórica de ambos. Consulte os limites e decisões em
[data/theses/2026/REVIEW.md](data/theses/2026/REVIEW.md) antes de interpretar
os resultados como uma comparação completa. A tela principal mostra foto,
nome, partido e percentual de cada candidatura, do maior percentual para o
menor, sem recomendar voto. Candidaturas sem respostas comparáveis exibem `—`
e aparecem no final da lista.

O cálculo mantém os pesos das respostas e considera somente perguntas
respondidas pelo usuário com posição categórica documentada no plano da
candidatura. Concordar nas nove respostas comparáveis resulta em 100%, mesmo
que o usuário tenha respondido 30 perguntas. Ausência de evidência não equivale
a discordância e não entra no denominador.

Os cartões não exibem contagens de respostas comparáveis nem explicações
extensas. A cobertura, as posições ausentes, as fontes e os trechos dos planos
podem ser consultados na comparação de respostas.

Atualizações de dados passam pelos testes do backend e acionam o deploy.
O carregamento reconcilia candidaturas, posições e evidências; preserva
respostas históricas e exige nova versão quando uma tese muda de significado.
Em produção, ele é executado uma vez pelo processo de implantação.

Os quatro pacotes oficiais usados — candidaturas, situação complementar,
planos e fotos — estão registrados com URL, horário, tamanho e SHA-256 em
`experimento-eleicoes-2026/fontes/recursos_oficiais.json`.

Para reconstruir os JSONs e retratos a partir dos pacotes preservados:

É necessário Python 3.12, `pdfinfo` e `pdftotext` (pacote Poppler). As entradas
editoriais textuais, inclusive o banco de 111 formulações, são versionadas e
validadas por hash; os ZIPs grandes ficam fora do Git e devem ser os
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

## Compartilhamento do quiz

Na tela de resultados, **Compartilhar resultado** abre uma prévia com dois tipos de imagem: **maior alinhamento**, destacando uma candidatura, ou **ranking**, com os **top 5 ou top 10** alinhamentos. O ranking respeita as candidaturas selecionadas no quiz e mostra apenas quem tem base comparável, em ordem de afinidade e, nos empates, por nome. Se houver menos candidaturas disponíveis, a imagem mostra a quantidade real.

A imagem inclui percentuais, nomes, partidos, a identificação do quiz presidencial de **2026** e o endereço do site, sem respostas individuais nem identidade local. Ao abrir o compartilhamento, uma das **12 paletas prontas** e um dos **4 padrões geométricos** são sorteados de forma independente, sem relação com o resultado. Cada nova abertura sorteia um padrão diferente do anterior na sessão. O padrão não possui controle de troca e permanece durante essa abertura, inclusive ao trocar o conteúdo, o formato ou a cor. Basta tocar em outra paleta para trocar as cores antes de compartilhar.

- **Stories:** PNG de 1080 × 1920; **Post:** PNG de 1080 × 1350. As fontes do cartão acompanham o app para a exportação não depender de downloads de fontes.
- **Compartilhar imagem:** abre o menu do dispositivo com o PNG. Na web, quando o menu não estiver disponível, inicia o download. **Baixar imagem** também fica disponível no navegador.
- **Instagram:** oferece instruções para levar a imagem aos Stories/feed. O link clicável nos Stories é adicionado pela pessoa no adesivo “Link”; a imagem não contém um hyperlink ativo.
- **X / Twitter e WhatsApp:** abrem texto e link de acordo com o tipo selecionado. O WhatsApp inclui a lista do ranking; o X usa um resumo curto com a quantidade de alinhamentos. Esses atalhos não anexam o PNG; para enviá-lo, use o menu de compartilhamento ou anexe o arquivo baixado.

O endereço público é `https://fpolitico.com.br`. A variável de repositório **PUBLIC_APP_URL** no GitHub Actions deve usar esse mesmo valor; para compilar localmente:

```bash
flutter build web --release \
  --dart-define=IOT_FEATURE_ENABLED=false \
  --dart-define=PUBLIC_APP_URL=https://fpolitico.com.br
```

O valor é público e deve ser uma URL HTTPS. Parâmetros e fragmentos são removidos do endereço compartilhado. Consulte [mobile/.env.example](mobile/.env.example). O compartilhamento depende dos apps disponíveis no dispositivo; abrir o menu não confirma que algo foi publicado.

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
