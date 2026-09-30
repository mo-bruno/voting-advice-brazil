# Cobertura de produto no Google Analytics — Design

**Data:** 2026-09-30

**Status:** aprovado para planejamento e implementação

**Projeto:** Farol Político

**Base auditada:** `origin/main` em
`162e3577a6f3738b8f95e1d15a0b855cd0ccd262`

## Decisão resumida

Ampliar a cobertura de produto do site Flutter Web usando a propriedade GA4
existente, sem criar outro pipeline e sem enviar ao Google respostas, teses,
candidaturas, partidos, colocações, afinidades ou conteúdo político.

A entrega parte da allowlist atual de 23 eventos, corrige seus problemas de
semântica, deprecia o evento prematuro `candidate_positions_viewed` e
acrescenta apenas quatro eventos genéricos:

- `screen_viewed`;
- `engagement_action`;
- `operation_result`;
- `quiz_abandoned`.

O Analytics permanece opcional, só inicializa depois do consentimento e não
bloqueia nenhuma ação do produto. A propriedade atual, o measurement ID
`G-0P9XLRYVWT` e seu histórico são preservados. Um instante de corte separará
as métricas novas do histórico legado.

Por decisão explícita do responsável pelo produto, esta entrega não guarda
respostas do quiz para análise, não cria contadores agregados no backend e não
mede quais posições foram escolhidas nem quais candidaturas ficaram em primeiro
lugar. Restaurar esses valores nos eventos GA4 não é uma alternativa permitida.

## Relação com o desenho de 2026-09-29

Este documento complementa
`2026-09-29-analytics-privacy-and-data-minimization-design.md` e prevalece nos
seguintes pontos:

1. a revisão de cobertura de produto antes adiada passa a ser autorizada;
2. a propriedade GA4 atual será mantida, sem relink do Firebase, propriedade
   nova ou envio da propriedade atual para a lixeira;
3. o dataset histórico do BigQuery não será apagado nem reescrito nesta
   entrega;
4. o histórico anterior será separado por data de corte, não migrado para um
   ambiente novo;
5. nenhum armazenamento analítico de respostas ou resultados políticos será
   acrescentado ao backend.

Continuam válidas as decisões já implantadas sobre consentimento básico,
inicialização preguiçosa, ausência de replay, publicidade sempre negada,
minimização de payloads, processamento transitório do quiz e ausência de
persistência das novas respostas quando o IoT está desligado.

## Objetivos e critérios de sucesso

A entrega deve permitir responder, somente dentro da coorte que aceitou
métricas:

- quais telas e abas são efetivamente usadas;
- de onde as pessoas entram no quiz;
- onde o funil do quiz avança ou é abandonado explicitamente;
- se explicações, fontes, notícias e compartilhamento são usados;
- se carregamentos e ações importantes terminam com sucesso, vazio, dado
  desatualizado ou falha;
- quanto duram as principais operações do cliente;
- como Home, Acompanhar, Quiz, Comunidade e compartilhamento participam da
  jornada.

Também são critérios de sucesso:

- nenhum hit antes do consentimento ou depois da revogação;
- nenhum evento duplicado por pipeline paralelo;
- nenhuma espera de Analytics no caminho crítico da interface;
- nenhum parâmetro livre, identificador funcional ou dado político;
- eventos interpretáveis na interface do GA4 e no BigQuery;
- rollback simples pelo kill switch já existente.

## Não objetivos

Esta entrega não inclui:

- respostas, prioridades ou pesos do quiz para fins analíticos;
- tese, candidatura, partido, posição, colocação, score ou afinidade no GA4;
- contadores ou histórico político no PostgreSQL;
- endpoint, painel ou consulta de estatísticas políticas;
- propriedade GA4 nova, relink do Firebase ou novo measurement ID;
- Sentry, Crashlytics, Firebase Performance ou outro fornecedor;
- Web Vitals, scroll, tempo de permanência ou gravação de sessão;
- eventos de fechamento/reload via `sendBeacon`;
- fingerprint, `user_id`, UUID de submissão ou deduplicação por pessoa;
- instrumentação de IoT, Android ou iOS;
- instrumentação das telas de busca/perfil político protegidas pela feature
  flag desativada em produção;
