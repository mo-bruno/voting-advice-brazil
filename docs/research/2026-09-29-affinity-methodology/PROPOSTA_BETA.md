# Proposta de ranking de afinidade para a edição beta

> **Atualização para continuação:** a bateria final aprovada é a versão 3 registrada em [HANDOFF.md](HANDOFF.md). O piso de oito posições, metade da bateria e três temas descrito abaixo foi uma hipótese anterior. A hipótese mais recente, ainda pendente de teste após quatro reclassificações, é de cinco posições comparáveis em pelo menos quatro categorias. Não implementar nenhum dos cortes como regra definitiva sem recalcular a matriz final.

Esta proposta continua o estudo de 29/09/2026. Registra a orientação aprovada pelo responsável pelo produto e os resultados de uma segunda investigação; não altera a edição publicada.

**Atualização documental:** a [revisão posterior de todas as 30 perguntas contra os 13 planos](reformulation/README.md) encontrou oito mudanças de redação recomendadas, correções de categorias e um recorte provisório de 16 itens. As listas de 18–20 abaixo são hipóteses anteriores, não uma seleção fechada. A nova análise também mostra que a base mínima operacional, sozinha, não comprova distinção suficiente entre todos os pares do ranking.

## Direção confirmada pelo usuário

- Preservar um ranking final de afinidade e seu compartilhamento.
- Priorizar a revisão das perguntas; preparar as mudanças de resultado em paralelo.
- Permitir que candidaturas sem cobertura documental suficiente fiquem fora do ranking, com justificativa pública.
- Apresentar o projeto como beta, em desenvolvimento para melhorar esta experiência e futuras edições.
- Manter o ranking sem percentual em destaque, dando visibilidade à base de respostas comparáveis. Esta preferência foi confirmada separadamente durante a investigação.

Não há necessidade de fabricar um teto de 95% ou 99%. O ranking pode continuar ordenando a afinidade observada internamente, enquanto a interface comunica colocação, alcance e evidência. Esconder o percentual, sozinho, não corrige uma base de uma ou duas perguntas: o filtro de inclusão também é necessário.

## Recomendação de produto

### Perguntas e participação

Trabalhar primeiro em uma lista curta de aproximadamente 18–20 perguntas, com revisão documental e editorial antes de publicar. Essa faixa é um objetivo de duração a testar, não um número cientificamente validado. Não escolher questões ou parâmetros para preservar nomes, partidos ou um resultado político desejado.

Os critérios devem considerar relevância para a Presidência, clareza, uma decisão por pergunta, fontes suficientes, diversidade temática e capacidade de comparação. Excluir duplicações de peso exige decisão editorial: perfis iguais entre candidatos não tornam automaticamente duas questões semanticamente iguais.

Como proposta operacional inicial de inclusão no **ranking beta**, aplicar conjuntamente:

1. Pelo menos oito posições categóricas comparáveis.
2. Cobertura de pelo menos metade das perguntas da edição.
3. Posições comparáveis em pelo menos três temas.

Para o resultado individual, exigir também pelo menos oito comparações efetivas, metade do peso das respostas não puladas e três temas comparáveis. A candidatura precisa já pertencer ao recorte editorial: pular perguntas não readmite quem ficou de fora da edição.

O corte é editorial, não uma garantia estatística. Deve ser publicado e versionado. Com 20 perguntas respondidas de peso igual, a exigência de metade implica dez comparações; com 18, implica nove. O piso absoluto evita que um questionário ou conjunto de respostas muito pequeno faça uma única posição parecer suficiente.

O tamanho do PDF não é um critério de exclusão: um plano longo também pode não responder às perguntas selecionadas. A mensagem correta é insuficiência **para este questionário**, não ausência de propostas ou inferioridade da candidatura.

### Ranking e compartilhamento

A ordenação proposta é por afinidade observada nas respostas comparáveis, preservando os pesos da pessoa. Falta de posição continua fora dessa média; não recebe oposição, neutralidade ou pontuação presumida. O filtro de inclusão evita os casos extremos de pouquíssima evidência, mas não transforma bases diferentes em uma medição de afinidade política completa.

Na tela e na imagem compartilhada, usar:

> **Meu ranking de afinidade · Beta**
>
> Entre os planos que atenderam aos critérios desta edição.
>
> **1º · Candidatura A**
>
> Base: 12 de 18 respostas comparáveis · 4 temas
>
> Farol Político · Presidência 2026

Esse é um exemplo fictício de apresentação, não um resultado calculado para uma pessoa ou candidatura real. Quantidade respondida e tamanho do questionário precisam ser distinguíveis quando houver perguntas puladas. Em uma lista compartilhada, a base deve acompanhar cada candidatura, não apenas a primeira.

