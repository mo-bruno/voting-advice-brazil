# Runbook — corte seguro da cobertura Web no GA4 e BigQuery

**Status em 2026-09-30:** configuração externa das fases B–D aplicada e relida;
produção continua desativada, com `ANALYTICS_ENABLED=false`. Não houve deploy
de ativação nem corte de produção. A atualização do BigQueryLink pode levar até
24 horas para se refletir nas tabelas, portanto a ausência de novas tabelas
intraday/user-data ainda exige a validação posterior descrita abaixo.

O trabalho de repositório que criou este documento não executou mutação externa.
As mudanças GA4/BigQuery aqui registradas foram aplicadas e conferidas pelo
operador autorizado, e os comandos permanecem como procedimento idempotente de
inventário, readback e recuperação.

Este runbook preserva a propriedade e o histórico existentes. Ele não autoriza
criar, relinkar ou excluir propriedade, stream, link, dataset, tabela ou linha.
Também não autoriza mudar ACLs. Qualquer limpeza histórica futura precisa de um
plano e de uma confirmação destrutiva próprios.

## Escopo e identificadores fixos

| Recurso | Valor imutável neste corte |
| --- | --- |
| Projeto Firebase/GCP | `farol-politico-495210` |
| Conta GA4 | `353673747` |
| Propriedade GA4 | `535804267` |
| Stream Web | `properties/535804267/dataStreams/14797759925` |
| Stream Android dormente | `properties/535804267/dataStreams/14797877644` |
| Measurement ID | `G-0P9XLRYVWT` |
| Dataset existente | `farol-politico-495210:analytics_535804267` |
| Localização do dataset | `southamerica-east1` |
| Retenção padrão futura | `5184000` segundos / `5184000000` ms |

### Decisão Web-only (não “no Android”)

O produto publicado é somente Web. O stream Web acima é o único que deve
receber o bundle e o único selecionado no link com o BigQuery. Existe o stream
Android `14797877644` registrado no Firebase, mas ele está dormente: não há
aplicativo publicado em loja, não houve dado Android nas 48 horas anteriores ao
readback e o Manifest mantém `firebase_analytics_collection_enabled=false`. O
stream foi removido do export BigQuery, mas seu cadastro foi preservado. Não
existe stream iOS, e nenhum stream Android/iOS deve ser criado ou habilitado por
este corte.

## Regras para evidência e segredos

- Nunca usar `set -x`, `curl -v` ou imprimir um access token.
- Tokens vivem somente em variável de shell e são removidos ao final.
- Arquivos temporários recebem apenas configuração, nomes de tabelas e
  metadados de expiração; são apagados pelo `trap`.
- Não salvar HAR, cookies, query string, payload de evento, endereço IP,
  `user_id`, `user_pseudo_id`, Firebase Installation ID, client ID ou session
  ID.
- Não salvar valores de parâmetros livres. Para eventos, registrar somente
  host, nome, conjunto de chaves e contagem.
- O measurement ID, o property ID e os resource names desta seção são
  identificadores de configuração, não identificadores de pessoa, e são os
  únicos identificadores persistidos neste registro.

## Estado já verificado, somente leitura

O inventário inicial foi somente leitura. Depois dele, o operador autorizado
aplicou e releu as configurações explicitamente marcadas abaixo.

| Área | Fato verificado |
| --- | --- |
| Repositório | Não há script ou dependência para Analytics Admin API ou cliente BigQuery. A opção de menor complexidade é REST oficial com `curl`/`jq` e `gcloud`/`bq`. |
| Ferramentas locais | `gcloud 579.0.0`, `bq 2.1.36`, `jq 1.8.1` e `curl 8.15.0` estavam disponíveis. Firebase CLI e os clientes Python de Analytics Admin/BigQuery não estavam instalados. |
| Contexto GCP | O projeto padrão local aponta para outro projeto; por isso todos os comandos abaixo passam projeto e quota project explicitamente. |
| Firebase/GA | Conta `353673747`, propriedade `535804267`, stream Web `14797759925` com `G-0P9XLRYVWT`, stream Android `14797877644` registrado/dormente e nenhum app/stream iOS. O Web stream usa `https://fpolitico.com.br`. |
| Privacidade GA4 | Retenção de eventos e usuários em 2 meses, reset por nova atividade off, Google Signals off, user-provided data off/não configurado e ads personalization permitido em 0/307 regiões. |
| Coleta Web | Enhanced Measurement on somente para page views, incluindo mudanças no histórico do navegador. Scroll, outbound clicks, site search, formulário, vídeo e download estão off. Redação de e-mail on e redação de `fbclid,gclid,dclid,gbraid,wbraid` on. |
| BigQueryLink | Um de dois streams selecionado: somente Web. Advertising IDs off, daily events on, streaming off e daily user export off. A UI confirmou a atualização; a propagação pode levar até 24 horas. |
| Dataset | O dataset existente está em `southamerica-east1`, com `defaultTableExpirationMs=5184000000` aplicado com ETag e sem `defaultPartitionExpirationMs`. |
| Tabelas | O readback com `--max_results=10000` encontrou 73 tabelas: 37 com prefixo `events_` (36 diárias e 1 `events_intraday_YYYYMMDD`), 36 `pseudonymous_users_YYYYMMDD` e 0 `users_YYYYMMDD`. As 73 tabelas legadas continuam com `expirationTime` ausente; o TTL vale somente para futuras tabelas. Intraday e pseudonymous atuais são legado, e a mudança de export pode levar até 24 horas. |
| ACL do dataset | Foram observadas 4 entradas: special groups do projeto (owners, writers e readers) e o principal gerenciado de medição como owner do dataset. Este corte preserva a ACL integralmente e não adiciona leitores. |
| Definições | As 11 dimensões e 2 métricas aprovadas foram criadas/confirmadas como event-scoped. As definições históricas `stance`, `thesis_id` e `time_to_answer_ms` foram preservadas, sem reutilização pelos eventos novos. |
| Ativação | A variável GitHub `ANALYTICS_ENABLED` foi relida como `false`. Nenhum deploy/canário de ativação foi executado. |
| Código Web | Há um único pipeline Firebase Analytics. `index.html` não carrega gtag externo nem emite `config`/`event`; o build usa `--no-web-resources-cdn` e exige `ANALYTICS_ENABLED=true|false`. |

`bq ls` sem `--max_results=10000` retornou somente a primeira página de 50
tabelas durante a auditoria. O parâmetro é obrigatório em todo inventário deste
runbook.

## Pendências após a configuração

Os itens seguintes são bloqueadores da ativação e não estão concluídos apenas
porque aparecem neste documento:

- aguardar a janela de propagação de até 24 horas do BigQueryLink e provar que
  não surgiram novas tabelas intraday/user-data;
- executar o deploy desabilitado no SHA final e a prova completa em navegador;
- congelar merges, reexecutar o mesmo Backend run com analytics habilitado e
  registrar `CUTOVER_UTC` somente depois do canário;
- executar as consultas pós-corte na primeira exportação diária completa;
- manter `ANALYTICS_ENABLED=false` até todos os hard stops estarem verdes.

## Contrato analítico

### Allowlist de 26 eventos de produto

```text
quiz_intro_viewed
quiz_started
quiz_restarted
thesis_viewed
thesis_skipped
weighting_started
weight_added
weight_removed
party_selection_viewed
party_toggled
results_viewed
comparison_opened
comparison_candidate_added
follow_waitlist_viewed
follow_waitlist_prompt_viewed
follow_waitlist_cta_clicked
follow_waitlist_registered
follow_waitlist_failed
thesis_answered
quiz_completed
weighting_completed
party_selection_completed
screen_viewed
engagement_action
operation_result
quiz_abandoned
```

