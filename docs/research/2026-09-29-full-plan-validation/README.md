# Validação integral das 16 perguntas contra os planos oficiais

**Concluída:** 13 pareceres, 836 páginas, 208 classificações, cinco correções adotadas. Leia o [relatório final](FINAL_REPORT.md) e as [16 perguntas com categorias atualizadas](QUESTIONS_AUDITED.md). A matriz tem 81 posições categóricas, uma condicional e 126 ausências; a auditoria completa não torna a bateria cientificamente validada ou pronta para comparar todas as candidaturas.

Esta rodada aprofunda a [revisão anterior](../2026-09-29-affinity-methodology/reformulation/README.md): um agente independente e exclusivo por PDF, configurado com `gpt-6-astra` e esforço `ultra`, lê todas as páginas e verifica as 16 redações congeladas. O [documento central](ORCHESTRATION.md) informa o estado real de cada entrega; lançamento de agente ou checkpoint não conta como conclusão.

## Fontes e escopo

O pacote foi baixado novamente do [recurso oficial de propostas do TSE](https://dadosabertos.tse.jus.br/dataset/candidatos-2026/resource/433ac1f4-07dc-44a2-bcbe-c87a2073721a) em 29/09/2026. A atualização HTTP do pacote é de 29/09/2026, 06:48:45 UTC. Os 14 PDFs têm os mesmos bytes dos documentos correspondentes no arquivo preservado de 19/09; isso não significa que os dois ZIPs tenham o mesmo hash. URLs, hashes, identificação dos membros e metadados estão no [manifesto de fontes](source-manifest.json).

São **13 documentos, 836 páginas físicas e 208 cruzamentos**, correspondentes aos planos da base anterior do produto. O usuário excluiu expressamente Pablo Marçal do escopo antes de qualquer agente ou leitura do seu documento. O manifesto preserva o inventário completo do ZIP, mas esse membro não recebe parecer nem entra nas verificações ou contagens da auditoria.

“Atualizado” refere-se ao snapshot verificado nesta data, não a uma garantia permanente sobre o conteúdo do endereço remoto.

## Como a revisão é registrada

- [Perguntas congeladas](questions.json): texto exato e hash de cada redação do rascunho anterior. Os 16 itens não foram escolhidos novamente durante esta rodada.
- [Protocolo](PROTOCOL.md): leitura sequencial, notas por página, inspeção visual quando necessária e critérios de interpretação.
- `inputs/`: categorias anteriores, consultadas por cada revisor somente depois da leitura integral.
- `reviews/`: checkpoint, parecer estruturado e resumo de cada responsável exclusivo. Cada ausência também recebe uma justificativa documental.
- [Adjudicações](ADJUDICATIONS.json): decisões do orquestrador e conferências de consistência. Os pareceres individuais são preservados quando a consolidação adota outra conclusão.
- [Matriz consolidada](CONSOLIDATION.json): categoria anterior, categoria do revisor, categoria adotada, fonte, cobertura e questões comuns entre cada par de candidaturas. Verifique `complete` antes de tratar o conjunto como encerrado.

Uma sugestão de nova redação não modifica a pergunta congelada nem herda sua classificação. Se mudar o objeto, precisará voltar aos mesmos responsáveis pelos planos para outra validação.

## Reprodução das verificações

Requer Python padrão e `pdftotext` do Poppler. Forneça o ZIP oficial preservado; o comando confere os hashes de cada PDF antes de extrair os textos em diretório temporário:

```bash
python docs/research/2026-09-29-full-plan-validation/validate.py \
  --archive /caminho/proposta_governo_2026_BR.zip
python docs/research/2026-09-29-full-plan-validation/consolidate.py
```

O arquivo de 19/09 também pode ser usado: o manifesto registra a equivalência dos 14 membros PDF. Um download futuro com conteúdo diferente será recusado, mesmo se vier do mesmo endereço. `--candidate ID` verifica uma entrega isolada; `--allow-pending` permite acompanhamento parcial sem declarar conclusão. Sem `--archive`, usa-se o corpus local indicado no manifesto.

As verificações automáticas conferem integridade, diário declarado, cobertura dos 16 itens e literalidade das citações. Não provam a correção de uma inferência política, não são revisão humana e não validam cientificamente o questionário. A leitura integral é a leitura executada pelos agentes sobre as páginas fornecidas, apoiada pelas inspeções visuais registradas.

Nenhuma alteração de cálculo, interface, perguntas publicadas, respostas históricas, candidaturas ou implantação integra esta rodada documental. A seleção e o ranking do beta continuam sujeitos aos limites de cobertura e de equilíbrio temático identificados na pesquisa.
