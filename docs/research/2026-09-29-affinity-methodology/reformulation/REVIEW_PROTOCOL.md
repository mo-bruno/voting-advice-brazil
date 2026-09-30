# Protocolo da revisão de reformulações

Pedido de 29/09/2026: confrontar todas as perguntas com todos os planos, principalmente as células sem posição categórica, e verificar se uma redação melhor recupera informação sem inventar posições. As 23 perguntas do núcleo não foram fechadas; o universo desta revisão são as 30 publicadas e as 13 candidaturas do snapshot preservado.

Esta é uma revisão documental assistida por agentes. Não equivale a revisão humana nem altera o produto publicado. Os PDFs são do pacote preservado de 19/09/2026; os hashes individuais devem coincidir com a edição versionada.

## Método

1. Para cada tese, ler texto, classificações, justificativas, condições e buscas anteriores das treze candidaturas.
2. Reexaminar as posições ausentes/condicionais nos textos completos extraídos dos treze PDFs, com expressões literais e equivalentes. Consultar o contexto da página relevante, não apenas a ocorrência de uma palavra. Usar `layout` e `raw` e conferir visualmente quando colunas, caixas ou tabelas afetarem o sentido.
3. Verificar também as posições categóricas: uma nova redação pode invalidá-las, e uma classificação antiga pode ter sido excessiva. Não considerar toda perda de cobertura como defeito da revisão.
4. Avaliar uma formulação uniforme, legível e relevante, com uma decisão política principal. Não escrever uma pergunta diferente por candidatura, imputar posições por ideologia, trocar silêncio por oposição ou diluir o item em um objetivo genericamente desejável.
5. Toda alternativa mantida no estudo deve ser aplicada às treze candidaturas. Registrar ganhos, perdas, polos e alteração de significado. Nova redação substantiva exige nova versão e não reaproveita respostas antigas.
6. Posições categóricas e condicionais precisam de trecho literal suficiente, página física e vínculo ao documento correto. A classificação pode usar mais de um trecho. Ausência deve explicar o que foi buscado e a diferença de escopo encontrada; busca sem resultado não prova ausência absoluta de opinião.
7. Diferenciar substituição no mesmo tema de simplificação equivalente. Uma tese mais abrangente pode perder o contraste. Apoio a uma meta menos ambiciosa não prova automaticamente rejeição a uma mais ambiciosa; checar mesmo público, instrumento, regime, tempo e condições.
8. Não escolher redações ou regras para favorecer/excluir nomes, partidos ou resultados de usuários. Não contar posições condicionais como meio ponto. Não inferir que textos longos são melhores.

## Entradas

- `data/theses/2026/theses.json`: edição existente; fonte da categoria anterior.
- `data/propostas/2026/candidates.json`: treze IDs e nomes do snapshot.
- Corpus de trabalho: `/tmp/farol-plan-review-20260929/manifest.json` e `<candidate_id>/{plan.pdf,layout-pages.json,raw-pages.json}`. Os arrays de páginas têm índice zero; as citações usam página física começando em um.
- O corpus foi extraído de `proposta_governo_2026_BR_20260919.zip`; cada PDF foi validado contra o hash da edição e a quantidade de páginas físicas.

## Saída por grupo

Cada grupo escreve um JSON separado, com `schema_version: 1`, `group` e `theses`. Cada elemento de `theses` tem:

- `id`: ID existente.
- `baseline_text`: texto exato vigente.
- `action`: `keep`, `reformulate`, `replace`, ou `remove_from_shortlist` (uma recomendação desta revisão).
- `summary`: achado principal e motivo da recomendação.
- `search_terms`: termos e equivalentes realmente usados.
- `original_review`: treze registros, um por candidatura, com `candidate_id`, `baseline_category`, `category`, `reason`, `evidence` e `inspected_pages`.
- `alternatives`: zero ou mais elementos com `label`, `text`, `recommendation` (`recommend`, `explore`, `reject`), `reason` e `positions` (treze registros com `candidate_id`, `category`, `reason`, `evidence`, `inspected_pages`). Usar no máximo duas alternativas por tese, priorizando a mais promissora.
- `limitations`: limitações específicas.
- `visual_checks`: registros de `candidate_id`, `page`, `reason`, somente para páginas de fato renderizadas e inspecionadas.

Cada evidência contém `page` e `quote`, com trecho contínuo que exista na página `layout` ou `raw` após normalização de espaços. Quando o PDF sobrepõe camadas idênticas e duplica cada linha (caso de Samara), aceita-se também remoção de linhas consecutivas exatamente idênticas na extração; o validador discrimina esse método. Não se corrigem palavras nem se combinam colunas diferentes numa citação. Não incluir número de página dentro do trecho. Evitar reticências que substituam partes do original. O manifest liga o ID ao SHA-256, arquivo e URL. `inspected_pages` registra somente páginas cujo contexto foi efetivamente inspecionado, não a quantidade total pesquisada por software.

Categorias: `CONCORDA`, `DISCORDA`, `CONDICIONAL_OU_MISTA`, `NEUTRO_EXPLICITO`, `NAO_ENCONTRADA`. Toda categoria substantiva exige evidência. Para ausência, `evidence` pode estar vazio; `reason` deve ser específico. Não usar placeholders ou células pendentes.

## Limites da conclusão

A revisão combina as decisões anteriores com novas buscas nos textos completos e leitura contextual das páginas pertinentes. Não deve ser descrita como nova leitura humana integral de todas as 836 páginas. Uma verificação automatizada de trechos prova rastreabilidade literal, não suficiência semântica; esta exige revisão contextual separada.