Eventos automáticos esperados do SDK (`page_view`, `session_start`,
`first_visit` e `user_engagement`) não ampliam a allowlist customizada. Eles são
tratados separadamente nas consultas. `scroll`, `click`, `view_search_results`,
eventos de vídeo, download e formulário não são esperados porque as respectivas
medições aprimoradas ficam desligadas.

### Treze definições customizadas

Dimensões event-scoped:

```text
screen
source
action
surface
target
operation
outcome
trigger
failure_type
stage
reason
```

Métricas event-scoped:

```text
duration_ms — MILLISECONDS
item_count — STANDARD
```

Não criar definição user-scoped e não criar `schema_version`. Campos como
`time_to_answer_ms`, totais e contagens continuam no export bruto, mas não
consomem slots adicionais de definição neste corte.

## Fase A — preparar acesso e repetir inventário

### A.1 Pré-requisito para repetir o readback

Este bloco não altera APIs do projeto, mas substitui a ADC local. Executá-lo
somente quando a conta operadora aprovada precisar repetir o inventário ou uma
correção. A Analytics Admin API deve estar previamente habilitada; se a
verificação somente leitura falhar, interromper o procedimento. Não é necessário
repeti-lo para aceitar o estado já relido acima.

```bash
set -euo pipefail

export FP_GCP_PROJECT='farol-politico-495210'
export FP_GA_PROPERTY='535804267'
export FP_GA_WEB_STREAM='14797759925'
export FP_GA_ANDROID_STREAM='14797877644'
export FP_GA_MEASUREMENT_ID='G-0P9XLRYVWT'
export FP_BQ_DATASET='farol-politico-495210:analytics_535804267'

gcloud auth application-default login \
  --scopes='openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/analytics.edit'
gcloud auth application-default set-quota-project "$FP_GCP_PROJECT"

test "$(gcloud auth list --filter=status:ACTIVE --format='value(status)' | wc -l)" -ge 1
gcloud services list --enabled --project="$FP_GCP_PROJECT" \
  --filter='name:analyticsadmin.googleapis.com' \
  --format='value(name)' | grep -qx 'analyticsadmin.googleapis.com'
```

Não registrar a saída da identidade autenticada. O operador deve conferir a
conta no próprio terminal/console e manter apenas o resultado “aprovada” no
registro de mudança.

### A.2 Helpers sem exposição do token

```bash
set -euo pipefail

umask 077
FP_CONFIG_DIR="$(mktemp -d)"
readonly FP_CONFIG_DIR
FP_GA_TOKEN="$(gcloud auth application-default print-access-token)"
cleanup_ga_inventory() {
  unset FP_GA_TOKEN
  rm -rf -- "$FP_CONFIG_DIR"
}
trap cleanup_ga_inventory EXIT

ga_get() {
  local resource_path="$1"
  local output_path="$2"
  printf 'header = "Authorization: Bearer %s"\nheader = "X-Goog-User-Project: %s"\n' \
    "$FP_GA_TOKEN" "$FP_GCP_PROJECT" |
    curl --config - \
      --fail-with-body --silent --show-error \
      "https://analyticsadmin.googleapis.com/${resource_path}" \
      > "$output_path"
}

ga_write() {
  local method="$1"
  local resource_path="$2"
  local json_body="$3"
  local output_path="$4"
  printf 'header = "Authorization: Bearer %s"\nheader = "X-Goog-User-Project: %s"\n' \
    "$FP_GA_TOKEN" "$FP_GCP_PROJECT" |
    curl --config - \
      --fail-with-body --silent --show-error \
      --request "$method" \
      --header 'Content-Type: application/json' \
      --data "$json_body" \
      "https://analyticsadmin.googleapis.com/${resource_path}" \
      > "$output_path"
}
```

Cada bloco GA até B.6 presume que as variáveis e funções acima continuam na
mesma sessão. O token permanece apenas na variável e segue pela entrada padrão
do `curl`; ele não é gravado em arquivo nem aparece nos argumentos do processo.
Encerrar essa sessão ao terminar B.6 para que o `trap` remova o token da memória
e os arquivos temporários; executar a fase D em uma shell nova. Não anexar os
JSONs temporários a PR, issue ou chat.

### A.3 Inventário GA4 e BigQueryLink — somente leitura

```bash
ga_get "v1beta/properties/${FP_GA_PROPERTY}" \
  "$FP_CONFIG_DIR/property.json"
ga_get "v1beta/properties/${FP_GA_PROPERTY}/dataStreams?pageSize=200" \
  "$FP_CONFIG_DIR/streams.json"
ga_get "v1alpha/properties/${FP_GA_PROPERTY}/bigQueryLinks?pageSize=200" \
  "$FP_CONFIG_DIR/bigquery-links.json"
ga_get "v1alpha/properties/${FP_GA_PROPERTY}/googleSignalsSettings" \
  "$FP_CONFIG_DIR/google-signals.json"
ga_get "v1beta/properties/${FP_GA_PROPERTY}/dataRetentionSettings" \
  "$FP_CONFIG_DIR/retention.json"
ga_get "v1alpha/properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_WEB_STREAM}/enhancedMeasurementSettings" \
  "$FP_CONFIG_DIR/enhanced-measurement.json"
ga_get "v1alpha/properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_WEB_STREAM}/dataRedactionSettings" \
  "$FP_CONFIG_DIR/redaction.json"
ga_get "v1alpha/properties/${FP_GA_PROPERTY}/userProvidedDataSettings" \
  "$FP_CONFIG_DIR/user-provided-data.json"
ga_get "v1beta/properties/${FP_GA_PROPERTY}/customDimensions?pageSize=200" \
  "$FP_CONFIG_DIR/custom-dimensions.json"
ga_get "v1beta/properties/${FP_GA_PROPERTY}/customMetrics?pageSize=200" \
  "$FP_CONFIG_DIR/custom-metrics.json"

jq -e --arg property_name "properties/${FP_GA_PROPERTY}" '
  .name == $property_name and .parent == "accounts/353673747"
' "$FP_CONFIG_DIR/property.json" > /dev/null

jq -e \
  --arg web_name "properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_WEB_STREAM}" \
  --arg android_name "properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_ANDROID_STREAM}" \
  --arg measurement_id "$FP_GA_MEASUREMENT_ID" '
    ([
      [
        $web_name,
        "WEB_DATA_STREAM"
      ],
      [
        $android_name,
        "ANDROID_APP_DATA_STREAM"
      ]
    ] | sort) as $expected_streams |
    ([
      (.dataStreams // [])[] |
      [.name, .type]
    ] | sort) as $actual_streams |
    ([
      (.dataStreams // [])[] |
      select(.name == $web_name and .type == "WEB_DATA_STREAM")
    ]) as $web |
    ((.nextPageToken // "") | length) == 0 and
    $actual_streams == $expected_streams and
    ($web | length) == 1 and
    $web[0].webStreamData.measurementId == $measurement_id and
    $web[0].webStreamData.defaultUri == "https://fpolitico.com.br"
  ' "$FP_CONFIG_DIR/streams.json" > /dev/null

test "$(jq '(.bigqueryLinks // []) | length' \
  "$FP_CONFIG_DIR/bigquery-links.json")" -eq 1
```