O percentual técnico pode permanecer no detalhamento da metodologia, identificado como concordância nas respostas comparáveis; não deve reaparecer como “100% de afinidade” na imagem, na legenda, no destaque ou no texto enviado a outros aplicativos. Também não deve ser substituído por uma barra que insinue a mesma completude.

Empates devem continuar empatados na interface e na imagem. A ordem alfabética pode organizar visualmente os nomes empatados, mas não converter empate em superioridade. API, sessão, tela e compartilhamento precisam usar a mesma regra. O número de candidaturas compartilhadas é o disponível de fato: não preencher um top 5 com candidaturas inelegíveis.

Se uma pessoa pular tantas perguntas que ninguém ou apenas uma candidatura atenda aos critérios, explicar a limitação e permitir completar respostas. Uma única candidatura elegível não deve ser anunciada como vencedora de uma comparação entre várias. O fluxo normal com o questionário preenchido deve oferecer o ranking entre as participantes desta edição.

### Candidaturas fora do ranking

Manter perfis, fontes e posições consultáveis em uma seção própria, com explicação verificável, por exemplo:

> **Fora do ranking desta edição beta**
>
> Identificamos posições comparáveis em 6 das 20 perguntas. Esta edição exige pelo menos 10 e cobertura de três temas. O plano continua disponível para consulta.

Não apagar candidaturas, inativar registros eleitorais ou atribuir 0% por insuficiência. “Fora do ranking da edição” e “sem comparações suficientes nas respostas desta pessoa” são motivos distintos.

Texto geral sugerido:

> O Farol Político está em fase beta. Este teste compara suas respostas com posições documentadas nos planos oficiais apresentados ao TSE. A seleção de perguntas e a cobertura dos planos ainda estão em revisão. O resultado é uma comparação limitada a esta edição, não uma recomendação de voto.

O selo beta deve estar na introdução, no resultado e no compartilhamento. Ele não substitui a explicação de cobertura.

## O que os experimentos mostraram

Uma lista provisória de 20 questões, derivada do núcleo de 23 e examinada sem usar nomes, partidos ou resultados de usuários como alvo, contém:

`T001`, `T003`, `T005`, `T011`, `T015`, `T017`, `T018`, `T026A`, `T036`, `T038`, `T041`, `T042`, `T043`, `T056`, `T058`, `T063`, `T064`, `T065`, `T066`, `T067`.

Ela preserva os nove temas ativos e tem 89 posições categóricas na codificação atual. Sob os critérios propostos, com todas as perguntas respondidas e pesos iguais:

| Candidatura | Comparações em 20 | Participaria do ranking provisório |
|---|---:|---|
| Clariana Barao | 0 | Não |
| Edmilson Costa | 13 | Sim |
| Escritor Augusto Cury | 4 | Não |
| Flavio Bolsonaro | 10 | Sim |
| Hertz Dias | 10 | Sim |
| Leonardo Avalanche | 3 | Não |
| Lula | 6 | Não |
| Renan Santos | 5 | Não |
| Ronaldo Caiado | 5 | Não |
| Rui Costa Pimenta | 7 | Não |
| Samara | 14 | Sim |
| Veterinário Wilson Grassi | 1 | Não |
| Zema | 11 | Sim |

Esta tabela descreve a consequência do cenário, **não uma lista de exclusões já decidida**. Demonstra por que a seleção precisa de revisão substantiva antes da implementação. Restringir o ranking atingiria também candidaturas com planos extensos, e não apenas planos pequenos.

Os dez pares entre as cinco participantes provisórias têm de quatro a dez questões em comum; somente seis pares apresentam oposição categórica. Aumentar o corte para 60% deixaria apenas Edmilson Costa e Samara, que coincidem nas dez questões que compartilham nesse cenário. Um corte mais alto, portanto, não garante um ranking mais informativo. Não se deve calibrar o corte para produzir vencedores ou uma lista de nomes desejada.

O cenário também continua sem meio ambiente, agricultura e infraestrutura como temas ativos. É uma lista para revisão, não a demonstração de que encontramos as vinte melhores perguntas.

## Revisão substantiva iniciada: jornada de trabalho

T005 hoje pergunta pelo limite exato de 30 horas. Uma formulação a testar é:

> **O limite geral da jornada de trabalho deve ser de 36 horas semanais ou menos, sem redução salarial.**

Essa alteração muda o significado da tese; exige nova versão, recodificação uniforme das treze candidaturas e revisão da explicação. Não se pode reinterpretar respostas antigas a “30 horas” como respostas à nova pergunta.

