# Metodologia V2 — Presidência 2026

## Fonte e unidade de análise

A única fonte de posição política é o plano de governo oficial associado à candidatura no snapshot do TSE. A unidade de análise é uma combinação entre uma formulação e uma candidatura. Todas as páginas físicas do PDF são lidas; buscas por termos e equivalentes servem como conferência, não como substituto da leitura.

## Regra de classificação

| Categoria | Regra operacional |
|---|---|
| `CONCORDA` | A evidência sustenta a decisão formulada, diretamente ou por equivalência semântica demonstrável. Uma salvaguarda de implementação só altera a categoria se restringir substantivamente a decisão. |
| `DISCORDA` | A evidência rejeita a decisão ou estabelece alternativa incompatível no mesmo escopo. Silêncio ou mera falta de apoio não bastam. |
| `CONDICIONAL_OU_MISTA` | Há condição substantiva, alcance parcial ou combinação documentada de posições que impede uma classificação binária. Menção temática próxima não basta. |
| `NEUTRO_EXPLICITO` | O plano manifesta neutralidade sobre a decisão. Desconhecimento ou ausência de evidência não são neutralidade. |
| `NAO_ENCONTRADA` | A leitura integral e as buscas registradas não encontraram evidência suficiente. A razão da insuficiência é obrigatória. |
| `PENDENTE` | A coleta, leitura ou verificação ainda não terminou. Esta categoria impede a publicação da matriz. |

Condições, diferenças de escopo e ausência de informação ficam em campos separados. Posições condicionais não valem “meio ponto”. Duas ausências não constituem concordância entre candidaturas.

Metas numéricas, quantificadores universais, instrumento, público, prazo e alcance são componentes substantivos. Uma meta diferente pode concordar, discordar ou ser condicional conforme a relação lógica com a pergunta; a mesma regra é aplicada a todas as candidaturas. Afinidade temática, ideologia presumida ou palavras semelhantes não substituem a decisão documentada.

## Evidência e verificação

Toda posição substantiva exige ao menos uma passagem literal com documento, página física, URL e SHA-256. Quando o contexto atravessa páginas, todas as passagens necessárias são preservadas. Na geração da edição, cada citação precisa ser encontrada na página indicada em ao menos uma das extrações `layout` e `raw` do próprio PDF oficial; páginas cuja estrutura visual alterava a leitura também foram renderizadas durante a revisão. Uma citação inexistente, uma evidência de outra candidatura ou uma página fora do intervalo físico do PDF invalida a exportação.

## Seleção das perguntas

A seleção ocorre depois da classificação completa:

- `nucleus`: ao menos uma concordância, uma discordância e três posições categóricas;
- `complementary`: há concordância e discordância, mas somente duas posições categóricas;
- `rejected`: falta um dos polos documentais, a formulação duplica uma escolha já selecionada ou o escopo não permite uma pergunta atômica e comparável.

`nucleus` e `complementary` entram no quiz. `rejected` permanece na matriz informativa, sem pontuação. O critério não usa popularidade, partido, pesquisa eleitoral ou meta de tamanho do questionário. A expansão aplica a mesma regra a novas formulações extraídas do banco presidencial e registra também as rejeições, evitando aumentar artificialmente o questionário com inversões ou variações redundantes. As 111 formulações de origem ficam versionadas em `source-bank-v3.jsonl`; um manifesto registra o hash do arquivo e o hash textual de cada ID, e a geração recusa uma origem ausente ou alterada.

## Comparabilidade

Para cada candidatura e tese, o relatório separa categorias binárias, condicionais e ausência de manifestação. Para cada par de candidaturas, conta:

1. perguntas ativas em que ambas possuem posição categórica;
2. entre essas, perguntas em que uma concorda e a outra discorda.

O denominador é sempre explícito. A cobertura, e não apenas o percentual de afinidade, deve acompanhar qualquer resultado.
