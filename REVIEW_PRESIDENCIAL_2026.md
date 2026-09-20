# Revisão de produto e engenharia — Presidência 2026

> Relatório histórico da revisão inicial. A rodada posterior solicitada para publicação concluiu a leitura integral automatizada dos 13 planos e substitui as pendências documentais descritas abaixo: ver `data/theses/2026/REVIEW.md`. O histórico abaixo é preservado e não representa o estado final da entrega.

Revisão de 20/09/2026, realizada na worktree isolada `.worktrees/repository-study`, branch `codex/repository-study`. O checkout principal foi preservado. Não houve commit, merge ou publicação.

## Conclusão

Foram corrigidas falhas de apresentação, atualização dos dados, preservação do histórico, rastreabilidade e implantação. O fluxo técnico foi validado do navegador até um PostgreSQL local descartável, incluindo as fotos e as evidências.

Isso não torna o questionário editorialmente completo. Há apenas 36 posições categóricas nas 117 combinações entre nove teses ativas e 13 candidaturas; 77 combinações continuam pendentes, duas são condicionais e duas têm insuficiência de escopo. Em 51 dos 78 pares não existe tese com posição categórica dos dois candidatos. Recomendo manter o caráter de piloto e concluir a revisão editorial humana antes de apresentar o resultado como uma comparação ampla entre candidaturas.

## Achados corrigidos

| Prioridade | Problema observado | Correção e proteção |
|---|---|---|
| Alta | Candidatura sem evidência podia aparecer como 0% de afinidade, confundindo ausência com discordância. | Contagens de respostas comparáveis na API e na interface; sem evidência fica sem colocação e sem porcentagem. Um 0% real continua válido. |
| Alta | Atualizar os arquivos não atualizava uma eleição já carregada; candidaturas substituídas continuavam disponíveis. | Carga transacional e repetível, com atualização das posições e inativação de candidaturas ausentes, sem apagar histórico. |
| Alta | Reformular uma tese podia reutilizar respostas dadas a outra pergunta. | Identidade e versão editorial persistidas; mudança de redação exige nova versão; anterior é arquivada, mantendo suas respostas. T011 passou à versão 3. |
| Alta | Carregar 2026 antes de publicar os filtros fazia a revisão antiga listar 25 candidaturas de duas eleições. | Implantação intermediária preserva o ano publicado e assume todo o tráfego antes da carga; só depois ativa 2026. Leitura/configuração ambígua interrompe o processo. |
| Alta | Regras de exportação descartavam posições documentadas e confundiam revisão pendente com ausência documental. | Decisões explícitas com justificativas; posições recuperadas; condicionais e insuficiências preservadas; pendência identificada sem inventar análise concluída. |
| Média | Cache de uma a seis horas reexibia perguntas arquivadas, candidaturas removidas e evidências corrigidas. | Removido somente das pequenas rotas eleitorais, evitando infraestrutura adicional de invalidação distribuída. |
| Média | Menos de cinco respostas permitiam avançar até um erro; falha no envio confundia seleção com carregamento. | Mínimo explicado e aplicado na interface; respostas podem ser revisadas; falhas preservam a seleção e permitem tentar novamente. |
| Média | Mudanças durante um quiz aberto podiam produzir resultado vazio ou combinar resposta antiga com evidência nova. | Recuperação para candidaturas removidas e perguntas indisponíveis; comparação verifica identidade, texto e posição antes de apresentar a evidência. |
| Média | Empates destacavam um candidato arbitrariamente como maior afinidade. | Destaque coletivo na tela de resultados e na gaveta; nove respostas neutras foram verificadas no navegador. |
| Média | Referências incompletas dificultavam conferir a interpretação e a origem do dado. | Trechos completos necessários, páginas, links, situação cadastral e data do retrato disponíveis; hashes vinculam os PDFs e as entradas editoriais à revisão. |

A checagem de migrações também encontrou uma omissão anterior: o modelo não declarava um índice de posts já criado pela migração 0006. O metadado foi alinhado, sem alteração adicional no banco, para impedir sua remoção acidental por geração automática de migrações.

## Evidências de verificação

- Backend: **332 testes passaram**, cobertura **89,20%**; Ruff e MyPy sem erros.
- Flutter **3.41.6**, mesma versão do CI: **226 testes passaram**, análise sem erros e build web de produção concluído. A compilação emitiu aviso não bloqueante sobre fonte Cupertino; o fluxo inspecionado não apresentou ícones ausentes.
- PostgreSQL **16** local: migração até 0007, carga de 2022 seguida de 2026, repetição e duas cargas concorrentes sem duplicação. `alembic check` terminou sem divergências.
- Migrações SQLite: atualização, reversão, reaplicação e preservação de respostas em banco populado verificadas.
- Integração HTTP real: 13 candidatos, nove perguntas, rejeição de tese não publicada, cálculo e contagens, evidências e 13 JPEGs oficiais.
- Navegador: introdução → nove respostas fictícias → pesos → seleção → resultado → comparação. Fotos, cobertura, ausência de evidência e empate coletivo conferidos. Nenhum aviso ou erro no console durante a verificação final.
- Reconstrução em diretório temporário: candidatos, teses, auditoria e fotos idênticos aos publicados; apenas o horário de geração varia.
- Auditoria documental: 55 referências localizadas nas páginas físicas; duas também conferidas visualmente. Isso não equivale à validação humana da interpretação.
- Implantação: dez casos de contrato com execução do comando de nuvem simulada. **Não foi realizado teste de publicação no Cloud Run nem build nativo Android/iOS.**

## Decisões de engenharia

Mantida a arquitetura existente de FastAPI, SQLAlchemy e Flutter. Sem novas dependências de aplicação, filas, microsserviços ou serviço de cache. A migração é aditiva; o carregamento usa uma transação e um lock transacional no PostgreSQL. Em produção, iniciar uma instância não recarrega seu snapshot antigo.

A implantação usa publicação sem tráfego e transferência explícita para a revisão pronta; os comandos foram conferidos na documentação oficial de [deploy](https://docs.cloud.google.com/sdk/gcloud/reference/run/deploy) e [transferência de tráfego](https://docs.cloud.google.com/sdk/gcloud/reference/run/services/update-traffic). O procedimento e as condições de recuperação estão em `backend/README.md`. Após carregar 2026, não se deve restaurar uma imagem anterior aos filtros eleitorais.

## Pendências e localização dos dados

As 36 teses recebidas originaram 38 registros porque dois itens foram desdobrados. Nove estão selecionados tecnicamente para o quiz e 29 continuam como rascunho. `approved` não significa aprovação editorial humana. O plano de Leonardo Avalanche permanece pendente e não herdou posições de Pablo Marçal.

- `data/theses/2026/REVIEW.md`: escopo e limitações da revisão documental.
- `data/theses/2026/editorial-review-2026-09-20.json`: decisões editoriais, redações e versões.
- `data/theses/2026/review-audit.json`: cobertura, comparação dos 78 pares e alterações.
- `data/theses/2026/theses.json`: conjunto consumido pela aplicação.
- `data/propostas/2026/candidates.json` e `data/fotos/2026/BR/`: retrato cadastral e fotografias.

O experimento original foi preservado. Esta revisão do serviço não conclui a V2 integral do experimento, o banco ampliado de formulações ou uma nova leitura integral dos planos. Esses itens não foram apresentados como concluídos.
