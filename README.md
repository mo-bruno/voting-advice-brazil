# Farol Político

Site acadêmico de orientação eleitoral para o Brasil, da Universidade Presbiteriana Mackenzie.

O produto atual reúne uma comparação de planos presidenciais de 2026, comunidade sob aliases pseudônimos e notícias oficiais dos últimos sete dias. A área de acompanhamento de políticos está em validação: o público pode registrar interesse sem fornecer nome ou contato, enquanto a busca, o perfil e o acompanhamento já implementados permanecem retidos atrás de feature flag. Os resultados usam respostas e pesos do quiz para comparar posições documentadas; as evidências legislativas não compõem esse score. Não há índice de consistência implementado.

O site gera e guarda localmente um UUID v4 (`anonymous_id`). O contrato do quiz ainda aceita esse UUID no campo `device_id`, mas o cliente público não o envia com IoT desligado; o backend calcula o ranking sem gravar respostas nem criar ou atualizar `devices`, mesmo quando um cliente antigo envia o campo. Com IoT habilitado, `device_id` permite a persistência histórica do quiz. Na comunidade e nas rotas `/me`, `X-Farol-Anonymous-Id` funciona como credencial privada de posse e gera um alias público estável. A validação usa outro UUID aleatório, exclusivo do experimento, e o backend armazena somente seu hash SHA-256 contextualizado. Esse hash é unidirecional, mas o mesmo navegador pode reproduzi-lo a partir do UUID retido para consultar o registro; a API também aceita retirada, embora a interface atual não ofereça botão para isso. As respostas públicas mostram `author_alias` e `is_mine`, sem divulgar o UUID do autor. Não há conta autenticada ou recuperação dessas identidades.

Posts e comentários podem revelar opinião política. O site destaca, antes de cada ação, que o texto será armazenado, publicado sob alias pseudônimo estável e enviado à NVIDIA NIM para moderação. O autor pode remover o conteúdo do próprio post, deixando uma lápide e preservando os comentários; pedidos para retirar comentários, interesse na área Acompanhar e outros direitos usam `privacidade@fpolitico.com.br`. Os dados funcionais permanecem enquanto necessários à função, segurança ou obrigações legais, sem promessa de um prazo fixo para toda a comunidade. Métricas GA contam apenas visitantes que aceitaram o opt-in opcional; a contagem de linhas ativas deduplicadas no banco continua sendo a fonte de demanda da validação. O interesse tem retenção operacional máxima de 180 dias.

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
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1 \
  --dart-define=IOT_FEATURE_ENABLED=false \
  --dart-define=POLITICIAN_FOLLOW_ENABLED=false
