# Desenho: Pareamento do Gadget IoT Farol Politico

Data: 2026-05-22

## Contexto

O repositorio `main` ja entrega o fluxo principal do app:

- Quiz com teses TSE 2022 via `GET /api/v1/quiz/questions`.
- Submissao do quiz via `POST /api/v1/quiz/submit`.
- Identidade anonima movel persistida no Flutter por `DeviceIdentityStore`.
- Busca e acompanhamento de politicos via `PUT /api/v1/me/followed-actor`.
- Evidencias oficiais da Camara, incluindo votos recentes, como dados informativos.

O gadget passa a ser o escopo principal desta fase. O app e o backend nao devem ter o fluxo de quiz alterado; eles receberao somente a camada adicional necessaria para vincular um dispositivo fisico ao dispositivo movel anonimo.

Tambem existem dois sketches Arduino fora do repositorio que servem como base:

- `sketch_may22b_esp.ino`: ESP32 com WiFi, LED RGB, botao, polling HTTP da Camara e envio UART para o Mega.
- `sketch_may22c.ino`: Arduino Mega com display TFT ILI9486, renderizando frames UART `V|cabec|sub|pagInfo|status|l1|l2|l3|l4`.

O desenho preserva o que funciona nesses sketches: arquitetura ESP32 + Mega, LED, botao, display e protocolo UART. O polling HTTP direto no ESP32 sera substituido por MQTT controlado pelo backend.

## Objetivos

1. Adicionar uma interface no app para conectar e visualizar o status de um Farol fisico.
2. Exibir o QR code de pareamento no display do gadget, nao no app.
3. Registrar no backend o vinculo entre o `anonymous_id` do app e o `device_token` fisico do gadget.
4. Confirmar o pareamento tanto no app quanto no display/LED do gadget.
5. Adicionar uma estrutura de firmware ao repositorio baseada nos sketches ESP32 e Mega.
6. Preparar o contrato para mensagens MQTT em `farol/{device_token}` sem exigir, nesta fatia, o loop completo Camara -> alinhamento -> MQTT.

## Fora de Escopo

- Mudar o quiz, resultados, pesos ou ranking atual.
- Mudar o fluxo de acompanhar politico ja existente.
- Implementar a regra completa de alinhamento entre votacoes legislativas e posicoes do usuario.
- Implementar BLE ou captive portal como fluxo principal.
- Criar login, conta, email, CPF ou qualquer identificacao pessoal.
- Migrar o hardware para uma unica placa.

## Decisoes

### Pareamento principal

O gadget entra em modo de pareamento e mostra no TFT um QR code contendo:

```text
farol://pair?device_token=<uuid>&pairing_code=<codigo_curto>
```

O app abre uma tela de "Conectar Farol", escaneia esse QR e envia o conteudo ao backend junto com o `X-Farol-Anonymous-Id` ja usado pelo app.

### Codigo manual como fallback

Se a camera falhar, o app permite digitar um codigo curto exibido no display. Para MVP, o codigo manual pode ser o proprio `device_token` encurtado visualmente ou um `pairing_code` temporario. A implementacao deve preferir `pairing_code`, porque ele e mais facil de digitar e evita expor o token inteiro desnecessariamente.

### Botao fisico

O botao do ESP32 abre o modo de pareamento. Acao recomendada:

- Aperto extra-longo: exibir QR/codigo de pareamento no display.
- Enquanto pareia: LED azul pulsante.
- Apos sucesso: LED verde e tela "Farol conectado".

### Alternativas documentadas, nao implementadas agora

- BLE: possivel no ESP32, mas exige plugin Flutter, permissoes e testes em Android/iOS.
- WiFi AP/captive portal: bom para configurar WiFi, mas pesado para pareamento MVP.
- USB Serial: util para bancada, nao adequado para usuario final.

## Arquitetura

### Mobile Flutter

Adicionar uma feature `iot` sem alterar as features existentes:

```text
mobile/lib/features/iot/
  iot_device_page.dart
  iot_pairing_page.dart
```

Adicionar modelos e cliente API:

```text
mobile/lib/shared/models/iot_device.dart
mobile/lib/shared/iot_device_session.dart
```

Responsabilidades:

- Carregar o status do Farol vinculado ao `anonymous_id` atual.
- Abrir o scanner de QR.
- Enviar `device_token` e `pairing_code` ao backend.
- Exibir estados: nao conectado, pareando, conectado, erro.

Entrada de UI:

- Home: botao "MEU FAROL" ou "CONECTAR FAROL" como entrada obrigatoria da Fatia 1.
- Tela de politico acompanhado: sem mudanca obrigatoria na Fatia 1; pode receber status do Farol em uma fatia posterior sem bloquear acompanhamento de politico.

### Backend FastAPI

Adicionar um novo recurso `iot_devices`, separado de `political_actors`.

Rotas propostas:

```http
GET /api/v1/me/iot-device
PUT /api/v1/me/iot-device
DELETE /api/v1/me/iot-device
POST /api/v1/iot-devices/{device_token}/pairing-session
```