O inventário deve conter exatamente os dois resource names acima: o Web e o
Android dormente, com seus tipos correspondentes. Qualquer ausência, stream
substituto, stream extra (inclusive iOS) ou tipo divergente interrompe o bloco
antes da fase mutável. Um `nextPageToken` também interrompe o procedimento,
pois um inventário parcial não comprova esse conjunto exato. Nenhum comando
desta fase altera ou remove o Android. Se houver outro link ou outro destino,
parar.

### A.4 Inventário BigQuery — somente leitura

```bash
bq --project_id="$FP_GCP_PROJECT" show --format=prettyjson \
  "$FP_BQ_DATASET" > "$FP_CONFIG_DIR/dataset.before.json"
bq --project_id="$FP_GCP_PROJECT" ls --max_results=10000 \
  --format=prettyjson "$FP_BQ_DATASET" \
  > "$FP_CONFIG_DIR/tables.list.before.json"

jq -r '.[].tableReference.tableId' \
  "$FP_CONFIG_DIR/tables.list.before.json" |
while IFS= read -r table_id; do
  bq --project_id="$FP_GCP_PROJECT" show --format=prettyjson \
    "${FP_BQ_DATASET}.${table_id}" |
  jq '{
    tableId: .tableReference.tableId,
    expirationTime: (.expirationTime // null)
  }'
done | jq -s 'sort_by(.tableId)' \
  > "$FP_CONFIG_DIR/table-expirations.before.json"

jq -S '(.access // []) | sort_by(tojson)' \
  "$FP_CONFIG_DIR/dataset.before.json" \
  > "$FP_CONFIG_DIR/dataset-acl.before.json"

jq '{
  location,
  defaultTableExpirationMs: (.defaultTableExpirationMs // null),
  defaultPartitionExpirationMs: (.defaultPartitionExpirationMs // null),
  tableCount: input | length
}' "$FP_CONFIG_DIR/dataset.before.json" \
  "$FP_CONFIG_DIR/table-expirations.before.json"
```

O último comando imprime somente configuração e contagem. Não consultar linhas
de eventos nesta fase.

## Fase B — configuração GA4 aplicada e relida

O estado descrito nesta fase foi aplicado em 2026-09-30. Os comandos são
mutáveis, mas permanecem como recuperação idempotente: se uma correção for
necessária, fazer um GET imediatamente antes e outro imediatamente depois de
cada PATCH. As máscaras de campo evitam alterar campos não relacionados.

### B.1 Google Signals desligado

```bash
ga_get "v1alpha/properties/${FP_GA_PROPERTY}/googleSignalsSettings" \
  "$FP_CONFIG_DIR/google-signals.before.json"

ga_write PATCH \
  "v1alpha/properties/${FP_GA_PROPERTY}/googleSignalsSettings?updateMask=state" \
  '{"state":"GOOGLE_SIGNALS_DISABLED"}' \
  "$FP_CONFIG_DIR/google-signals.patch.json"

ga_get "v1alpha/properties/${FP_GA_PROPERTY}/googleSignalsSettings" \
  "$FP_CONFIG_DIR/google-signals.after.json"
jq -e '.state == "GOOGLE_SIGNALS_DISABLED"' \
  "$FP_CONFIG_DIR/google-signals.after.json" > /dev/null
```

### B.2 Retenção de eventos e usuários em dois meses

```bash
ga_get "v1beta/properties/${FP_GA_PROPERTY}/dataRetentionSettings" \
  "$FP_CONFIG_DIR/retention.before.json"

ga_write PATCH \
  "v1beta/properties/${FP_GA_PROPERTY}/dataRetentionSettings?updateMask=event_data_retention,user_data_retention,reset_user_data_on_new_activity" \
  '{"eventDataRetention":"TWO_MONTHS","userDataRetention":"TWO_MONTHS","resetUserDataOnNewActivity":false}' \
  "$FP_CONFIG_DIR/retention.patch.json"

ga_get "v1beta/properties/${FP_GA_PROPERTY}/dataRetentionSettings" \
  "$FP_CONFIG_DIR/retention.after.json"
jq -e '
  .eventDataRetention == "TWO_MONTHS" and
  .userDataRetention == "TWO_MONTHS" and
  .resetUserDataOnNewActivity == false
' "$FP_CONFIG_DIR/retention.after.json" > /dev/null
```

### B.3 Enhanced Measurement somente com page views

`streamEnabled=true` mantém Enhanced Measurement ativo e
`pageChangesEnabled=true` permite page views em mudanças de histórico da SPA.
As outras medições automáticas ficam desligadas para não duplicar os eventos
tipados do produto.

```bash
ga_get "v1alpha/properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_WEB_STREAM}/enhancedMeasurementSettings" \
  "$FP_CONFIG_DIR/enhanced.before.json"

ga_write PATCH \
  "v1alpha/properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_WEB_STREAM}/enhancedMeasurementSettings?updateMask=stream_enabled,scrolls_enabled,outbound_clicks_enabled,site_search_enabled,video_engagement_enabled,file_downloads_enabled,page_changes_enabled,form_interactions_enabled" \
  '{"streamEnabled":true,"scrollsEnabled":false,"outboundClicksEnabled":false,"siteSearchEnabled":false,"videoEngagementEnabled":false,"fileDownloadsEnabled":false,"pageChangesEnabled":true,"formInteractionsEnabled":false}' \
  "$FP_CONFIG_DIR/enhanced.patch.json"

ga_get "v1alpha/properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_WEB_STREAM}/enhancedMeasurementSettings" \
  "$FP_CONFIG_DIR/enhanced.after.json"
jq -e '
  .streamEnabled == true and
  .pageChangesEnabled == true and
  .scrollsEnabled == false and
  .outboundClicksEnabled == false and
  .siteSearchEnabled == false and
  .videoEngagementEnabled == false and
  .fileDownloadsEnabled == false and
  .formInteractionsEnabled == false
' "$FP_CONFIG_DIR/enhanced.after.json" > /dev/null
```

### B.4 Redação de e-mail e parâmetros de campanha

As chaves mínimas são unidas às chaves existentes. Nunca substituir ou remover
uma redação adicional já configurada.

```bash
ga_get "v1alpha/properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_WEB_STREAM}/dataRedactionSettings" \
  "$FP_CONFIG_DIR/redaction.before.json"

FP_REDACTION_BODY="$(jq -c '
  {
    emailRedactionEnabled: true,
    queryParameterRedactionEnabled: true,
    queryParameterKeys:
      (((.queryParameterKeys // []) +
        ["fbclid", "gclid", "dclid", "gbraid", "wbraid"]) | unique)
  }
' "$FP_CONFIG_DIR/redaction.before.json")"

ga_write PATCH \
  "v1alpha/properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_WEB_STREAM}/dataRedactionSettings?updateMask=email_redaction_enabled,query_parameter_redaction_enabled,query_parameter_keys" \
  "$FP_REDACTION_BODY" \
  "$FP_CONFIG_DIR/redaction.patch.json"
unset FP_REDACTION_BODY

ga_get "v1alpha/properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_WEB_STREAM}/dataRedactionSettings" \
  "$FP_CONFIG_DIR/redaction.after.json"
jq -e '
  .emailRedactionEnabled == true and
  .queryParameterRedactionEnabled == true and
  (["fbclid", "gclid", "dclid", "gbraid", "wbraid"] -
    (.queryParameterKeys // []) | length) == 0
' "$FP_CONFIG_DIR/redaction.after.json" > /dev/null
```

