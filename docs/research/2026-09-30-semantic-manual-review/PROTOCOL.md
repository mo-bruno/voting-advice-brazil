# Protocolo da revisão semântica manual

## Objetivo

Produzir um caderno de revisão humana das 20 teses publicadas contra os 13 planos oficiais. A classificação atual é provisória para esta auditoria. Nenhuma posição do aplicativo será alterada automaticamente.

Cada responsável trabalha com uma única candidatura e usa três camadas documentais:

1. a posição atual em `FINAL_MATRIX.json`;
2. o perfil temático integral da candidatura, incluindo posições, lacunas e tensões;
3. o relatório anterior de leitura integral e, quando necessário, seus trechos adicionais.

## Regra central

A análise deve ser semântica. Ausência de uma palavra ou expressão exata não prova ausência de posição. O responsável deve procurar decisões equivalentes, princípios operacionais, instrumentos próximos, públicos afetados, condições e propostas incompatíveis.

Por exemplo, a tese sobre imposto sobre grandes fortunas exige considerar tributação patrimonial, progressividade, heranças, dividendos, renda do topo, concentração de riqueza e propostas gerais de redução ou reorganização de impostos. Esses elementos podem oferecer contexto, mas não devem ser convertidos automaticamente no instrumento exato perguntado.

## Ficha obrigatória por tese

Para cada uma das 20 teses, registrar:

- classificação e justificativa atuais;
- evidência direta já usada;
- síntese do contexto semântico do plano;
- trechos semanticamente relacionados, com página e vínculo a uma posição do perfil ou à revisão integral;
- relação de cada trecho com a tese: `APOIA`, `CONTRADIZ`, `QUALIFICA` ou `CONTEXTO`;
- argumentos para manter a classificação;
- argumentos para reconsiderá-la;
- questão concreta que o revisor humano precisa decidir;
- recomendação preliminar: `MANTER`, `RECLASSIFICAR_CONCORDA`, `RECLASSIFICAR_DISCORDA` ou `RECLASSIFICAR_CONDICIONAL`;
- confiança `alta`, `media` ou `baixa`.

## Critérios

- Uma orientação geral não equivale automaticamente ao mecanismo específico da tese.
- Instrumentos funcionalmente equivalentes podem sustentar uma posição mesmo com vocabulário diferente, desde que a equivalência seja explicada.
- Escopo, público, prazo, exceções e conjunções devem ser preservados.
- Trecho próximo deve aparecer mesmo quando for insuficiente para classificar.
- `NAO_ENCONTRADA` significa que nenhuma decisão suficientemente determinada foi estabelecida; não significa que o tema esteja ausente do plano.
- Toda citação deve ser literal, contínua e acompanhada da página física.
- Não usar entrevistas, redes sociais, histórico partidário ou conhecimento externo.
- Não alterar a matriz final, o produto ou os arquivos de outra candidatura.

## Entrega

Cada responsável escreve somente `candidates/<candidate_id>.json` e `candidates/<candidate_id>.md`. O orquestrador valida as 20 fichas, confere a separação entre candidaturas e gera o caderno consolidado editável.