- exclusão ou transformação destrutiva do histórico de GA4/BigQuery.

## Estado atual relevante

Na base auditada:

- `ANALYTICS_ENABLED` continua falso por padrão e é definido no build Web;
- o pipeline efetivo usa somente `FirebaseAnalytics.logEvent`;
- existem 23 eventos permitidos e todos possuem ao menos um call site;
- a política aceita somente parâmetros inteiros não negativos;
- não há `NavigatorObserver` analítico nem rastreamento das quatro abas do
  `IndexedStack`;
- Home, notícias, comunidade e compartilhamento têm cobertura insuficiente;
- algumas chamadas aguardam Analytics antes de avançar a interface;
- pular uma tese emite hoje `thesis_answered` e `thesis_skipped`;
- `party_selection_completed` é emitido antes de o submit terminar;
- `candidate_positions_viewed` é emitido antes de a consulta terminar;
- `results_viewed` nasce como efeito colateral de `build` e depende de haver um
  líder elegível;
- a revogação durante uma inicialização é verificada, mas a sequência
  concedido A → negado → concedido B pode liberar um evento iniciado em A;
- o site já empacota as fontes principais e usa
  `--no-web-resources-cdn`, mas o navegador real ainda precisa provar ausência
  de fallbacks remotos antes da ativação.

## Arquitetura

O fluxo permanece único:

```text
call site de produto
  → AnalyticsService
  → ConsentAwareAnalyticsSink
  → AnalyticsEventPolicy
  → FirebaseAnalyticsRuntime
  → propriedade GA4 atual
  → exportação diária BigQuery atual
```

Não haverá chamada direta a `gtag('event')`, Measurement Protocol ou segundo
sink. O código de produto só conhece métodos semânticos do
`AnalyticsService`; chaves, enumerações e limites ficam centralizados na
política.

### Entrega não bloqueante e ordenada

Call sites não aguardam a conclusão da rede. O sink mantém uma fila interna
ordenada para preservar a sequência lógica dos eventos sem bloquear botões,
navegação ou atualização de estado.

Uma falha de inicialização ou envio:

- descarta apenas o evento afetado;
- não interrompe a fila posterior;
- não impede a ação da pessoa;
- chama diagnóstico genérico, sem nome de tela, payload, URL ou conteúdo.

### Revisão de consentimento

O controlador expõe uma revisão monotônica que muda em toda transição de
estado. Ao aceitar um evento, o sink captura estado e revisão. Depois de
qualquer `await`, o envio só ocorre se:

- o estado ainda for `granted`;
- a revisão continuar exatamente igual;
- `ANALYTICS_ENABLED` continuar efetivo para aquele build.

Assim, um evento iniciado sob uma concessão antiga não atravessa a sequência
concedido → negado → concedido. Revogar fecha o gate imediatamente e invalida
eventos aguardando inicialização ou fila.

Eventos ocorridos antes do aceite são descartados e nunca reconstruídos. Ao
aceitar em uma tela já aberta, não haverá replay de cliques nem de telas
anteriores; a cobertura começa na próxima observação legítima.

## Taxonomia nova

Todos os valores textuais abaixo são enumerações fechadas. Valores fora da
lista descartam o parâmetro ou, quando o parâmetro for obrigatório, o evento.

### `screen_viewed`

Emitido quando uma tela/aba se torna realmente visível, uma vez por transição.
Tocar novamente na aba já selecionada não emite outro evento.

Parâmetros:

- `screen`, obrigatório:
  - `home`;
  - `follow_validation`;
  - `quiz_intro`;
  - `quiz_questions`;
  - `weighting`;
  - `candidate_selection`;
  - `results`;
  - `comparison`;
  - `community_feed`;
  - `community_post`;
  - `community_create`;
  - `result_share`;
  - `privacy`;
