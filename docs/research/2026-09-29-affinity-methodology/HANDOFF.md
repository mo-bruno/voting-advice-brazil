# Continuação do estudo de afinidade — handoff

## Estado entregue

A branch `codex/affinity-methodology` contém o estudo, a matriz final e a implementação do beta no worktree isolado `.worktrees/affinity-methodology`. A branch deve permanecer separada para a continuação por outro desenvolvedor.

A bateria editorial canônica é a **versão 3**, com 20 teses aprovadas e os botões **Concordo, Discordo, Neutro e Pular**:

- leitura humana: `../2026-09-29-full-thesis-battery/BATTERY.md`;
- estrutura e hashes: `../2026-09-29-full-thesis-battery/BATTERY.json`;
- aprovação: `../2026-09-29-full-thesis-battery/APPROVAL.json`;
- versão anterior preservada: `BATTERY_V2.*` e `APPROVAL_V2.json` no mesmo diretório.

Pablo Marçal foi excluído do corpus por decisão do usuário. Nenhuma tese da edição anteriormente publicada foi usada para gerar esta bateria. Em 30/09/2026, o ZIP oficial do TSE foi baixado novamente; o pacote tem SHA-256 `2c4073d55a4c6606d42137ce3e30bf1dd3f87557d14b5feaad4058a152f1e970` e os hashes dos 13 planos incluídos permaneceram iguais.

## O que foi feito

1. Treze agentes especialistas leram integralmente, cada um, um plano oficial do TSE. Os perfis temáticos preservam posições, citações, páginas, condições e lacunas nas dez categorias definidas pelo usuário.
2. O orquestrador consolidou 636 registros em 118 famílias de decisão e formulou uma bateria nova, independente da edição publicada.
3. A bateria passou por revisão semântica, cobertura, crítica adversarial e duas decisões humanas.
4. Os treze planos foram confrontados com a versão 2: 13 pareceres válidos, 260 respostas e 273 ocorrências de citações verificadas contra o corpus local.
5. A validação revelou quatro redações com interseção artificialmente baixa. O usuário aprovou as quatro mudanças, agora incorporadas na versão 3.
6. Treze executores exclusivos, um por candidatura, reclassificaram as quatro teses alteradas a partir do contexto do respectivo plano. Rui Costa Pimenta e Leonardo Avalanche foram processados por executores novos e dedicados; qualquer resultado parcial de agentes reaproveitados foi descartado. O validador rejeita executor repetido entre candidaturas. A rodada final tem 13 pareceres válidos, 52 respostas e 107 ocorrências de citações verificadas.
7. A matriz final combina 208 respostas reutilizadas e 52 novas, totalizando 260 classificações. Posições condicionais ou mistas permanecem documentadas, mas não entram no score nem são tratadas como resposta neutra.
8. O beta adota o piso de cinco posições comparáveis em pelo menos quatro categorias para a edição e para as respostas efetivas de cada pessoa. Nove candidaturas entram no ranking; Leonardo Avalanche, Rui Costa Pimenta, Clariana Barao e Veterinário Wilson Grassi aparecem fora dele com a base explicada.
9. Backend, seed, aplicativo e compartilhamento foram atualizados. O ranking é calculado somente entre as candidaturas selecionadas pela pessoa. A interface mostra colocação e base comparável, preserva `Concordo`, `Discordo`, `Neutro` e `Pular`, não mostra percentual e mantém candidaturas inelegíveis disponíveis para consulta.
10. As oito posições condicionais ou mistas atravessam snapshot, banco, API e comparação com rótulo próprio, mas continuam fora do score. O aplicativo falha fechado se receber um contrato antigo sem a elegibilidade explícita da metodologia beta.

## Bateria final aprovada

