# Resultado da validação integral dos planos

**A auditoria foi concluída: 13 agentes exclusivos, configurados com Astra (`gpt-6-astra`) e esforço `ultra`, leram as 836 páginas dos 13 PDFs oficiais e verificaram as mesmas 16 perguntas.** Foram conferidos 208 cruzamentos, incluindo todas as ausências. Pablo Marçal foi retirado do escopo por instrução do usuário antes de qualquer agente ou leitura do seu plano.

**A conclusão editorial é manter as correções abaixo, mas ainda não considerar essas 16 perguntas uma bateria final suficientemente representativa para comparar todas as candidaturas.** A leitura completa recuperou uma posição categórica e corrigiu classificações indevidas; não eliminou as grandes diferenças de cobertura. Reduzir o número de perguntas, sozinho, não resolve o problema do ranking.

As fontes foram baixadas novamente do [recurso oficial do TSE](https://dadosabertos.tse.jus.br/dataset/candidatos-2026/resource/433ac1f4-07dc-44a2-bcbe-c87a2073721a) em 29/09/2026. Os PDFs das 13 candidaturas têm os mesmos hashes dos documentos anteriormente preservados. O [manifesto](source-manifest.json) registra a consulta, os bytes e os metadados; a atualidade se refere a esse snapshot.

Leituras de entrada: [16 perguntas com as categorias consolidadas](QUESTIONS_AUDITED.md), [documento central](ORCHESTRATION.md), [matriz e evidências](CONSOLIDATION.json), [decisões do orquestrador](ADJUDICATIONS.json).

## Correções adotadas

Os revisores confirmaram **202 classificações** e propuseram **6 divergências**. A consolidação adotou cinco mudanças e recusou uma inferência. Cada parecer independente foi preservado, inclusive quando a conclusão consolidada é diferente.

| Plano | Pergunta | Categoria anterior → adotada | Fundamento |
|---|---|---|---|
| [Cury](reviews/280002551547.md) | T011 — substituir Bolsa Família por trabalho público | Condicional/mista → Não encontrada | Manter temporariamente o benefício ao obter emprego ou abrir microempresa não decide a substituição perguntada — pp.98–99. |
| [Hertz](reviews/280002541457.md) | T038 — integrar produção e refino na Petrobras | Condicional/mista → Não encontrada | Propriedade estatal e investimento em refino não definem integração das atividades na empresa — p.26. |
| [Hertz](reviews/280002541457.md) | T043 — financiar vagas em creches privadas | Condicional/mista → Discorda | A leitura integral acrescenta a defesa de educação totalmente pública — p.30 — às creches públicas universais, p.23. A inferência universal está explicitada. |
| [Rui](reviews/280002552487.md) | T011 — substituir Bolsa Família por trabalho público | Condicional/mista → Não encontrada | A condição temporal qualifica a proposta de benefício/piso, sem decidir o mecanismo para beneficiários economicamente ativos — p.2. |
| [Rui](reviews/280002552487.md) | T038 — integrar produção e refino na Petrobras | Condicional/mista → Não encontrada | Estatizar Petrobras e refinarias não define se ficarão integradas ou em empresas estatais distintas — p.3. |

**Divergência não adotada: Lula / T002.** O revisor propôs discordância da privatização de todas as estatais a partir das funções futuras de empresas e bancos públicos (pp.43, 54 e 58). A consolidação manteve **Não encontrada**. O próprio corpus fornece um contraexemplo: Zema propõe privatizar todas as estatais na p.15 e ampliar instrumentos dos bancos públicos na p.27. Funções futuras, isoladamente, não fixam preservação do controle acionário; podem coexistir com transição ou cronograma indefinido. Esse critério foi aplicado igualmente a Lula, Caiado e Cury. Caiado retornou ao mesmo revisor e manteve a ausência. Isso não atribui a esses planos apoio à privatização.

Também foram corrigidas justificativas sem alterar categorias. Em Grassi, contratualização de mutirões por resultado não identifica prestador privado nem contrato de gestão; foram corrigidas referências a páginas de pesquisa/habitação anteriormente descritas como direitos da pessoa idosa. Em Clariana, a menção anterior a ensino integral foi retirada porque não aparece no PDF. As hipóteses anteriores permanecem em `inputs/` para comparação.

## O que a matriz permite comparar

| Categoria consolidada | Cruzamentos |
|---|---:|
| Concorda | 36 |
| Discorda | 45 |
| Condicional/mista | 1 |
| Posição não encontrada | 126 |
| **Total** | **208** |

São **81 posições categóricas**, contra 80 no rascunho anterior. A única posição condicional remanescente é Flavio / T002, sobre desestatização caso a caso. Ausência e condição não foram convertidas em neutralidade ou concordância. Essas contagens medem documentação, não afinidade com uma pessoa.

A tabela abaixo está em ordem alfabética e **não é ranking de afinidade**. “Temas” usa a taxonomia herdada da edição anterior, preservada em [question-themes.json](question-themes.json).

| Plano | Páginas lidas | Perguntas com concordância/discordância, de 16 | Temas comparáveis |
|---|---:|---:|---:|
| Clariana Barao | 15 | 0 | 0 |
| Edmilson Costa | 16 | 12 | 7 |
| Escritor Augusto Cury | 200 | 1 | 1 |
| Flavio Bolsonaro | 76 | 9 | 7 |
| Hertz Dias | 33 | 9 | 7 |
| Leonardo Avalanche | 48 | 3 | 3 |
| Lula | 84 | 6 | 4 |
| Renan Santos | 51 | 6 | 5 |
| Ronaldo Caiado | 100 | 7 | 5 |
| Rui Costa Pimenta | 7 | 4 | 3 |
| Samara | 67 | 13 | 7 |
| Veterinário Wilson Grassi | 58 | 1 | 1 |
| Zema | 81 | 10 | 6 |

Um plano de 200 páginas pode ter apenas uma posição neste recorte. Portanto, a explicação ao usuário deve ser “base comparável insuficiente nas perguntas desta versão”, sem concluir que o plano é curto, pobre em propostas ou que a candidatura não tenha opinião sobre o tema.

As 16 perguntas têm pelo menos um plano em cada polo, mas cada item cobre apenas **3 a 8 das 13 candidaturas**. Entre os **78 pares** de candidaturas, **23 não têm nenhuma pergunta categórica em comum**. O ganho de leitura integral não tornou comparável todo o conjunto.

A simulação da regra beta anteriormente proposta — pelo menos oito posições, metade da edição e três temas — continua admitindo somente **Edmilson, Flavio, Hertz, Samara e Zema**. Trata-se de regra editorial para estudo, não de limiar estatístico validado nem de exclusão já aplicada ao produto. Não se deve mover o limiar para incluir um nome específico.

Mesmo nesses cinco planos, os dez pares têm de cinco a onze perguntas em comum, e quatro pares não apresentam oposição nos itens compartilhados: Hertz–Edmilson, Hertz–Samara, Edmilson–Samara e Flavio–Zema. Isso não demonstra equivalência dos programas completos. Mostra que este recorte oferece pouca distinção entre esses pares; uma ordenação pode depender das perguntas diferentes disponíveis para cada plano.

## Reformulações sugeridas e decisão editorial

As quatro sugestões individuais correspondem a três ideias. Elas **mudam o objeto da pergunta** e ainda não foram validadas contra todos os planos. Não alteram a matriz concluída, não herdam categorias anteriores e não são apresentadas como ganho de cobertura comprovado.

| Nova pergunta sugerida | Origem documental | Avaliação do orquestrador |
|---|---|---|
| Beneficiários do Bolsa Família devem poder manter temporariamente o benefício ao ingressarem no emprego formal ou abrirem uma microempresa. | Cury, pp.98–99 | Candidata a uma nova rodada sobre transição de renda. É outra decisão em relação a trabalho público substitutivo. Antes de adotar, testar os dois casos de ingresso e procurar contraste documentado entre planos. |
| A Petrobras deve ser uma empresa de capital 100% estatal. | Hertz, pp.26/29; Rui, p.3, com redação equivalente | Pergunta mais direta sobre composição do capital. Não equivale a integração produtiva nem apenas a controle estatal majoritário. Testar todos os planos e a redundância com T002; não adicionar ambas só para contar mais respostas sobre a mesma dimensão. |
| O Bolsa Família deve pagar pelo menos um salário mínimo. | Rui, p.2 | Troca mecanismo por valor. Antes de selecionar, esclarecer unidade do benefício e condição temporal, além de verificar comparabilidade e contrapontos nos demais documentos. Não adotar apenas para recuperar uma candidatura. |

As redações originais de cada sugestão e seus limites estão na [consolidação](CONSOLIDATION.json), em `reformulation_suggestions`. Uma rodada futura com texto novo deve voltar aos mesmos responsáveis exclusivos, usando seus diários; não precisa repetir a leitura inteira dos PDFs inalterados.

**Recomendação para fechar a edição:** preservar a matriz auditada como referência e usar as alternativas acima como hipóteses. Ainda falta equilíbrio temático: o recorte tem cinco itens de economia e três de política externa, mas nenhum classificado nos temas de meio ambiente, agro, infraestrutura ou governança. Selecionar novas decisões documentáveis nesses temas e avaliar itens comuns entre candidatos é mais útil do que impor um número predeterminado de perguntas ou reformular tudo para produzir respostas.

## Consequências para o resultado compartilhável

Manter ranking e compartilhamento continua compatível com o objetivo do produto, desde que a apresentação mostre a base real da comparação. A leitura integral reforça a necessidade de:

1. Destacar concordâncias, divergências e quantidade de respostas comparáveis, sem transformar uma única resposta em promessa de afinidade geral.
2. Exigir base mínima tanto na edição quanto nas respostas efetivamente dadas; os saltos do usuário não podem criar elegibilidade documental.
3. Manter perfis com base insuficiente acessíveis em seção própria, com justificativa ligada ao recorte do beta.
4. Admitir empates e não tratar pequenas diferenças entre conjuntos de perguntas distintos como uma separação robusta.
5. Preservar condições e evidências no detalhe; nunca usar ausência como oposição, neutralidade ou concordância.

Texto possível para o produto: “Este teste compara suas respostas com propostas documentadas nos planos oficiais. O ranking mostra afinidade nas questões comparáveis desta versão. Alguns planos ainda não têm base suficiente para entrar no ranking. O Farol Político está em beta e continua em desenvolvimento.”

## Integridade e limites da conclusão

A validação final reextraiu os **13 PDFs diretamente do ZIP oficial** e conferiu hashes, todas as entradas dos diários, os 16 textos congelados e **292 ocorrências de citações literais**. Há **150 registros de inspeção visual** e nenhuma página reportada como ilegível. São citações usadas em posições e contextos, com possíveis repetições; o número não mede força da evidência. Resultado: [validation.json](validation.json), sem pendências ou erros. A [consolidação](CONSOLIDATION.json) está completa, com todas as divergências resolvidas e 13 responsáveis distintos.

Leitura integral significa todas as páginas dos PDFs oficiais fornecidos. Renan apresenta seu arquivo de 51 páginas como resumo de uma obra maior; essa obra externa não foi incorporada. A última página do arquivo de Cury anuncia materiais que não constam nas 200 páginas entregues. Clariana identifica seu documento como uma versão para desenvolvimento programático e definição posterior de metas. Essas limitações não foram preenchidas com ideologia, entrevistas ou material externo.

As verificações automáticas confirmam integridade, cobertura declarada e literalidade; a correção semântica resulta da revisão assistida e das decisões editoriais documentadas. Isso não equivale a revisão humana nem a validação científica do instrumento. A auditoria documental está concluída; não houve alteração no cálculo, aplicativo, dados publicados, respostas históricas, candidaturas ou implantação.

Trabalho isolado na branch `codex/affinity-methodology`, com a main remota `d31078e` integrada antes desta rodada. Instruções de reprodução: [README](README.md).