### B.5 BigQueryLink atual, diário e Web-only

O PATCH não toca em `excludedEvents` nem em campos imutáveis. Ele preserva o
link existente, inclui somente o stream Web e não exclui o cadastro Android
dormente.

```bash
ga_get "v1alpha/properties/${FP_GA_PROPERTY}/bigQueryLinks?pageSize=200" \
  "$FP_CONFIG_DIR/bigquery-links.before.json"

test "$(jq '(.bigqueryLinks // []) | length' \
  "$FP_CONFIG_DIR/bigquery-links.before.json")" -eq 1
FP_BQ_LINK_NAME="$(jq -er '.bigqueryLinks[0].name' \
  "$FP_CONFIG_DIR/bigquery-links.before.json")"
FP_GCP_PROJECT_NUMBER="$(gcloud projects describe "$FP_GCP_PROJECT" \
  --project="$FP_GCP_PROJECT" --format='value(projectNumber)')"

jq -e --arg project "projects/${FP_GCP_PROJECT_NUMBER}" '
  .bigqueryLinks[0].project == $project and
  .bigqueryLinks[0].datasetLocation == "southamerica-east1"
' "$FP_CONFIG_DIR/bigquery-links.before.json" > /dev/null

ga_write PATCH \
  "v1alpha/${FP_BQ_LINK_NAME}?updateMask=daily_export_enabled,streaming_export_enabled,fresh_daily_export_enabled,include_advertising_id,export_streams" \
  "$(jq -nc --arg stream "properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_WEB_STREAM}" '{dailyExportEnabled:true,streamingExportEnabled:false,freshDailyExportEnabled:false,includeAdvertisingId:false,exportStreams:[$stream]}')" \
  "$FP_CONFIG_DIR/bigquery-link.patch.json"

ga_get "v1alpha/properties/${FP_GA_PROPERTY}/bigQueryLinks?pageSize=200" \
  "$FP_CONFIG_DIR/bigquery-links.after.json"
jq -e --arg stream "properties/${FP_GA_PROPERTY}/dataStreams/${FP_GA_WEB_STREAM}" '
  (.bigqueryLinks | length) == 1 and
  .bigqueryLinks[0].dailyExportEnabled == true and
  .bigqueryLinks[0].streamingExportEnabled == false and
  .bigqueryLinks[0].freshDailyExportEnabled == false and
  .bigqueryLinks[0].includeAdvertisingId == false and
  .bigqueryLinks[0].exportStreams == [$stream]
' "$FP_CONFIG_DIR/bigquery-links.after.json" > /dev/null
```

### B.6 Definições customizadas ausentes somente

Antes de criar, calcular quantas definições realmente faltam e abrir **Admin >
Data display > Custom definitions**. A quota livre deve ser pelo menos o número
ausente de cada tipo; não reservar 11/2 slots se parte das definições já existe.
A Admin API lista as definições, mas não expõe a quota de slots dessa tela; a
quota da Data API é diferente e não serve como substituta.

```bash
ga_get "v1beta/properties/${FP_GA_PROPERTY}/customDimensions?pageSize=200" \
  "$FP_CONFIG_DIR/custom-dimensions.before.json"
ga_get "v1beta/properties/${FP_GA_PROPERTY}/customMetrics?pageSize=200" \
  "$FP_CONFIG_DIR/custom-metrics.before.json"

jq '{eventDimensions: [(.customDimensions // [])[] |
  select(.scope == "EVENT")] | length}' \
  "$FP_CONFIG_DIR/custom-dimensions.before.json"
jq '{eventMetrics: [(.customMetrics // [])[] |
  select(.scope == "EVENT")] | length}' \
  "$FP_CONFIG_DIR/custom-metrics.before.json"

jq --argjson required '["screen","source","action","surface","target","operation","outcome","trigger","failure_type","stage","reason"]' '
  {
    missingDimensions:
      ($required - [(.customDimensions // [])[] |
        select(.scope == "EVENT") | .parameterName])
  }
' "$FP_CONFIG_DIR/custom-dimensions.before.json"

jq '
  {
    missingMetrics: ([
      {parameterName:"duration_ms", measurementUnit:"MILLISECONDS"},
      {parameterName:"item_count", measurementUnit:"STANDARD"}
    ] - [(.customMetrics // [])[] |
      select(.scope == "EVENT") |
      {parameterName, measurementUnit}])
  }
' "$FP_CONFIG_DIR/custom-metrics.before.json"

ensure_event_dimension() {
  local parameter_name="$1"
  local matches
  matches="$(jq --arg parameter_name "$parameter_name" '
    [(.customDimensions // [])[] |
      select(.parameterName == $parameter_name)] | length
  ' "$FP_CONFIG_DIR/custom-dimensions.before.json")"
  case "$matches" in
    0)
      ga_write POST \
        "v1beta/properties/${FP_GA_PROPERTY}/customDimensions" \
        "$(jq -nc --arg parameter_name "$parameter_name" '{parameterName:$parameter_name,displayName:$parameter_name,description:"Closed product analytics dimension",scope:"EVENT"}')" \
        "$FP_CONFIG_DIR/custom-dimension-${parameter_name}.created.json"
      ;;
    1)
      jq -e --arg parameter_name "$parameter_name" '
        [(.customDimensions // [])[] |
          select(.parameterName == $parameter_name)][0].scope == "EVENT"
      ' "$FP_CONFIG_DIR/custom-dimensions.before.json" > /dev/null || {
        echo "Conflicting custom dimension" >&2
        return 1
      }
      ;;
    *)
      echo "Duplicate custom dimension" >&2
      return 1
      ;;
  esac
}

for parameter_name in \
  screen source action surface target operation outcome trigger \
  failure_type stage reason; do
  ensure_event_dimension "$parameter_name"
done

ensure_event_metric() {
  local parameter_name="$1"
  local measurement_unit="$2"
  local matches
  matches="$(jq --arg parameter_name "$parameter_name" '
    [(.customMetrics // [])[] |
      select(.parameterName == $parameter_name)] | length
  ' "$FP_CONFIG_DIR/custom-metrics.before.json")"
  case "$matches" in
    0)
      ga_write POST \
        "v1beta/properties/${FP_GA_PROPERTY}/customMetrics" \
        "$(jq -nc --arg parameter_name "$parameter_name" --arg unit "$measurement_unit" '{parameterName:$parameter_name,displayName:$parameter_name,description:"Closed product analytics metric",measurementUnit:$unit,scope:"EVENT"}')" \
        "$FP_CONFIG_DIR/custom-metric-${parameter_name}.created.json"
      ;;
    1)
      jq -e --arg parameter_name "$parameter_name" \
        --arg unit "$measurement_unit" '
        [(.customMetrics // [])[] |
          select(.parameterName == $parameter_name)][0] as $metric |
        $metric.scope == "EVENT" and
        $metric.measurementUnit == $unit
      ' "$FP_CONFIG_DIR/custom-metrics.before.json" > /dev/null || {
        echo "Conflicting custom metric" >&2
        return 1
      }
      ;;
    *)
      echo "Duplicate custom metric" >&2
      return 1
      ;;
  esac
}

ensure_event_metric duration_ms MILLISECONDS
ensure_event_metric item_count STANDARD

ga_get "v1beta/properties/${FP_GA_PROPERTY}/customDimensions?pageSize=200" \
  "$FP_CONFIG_DIR/custom-dimensions.after.json"
ga_get "v1beta/properties/${FP_GA_PROPERTY}/customMetrics?pageSize=200" \
  "$FP_CONFIG_DIR/custom-metrics.after.json"

for parameter_name in \
  screen source action surface target operation outcome trigger \
  failure_type stage reason; do
  jq -e --arg parameter_name "$parameter_name" '
    [(.customDimensions // [])[] |
      select(.parameterName == $parameter_name and .scope == "EVENT")] |
    length == 1
  ' "$FP_CONFIG_DIR/custom-dimensions.after.json" > /dev/null
done

while read -r parameter_name measurement_unit; do
  jq -e --arg parameter_name "$parameter_name" \
    --arg unit "$measurement_unit" '
    [(.customMetrics // [])[] |
      select(
        .parameterName == $parameter_name and
        .scope == "EVENT" and
        .measurementUnit == $unit
      )] |
    length == 1
  ' "$FP_CONFIG_DIR/custom-metrics.after.json" > /dev/null
done <<'METRICS'
duration_ms MILLISECONDS
item_count STANDARD
METRICS
```