- `source`, obrigatório:
  - `initial`;
  - `tab`;
  - `home_cta`;
  - `drawer`;
  - `deep_link`;
  - `route`;
  - `back`.

Um observer cobre push, replacement e retorno das rotas nomeadas. O
`MainShell` cobre separadamente a aba inicial e trocas reais, porque seu
`IndexedStack` não altera o Navigator.

Um marcador de intenção de navegação, consumido uma única vez, atribui
`home_cta`, `drawer` ou `deep_link` à próxima tela. Na ausência do marcador, o
observer usa `route` ou `back`; o shell usa `initial` ou `tab`. Esse marcador
guarda apenas uma enumeração em memória e nunca uma rota ou identificador.

Rotas hoje criadas por `MaterialPageRoute` para detalhe/criação da comunidade
e compartilhamento recebem `RouteSettings.name` canônico. O nome da rota não
é enviado como parâmetro; ele só é convertido localmente para o enum `screen`.

### `engagement_action`

Mede somente ações deliberadas de alto valor.

Parâmetros possíveis:

- `action`, obrigatório:
  - `quiz_entry`;
  - `evidence_open`;
  - `outbound_open`;
  - `share`;
- `surface`, quando aplicável:
  - `home`;
  - `quiz`;
  - `comparison`;
  - `news`;
  - `results`;
  - `privacy`;
- `source`, para `quiz_entry`, usando a enumeração de `screen_viewed`;
- `target`, para abertura/compartilhamento:
  - `quiz_guide`;
  - `quiz_source`;
  - `comparison_source`;
  - `news_article`;
  - `news_index`;
  - `privacy_email`;
  - `google_privacy`;
  - `native_share`;
  - `download`;
  - `copy_link`;
  - `twitter`;
  - `whatsapp`;
  - `instagram_help`;
- `outcome`, somente quando a ação possui retorno observável:
  - `success`;
  - `failed`.

Nunca são enviados URL, domínio, título, texto, nome de candidatura ou formato
personalizado produzido pela pessoa.

### `operation_result`

Um único evento terminal representa cada tentativa. Não haverá pares
`started`/`completed`.

Parâmetros:

- `operation`, obrigatório:
  - `news_load`;
  - `quiz_load`;
  - `candidate_load`;
  - `results_submit`;
  - `comparison_load`;
  - `follow_status_load`;
  - `follow_register`;
  - `community_feed_load`;
  - `community_post_load`;
  - `community_post_create`;
  - `community_comment_create`;
  - `community_vote`;
  - `community_report`;
  - `share_render`;
- `outcome`, obrigatório:
  - `success`;
  - `empty`;
  - `failed`;
  - `stale`;
  - `blocked`;
- `trigger`, obrigatório:
  - `initial`;
  - `retry`;
  - `refresh`;
  - `pagination`;
  - `submit`;
- `failure_type`, somente para `failed` ou `blocked`:
  - `network`;
  - `timeout`;
  - `client`;
  - `server`;
  - `rate_limited`;
  - `moderation_rejected`;
  - `unavailable`;
  - `unknown`;
- `duration_ms`, inteiro não negativo medido com `Stopwatch`;
- `item_count`, inteiro não negativo quando uma lista foi recebida.

Não são enviados status HTTP, exceção, stack trace, texto de moderação, ID do
recurso, conteúdo, voto escolhido, ordenação ou tema.

### `quiz_abandoned`

Emitido somente em uma saída explícita dentro do site antes de chegar aos
resultados. Fechar/recarregar a aba continua sendo inferido pela ausência do
próximo estágio do funil; não haverá emissor alternativo no `pagehide`.

Parâmetros:

- `stage`, obrigatório:
  - `questions`;
  - `weighting`;
  - `candidate_selection`;
- `reason`, obrigatório:
  - `back`;
  - `restart`;
  - `recovery`;
