# Continuação do estudo de afinidade — handoff

## Estado entregue

A branch `codex/affinity-methodology` contém o estudo documental e editorial em um worktree isolado. A `origin/main` é ancestral direta da branch; o último `fetch` foi feito antes da publicação.

A bateria editorial canônica é a **versão 3**, com 20 teses aprovadas e os botões **Concordo, Discordo, Neutro e Pular**:

- leitura humana: `../2026-09-29-full-thesis-battery/BATTERY.md`;
- estrutura e hashes: `../2026-09-29-full-thesis-battery/BATTERY.json`;
- aprovação: `../2026-09-29-full-thesis-battery/APPROVAL.json`;
- versão anterior preservada: `BATTERY_V2.*` e `APPROVAL_V2.json` no mesmo diretório.

Pablo Marçal foi excluído do corpus por decisão do usuário. Nenhuma tese da edição anteriormente publicada foi usada para gerar esta bateria. Nenhum código de produção, ranking, seed ou interface foi alterado.

## O que foi feito

1. Treze agentes especialistas leram integralmente, cada um, um plano oficial do TSE. Os perfis temáticos preservam posições, citações, páginas, condições e lacunas nas dez categorias definidas pelo usuário.
2. O orquestrador consolidou 636 registros em 118 famílias de decisão e formulou uma bateria nova, independente da edição publicada.
3. A bateria passou por revisão semântica, cobertura, crítica adversarial e duas decisões humanas.
4. Os treze planos foram confrontados com a versão 2: 13 pareceres válidos, 260 respostas e 273 ocorrências de citações verificadas contra o corpus local.
5. A validação revelou quatro redações com interseção artificialmente baixa. O usuário aprovou as quatro mudanças, agora incorporadas na versão 3.
6. Foi registrada uma regra preliminar de elegibilidade para impedir que uma única coincidência produza “100%”: pelo menos cinco posições comparáveis em pelo menos quatro categorias. Essa regra ainda é hipótese de produto, não implementação.

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

## Validação que pode ser reutilizada

O diretório `../2026-09-29-approved-full-battery-validation/` contém os 13 pareceres da versão 2 e o validador que confere identidade, hash do PDF, cobertura, página e literalidade das citações. O comando abaixo retorna 13 pareceres válidos e 260 respostas:

```bash
python docs/research/2026-09-29-approved-full-battery-validation/validate.py
```

As classificações das 16 teses que não mudaram podem ser copiadas para uma matriz da versão 3. Não reutilizar as classificações antigas das posições 8, 10, 12 e 18, porque o objeto ou o alcance mudou.

## O que falta

### 1. Reclassificar quatro teses

Se a continuação precisar calcular afinidade real, cada um dos 13 planos deve responder às teses `FB-Q23`, `FB-Q24`, `FB-Q25` e `FB-Q19 v2`. São 52 classificações. As hipóteses de interseção em `EDITORIAL_ADJUDICATION.json` servem apenas para orientar buscas; não são respostas finais.

Depois disso:

- juntar as 52 classificações novas às 208 classificações reutilizáveis;
- executar as mesmas verificações de citações e páginas;
- recalcular cobertura por tese, candidatura e categoria;
- decidir quais candidaturas atingem o piso editorial do ranking.

### 2. Fechar a metodologia do ranking beta

A direção aceita pelo usuário é manter um ranking compartilhável, sem percentual de “100% de afinidade” em destaque. O resultado deve mostrar quantidade de respostas comparáveis e explicar candidaturas com dados insuficientes.

A hipótese mais recente exige pelo menos cinco posições comparáveis em quatro categorias. Deve ser testada depois da matriz versão 3. A falta de posição de um plano não pode virar discordância, neutralidade ou nota zero.

### 3. Implementar no produto

Ainda falta alterar backend, aplicativo e compartilhamento para:

- versionar a edição das teses e a metodologia;
- separar afinidade observada de suficiência documental;
- aplicar a mesma ordenação na API, tela, sessão e imagem compartilhada;
- exibir estado beta, base comparável e candidaturas fora do ranking;
- preservar os quatro botões e distinguir `Neutro` de `Pular`;
- testar pouca evidência, empates, pesos, respostas puladas e paridade com o compartilhamento.

## Arquivos principais

- `../2026-09-29-thematic-profiles/`: perfis dos 13 planos por categoria.
- `../2026-09-29-question-editorial-review/DECISION_MAP.json`: 118 famílias de decisão.
- `../2026-09-29-full-thesis-battery/BATTERY.md`: bateria final aprovada.
- `../2026-09-29-approved-full-battery-validation/FINAL_REPORT.md`: cobertura da versão 2.
- `../2026-09-29-approved-full-battery-validation/EDITORIAL_ADJUDICATION.md`: motivo das quatro mudanças.
- `PROPOSTA_BETA.md`: desenho de ranking e comunicação.

## Verificações antes do handoff

```bash
python docs/research/2026-09-29-full-thesis-battery/validate.py
python docs/research/2026-09-29-approved-full-battery-validation/validate.py
git diff --check
```

O primeiro comando valida a bateria versão 3. O segundo preserva a prova histórica da rodada completa contra a versão 2.