`GET /me/iot-device`:

- Header: `X-Farol-Anonymous-Id`.
- Retorna o gadget vinculado ou `404` se nao houver.

`PUT /me/iot-device`:

- Header: `X-Farol-Anonymous-Id`.
- Body:

```json
{
  "device_token": "550e8400-e29b-41d4-a716-446655440000",
  "pairing_code": "482913"
}
```

- Valida uma sessao de pareamento ativa e nao consumida para `device_token` + `pairing_code`.
- Cria ou substitui o vinculo do app atual.
- Marca a sessao de pareamento como consumida.
- Publica uma mensagem MQTT de confirmacao para `farol/{device_token}`.
- Retorna status conectado.

`DELETE /me/iot-device`:

- Remove o vinculo do app atual.
- Opcionalmente publica evento MQTT de desvinculo.

`POST /iot-devices/{device_token}/pairing-session`:

- Uso pelo ESP32 quando o usuario coloca o gadget em modo de pareamento.
- Body:

```json
{
  "pairing_code": "482913",
  "firmware_version": "0.1.0"
}
```

- Cria uma sessao temporaria de pareamento com expiracao curta, recomendada em 10 minutos.
- Retorna o `pairing_code`, `expires_at` e o payload QR canonico que deve ser exibido no display.
- Este endpoint nao usa `X-Farol-Anonymous-Id`, porque e chamado pelo gadget.

### Banco de Dados

Nova tabela:

```text
iot_device_links
  device_token varchar(64) primary key
  anonymous_id varchar(64) not null
  status varchar(32) not null default 'linked'
  created_at datetime not null
  updated_at datetime not null
  last_seen_at datetime nullable
```

Indices:

- `ix_iot_device_links_anonymous_id`
- `ix_iot_device_links_updated_at`

Regra de unicidade:

- Um `device_token` aponta para no maximo um `anonymous_id`.
- Um `anonymous_id` pode ter no maximo um gadget vinculado no MVP.

Nova tabela para pareamento temporario:

```text
iot_pairing_sessions
  id integer primary key
  device_token varchar(64) not null
  pairing_code_hash varchar(128) not null
  qr_payload varchar(512) not null
  firmware_version varchar(32) nullable
  created_at datetime not null
  expires_at datetime not null
  consumed_at datetime nullable
```

Indices:

- `ix_iot_pairing_sessions_device_expires`

Regra:

- O backend valida somente sessoes nao expiradas e nao consumidas.
- A criacao de uma nova sessao para o mesmo `device_token` invalida as sessoes anteriores nao consumidas.

### Firmware ESP32

Criar estrutura no repositorio:

```text
firmware/esp32/
  platformio.ini
  include/config.h
  include/secrets.h.example
  src/main.cpp
  lib/DeviceToken/
  lib/WifiManager/
  lib/MqttClient/
  lib/PayloadParser/
  lib/LedStatus/
  lib/DisplayUart/
```

Basear no sketch ESP32, mas trocar responsabilidades:

- Remover polling HTTP direto da Camara do caminho principal.
- Gerar ou recuperar `device_token` persistente em NVS.
- Ao entrar em modo pareamento, gerar `pairing_code`, registrar sessao no backend por HTTP e exibir o QR retornado.
- Subscrever `farol/{device_token}` via MQTT.
- Parsear payload JSON do backend.
- Atualizar LED conforme `color`.
- Enviar frames UART ao Mega.
- Enviar frame de QR ao Mega.

Frame UART novo para QR:

```text
Q|<titulo>|<payload_qr>|<codigo_curto>\n
```

Exemplo:

```text
Q|Conectar Farol|farol://pair?device_token=550e8400-e29b-41d4-a716-446655440000&pairing_code=482913|482913
```

Frame MQTT de confirmacao:

```json
{
  "type": "pairing_confirmed",
  "color": "green",
  "deputy_name": "Farol Politico",
  "vote_summary": "Dispositivo conectado ao app com sucesso.",
  "timestamp_utc": "2026-05-22T20:00:00Z"
}
```

Frame MQTT de votacao futura:

```json
{
  "type": "vote_event",
  "color": "green",
  "deputy_name": "Erika Hilton",
  "vote_summary": "Votou SIM em votacao acompanhada.",
  "timestamp_utc": "2026-05-22T20:00:00Z"
}
```

### Firmware Arduino Mega

Criar estrutura:

```text
firmware/mega/
  platformio.ini
  src/main.cpp
```

Basear no sketch Mega atual:

- Manter TFT ILI9486 via `MCUFRIEND_kbv`.
- Manter frame `V|...` para telas de status/evento.
- Adicionar frame `Q|...` para renderizar QR code e codigo manual.

Renderizacao do QR:

- Usar biblioteca QR compatavel com Arduino AVR, se o tamanho couber.
- Se o QR ficar pesado ou ilegivel no TFT, fallback aceitavel para MVP: mostrar o codigo manual grande e o `device_token` abreviado. O app mantem campo manual.