- `total_answered`;
- `total_skipped`;
- `duration_ms`.

Os totais descrevem apenas volume da sessão em memória, nunca tese ou resposta.

## Correções dos eventos existentes

Os nomes existentes permanecem para continuidade, com estas correções:

1. `thesis_answered` e `thesis_skipped` tornam-se mutuamente exclusivos.
2. `quiz_completed` continua significando término da etapa de perguntas; a
   conversão final é `results_viewed`.
3. `party_selection_completed` só é emitido depois de submit e validações
   bem-sucedidos.
4. `results_viewed` é emitido uma vez fora de `build` para qualquer resultado
   não vazio, inclusive sem ranking elegível.
5. `candidate_positions_viewed` deixa de ser emitido; o resultado real passa a
   ser representado por `operation_result(operation=comparison_load)`.
6. `follow_waitlist_*` permanece sem parâmetros; operações de leitura e
   registro ganham o respectivo `operation_result`.
7. As assinaturas públicas do `AnalyticsService` deixam de receber tese,
   resposta, partido, candidatura, score ou posição que seriam descartados.

Não haverá emissão simultânea de nomes antigos e substitutos para a mesma
ação. O instante do deploy separa semanticamente o histórico legado.

## Matriz de cobertura

### Navegação

- `MaterialApp.navigatorObservers`: rotas nomeadas, push, replace e pop;
- `MainShell`: aba inicial e troca efetiva nas navegações móvel e desktop;
- origem do quiz: Home, aba, gaveta, deep link e recuperação;
- detalhe/criação da comunidade e compartilhamento: nomes de rota canônicos.

### Quiz e evidências

- carregamento e retry das perguntas;
- início, reinício, respostas/pulos genéricos e conclusão;
- abertura da explicação e tentativa de abrir a fonte;
- ponderação, seleção, submit, resultado e comparação;
- abandono explícito nas três etapas anteriores ao resultado.

### Notícias e links

- carga inicial e retry do feed;
- abertura do guia, índice e artigo externo por categoria fechada;
- sucesso/falha ao delegar a abertura ao navegador.

### Comunidade

- carga inicial, refresh, paginação, vazio e falha do feed;
- carga do detalhe;
- criação de publicação e comentário;
- voto e denúncia, sem direção, motivo, ID ou conteúdo;
- moderação rejeitada representada apenas pelo enum
  `failure_type=moderation_rejected`.

### Compartilhamento

- tela de compartilhamento;
- renderização da imagem;
- share nativo, download, cópia e atalhos sociais por enum;
- sucesso/falha observável, sem candidato, ranking, legenda, URL ou estilo.

### Acompanhar

- os cinco eventos atuais do funil de validação;
- resultado da consulta de status e do registro;
- nenhum UUID ou hash.

## Política de dados

`AnalyticsEventPolicy` passa a validar:

- nome do evento;
- conjunto exato de chaves por evento;
- tipo do valor;
- enumeração fechada de toda string;
- coerência entre parâmetros, por exemplo `failure_type` apenas em falha;
- limites máximos plausíveis para números.

Limites:

- duração: `0..86400000` ms;
- respostas/pulos do quiz: `0..60`;
- seleções de candidatura: `0..50`;
- `item_count`: `0..1000`.

Valores inválidos não são truncados silenciosamente para outro significado.
Parâmetro opcional inválido é descartado; parâmetro obrigatório inválido
descarta o evento.

Continuam proibidos, em qualquer chave ou valor customizado:

- UUID, Firebase Installation ID, cookie, IP ou user ID;
- tese, índice de tese, resposta, peso ou prioridade;
- candidatura, partido, colocação, score ou afinidade;
- post, comentário, pesquisa, denúncia, legenda ou texto de erro;
- URL, rota crua, domínio, referrer, título ou query string;
- timestamp produzido pelo cliente.

O SDK do GA4 acrescenta automaticamente página, referrer, título, idioma,
resolução e identificador pseudônimo depois do consentimento. Esses campos não
passam pela allowlist customizada. Por isso, nenhuma informação sensível pode
entrar em path, hash, query ou título, e a configuração de redação continua
obrigatória.