| Nº | ID | Tese |
|---:|---|---|
| 1 | B01-Q01 v1 | O Brasil deve cobrar um imposto específico sobre grandes fortunas. |
| 2 | B01-Q02 v1 | O governo deve oferecer linhas de crédito específicas para setores industriais considerados prioritários. |
| 3 | B01-Q03 v1 | Empresas estrangeiras devem poder participar da exploração de minerais estratégicos no Brasil. |
| 4 | B01-Q04 v1 | Durante uma auditoria da dívida pública, o governo deve suspender os pagamentos dessa dívida. |
| 5 | FB-Q05 v1 | O governo federal deve ter uma regra que limite o crescimento das despesas públicas. |
| 6 | FB-Q06 v1 | A Petrobras deve permanecer sob controle do governo federal. |
| 7 | FB-Q07 v2 | A lei deve permitir a demissão de um servidor público estável por baixo desempenho comprovado em avaliações periódicas, com direito de defesa. |
| 8 | FB-Q23 v1 | O governo federal deve usar concessões e parcerias público-privadas para ampliar a infraestrutura de transportes. |
| 9 | FB-Q10 v1 | O Brasil deve adotar um mercado regulado de carbono. |
| 10 | FB-Q24 v1 | O governo federal deve investir no desenvolvimento de capacidade nacional de inteligência artificial. |
| 11 | FB-Q12 v1 | O SUS deve contratar atendimento de clínicas e hospitais privados quando a rede pública não tiver capacidade suficiente para atender a demanda. |
| 12 | FB-Q25 v1 | Concursos públicos federais devem reservar vagas com base em critérios raciais. |
| 13 | FB-Q14 v1 | O poder público deve oferecer cuidado domiciliar a idosos e pessoas com deficiência com alto grau de dependência. |
| 14 | FB-Q15 v1 | Parte dos recursos federais para redes de ensino deve depender do cumprimento de metas de aprendizagem. |
| 15 | FB-Q16 v1 | A jornada semanal de trabalho deve ser reduzida sem redução salarial. |
| 16 | FB-Q17 v2 | O aborto voluntário deve deixar de ser crime até determinado período da gestação. |
| 17 | FB-Q18 v1 | A partir dos 16 anos, adolescentes devem responder pelo regime penal adulto por qualquer crime. |
| 18 | FB-Q19 v2 | O poder público deve usar reconhecimento facial em espaços públicos para fins de segurança. |
| 19 | FB-Q21 v1 | O Brasil deve permanecer nos BRICS. |
| 20 | FB-Q22 v1 | O Brasil deve ratificar o texto final do acordo comercial entre Mercosul e União Europeia. |

## Validação final

O diretório `../2026-09-30-v3-delta-validation/` contém os 13 pareceres das quatro teses alteradas, a matriz de 260 células e o relatório de cobertura. `FINAL_MATRIX.json` é a entrada documental canônica para o snapshot publicado. `scripts/build_affinity_beta_2026_data.py` gera de forma reproduzível `data/theses/2026/theses.json` e `explanations.json`.

O percentual técnico permanece apenas como valor interno para ordenar o ranking. A API marca a elegibilidade e a colocação; aplicativo, sessão e imagem compartilhada usam esses campos, preservam empates e não reordenam por percentual.

Na verificação final de 30/09/2026, passaram 612 testes do backend com 94,05% de cobertura, 310 testes do aplicativo, `flutter analyze`, Ruff, mypy, os três validadores documentais e a conferência reprodutível dos snapshots.

## Continuação recomendada

- Fazer uma revisão editorial humana das 260 classificações antes de retirar o selo beta. A aprovação humana registrada cobre a redação das 20 teses; as posições dos planos continuam identificadas como revisão por agentes.
- Fazer QA visual em dispositivo com resultados que tenham nove elegíveis, empates e nenhuma candidatura elegível.
- Se o piso 5/4 mudar em outra edição, versionar a metodologia e atualizar em conjunto backend, metadados do snapshot e textos do aplicativo.
- Manter o histórico da versão 2 e os pareceres delta. Não substituir `CONDICIONAL_OU_MISTA` por `neutro`: neutralidade do usuário é uma resposta distinta.

## Arquivos principais

- `../2026-09-29-thematic-profiles/`: perfis dos 13 planos por categoria.
- `../2026-09-29-question-editorial-review/DECISION_MAP.json`: 118 famílias de decisão.
- `../2026-09-29-full-thesis-battery/BATTERY.md`: bateria final aprovada.
- `../2026-09-29-approved-full-battery-validation/FINAL_REPORT.md`: cobertura da versão 2.
- `../2026-09-29-approved-full-battery-validation/EDITORIAL_ADJUDICATION.md`: motivo das quatro mudanças.
- `../2026-09-30-v3-delta-validation/FINAL_MATRIX.json`: matriz final de 20 teses por 13 planos.
- `../2026-09-30-v3-delta-validation/FINAL_REPORT.md`: cobertura final e elegibilidade 5/4.
- `../../../scripts/build_affinity_beta_2026_data.py`: exportador do snapshot de produção.
- `PROPOSTA_BETA.md`: desenho de ranking e comunicação.

## Verificações antes do handoff

```bash
python docs/research/2026-09-29-full-thesis-battery/validate.py
python docs/research/2026-09-29-approved-full-battery-validation/validate.py
python docs/research/2026-09-30-v3-delta-validation/validate.py
python scripts/build_affinity_beta_2026_data.py --check
cd backend && .venv/bin/pytest
cd ../mobile && flutter test && flutter analyze
git diff --check
```

O validador histórico espera o corpus em `/tmp/farol-full-plan-review-20260929`; o corpus oficial reconstruído em 30/09 pode ser ligado a esse caminho porque os hashes dos 13 PDFs são idênticos.
