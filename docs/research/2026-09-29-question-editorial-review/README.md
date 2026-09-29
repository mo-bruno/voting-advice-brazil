# Revisão editorial com validação humana

Continuação dos perfis concluídos: mapa comum das decisões e primeiro bloco de afirmações compatíveis com os quatro botões do aplicativo.

- [Documento central](ORCHESTRATION.md): estado do fluxo e limite da aprovação.
- [Bloco 1 aprovado](BLOCK_01.md): quatro afirmações, explicações, origens e limites.
- [Revisão política e linguística](EDITORIAL_REVIEW.md): critérios e alterações de redação.
- [Mapa comum](DECISION_MAP.md): famílias de decisões nas dez categorias.
- [Protocolo](PROTOCOL.md): regras de interpretação e aprovação.

Os treze perfis anteriores foram preservados. Três dos agentes originais apenas organizaram os registros existentes em recortes editoriais; não classificaram candidaturas em relação às perguntas deste bloco. O usuário aprovou B01 v1. A rodada dos treze responsáveis foi iniciada, gerou seis pareceres piloto e está pausada enquanto a [bateria completa](../2026-09-29-full-thesis-battery/BATTERY.md) passa pela revisão humana.

O mapa cobre os 636 registros selecionados no inventário, não todas as frases dos PDFs. As famílias incluem subdecisões que podem exigir perguntas separadas. Número de vínculos ou presença temática não mede afinidade, relevância ou cobertura da mesma redação.

## Conferência após a aprovação

A `validation.json` deste diretório é o retrato histórico da entrega editorial anterior à aprovação. `assemble.py` agora recusa executar após a aprovação, impedindo reinicialização acidental das decisões humanas. A redação e a explicação aprovadas são conferidas por hash na [etapa seguinte](../2026-09-29-approved-block-01-validation/validation.json).