## Propriedade GA4 e BigQuery

### Propriedade atual

A entrega mantém a propriedade `535804267`, o stream Web e o measurement ID
`G-0P9XLRYVWT`. Não haverá:

- criação ou relink de propriedade;
- stream manual paralelo;
- mudança do Firebase Project;
- ativação de stream Android;
- envio da propriedade atual para a lixeira.

Antes da ativação, a configuração será lida e ajustada para:

- Google Signals desligado;
- personalização de anúncios desligada;
- user-provided data desligado;
- vínculos/recursos publicitários não utilizados;
- `ad_storage`, `ad_user_data` e `ad_personalization` sempre negados;
- Enhanced Measurement apenas para page views; scroll, outbound, search,
  vídeo, download e formulário desligados;
- redação de e-mail e, no mínimo, `fbclid`, `gclid`, `dclid`, `gbraid` e
  `wbraid`;
- retenção de eventos e usuários em 2 meses, com reset em nova atividade
  desligado, coerente com o aviso público.

Serão registradas somente as definições customizadas necessárias para os
parâmetros fechados desta especificação. Não haverá dimensão de usuário. As
definições event-scoped incluem `screen`, `source`, `action`, `surface`,
`target`, `operation`, `outcome`, `trigger`, `failure_type`, `stage` e
`reason`. `duration_ms` e `item_count` são métricas customizadas.

### BigQuery

O link e o dataset atuais são mantidos. A entrega:

- mantém exportação diária;
- mantém streaming desligado;
- desliga exportação de user-data/pseudonymous users para novas exportações;
- configura expiração padrão de 60 dias para novas tabelas, conforme o aviso
  atual;
- não altera a expiração das tabelas históricas existentes;
- não exclui tabela, dataset ou linha;
- preserva os acessos já concedidos, sem ampliar novos leitores.

A diferença entre tabelas históricas sem expiração e novas tabelas com 60 dias
deve constar do registro operacional e da transparência pública enquanto ela
existir. Uma futura limpeza do histórico exige inventário, desenho e
confirmação destrutiva próprios; não é consequência desta aprovação.

## Corte e interpretação do histórico

O deploy habilitado registra:

- SHA publicado;
- timestamp UTC exato;
- measurement ID servido;
- estado da configuração GA4/BigQuery;
- versão da taxonomia deste documento.

Dashboards, Explorações e consultas oficiais filtram eventos em ou depois desse
timestamp. Dados anteriores permanecem consultáveis, mas são classificados
como legado porque podem conter duplicação, parâmetros políticos e coleta sob
regras anteriores. Eles não são misturados à nova linha de base nem usados
como prova de conversão atual.

Não será adicionado `schema_version` aos eventos: o timestamp de corte evita
uma dimensão extra e é suficiente enquanto há um único deploy de mudança.

## Fontes e recursos antes do consentimento

O Web continuará sendo produzido com `--no-web-resources-cdn` e fontes
versionadas localmente. Antes do unpause, um navegador limpo deve provar zero
requisições para:

- `fonts.googleapis.com`;
- `fonts.gstatic.com`;
- recursos Flutter/CanvasKit em `www.gstatic.com`;
- `googletagmanager.com`;
- `google-analytics.com`;
- Firebase Installations.

Se um glyph/fallback ainda causar requisição remota, a ativação é bloqueada e
o fallback necessário é empacotado ou substituído por fonte do sistema. O
teste de código existente continua proibindo `google_fonts` em runtime.

## Testes

### Unidade

- cada evento aceita somente suas chaves, tipos, enums e limites;
- UUID, URL, rota crua, texto, tese, resposta, candidatura, partido e
  afinidade são rejeitados;
- parâmetros obrigatórios ausentes descartam o evento;
- a sequência concedido A → negado → concedido B descarta eventos iniciados
  em A;