Não arquivar, renomear nem criar alias para resolver conflito; conflito ou
quota insuficiente é hard stop.

## Fase C — readback obrigatório na UI, concluído

As APIs oficiais atuais não cobrem todos os controles. Estes passos foram
executados na propriedade `535804267`; a lista permanece como roteiro de
readback futuro, sem criar recurso novo.

1. **Admin > Data collection and modification > Data collection**:
   confirmar Google Signals desligado e desligar **User-provided data
   collection**. A aceitação histórica da política pode ser permanente, mas a
   coleta/processamento deve ficar off.
2. No stream Web, abrir **Google tag > Configure tag settings** e desligar
   **Allow user-provided data capabilities**. Não configurar detecção automática,
   seletores, hash ou `user_data`.
3. Em **Advanced settings to allow for ads personalization**, desligar todas as
   regiões e aplicar. Se houver algum Google Ads link, manter **Enable
   Personalized Advertising** desligado nele. Não criar vínculo publicitário.
4. Em **Product links > BigQuery Links**, editar somente o link existente:
   exportação diária on; streaming off; Fresh Daily off quando o controle estiver
   disponível; advertising identifiers off; somente o stream Web selecionado;
   **Include user data** off. Não relinkar nem mudar região.
5. Em **Data display > Custom definitions**, confirmar a quota antes e reler as
   11 dimensões e 2 métricas depois do bloco B.6.

Limitações de readback:

- `getUserProvidedDataSettings` é somente GET; desligar exige UI.
- O controle property-wide de ads personalization exige UI.
- O recurso `BigQueryLink` da Admin API não expõe o toggle de user-data export.
  A prova complementar é não surgir nova tabela `users_*` ou
  `pseudonymous_users_*` depois do corte.
- Se um rótulo/toggle não existir na UI atual, parar e registrar a divergência;
  não presumir que a opção está desligada.

## Fase D — TTL seguro aplicado somente para tabelas futuras

O TTL padrão não altera tabelas existentes. O ETag impede sobrescrever uma
alteração concorrente. O readback compara ACLs e **somente as tabelas
preexistentes**; tabelas diárias novas podem surgir legitimamente entre os dois
snapshots e não devem causar falso positivo. Em 2026-09-30 o readback mostrou
`5184000000` ms, ACL idêntica e zero diferença nas 73 tabelas preexistentes.

```bash
set -euo pipefail

export FP_GCP_PROJECT='farol-politico-495210'
export FP_BQ_DATASET='farol-politico-495210:analytics_535804267'
FP_TTL_DIR="$(mktemp -d)"
readonly FP_TTL_DIR
cleanup_bq_ttl() {
  rm -rf -- "$FP_TTL_DIR"
}
trap cleanup_bq_ttl EXIT

bq --project_id="$FP_GCP_PROJECT" show --format=prettyjson \
  "$FP_BQ_DATASET" > "$FP_TTL_DIR/dataset.before.json"
bq --project_id="$FP_GCP_PROJECT" ls --max_results=10000 \
  --format=prettyjson "$FP_BQ_DATASET" \
  > "$FP_TTL_DIR/tables.list.before.json"

jq -r '.[].tableReference.tableId' \
  "$FP_TTL_DIR/tables.list.before.json" |
while IFS= read -r table_id; do
  bq --project_id="$FP_GCP_PROJECT" show --format=prettyjson \
    "${FP_BQ_DATASET}.${table_id}" |
  jq '{tableId:.tableReference.tableId,expirationTime:(.expirationTime // null)}'
done | jq -s 'sort_by(.tableId)' \
  > "$FP_TTL_DIR/table-expirations.before.json"

jq -S '(.access // []) | sort_by(tojson)' \
  "$FP_TTL_DIR/dataset.before.json" \
  > "$FP_TTL_DIR/dataset-acl.before.json"

FP_BQ_ETAG="$(jq -er '.etag' "$FP_TTL_DIR/dataset.before.json")"
FP_CURRENT_TTL="$(jq -r '.defaultTableExpirationMs // ""' \
  "$FP_TTL_DIR/dataset.before.json")"

if [ "$FP_CURRENT_TTL" != '5184000000' ]; then
  bq --project_id="$FP_GCP_PROJECT" update \
    --etag="$FP_BQ_ETAG" \
    --default_table_expiration=5184000 \
    "$FP_BQ_DATASET"
fi
unset FP_BQ_ETAG FP_CURRENT_TTL

bq --project_id="$FP_GCP_PROJECT" show --format=prettyjson \
  "$FP_BQ_DATASET" > "$FP_TTL_DIR/dataset.after.json"
bq --project_id="$FP_GCP_PROJECT" ls --max_results=10000 \
  --format=prettyjson "$FP_BQ_DATASET" \
  > "$FP_TTL_DIR/tables.list.after.json"

jq -r '.[].tableReference.tableId' \
  "$FP_TTL_DIR/tables.list.after.json" |
while IFS= read -r table_id; do
  bq --project_id="$FP_GCP_PROJECT" show --format=prettyjson \
    "${FP_BQ_DATASET}.${table_id}" |
  jq '{tableId:.tableReference.tableId,expirationTime:(.expirationTime // null)}'
done | jq -s 'sort_by(.tableId)' \
  > "$FP_TTL_DIR/table-expirations.after.json"

jq -S '(.access // []) | sort_by(tojson)' \
  "$FP_TTL_DIR/dataset.after.json" \
  > "$FP_TTL_DIR/dataset-acl.after.json"

jq -e '.defaultTableExpirationMs == "5184000000"' \
  "$FP_TTL_DIR/dataset.after.json" > /dev/null
cmp "$FP_TTL_DIR/dataset-acl.before.json" \
  "$FP_TTL_DIR/dataset-acl.after.json"

jq -n \
  --slurpfile before "$FP_TTL_DIR/table-expirations.before.json" \
  --slurpfile after "$FP_TTL_DIR/table-expirations.after.json" '
    $after[0] as $after_rows |
    [$before[0][] as $old |
      ($after_rows |
        map(select(.tableId == $old.tableId)) |
        first) as $new |
      select($new == null or
        $new.expirationTime != $old.expirationTime) |
      {
        tableId: $old.tableId,
        before: $old.expirationTime,
        after: ($new.expirationTime // null)
      }
    ]
  ' > "$FP_TTL_DIR/preexisting-table-diff.json"
test "$(jq 'length' "$FP_TTL_DIR/preexisting-table-diff.json")" -eq 0
```