## Fluxo de Pareamento

1. Usuario liga o gadget.
2. ESP32 conecta no WiFi e no MQTT.
3. Mega mostra tela inicial "Aguardando pareamento" se nao houver confirmacao recente.
4. Usuario segura o botao no gadget.
5. ESP32 gera `pairing_code` temporario.
6. ESP32 registra `POST /api/v1/iot-devices/{device_token}/pairing-session`.
7. Backend grava sessao temporaria e retorna o payload QR canonico `farol://pair?...`.
8. ESP32 envia frame `Q|...` ao Mega.
9. Mega renderiza QR e codigo manual.
10. Usuario abre "Conectar Farol" no app.
11. App escaneia QR ou recebe codigo manual.
12. App chama `PUT /api/v1/me/iot-device`.
13. Backend valida a sessao, cria o vinculo `anonymous_id -> device_token` e consome a sessao.
14. Backend publica confirmacao MQTT em `farol/{device_token}`.
15. ESP32 recebe confirmacao, LED verde, envia tela de sucesso ao Mega.
16. App mostra status "Farol conectado".

## Erros e Estados

Mobile:

- Sem camera/permissao negada: mostrar entrada manual.
- QR invalido: nao chamar backend; mostrar mensagem clara.
- Backend 404/422: codigo expirado ou token invalido.
- Sem internet: permitir tentar novamente.

Backend:

- `404`: nenhum gadget vinculado ao app.
- `409`: gadget ja vinculado a outro app, se a politica de substituicao estiver bloqueada.
- `422`: QR/payload invalido, codigo expirado ou sessao ja consumida.

Firmware:

- WiFi indisponivel: LED amarelo e tela de erro.
- MQTT indisponivel: LED azul pulsante lento e tela "Conectando broker".
- Payload MQTT invalido: log serial e manter ultimo estado visual.

## Seguranca e Privacidade

- O app continua anonimo. O backend armazena somente `anonymous_id` e `device_token`.
- `device_token` nao deve ser derivado do MAC; deve ser UUID persistente gerado no primeiro boot.
- QR com `pairing_code` temporario reduz risco de alguem fotografar o token e parear depois.
- `pairing_code` deve expirar e ser armazenado como hash, nao em texto puro.
- Para MVP academico, HiveMQ publico e TLS sem validacao estrita podem ser aceitos como debito tecnico, desde que documentados.
- Bloqueador mesmo para MVP: credenciais WiFi hardcoded em arquivo commitado. Devem ficar em `secrets.h`, ignorado pelo Git.

## Testes

Backend:

- Testes de schema/API para `GET`, `PUT` e `DELETE /me/iot-device`.
- Teste de criacao e expiracao de `POST /iot-devices/{device_token}/pairing-session`.
- Teste de substituicao de vinculo para o mesmo `anonymous_id`.
- Teste de rejeicao de QR/pairing code invalido.
- Teste de consumo unico da sessao de pareamento.
- Teste de publicacao MQTT usando adapter fake, sem broker real.

Mobile:

- Testes de parsing de QR `farol://pair?...`.
- Teste de `ApiClient` para envio de `device_token` e `pairing_code`.
- Teste de tela mostrando sucesso de pareamento.
- Teste de fallback manual.

Firmware:

- Build check PlatformIO para ESP32.
- Build check PlatformIO para Mega.
- Teste unitario, se viavel, do parser JSON e do sanitizador UART.
- Validacao manual de bancada: botao -> QR no display -> app vincula -> MQTT confirmacao -> display sucesso.

## Plano de Entrega

Fatia 1:

- Backend: modelos, migration, endpoints de vinculo/pareamento e MQTT adapter fake/testado.
- Mobile: tela "Meu Farol", scanner/entrada manual, status conectado.
- Firmware: estrutura PlatformIO, ESP32 MQTT, Mega com frame `Q|`.

Fatia 2:

- Publicacao manual/test endpoint para validar mensagem MQTT no gadget.
- Melhorar QR real no TFT se o fallback manual for usado na Fatia 1.

Fatia 3:

- Loop Camara -> selecionar seguidores -> publicar eventos reais.
- Regra de alinhamento entre voto nominal e preferencia do usuario.

## Criterios de Aceite

- O usuario consegue abrir uma tela no app e ver que nao ha Farol conectado.
- O gadget consegue exibir no display um QR ou codigo de pareamento.
- O ESP32 registra uma sessao temporaria de pareamento antes de mostrar o QR.
- O app consegue ler o QR ou receber codigo manual e vincular o gadget ao `anonymous_id` atual.
- O app mostra "Farol conectado" apos resposta do backend.
- O backend persiste o vinculo sem armazenar PII.
- O backend envia confirmacao MQTT por adapter testavel.
- O ESP32 recebe uma mensagem no topico `farol/{device_token}` e atualiza LED/display.
- O Mega continua renderizando os frames `V|...` existentes e tambem aceita `Q|...`.
- O fluxo de quiz e acompanhamento de politico existente continua inalterado.
