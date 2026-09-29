# Perfis programáticos em dez categorias

Etapa solicitada pelo usuário depois da [auditoria integral das 16 perguntas](../2026-09-29-full-plan-validation/FINAL_REPORT.md). Os **mesmos 13 agentes Astra Ultra**, cada um responsável pelo mesmo plano, retomam seu contexto e seus diários. Não há agente para Pablo Marçal.

**Etapa concluída:** 13 perfis conferidos, 130 seções temáticas, 636 posições selecionadas e 104 sementes de teses. Consulte o [relatório final](FINAL_REPORT.md) e a [agenda inicial de 18 hipóteses](AGENDA_TESES.md). As hipóteses ainda exigem uma nova matriz de validação entre os planos.

O objetivo é ampliar o mapa de decisões antes de escolher perguntas: identificar o que cada plano efetivamente propõe em **Economia e Desenvolvimento; Estado e Gestão Pública; Infraestrutura e Território; Meio Ambiente e Clima; Ciência, Tecnologia e Inovação; Bem-Estar Social; Educação, Cultura e Sociedade; Cidadania e Direitos; Segurança Pública; Soberania e Relações Internacionais**. Os limites operacionais estão em [taxonomy.json](taxonomy.json).

## Como usar os documentos

1. Consultar o [documento central](ORCHESTRATION.md) para saber quais perfis foram entregues e conferidos.
2. Ler a síntese e as dez seções do perfil da candidatura, com escolhas, instrumentos, condições e lacunas.
3. Usar os IDs de posições e suas citações para comparar **a mesma decisão**, não apenas temas com nomes parecidos.
4. Tratar as sementes de novas teses como hipóteses editoriais. Uma síntese pode omitir propostas; ausência no perfil não prova ausência no plano. A validação de cada redação nova deve voltar à evidência original e, quando necessário, ao mesmo responsável pelo PDF.

O [mapa por categoria](CATEGORY_MAP.md) permite navegar pelos perfis, e o [guia de construção das teses](THESIS_DESIGN.md) registra os critérios para a próxima matriz. O [índice estruturado](DOCUMENT_INDEX.json) mantém IDs, páginas, condições e rastreabilidade. A [conferência editorial](EDITORIAL_REVIEW.json) identifica a versão de cada perfil aceita pelo orquestrador.

Os perfis são índices de evidências e sínteses do programa. Não medem afinidade pessoal, não classificam a ideologia por suposição e não substituem os PDFs. “Mais abrangente” deve significar diversidade temática e cobertura comparável; cada pergunta continua precisando isolar uma decisão política concreta.

## Fonte e método

Fonte exclusiva: os mesmos PDFs do [recurso oficial do TSE](https://dadosabertos.tse.jus.br/dataset/candidatos-2026/resource/433ac1f4-07dc-44a2-bcbe-c87a2073721a), snapshot verificado em 29/09/2026, identificado no [manifesto anterior](../2026-09-29-full-plan-validation/source-manifest.json). A leitura integral das 836 páginas já foi concluída na etapa anterior. Nesta rodada, os responsáveis reaproveitam o contexto e fazem novas conferências das páginas citadas; não se conta uma segunda leitura integral.

O [protocolo](PROTOCOL.md) distingue proposta concreta, rejeição expressa, objetivo genérico e inferência clara. Cada posição tem uma categoria principal, para evitar contagem duplicada, e pode referenciar categorias secundárias. Condições, tensões e lacunas não são apagadas para aumentar cobertura.

## Verificação e estado

```bash
python docs/research/2026-09-29-thematic-profiles/validate.py \
  --archive /caminho/proposta_governo_2026_BR.zip
python docs/research/2026-09-29-thematic-profiles/orchestrate.py
python docs/research/2026-09-29-thematic-profiles/consolidate.py
```

Requer Python padrão e `pdftotext` (Poppler). O arquivo preservado de 19/09 também serve: seus PDFs são byte a byte equivalentes, conforme o manifesto anterior. Um download futuro com PDFs diferentes é recusado; os hashes dos documentos são decisivos. O modo `--archive` extrai os treze PDFs autorizados para um diretório temporário, confere contagem de páginas e testa as citações nessa extração nova, sem depender do cache local. Sem essa opção, usa o corpus indicado em STATE.json.

Para verificar uma entrega, usar `--candidate ID`. `--allow-pending` serve apenas ao acompanhamento parcial. O validador confere agente original, hashes, dez categorias, referências internas, páginas e literalidade. A conferência semântica permanece responsabilidade editorial do orquestrador; a consolidação exige registro editorial com o hash atual de cada perfil.

A organização dos perfis não altera dados publicados, perguntas, respostas históricas, algoritmo ou implantação do aplicativo.