Nunca substituir esse bloco por `bq rm`, `ALTER TABLE`, atualização wildcard,
mudança de expiração por tabela ou patch amplo de dataset. O histórico continua
sem expiração; somente tabelas criadas depois do default recebem 60 dias.

## Fase E — prova em navegador sem dados pessoais

Usar um perfil limpo, DevTools aberto antes da navegação, cache desabilitado e
sem extensão. Não exportar HAR.

1. Em estado `pending`, confirmar zero request para
   `googletagmanager.com`, `google-analytics.com` e Firebase Installations,
   nenhum cookie `_ga` e nenhum recurso remoto de fontes/CanvasKit.
2. Rejeitar, recarregar e confirmar a mesma ausência.
3. Aceitar, executar uma única ação conhecida e confirmar exatamente uma
   request de coleta para o pipeline esperado.
4. Conferir visualmente `tid=G-0P9XLRYVWT`, sem copiar a query string.
5. Revogar e confirmar que ações futuras não geram novos hits.
6. Aceitar novamente e confirmar que somente eventos futuros são enviados.

Formato permitido para evidência:

```text
consent_state=granted
host=www.google-analytics.com
path=/g/collect
expected_measurement_id=true
event_name=screen_viewed
query_keys=[...somente nomes das chaves...]
request_count=1
query_values=REDACTED
```

Hosts regionais oficiais podem variar; registrar o host realmente observado.
Não anexar screenshot da query completa. Se uma captura for indispensável,
recortar e redigir todos os valores antes de salvá-la.

## Fase F — corte no mesmo SHA

Pré-condições: fases A–E verdes, configuração externa relida, PR já integrado,
`main` estável e operador autorizado. Nenhum comando desta seção foi executado
na preparação do documento.

### F.1 Deploy desabilitado

```bash
set -euo pipefail

export FP_REPO='mo-bruno/voting-advice-brazil'
git fetch origin main
export FP_CUTOVER_SHA="$(git rev-parse origin/main)"
export FP_DISABLED_DISPATCH_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

gh variable set ANALYTICS_ENABLED --body false --repo "$FP_REPO"
test "$(gh variable get ANALYTICS_ENABLED --repo "$FP_REPO" \
  --json value --jq .value)" = 'false'
gh workflow run deploy-backend.yml --ref main --repo "$FP_REPO"

FP_BACKEND_RUN_ID=''
for _ in {1..24}; do
  FP_BACKEND_RUN_ID="$(
    gh run list --workflow deploy-backend.yml --branch main \
      --event workflow_dispatch --commit "$FP_CUTOVER_SHA" --limit 20 \
      --json databaseId,createdAt,headSha --repo "$FP_REPO" |
    jq -er --arg since "$FP_DISABLED_DISPATCH_UTC" \
      '[.[] | select(.createdAt >= $since)] |
       sort_by(.createdAt) | last | .databaseId // empty' 2>/dev/null || true
  )"
  [ -n "$FP_BACKEND_RUN_ID" ] && break
  sleep 5
done
test -n "$FP_BACKEND_RUN_ID"
gh run watch "$FP_BACKEND_RUN_ID" --exit-status --repo "$FP_REPO"
test "$(gh run view "$FP_BACKEND_RUN_ID" --repo "$FP_REPO" \
  --json headSha --jq .headSha)" = "$FP_CUTOVER_SHA"

FP_DISABLED_WEB_RUN_ID=''
for _ in {1..24}; do
  FP_DISABLED_WEB_RUN_ID="$(
    gh run list --workflow deploy-web.yml --branch main \
      --event workflow_run --commit "$FP_CUTOVER_SHA" --limit 20 \
      --json databaseId,createdAt,headSha --repo "$FP_REPO" |
    jq -er --arg since "$FP_DISABLED_DISPATCH_UTC" \
      '[.[] | select(.createdAt >= $since)] |
       sort_by(.createdAt) | last | .databaseId // empty' 2>/dev/null || true
  )"
  [ -n "$FP_DISABLED_WEB_RUN_ID" ] && break
  sleep 5
done
test -n "$FP_DISABLED_WEB_RUN_ID"
gh run watch "$FP_DISABLED_WEB_RUN_ID" --exit-status --repo "$FP_REPO"
test "$(gh run view "$FP_DISABLED_WEB_RUN_ID" --repo "$FP_REPO" \
  --json headSha --jq .headSha)" = "$FP_CUTOVER_SHA"
```

No site servido, provar bundle com analytics desabilitado, consentimento,
fontes locais e ausência total de hits. Se outro commit entrar em `main`, não
atualizar `FP_CUTOVER_SHA`: parar e reiniciar a sequência.

### F.2 Congelar merges e ativar o mesmo run/SHA

Depois de ambos os runs desabilitados provarem `headSha == FP_CUTOVER_SHA`,
congelar merges, preservar `FP_BACKEND_RUN_ID` e executar:

```bash
export FP_ENABLE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FP_BACKEND_ATTEMPT_BEFORE="$(gh run view "$FP_BACKEND_RUN_ID" \
  --repo "$FP_REPO" --json attempt --jq .attempt)"
gh variable set ANALYTICS_ENABLED --body true --repo "$FP_REPO"
test "$(gh variable get ANALYTICS_ENABLED --repo "$FP_REPO" \
  --json value --jq .value)" = 'true'
gh run rerun "$FP_BACKEND_RUN_ID" --repo "$FP_REPO"

FP_BACKEND_ATTEMPT_AFTER=''
for _ in {1..24}; do
  FP_BACKEND_ATTEMPT_AFTER="$(gh run view "$FP_BACKEND_RUN_ID" \
    --repo "$FP_REPO" --json attempt --jq .attempt)"
  [ "$FP_BACKEND_ATTEMPT_AFTER" -gt "$FP_BACKEND_ATTEMPT_BEFORE" ] && break
  sleep 5
done
test "$FP_BACKEND_ATTEMPT_AFTER" -gt "$FP_BACKEND_ATTEMPT_BEFORE"
gh run watch "$FP_BACKEND_RUN_ID" --exit-status --repo "$FP_REPO"
test "$(gh run view "$FP_BACKEND_RUN_ID" --repo "$FP_REPO" \
  --json headSha --jq .headSha)" = "$FP_CUTOVER_SHA"

FP_ENABLED_WEB_RUN_ID=''
for _ in {1..24}; do
  FP_ENABLED_WEB_RUN_ID="$(
    gh run list --workflow deploy-web.yml --branch main \
      --event workflow_run --commit "$FP_CUTOVER_SHA" --limit 20 \
      --json databaseId,createdAt,headSha --repo "$FP_REPO" |
    jq -er --arg since "$FP_ENABLE_UTC" \
      '[.[] | select(.createdAt >= $since)] |
       sort_by(.createdAt) | last | .databaseId // empty' 2>/dev/null || true
  )"
  [ -n "$FP_ENABLED_WEB_RUN_ID" ] && break
  sleep 5
done
test -n "$FP_ENABLED_WEB_RUN_ID"
test "$FP_ENABLED_WEB_RUN_ID" != "$FP_DISABLED_WEB_RUN_ID"
gh run watch "$FP_ENABLED_WEB_RUN_ID" --exit-status --repo "$FP_REPO"
test "$(gh run view "$FP_ENABLED_WEB_RUN_ID" --repo "$FP_REPO" \
  --json headSha --jq .headSha)" = "$FP_CUTOVER_SHA"
```