- revogação descarta eventos já enfileirados;
- falha de um envio não interrompe a fila;
- um sink bloqueado não impede avanço do quiz ou navegação.

### Widgets e navegação

- tela inicial e cada troca real de aba emitem exatamente um `screen_viewed`;
- tocar na aba ativa não duplica;
- push, replace e pop mapeiam para a tela e origem corretas;
- deep link do quiz preserva a origem;
- skip não emite `thesis_answered`;
- submit com falha não emite conclusão de seleção nem resultado;
- resultado sem líder elegível ainda emite `results_viewed` uma vez;
- abrir/recolher evidência não envia ID ou conteúdo;
- notícias, comunidade, Acompanhar e compartilhamento emitem somente enums;
- saída explícita do quiz emite abandono; fechamento do navegador não tenta
  emitir.

### Suítes e navegador

```bash
cd backend
uv run pytest
uv run ruff check .
uv run mypy app/

cd ../mobile
flutter analyze
flutter test
flutter test --platform chrome test/analytics_default_pipeline_web_test.dart
flutter build web --release \
  --no-web-resources-cdn \
  --dart-define=IOT_FEATURE_ENABLED=false \
  --dart-define=POLITICIAN_FOLLOW_ENABLED=false \
  --dart-define=ANALYTICS_ENABLED="$ANALYTICS_ENABLED" \
  --dart-define=PUBLIC_APP_URL="$PUBLIC_APP_URL" \
  --dart-define=PRIVACY_CONTROLLER_NAME="$PRIVACY_CONTROLLER_NAME" \
  --dart-define=PRIVACY_CONTACT_EMAIL="$PRIVACY_CONTACT_EMAIL"
```

Em navegador real:

1. `pending`: nenhuma tag, FID, cookie `_ga` ou hit;
2. `denied` e reload: a mesma ausência;
3. `granted`: um único pipeline, eventos únicos e apenas parâmetros
   permitidos;
4. revogação: nenhum novo hit;
5. nova aceitação: somente eventos futuros;
6. rotas, abas, Home, quiz, notícias, comunidade e share cobertos;
7. nenhum recurso de fonte/Flutter remoto antes da escolha.

## Implantação e rollback

1. Implementar e publicar com `ANALYTICS_ENABLED=false`.
2. Verificar testes, bundle servido, fontes, consentimento e configuração
   externa.
3. Registrar estado da propriedade atual, criar as definições customizadas e
   registrar o timestamp de preparação.
4. Publicar o mesmo código com `ANALYTICS_ENABLED=true`.
5. Fazer um canário consentido no stream atual e validar DebugView/Network.
6. Registrar SHA e timestamp UTC do corte.
7. Conferir a primeira exportação diária e validar as consultas pós-corte.

O rollback recompila e republica o mesmo SHA com
`ANALYTICS_ENABLED=false`. Alterar apenas a variável sem redeploy não desliga o
bundle já servido.

Hard stops:

- hit antes do consentimento;
- hit depois da revogação;
- evento duplicado;
- destino diferente da propriedade atual;
- parâmetro político, identificador ou texto livre;
- configuração real divergente do aviso público;
- recurso Google/Flutter remoto antes da escolha.

## Critérios finais de aceite

A entrega só está completa quando:

- o funil existente e os quatro eventos novos passam por uma única allowlist;
- telas/abas e jornadas prioritárias possuem testes de emissão e minimização;
- nenhuma interação aguarda rede analítica;
- a corrida de consentimento está coberta por regressão;
- a propriedade atual recebe uma única cópia dos eventos consentidos;
- nenhum novo dado político é enviado ou persistido para análise;
- o histórico permanece intacto e claramente separado pelo corte;
- a configuração e o aviso público descrevem o estado real;
- há evidência de canário e rollback executável;
- backend, Flutter, Chrome e build Web passam integralmente.

Esta especificação organiza requisitos técnicos e transparência. Ela não
substitui uma avaliação jurídica individual do controlador.