```

`API_BASE_URL` deve incluir `/api/v1`. Em emuladores/aparelhos, ajuste o host para alcançar sua máquina. Para web, inclua a origem/porta do app em `ALLOWED_ORIGINS` no backend.

## Compartilhamento do quiz

Na tela de resultados, **Compartilhar resultado** abre uma prévia com dois tipos de imagem: **maior alinhamento**, destacando uma candidatura, ou **ranking**, com os **top 5 ou top 10** alinhamentos. O ranking respeita as candidaturas selecionadas no quiz e mostra apenas quem tem base comparável, em ordem de afinidade e, nos empates, por nome. Se houver menos candidaturas disponíveis, a imagem mostra a quantidade real.

A imagem inclui colocação, nomes, partidos, a identificação do quiz presidencial de **2026** e o endereço do site, sem respostas individuais nem identidade local. Ao abrir o compartilhamento, uma das **12 paletas prontas** e um dos **4 padrões geométricos** são sorteados de forma independente, sem relação com o resultado. Cada nova abertura sorteia um padrão diferente do anterior na sessão. O padrão não possui controle de troca e permanece durante essa abertura, inclusive ao trocar o conteúdo, o formato ou a cor. Basta tocar em outra paleta para trocar as cores antes de compartilhar.

- **Stories:** PNG de 1080 × 1920; **Post:** PNG de 1080 × 1350. As fontes do cartão acompanham o app para a exportação não depender de downloads de fontes.
- **Compartilhar imagem:** envia somente o PNG pelo menu padrão do dispositivo, para qualquer app disponível. A imagem é preparada antes do toque e o botão fica indisponível durante o envio. Cancelar não inicia download, não abre redes e não confirma publicação.
- **X:** abre diretamente o compositor com texto e link. O ranking usa um resumo curto, sem levar a lista completa de candidaturas para a legenda.
- **WhatsApp:** abre diretamente a seleção de conversa com o texto do resultado selecionado e o link.

Se o navegador recusar o compartilhamento da imagem, uma mensagem oferece **Baixar** em um novo toque, para anexar o PNG manualmente. O retorno sem status de entrega do navegador não é tratado como falha. A tela mantém somente essas três ações principais; Stories/Post definem o tamanho da imagem, sem direcionar a um app ou modo de publicação.

O endereço público é `https://fpolitico.com.br`. O deploy exige as variáveis de repositório `PUBLIC_APP_URL`, `ANALYTICS_ENABLED`, `PRIVACY_CONTROLLER_NAME` e `PRIVACY_CONTACT_EMAIL`. O controlador deve ser uma identidade civil/jurídica real, não a marca nem um exemplo. Para um build local de desenvolvimento, sem valores de produção:

```bash
flutter build web --release --no-web-resources-cdn \
  --dart-define=IOT_FEATURE_ENABLED=false \
  --dart-define=POLITICIAN_FOLLOW_ENABLED=false \
  --dart-define=ANALYTICS_ENABLED=false \
  --dart-define=PUBLIC_APP_URL=https://example.invalid \
  --dart-define='PRIVACY_CONTROLLER_NAME=Responsável de Teste' \
  --dart-define=PRIVACY_CONTACT_EMAIL=privacidade@example.invalid
```

O valor é público e deve ser uma URL HTTPS. Parâmetros e fragmentos são removidos do endereço compartilhado. Consulte [mobile/.env.example](mobile/.env.example). O compartilhamento depende dos apps disponíveis no dispositivo; abrir o menu não confirma que algo foi publicado.

## Página pública e SEO

O aplicativo permanece na raiz de `https://fpolitico.com.br/`. A página
`/eleicoes-2026/` apresenta o quiz, as fontes, a metodologia e as perguntas
frequentes em HTML, disponível sem JavaScript. Seu botão abre `/?tab=quiz`,
que seleciona a introdução do quiz dentro do shell do aplicativo.

Os arquivos ficam em `mobile/web/` e são copiados pelo próprio
`flutter build web`; o workflow de publicação existente também os publica.
Não há etapa adicional de geração nem dependência nova. `robots.txt` aponta
para o sitemap com a raiz e a página pública. Cada página tem seu próprio
endereço canônico. As rotas conhecidas do aplicativo continuam usando
`index.html`; outros endereços inexistentes recebem a página `404.html`.

Depois de publicar, inspecione a raiz e `/eleicoes-2026/` no Search Console,
execute o teste ao vivo e consulte o HTML renderizado. Envie `/sitemap.xml`
e solicite a indexação das duas páginas. A solicitação não garante indexação
nem posição. No relatório de desempenho, acompanhe consultas, impressões,
cliques e CTR; o funil do quiz já registra `quiz_started`, `quiz_completed`
e `results_viewed` sem opiniões ou afinidades nos eventos de analytics.

## API ativa

Os caminhos abaixo usam o prefixo `/api/v1`, exceto saúde e documentação.