Somente depois de o bundle `true` estar servido e o canário consentido mostrar
visualmente o destino esperado, definir:

```bash
export CUTOVER_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

Registrar `FP_CUTOVER_SHA`, `CUTOVER_UTC`, os IDs dos runs, a confirmação
booleana do measurement ID, estado final da configuração e a versão desta
taxonomia. Não registrar a request do canário. Dashboards oficiais filtram
`event_timestamp >= UNIX_MICROS(@cutover)`; o histórico anterior é legado.

## Rollback

Mudar somente a variável não altera o JavaScript já publicado. O rollback
obrigatório recompila e republica o mesmo SHA pelo mesmo Backend run:

```bash
export FP_ROLLBACK_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FP_BACKEND_ATTEMPT_BEFORE="$(gh run view "$FP_BACKEND_RUN_ID" \
  --repo "$FP_REPO" --json attempt --jq .attempt)"
gh variable set ANALYTICS_ENABLED --body false --repo "$FP_REPO"
test "$(gh variable get ANALYTICS_ENABLED --repo "$FP_REPO" \
  --json value --jq .value)" = 'false'
gh run rerun "$FP_BACKEND_RUN_ID" --repo "$FP_REPO"

FP_BACKEND_ATTEMPT_AFTER=''
for _ in {1..24}; do
  FP_BACKEND_ATTEMPT_AFTER="$(gh run view "$FP_BACKEND_RUN_ID" \
    --repo "$FP_REPO" --json attempt --jq .attempt)"
  [ "$FP_BACKEND_ATTEMPT_AFTER" -gt "$FP_BACKEND_ATTEMPT_BEFORE" ] && break
  sleep 5
done
test "$FP_BACKEND_ATTEMPT_AFTER" -gt "$FP_BACKEND_ATTEMPT_BEFORE"
gh run watch "$FP_BACKEND_RUN_ID" --exit-status --repo "$FP_REPO"
test "$(gh run view "$FP_BACKEND_RUN_ID" --repo "$FP_REPO" \
  --json headSha --jq .headSha)" = "$FP_CUTOVER_SHA"

FP_ROLLBACK_WEB_RUN_ID=''
for _ in {1..24}; do
  FP_ROLLBACK_WEB_RUN_ID="$(
    gh run list --workflow deploy-web.yml --branch main \
      --event workflow_run --commit "$FP_CUTOVER_SHA" --limit 20 \
      --json databaseId,createdAt,headSha --repo "$FP_REPO" |
    jq -er --arg since "$FP_ROLLBACK_UTC" \
      '[.[] | select(.createdAt >= $since)] |
       sort_by(.createdAt) | last | .databaseId // empty' 2>/dev/null || true
  )"
  [ -n "$FP_ROLLBACK_WEB_RUN_ID" ] && break
  sleep 5
done
test -n "$FP_ROLLBACK_WEB_RUN_ID"
test "$FP_ROLLBACK_WEB_RUN_ID" != "$FP_ENABLED_WEB_RUN_ID"
gh run watch "$FP_ROLLBACK_WEB_RUN_ID" --exit-status --repo "$FP_REPO"
test "$(gh run view "$FP_ROLLBACK_WEB_RUN_ID" --repo "$FP_REPO" \
  --json headSha --jq .headSha)" = "$FP_CUTOVER_SHA"
```

Validar em perfil limpo que o bundle servido pelo novo run Web está
desabilitado. Abas antigas podem
continuar executando o bundle anterior até reload ou fechamento; avisar os
testadores e não tratar a variável como kill switch instantâneo para abas já
abertas.

## Consultas pós-corte sem identificadores

Usar o menor intervalo de sufixos que contenha o corte. Nenhuma consulta abaixo
seleciona `user_pseudo_id`, `user_id` ou valores de `event_params`.
Por padrão, o intervalo é exatamente a data UTC de `CUTOVER_UTC`; só definir
`FP_START_SUFFIX` ou `FP_END_SUFFIX` antes deste bloco quando for necessário
abranger outra tabela diária.

```bash
set -euo pipefail

export FP_GCP_PROJECT='farol-politico-495210'
test -n "${CUTOVER_UTC:?CUTOVER_UTC is required}"
date -u -d "$CUTOVER_UTC" +%s >/dev/null

FP_CUTOVER_SUFFIX="$(date -u -d "$CUTOVER_UTC" +%Y%m%d)"
export FP_START_SUFFIX="${FP_START_SUFFIX:-$FP_CUTOVER_SUFFIX}"
export FP_END_SUFFIX="${FP_END_SUFFIX:-$FP_CUTOVER_SUFFIX}"

validate_utc_suffix() {
  local suffix="$1"
  local normalized
  [[ "$suffix" =~ ^[0-9]{8}$ ]]
  normalized="$(date -u \
    -d "${suffix:0:4}-${suffix:4:2}-${suffix:6:2}" +%Y%m%d)"
  test "$normalized" = "$suffix"
}

validate_utc_suffix "$FP_START_SUFFIX"
validate_utc_suffix "$FP_END_SUFFIX"
if [[ "$FP_START_SUFFIX" > "$FP_END_SUFFIX" ]]; then
  echo 'FP_START_SUFFIX must not be after FP_END_SUFFIX' >&2
  exit 1
fi
unset FP_CUTOVER_SUFFIX
```

### Contagem por evento

```bash
bq --project_id="$FP_GCP_PROJECT" query --use_legacy_sql=false \
  --parameter="cutover:TIMESTAMP:${CUTOVER_UTC}" \
  --parameter="start_suffix:STRING:${FP_START_SUFFIX}" \
  --parameter="end_suffix:STRING:${FP_END_SUFFIX}" '
SELECT event_name, COUNT(*) AS event_count
FROM `farol-politico-495210.analytics_535804267.events_*`
WHERE REGEXP_CONTAINS(_TABLE_SUFFIX, r"^[0-9]{8}$")
  AND _TABLE_SUFFIX BETWEEN @start_suffix AND @end_suffix
  AND event_timestamp >= UNIX_MICROS(@cutover)
GROUP BY event_name
ORDER BY event_count DESC, event_name
'
```

### Nomes fora da allowlist

Os quatro nomes automáticos aprovados são separados da allowlist de 26 eventos
de produto. Qualquer outro nome exige investigação.

```bash
bq --project_id="$FP_GCP_PROJECT" query --use_legacy_sql=false \
  --parameter="cutover:TIMESTAMP:${CUTOVER_UTC}" \
  --parameter="start_suffix:STRING:${FP_START_SUFFIX}" \
  --parameter="end_suffix:STRING:${FP_END_SUFFIX}" '
WITH allowed AS (
  SELECT event_name FROM UNNEST([
    "quiz_intro_viewed", "quiz_started", "quiz_restarted",
    "thesis_viewed", "thesis_skipped", "weighting_started",
    "weight_added", "weight_removed", "party_selection_viewed",
    "party_toggled", "results_viewed", "comparison_opened",
    "comparison_candidate_added", "follow_waitlist_viewed",
    "follow_waitlist_prompt_viewed", "follow_waitlist_cta_clicked",
    "follow_waitlist_registered", "follow_waitlist_failed",
    "thesis_answered", "quiz_completed", "weighting_completed",
    "party_selection_completed", "screen_viewed", "engagement_action",
    "operation_result", "quiz_abandoned",
    "page_view", "session_start", "first_visit", "user_engagement"
  ]) AS event_name
)
SELECT event_name, COUNT(*) AS event_count
FROM `farol-politico-495210.analytics_535804267.events_*`
WHERE REGEXP_CONTAINS(_TABLE_SUFFIX, r"^[0-9]{8}$")
  AND _TABLE_SUFFIX BETWEEN @start_suffix AND @end_suffix
  AND event_timestamp >= UNIX_MICROS(@cutover)
  AND event_name NOT IN (SELECT event_name FROM allowed)
