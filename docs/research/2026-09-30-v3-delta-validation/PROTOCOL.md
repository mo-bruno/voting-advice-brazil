# Protocolo — quatro mudanças da bateria versão 3

Cada responsável recebe exatamente um plano e as quatro teses aprovadas em `questions.json`. A leitura integral anterior, o perfil temático, o checkpoint e o parecer da versão 2 devem ser reidratados antes da busca no PDF oficial.

Um executor pertence exclusivamente a uma candidatura nesta rodada. Ele não pode analisar, revisar nem produzir arquivos para outro plano. O validador rejeita IDs de executor repetidos entre candidaturas e confere o executor registrado em cada parecer.

## Classificação

- `CONCORDA`: o plano adota a decisão perguntada no mesmo alcance ou em alcance mais forte compatível.
- `DISCORDA`: o plano rejeita a decisão ou escolhe regra incompatível de forma clara.
- `CONDICIONAL_OU_MISTA`: a posição depende de condição capaz de mudar a resposta, combina direções opostas ou cobre somente parte essencial do alcance.
- `NAO_ENCONTRADA`: não há evidência suficiente. Silêncio nunca vira neutralidade, concordância ou discordância.

Avalie o objeto da tese, não palavras isoladas. Concessão não é toda forma de capital privado; capacidade nacional de IA não define propriedade; cotas em outro universo não respondem automaticamente a concursos federais; câmeras sem identificação facial não respondem à tese de reconhecimento facial.

## Evidência

Toda classificação diferente de `NAO_ENCONTRADA` exige citação literal, página física e interpretação. Pesquise o documento inteiro e registre `searched_page_ranges` cobrindo da página 1 até a última. Inclua contrapontos e limites capazes de impedir uma generalização.

O arquivo JSON deve seguir o mesmo formato dos pareceres em `../2026-09-29-approved-full-battery-validation/reviews/`, com quatro respostas na ordem de `questions.json`. Grave também um relatório Markdown com o mesmo nome-base. Não altere arquivos de outros planos.
