# Firmware histórico — Farol Político

O firmware ESP32 + Arduino Mega é mantido como referência histórica, sem suporte nas implantações atuais. O IoT físico está desativado por padrão desde 2026-09-09 e não tem deployment automático. Compilar firmware em CI não programa um dispositivo nem ativa um serviço de notificações.

O produto atual funciona sem hardware. Cloud Run usa `IOT_FEATURE_ENABLED=false`, e Flutter usa `--dart-define=IOT_FEATURE_ENABLED=false`: pareamento e telas físicas ficam indisponíveis. O [desenho atual](../docs/superpowers/specs/2026-09-09-disable-iot-and-close-gaps-design.md) substitui as expectativas operacionais dos documentos antigos.

## Desenvolvimento histórico, sem suporte

Para experimentar o fluxo completo retido, é necessário ativar ambas as flags: `IOT_FEATURE_ENABLED=true` no backend e `--dart-define=IOT_FEATURE_ENABLED=true` no build/run Flutter. Também são necessários banco migrado, URLs compatíveis, Wi-Fi, broker MQTT, firmware configurado e pareamento. Isso não fornece um motor concluído de alinhamento entre respostas do quiz e votos legislativos, nem um scheduler de produção.

A API não agenda notificações. Após a configuração histórica, o monitor retido depende de uma invocação externa de execução única, a partir de `backend/`:

```bash
IOT_FEATURE_ENABLED=true uv run python -m app.infrastructure.scheduler
```

Esse comando executa uma vez e termina; qualquer periodicidade teria de ser organizada externamente e não está implantada pelo projeto. Com a flag falsa, o job não faz trabalho externo. O job mantém votos como `pending`, exceto abstenções (`abstained`); não deduz compatibilidade de votos “Sim” ou “Não”. Reserva o evento antes de publicar para deduplicar, mas falhas do broker após essa reserva não são reenviadas. GNews pode alimentar notícias temáticas neste fluxo histórico e é separado das notícias oficiais ativas do app.

O ESP32 gera um `device_token` físico persistente, usa sessões de pareamento e assina `farol/{device_token}` por MQTT. Esse token é distinto do `anonymous_id` privado do app. O Mega recebe frames UART `V|...` para telas e `Q|...` para o QR de pareamento.

## Compilação manual histórica

Os comandos abaixo partem da raiz do repositório e exigem PlatformIO:

```bash
cp firmware/esp32/include/secrets.h.example firmware/esp32/include/secrets.h
# Preencher credenciais locais de Wi-Fi no secrets.h; não versionar segredos.
pio run --project-dir firmware/esp32
pio run --project-dir firmware/mega
```

Revise [esp32/include/config.h](esp32/include/config.h) para os endereços de backend/broker e o contrato físico. Não presuma que a URL de um deploy atual aceita pareamento: as rotas permanecem desativadas por padrão.

Para o shield TFT de 16 bits no Mega, a configuração histórica da biblioteca `MCUFRIEND_kbv` exige habilitar `USE_SPECIAL` em `firmware/mega/.pio/libdeps/megaatmega2560/MCUFRIEND_kbv/utility/mcufriend_shield.h` e `USE_MEGA_16BIT_SHIELD` no arquivo vizinho `mcufriend_special.h`. Esses arquivos são gerados pela instalação das dependências; mudanças locais podem precisar ser reaplicadas.

O envio ao aparelho é manual e usa a porta escolhida pelo operador, por exemplo:

```bash
pio run --target upload --project-dir firmware/mega --upload-port <PORTA>
```

Este README preserva instruções de desenvolvimento histórico; não representa validação recente em hardware ou promessa de operação em produção.
