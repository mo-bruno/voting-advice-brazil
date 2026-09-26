# Comparação V1 × V2 — Presidência 2026

## Resultado

| Medida | Edição anterior | V2 |
|---|---:|---:|
| Formulações preservadas | 38 | 38 |
| Células classificadas | 117 | 494 |
| Perguntas publicadas | 9 | 13 |
| Posições categóricas no quiz | 37 | 52 |
| Condicionais ou mistas no quiz | 4 | 7 |
| Sem manifestação suficiente no quiz | 76 | 110 |
| Pares sem posição categórica em comum | 47 de 78 | 43 de 78 |

A V2 não tenta maximizar cobertura. Ela completa a matriz, aplica uma regra uniforme e só então seleciona o questionário.

## Seleção

As nove perguntas já publicadas foram mantidas: `T001`, `T002`, `T003`, `T011`, `T017`, `T018`, `T026B`, `T034A` e `T036`.

Quatro perguntas passaram a integrar o quiz após a revisão completa:

- `T005`, jornada legal de 30 horas: uma concordância, três discordâncias e duas posições condicionais;
- `T015`, idade mínima de 16 anos para responder como adulto em crimes graves: uma concordância, quatro discordâncias e uma posição condicional;
- `T026A`, encerramento da gestão por organizações sociais: três concordâncias e uma discordância;
- `T034B`, reforma do Conselho de Segurança da ONU: uma concordância e uma discordância, classificada como complementar pela baixa cobertura.

`T034A` também é complementar: continuidade e fim do Conselho de Segurança estão documentados, mas só por duas candidaturas. As 25 restantes foram rejeitadas para pontuação porque não apresentam os dois polos; suas posições continuam publicadas no artefato de auditoria.

## Mudanças de classificação e formulação

O relatório `review-audit.json` registra 46 células que mudaram em relação à exportação anterior: 20 correções ou novas posições na mesma formulação e 26 registros associados às versões reformuladas de `T011` e `T034A`. Cada entrada contém tese e versão, candidatura, posição anterior, posição nova, motivo e evidências.

Exemplos:

- `T001` / Renan Santos: passou de ausência na exportação anterior para discordância, porque o plano propõe substituir o arcabouço fiscal por outro modelo;
- `T003` / Samara: passou a concordância após a leitura conjunta do título e da continuação da proposta de revogação da reforma trabalhista;
- `T005`: metas de 40, 36 ou 35 horas foram tratadas de forma uniforme em relação ao limite exato de 30 horas, preservando como mista a proposta que contém simultaneamente 36 e 30 horas;
- `T015`: propostas de idade diferente ou alcance incompatível foram classificadas pela relação com o limiar formulado, não pela afinidade temática;
- `T026A` / Edmilson Costa: concordância sustentada pela revogação expressa de todos os contratos com organizações sociais;
- `T034B`: reformar o órgão e extingui-lo formam polos comparáveis; a baixa cobertura permanece visível.

Casos auditados que não entraram no quiz também foram preservados. Por exemplo, `T025` tem uma concordância e sete propostas parciais ou condicionais, mas nenhuma discordância; `T032` tem quatro concordâncias e cinco posições condicionais, sem polo contrário inequívoco.

## Integridade e limites

A V2 contém 494 decisões sem `PENDENTE`, 267 células com citações e 400 passagens de evidência. Os quatro arquivos de revisão V2 somam 377 decisões adicionais às 117 já revisadas. O gerador verifica IDs, completude, hashes dos PDFs, contagem de páginas, vínculo da evidência e contraste de toda pergunta ativa.

O ganho de quatro perguntas reduz de 47 para 43 os pares sem nenhuma posição categórica em comum, mas a comparação continua esparsa: a média é 1,09 pergunta categórica comum por par. A V2 está tecnicamente consistente para publicação do piloto.