Foram conferidos os hashes dos treze PDFs no pacote preservado `proposta_governo_2026_BR_20260919.zip` contra a matriz atual. Foram feitas buscas em todos os PDFs por jornada, escala 6×1 e patamares de horas. As páginas das evidências dos seis planos com manifestação substantiva foram extraídas integralmente; a página 10 do plano de Samara também foi renderizada e inspecionada visualmente.

| Plano no acervo | Página física | Conteúdo relevante |
|---|---:|---|
| Lula | 75 | Propõe 40 horas sem redução salarial |
| Hertz Dias | 8 e 29 | Propõe 36 horas sem redução dos salários; contempla reduções futuras por produtividade |
| Edmilson Costa | 2 | Propõe 30 horas sem redução salarial |
| Rui Costa Pimenta | 2 | Propõe máximo de 35 horas; o contexto explicita ausência de prejuízo salarial |
| Zema | 23 | O regime alternativo à CLT permite jornada até 44 horas semanais |
| Samara | 10 | A página apresenta propostas de 30 e 36 horas, ambas sem redução salarial |

Há fundamento para testar uma classificação comum de propostas de 30, 35 e 36 horas no lado favorável à nova formulação. A discordância referente aos patamares de 40/44 horas precisa preservar o recorte de limite geral e verificar condições, transição e regime abrangido; não significa oposição a qualquer redução de jornada. Busca por termos, isoladamente, não fecha a revisão das ausências. As classificações propostas permanecem hipóteses editoriais nesta etapa.

Uma revisão independente ressaltou a assimetria: propor um teto menor pode satisfazer “no máximo 36”; propor 40 horas não demonstra, sozinho, rejeição a um teto menor, e um regime alternativo pode ter escopo diferente do limite geral. A revisão pode recuperar concordâncias sem preservar o polo contrário. Isso deve ser resolvido pela leitura contextual, não pela necessidade de obter uma tese que entre no ranking.

Esse exemplo ilustra a prioridade desta frente: aumentar comparabilidade por uma escolha política clara e sustentada nos planos, sem inferir posições partidárias nem apenas retirar perguntas do denominador.

## Organização da execução futura

As duas frentes podem avançar em paralelo, com uma dependência explícita: a edição final e o recorte de candidaturas só fecham depois da revisão das perguntas.

- **Frente editorial:** revisar a lista provisória, formular questões, verificar o mesmo escopo nos treze planos, registrar versões e motivos, preservar explicações, recalcular cobertura e publicar o manifesto da edição.
- **Frente técnica:** preparar ranking sem percentual em destaque, critérios configurados pela edição, estados de exclusão, beta e compartilhamento. Usar dados de teste enquanto o manifesto editorial não estiver fechado.
- **Integração:** aplicar o manifesto final, verificar casos de pouca evidência, pesos e pulos, conferir empates e paridade entre resultado e imagem, preservar histórico e sessões versionadas.

No código atual, elegibilidade deve ser separada de `is_active`. Remover alguém de `candidates.json` faz o seed inativar o perfil; essa não é a operação desejada. Da mesma forma, uma tese documentalmente válida retirada por duração ou diversidade não deve ser reclassificada como evidência inválida. A publicação precisa de um manifesto próprio, distinto da matriz documental.

A proposta dispensa, nesta primeira mudança, um novo índice estatístico, imputação de posições, prior bayesiano ou penalização silenciosa por ausência. O trabalho principal é editorial, de elegibilidade e de comunicação coerente.

## Reprodução dos cenários

`selection-audit.py` examina subconjuntos de 12–20 perguntas do núcleo após retirar um representante de cada um dos dois pares com perfis idênticos. Preserva os nove temas e limita a quatro perguntas por tema. A prioridade é menor concentração temática, mais pares com oposição, mais pares com pelo menos três itens compartilhados, mais posições documentadas e IDs para desempate. Essas prioridades são hipóteses editoriais declaradas, não uma definição universal de qualidade.

Os cenários não usam nomes, partidos, scores de usuários ou elegibilidade como objetivo de seleção. `selection-audit.json` também registra uma análise de sensibilidade de T050 e T005; nenhuma dessas simulações altera a matriz publicada. Em particular, a simulação T005 mantém provisoriamente as discordâncias de Lula e Zema, hipótese que depende da revisão de escopo descrita acima.

```bash
python3 docs/research/2026-09-29-affinity-methodology/selection-audit.py \
  --output /tmp/farol-selection-audit.json
diff -u docs/research/2026-09-29-affinity-methodology/selection-audit.json \
  /tmp/farol-selection-audit.json
```