| Família | Métodos e caminhos |
|---|---|
| Saúde e contrato | `GET /health`, `GET /docs`, `GET /redoc`, `GET /openapi.json` |
| Quiz | `GET /quiz/questions`, `POST /quiz/submit` |
| Presidência 2026 | `GET /candidates`, `GET /candidates/{candidate_id}`, `GET /candidates/{candidate_id}/positions`, `GET /candidates/{candidate_id}/justifications` |
| Temas | `GET /themes` |
| Deputados atuais | `GET /political-actors`, `GET /political-actors/trending`, `GET /political-actors/{actor_id}`, `GET /political-actors/{actor_id}/evidence` |
| Validação do acompanhamento | `GET`, `PUT`, `DELETE /me/politician-follow-interest` |
| Acompanhamento retido | `GET`, `PUT`, `DELETE /me/followed-actor` quando `POLITICIAN_FOLLOW_ENABLED=true` |
| Comunidade | `GET`, `POST /community/posts`; `GET`, `DELETE /community/posts/{post_id}`; `POST /community/posts/{post_id}/votes`, `/comments`, `/reports` |
| Notícias oficiais | `GET /news/weekly`, `GET /news/image?url=...` |

Arquivos públicos em `/data/...` são servidos quando `DATA_DIR` existe. Notícias semanais vêm da Câmara; seu proxy de imagens aceita apenas hosts autorizados da Câmara. Detalhes de identidade, limites, moderação e erros estão no [README do backend](backend/README.md).

## Medição da validação

O funil usa somente eventos genéricos do Firebase Analytics, sem UUID, nome de político, partido, resposta ou texto livre: `follow_waitlist_viewed`, `follow_waitlist_prompt_viewed`, `follow_waitlist_cta_clicked`, `follow_waitlist_registered` e `follow_waitlist_failed`. `viewed` mede a exposição geral; a conversão principal é a proporção de usuários únicos que acionam `registered` após `prompt_viewed`, quando o CTA realmente ficou elegível. Cliques e falhas ajudam a diagnosticar atrito.

A contagem de interesses ativos no banco, deduplicada pelo hash do UUID exclusivo do experimento, é a fonte de verdade para a demanda atual. O hash é unidirecional; o navegador que conserva o UUID pode reproduzi-lo para consultar o registro. A API aceita retirada por esse identificador, mas a interface pública atual não oferece essa ação; o pedido pode ser feito pelo canal de privacidade. O evento GA de sucesso só é emitido quando a API informa que criou um registro novo e somente para visitantes que aceitaram métricas; chamadas idempotentes não geram conversões adicionais. Como não há conta ou contato, a contagem representa instalações que manifestaram interesse, não uma quantidade garantida de pessoas únicas; o limite global da API reduz abuso básico, mas não substitui proteção distribuída contra tráfego coordenado.

## Features retidas e deploy

O Farol físico está desativado e invisível por padrão: `IOT_FEATURE_ENABLED=false` no backend e no build Flutter. O acompanhamento real também fica desativado por padrão com `POLITICIAN_FOLLOW_ENABLED=false`; o site mostra o registro de interesse sem nome ou contato e o backend rejeita operações antigas de follow, sem apagar código ou dados existentes.

Cloud Build publica a API no Cloud Run com as duas flags em `false`; o workflow de Firebase Hosting compila o site com os mesmos valores. O build Web de produção exige a identidade pública real e a chave operacional `ANALYTICS_ENABLED` explicitamente `true` ou `false`. Mesmo com `true`, eventos só são enviados após o opt-in; `false` pausa toda a coleta. Nenhum scheduler é iniciado pelo processo da API.

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
flutter build web --release --no-web-resources-cdn \
  --dart-define=IOT_FEATURE_ENABLED=false \
  --dart-define=POLITICIAN_FOLLOW_ENABLED=false \
  --dart-define=ANALYTICS_ENABLED=false \
  --dart-define=PUBLIC_APP_URL=https://example.invalid \
  --dart-define='PRIVACY_CONTROLLER_NAME=Responsável de Teste' \
  --dart-define=PRIVACY_CONTACT_EMAIL=privacidade@example.invalid
```

## Contribuição e licença

Leia [CONTRIBUTING.md](CONTRIBUTING.md). Abra PRs com contexto claro e testes proporcionais às mudanças de comportamento. Licença ainda não definida.
