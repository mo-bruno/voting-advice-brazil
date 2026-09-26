# Edição documental presidencial — 26/09/2026

A edição compara 70 formulações com as 13 candidaturas do retrato oficial do TSE: 38 formulações derivadas das 36 teses recebidas e 32 escolhas adicionais extraídas do banco presidencial. As 910 células foram classificadas a partir das 836 páginas dos planos oficiais. O resultado não constitui certificação do TSE nem recomendação de voto.

## O que foi concluído

Não há células `PENDENTE`. Na matriz completa existem 137 concordâncias, 84 discordâncias, 74 posições condicionais ou mistas e 615 casos sem manifestação suficiente. Há 410 células com citações e, ao todo, 595 trechos ligados à página física e ao SHA-256 do PDF analisado.

`NAO_ENCONTRADA` significa que a leitura integral e as buscas complementares não sustentaram uma posição no escopo exato da tese. Não significa discordância, neutralidade ou ausência de opinião fora do plano. `CONDICIONAL_OU_MISTA` também não recebe pontuação binária.

Cada decisão registra motivo, termos de busca, condições e diferenças de escopo. Capas, diagramas, caixas e páginas com falha de extração foram inspecionados visualmente quando necessários. A análise ficou restrita aos planos oficiais; notícias, entrevistas, histórico político e ideologia partidária não foram usados.

## Seleção do questionário

Trinta perguntas têm contraste documental, passaram pela revisão de redundância e entram no quiz:

- núcleo, com os dois polos e ao menos três posições categóricas: `T001`, `T002`, `T003`, `T005`, `T011`, `T015`, `T017`, `T018`, `T026A`, `T026B`, `T036`, `T038`, `T041`, `T042`, `T043`, `T044`, `T056`, `T058`, `T063`, `T064`, `T065`, `T066` e `T067`;
- complementares, com os dois polos mas apenas duas posições categóricas: `T034A`, `T034B`, `T054`, `T057`, `T061`, `T062` e `T068`.

As outras 40 formulações permanecem acessíveis na matriz, com decisões e evidências, mas ficam como `draft`: faltou um dos polos documentais ou a formulação era redundante, composta ou inadequada ao quiz. O número de perguntas não foi definido previamente; é consequência do critério registrado em `question-selection-v2.json` e nos três arquivos de `expansion-review-v3`.

Nas 30 perguntas ativas existem 46 concordâncias, 70 discordâncias, 20 posições condicionais ou mistas e 254 ausências de manifestação suficiente. Portanto, 116 das 390 células ativas sustentam pontuação categórica.

## Limites de comparação

Entre os 78 pares possíveis de candidaturas, 20 não possuem pergunta ativa com posição categórica de ambos. A quantidade comparável varia de zero a 13 perguntas, com média de 2,53; 34 pares apresentam ao menos uma oposição categórica. Os percentuais de afinidade podem usar bases documentais diferentes e devem ser interpretados com essa limitação.

A tela principal exibe foto, nome, partido e percentual de cada candidatura, do maior percentual para o menor, sem recomendar voto ou anunciar vencedor. Os cartões não incluem contagens de respostas comparáveis nem explicações extensas. A cobertura e as posições ausentes continuam disponíveis na comparação de respostas, junto às fontes e aos trechos dos planos.

O cálculo ponderado considera somente perguntas respondidas pelo usuário em que a candidatura possui posição categórica documentada. Nove concordâncias em nove respostas comparáveis resultam em 100%, mesmo havendo 30 respostas totais. Candidaturas sem respostas comparáveis exibem `—` e ficam no final da lista. Ausência documental não é convertida em concordância, discordância ou neutralidade artificial.

## Histórico e rastreabilidade

- `editorial-review-2026-09-20.json`: revisão anterior de passagens e hashes das entradas preservadas;
- `full-review/group-a.json` a `group-d.json`: revisão integral das nove formulações inicialmente publicadas;
- `full-review-v2/group-a.json` a `group-d.json`: decisões das outras 29 formulações originais;
- `question-selection-v2.json`: regra e motivo da seleção das 38 formulações originais;
- `source-bank-v3.jsonl` e `source-bank-manifest-v3.json`: conteúdo versionado das 111 teses do banco presidencial, com SHA-256 do arquivo e de cada formulação;
- `expansion-review-v3/group-a.json` a `group-c.json`: 32 formulações adicionais e 416 decisões;
- `theses.json`: exportação consumida pela aplicação, com as 910 células;
- `review-audit.json`: cobertura por candidatura e tese, comparabilidade dos 78 pares, 110 mudanças publicadas e 40 exclusões justificadas;
- `METODOLOGIA_V2.md`, `COMPARACAO_V1_V2.md` e `COMPARACAO_V2_V3.md`: regra operacional e evolução entre edições.

A tese 11 permanece na versão 3, delimitada aos beneficiários em idade economicamente ativa. A tese 34A também está na versão 3: “O Conselho de Segurança da ONU deve continuar existindo.” Texto, versão e hash anteriores ficam em `supersedes`; respostas antigas não são reaproveitadas quando a formulação muda de significado.

O construtor exige exatamente os 13 IDs ativos, 70 decisões por candidatura, páginas físicas contíguas, PDFs com hashes correspondentes, justificativa de ausência, evidência vinculada ao documento correto e IDs estáveis para cada nova formulação. Ele também confere o conteúdo do banco contra seu manifesto e procura cada um dos 595 trechos literalmente na página física indicada do PDF oficial, usando extrações `layout` e `raw`. Qualquer lacuna ou divergência interrompe a geração.