GROUP BY event_name
ORDER BY event_count DESC, event_name
'
```

Resultado esperado: zero linhas.

### Conjunto de chaves, nunca valores

```bash
bq --project_id="$FP_GCP_PROJECT" query --use_legacy_sql=false \
  --parameter="cutover:TIMESTAMP:${CUTOVER_UTC}" \
  --parameter="start_suffix:STRING:${FP_START_SUFFIX}" \
  --parameter="end_suffix:STRING:${FP_END_SUFFIX}" '
SELECT
  event_name,
  ARRAY_AGG(DISTINCT parameter.key ORDER BY parameter.key) AS parameter_keys,
  COUNT(DISTINCT parameter.key) AS parameter_key_count
FROM `farol-politico-495210.analytics_535804267.events_*`,
UNNEST(event_params) AS parameter
WHERE REGEXP_CONTAINS(_TABLE_SUFFIX, r"^[0-9]{8}$")
  AND _TABLE_SUFFIX BETWEEN @start_suffix AND @end_suffix
  AND event_timestamp >= UNIX_MICROS(@cutover)
GROUP BY event_name
ORDER BY event_name
'
```

Comparar as chaves customizadas com a política do código. Chaves automáticas do
SDK devem ser classificadas separadamente; nunca abrir os respectivos valores
para “descobrir” seu conteúdo.

### Stream e plataforma esperados

```bash
bq --project_id="$FP_GCP_PROJECT" query --use_legacy_sql=false \
  --parameter="cutover:TIMESTAMP:${CUTOVER_UTC}" \
  --parameter="start_suffix:STRING:${FP_START_SUFFIX}" \
  --parameter="end_suffix:STRING:${FP_END_SUFFIX}" '
SELECT
  COUNT(*) AS total_events,
  COUNTIF(platform != "WEB") AS unexpected_platform_count,
  COUNTIF(stream_id != "14797759925") AS unexpected_stream_count
FROM `farol-politico-495210.analytics_535804267.events_*`
WHERE REGEXP_CONTAINS(_TABLE_SUFFIX, r"^[0-9]{8}$")
  AND _TABLE_SUFFIX BETWEEN @start_suffix AND @end_suffix
  AND event_timestamp >= UNIX_MICROS(@cutover)
'
```

As duas contagens inesperadas devem ser zero.

### Distribuição agregada do consentimento

```bash
bq --project_id="$FP_GCP_PROJECT" query --use_legacy_sql=false \
  --parameter="cutover:TIMESTAMP:${CUTOVER_UTC}" \
  --parameter="start_suffix:STRING:${FP_START_SUFFIX}" \
  --parameter="end_suffix:STRING:${FP_END_SUFFIX}" '
SELECT
  COALESCE(privacy_info.analytics_storage, "UNSET") AS analytics_storage,
  COALESCE(privacy_info.ads_storage, "UNSET") AS ads_storage,
  COUNT(*) AS event_count
FROM `farol-politico-495210.analytics_535804267.events_*`
WHERE REGEXP_CONTAINS(_TABLE_SUFFIX, r"^[0-9]{8}$")
  AND _TABLE_SUFFIX BETWEEN @start_suffix AND @end_suffix
  AND event_timestamp >= UNIX_MICROS(@cutover)
GROUP BY analytics_storage, ads_storage
ORDER BY analytics_storage, ads_storage
'
```

Não há expectativa de evento com analytics negado: o aplicativo usa
consentimento básico e só inicializa o pipeline após aceitação. `ads_storage`
permanece negado.

### Ausência de novas tabelas intraday e de user-data

Executar depois de ao menos um ciclo diário completo. Tabelas históricas
anteriores ao corte permanecem e não são falha.

```bash
bq --project_id="$FP_GCP_PROJECT" query --use_legacy_sql=false \
  --parameter="cutover:TIMESTAMP:${CUTOVER_UTC}" '
SELECT table_name, creation_time
FROM `farol-politico-495210.analytics_535804267.INFORMATION_SCHEMA.TABLES`
WHERE creation_time >= @cutover
  AND (
    STARTS_WITH(table_name, "events_intraday_") OR
    STARTS_WITH(table_name, "users_") OR
    STARTS_WITH(table_name, "pseudonymous_users_")
  )
ORDER BY creation_time, table_name
'
```

Resultado esperado: zero linhas. Se a tabela intraday do próprio dia já
existia antes da mudança, aguardar a conclusão do ciclo diário e validar que
nenhuma nova tabela intraday foi criada depois do corte; não excluí-la.

## Hard stops

Interromper a ativação, ou executar rollback se já ativado, quando houver:

- Admin API sem escopo, propriedade inacessível ou readback incompleto;
- mais de um stream Web/destino, measurement ID diferente ou outro link;
- tentativa de criar/relinkar/excluir propriedade, stream, link ou dataset;
- Android selecionado para exportação ou criação/ativação de Android/iOS;
- Google Signals, ads personalization, user-provided data ou advertising ID on;
- streaming/fresh-daily on, user-data export on ou exportação diária off;
- Enhanced Measurement diferente de page views only;
- redação de e-mail/chaves mínimas ausente;
- quota insuficiente, definição duplicada/conflitante ou definição user-scoped;
- falha de ETag, mudança de ACL ou mudança de expiração em qualquer tabela
  preexistente;
- hit antes do consentimento, depois da revogação, duplicado ou destinado a
  outra propriedade;
- evento customizado fora da allowlist, parâmetro político, identificador,
  URL/query, rota crua, texto livre ou erro bruto;
- recurso Google/Flutter remoto antes da escolha;
- SHA diferente entre Backend, Web e `FP_CUTOVER_SHA`, ou merge durante o
  intervalo congelado;
- novas tabelas `events_intraday_*`, `users_*` ou `pseudonymous_users_*` após
  a janela de verificação.

## Referências oficiais verificadas

- [Google Analytics Admin API](https://developers.google.com/analytics/devguides/config/admin/v1/rest)
- [Google Signals settings](https://developers.google.com/analytics/devguides/config/admin/v1/rest/v1alpha/GoogleSignalsSettings)
- [Enhanced Measurement settings](https://developers.google.com/analytics/devguides/config/admin/v1/rest/v1alpha/EnhancedMeasurementSettings)
- [Data redaction settings](https://developers.google.com/analytics/devguides/config/admin/v1/rest/v1alpha/DataRedactionSettings)
- [Data retention settings](https://developers.google.com/analytics/devguides/config/admin/v1/rest/v1beta/DataRetentionSettings)
- [BigQueryLink resource](https://developers.google.com/analytics/devguides/config/admin/v1/rest/v1alpha/properties.bigQueryLinks)
- [User-provided data collection](https://support.google.com/analytics/answer/14077171)
- [Advanced ads-personalization settings](https://support.google.com/analytics/answer/9626162)
- [Set up BigQuery Export](https://support.google.com/analytics/answer/9823238)
- [BigQuery Export user-data schema](https://support.google.com/analytics/answer/12769371)
- [`bq` CLI reference](https://cloud.google.com/bigquery/docs/reference/bq-cli-reference)
