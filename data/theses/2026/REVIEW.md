# Edição documental presidencial — 20/09/2026

O núcleo contém nove teses e 13 candidaturas do retrato oficial do TSE. Foram lidas integralmente as 836 páginas dos 13 planos, inclusive o novo plano de Leonardo Avalanche. A análise foi automatizada por IA; não equivale a aprovação editorial humana, certificação do TSE ou recomendação de voto.

## O que está concluído

As 117 combinações entre candidatura e tese ativa têm decisão explícita: 16 concordâncias, 21 discordâncias, quatro posições condicionais/mistas e 76 casos sem manifestação suficiente no escopo exato. Não existem células `PENDENTE` no núcleo. `NAO_ENCONTRADA` significa que a leitura integral não sustentou uma classificação — não que a candidatura discorde, seja neutra ou não possua opinião fora do plano.

Cada decisão registra motivo, termos de busca complementares, condições e diferenças de escopo. Citações estão ligadas a páginas físicas e ao SHA-256 do PDF oficial. As buscas não substituíram a leitura sequencial. Capas, páginas sem texto e trechos com falhas de extração foram inspecionados visualmente quando necessário.

## Limites de comparação

Apenas 37 das 117 células sustentam pontuação categórica. Em 47 dos 78 pares de candidaturas não há nenhuma tese com posição categórica de ambos. Por isso a interface mostra percentuais acompanhados da cobertura e candidaturas em ordem alfabética, sem líder ou vencedor. Percentuais de bases diferentes não constituem uma ordem de preferência confiável. Ausências e condicionais ficam fora do cálculo, não recebem neutralidade artificial.

As 36 teses recebidas foram preservadas em 38 registros após desdobrar dois itens. Nove integram esta edição; 29 continuam como rascunhos. A leitura completa dos documentos para estas nove perguntas não conclui a análise das demais formulações nem a versão 2 ampliada do experimento. O campo `approved` significa seleção técnica para este recorte, não chancela humana.

## Histórico e rastreabilidade

- `editorial-review-2026-09-20.json`: revisão anterior, restrita a passagens, preservada como histórico e com hashes das entradas originais.
- `full-review/group-a.json` a `group-d.json`: decisões da leitura integral, por candidatura, com páginas e hashes. Não herdam posição de candidatura substituída.
- `theses.json`: exportação consumida pela aplicação; preserva categorias, citações, condições e histórico.
- `review-audit.json`: cobertura por candidato/tese, todos os pares e mudanças.

A tese 11 está na versão 3: trabalho público remunerado para beneficiários em idade economicamente ativa. A tese 34A passa à versão 3: “O Conselho de Segurança da ONU deve continuar existindo.” A redação elimina a ambiguidade entre existência da instituição e conservação de sua composição atual. Texto, versão e hash anteriores ficam em `supersedes`; respostas antigas não são reaproveitadas para redações novas.

O construtor exige os 13 IDs ativos exatos, as nove decisões por candidatura, leitura de todas as páginas físicas e PDFs com hashes correspondentes. Falta de revisão, categoria pendente, ausência sem justificativa ou evidência de outro candidato interrompe a geração. A data de geração é separada da revisão e do retrato cadastral. Os snapshots ZIP são preservados localmente; os URLs oficiais podem mudar e não substituem a verificação de integridade.
