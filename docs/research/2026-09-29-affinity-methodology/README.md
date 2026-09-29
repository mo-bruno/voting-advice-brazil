# Estudo de cobertura, teses e afinidade presidencial

Data: 29/09/2026. Base de código: `origin/main`, commit `b61d768`.
Branch isolada: `codex/affinity-methodology`.

**Conclusão:** o percentual atual mede concordância nas posições conhecidas de cada candidatura. Ele não sustenta, sozinho, uma classificação de afinidade sobre todo o questionário. Diminuir o número de perguntas ou trocar Manhattan por outra distância não resolve a falta de evidência. A direção recomendada combina transparência da cobertura, limites ao ranking e revisão editorial das teses.

Este é um estudo e uma recomendação de produto; não é uma metodologia nova já aprovada ou implantada. Código de produção, questionário, classificações dos planos e serviços publicados não foram alterados.

Continuação após a orientação do usuário: [proposta de ranking beta compartilhável, sem percentual em destaque](PROPOSTA_BETA.md). Essa proposta preserva o ranking como requisito e analisa a exclusão transparente de candidaturas com cobertura insuficiente.

Nova etapa concluída: [revisão das 30 perguntas contra os 13 planos e de 12 alternativas](reformulation/README.md), com 546 registros e um rascunho provisório de 16 itens. Essa etapa reexamina fontes e classificações; as contagens deste relatório inicial continuam descrevendo a edição publicada, sem incorporar as correções propostas na revisão posterior.

## Objetivo e escopo

O pedido é permitir que a pessoa se reconheça nas questões e compare suas respostas com os planos oficiais entregues ao TSE, sem transformar uma única concordância em uma promessa de alinhamento global. Redução de perguntas e mudanças matemáticas são meios possíveis, não metas previamente fixadas.

A auditoria usa a edição documental versionada no repositório: 13 candidaturas, 70 formulações classificadas, 30 publicadas e banco de origem com 111 itens. Trata-se do retrato local, não de uma nova coleta do TSE nem de uma confirmação da situação eleitoral em tempo real. As contagens assumem todas as perguntas respondidas, com pesos iguais. No produto, respostas puladas e pesos alteram a base de cada pessoa.

Não foi refeita a leitura das 836 páginas dos planos. As classificações existentes são entradas da análise, não fatos independentemente recodificados neste estudo. A própria metadata registra `human_reviewed: false`. Página e trecho rastreável ajudam a verificar uma decisão, mas não garantem por si sua interpretação correta.

## 1. Causa reproduzida

Em `backend/app/core/scoring.py`, perguntas puladas, posições ausentes e `NO_OPINION` saem do numerador e do denominador. O mínimo de cinco respostas se aplica ao usuário, não à quantidade de posições conhecidas de cada candidatura. Em `submit_quiz.py`, uma única comparação basta para entrar no ranking.

| Exemplo de execução do cálculo atual | Comparáveis | Percentual |
|---|---:|---:|
| 30 respostas; uma concordância e 29 posições ausentes | 1 | 100% |
| 30 respostas; nove concordâncias e 21 posições ausentes | 9 | 100% |
| 30 respostas; 30 concordâncias | 30 | 100% |
| 30 respostas; uma concordância e 29 discordâncias conhecidas | 30 | 3,33% |
| Cinco respostas e 25 puladas; uma concordância comparável | 1 | 100% |
| 30 respostas; nenhuma posição conhecida | 0 | Sem comparação; sentinela interna 0 |

Uma concordância e uma discordância produzem 50% com pesos iguais, 66,67% quando a concordância tem peso duplo e 33,33% quando a discordância tem peso duplo. Dobrar pesos das perguntas sem posição conhecida não modifica o percentual observado.

A fórmula não tem um erro aritmético nesse exemplo. O erro está em comunicar e ordenar resultados condicionados a bases diferentes como se fossem comparações completas equivalentes.

### Caminho até a interface

- API: `backend/app/api/schemas/quiz.py` e `routers/quiz.py` expõem percentual e contagens, mas não pesos comparáveis, limites ou status de suficiência.
- Modelo: `mobile/lib/shared/models/candidate_result.dart` trata qualquer contagem positiva como suficiente para exibir percentual.
- Resultados: `mobile/lib/features/results/results_page.dart` ordena por percentual e nome; a cobertura está na tela secundária de comparação.
- Sessão: `mobile/lib/shared/quiz_session.dart` inclui resultados de uma comparação entre os de maior afinidade.
- Compartilhamento: `mobile/lib/features/results/sharing/result_share_data.dart` e `result_share_card.dart` podem divulgar “maior afinidade” e 100% sem informar a base.
- Temas: o percentual por tema em `submit_quiz.py` repete a normalização sobre posições disponíveis.

Há ainda uma divergência: o backend desempata por percentual, concordâncias exatas, discordâncias e nome; interface e compartilhamento reordenam por percentual e nome. Alterar somente o `rank` da API não corrige o resultado mostrado.

O commit `0f43a39` retirou cobertura e explicação de bases diferentes dos cartões e passou a ordenar por afinidade. `95c22e1` acrescentou compartilhamento. Os testes atuais protegem esse contrato; sua aprovação não significa que a metodologia é adequada.

## 2. Cobertura real da edição

Das 390 células publicadas, 116 têm posição categórica (**29,7%**), 20 são condicionais/mistas e 254 não têm manifestação suficiente no escopo da tese. Todas as 116 posições categóricas atuais são concordância ou discordância; não há neutralidade explícita nessa matriz ativa.

Nomes abaixo seguem o cadastro do repositório. Contagens representam cobertura do questionário, não qualidade do plano ou mérito da candidatura.

| Candidatura | Posições em 30 | Cobertura | Temas com posição |
|---|---:|---:|---:|
| Clariana Barao | 0 | 0% | 0 |
| Veterinário Wilson Grassi | 1 | 3,3% | 1 |
| Leonardo Avalanche | 3 | 10% | 3 |
| Escritor Augusto Cury | 4 | 13,3% | 4 |
| Ronaldo Caiado | 5 | 16,7% | 4 |
| Renan Santos | 7 | 23,3% | 5 |
| Lula | 9 | 30% | 5 |
| Rui Costa Pimenta | 10 | 33,3% | 4 |
| Flavio Bolsonaro | 11 | 36,7% | 7 |
| Hertz Dias | 13 | 43,3% | 7 |
| Zema | 17 | 56,7% | 7 |
| Samara | 17 | 56,7% | 8 |
| Edmilson Costa | 19 | 63,3% | 8 |

Entre os 78 pares de candidaturas:

- 20 não compartilham nenhuma posição categórica na mesma tese;
- 39 compartilham zero ou apenas uma;
- somente 14 compartilham cinco ou mais;
- 34 possuem pelo menos uma oposição categórica documentada.

“100% em uma pergunta de economia” e “80% em vários assuntos” não medem exatamente o mesmo conteúdo. Um maior número de comparações também não resolve sozinho a diferença de temas.

### Conteúdo e seleção

As 30 perguntas se distribuem em economia (6), educação (5), política externa (5), trabalho (4), saúde (3), governança (3), política social (2), segurança (1) e direitos sociais (1). Não há pergunta ativa classificada como meio ambiente, agricultura ou infraestrutura. Essas categorias aparecem nas formulações não publicadas. Contar categorias não substitui leitura semântica: uma tese pode ter efeitos em mais de um tema.

Em 25 das 30 teses, um dos polos categóricos é ocupado por apenas uma candidatura. Isso não torna a tese inválida, mas requer verificar se a seleção dá peso excessivo a escolhas muito particulares e deixa de fora questões relevantes.

Três pares têm perfis documentais idênticos: T026A/T026B (gestão da saúde), T034A/T034B (Conselho de Segurança da ONU), T043/T044 (vouchers). Os objetos não são necessariamente iguais e usuários podem responder diferentemente. A coincidência indica uma prioridade de revisão de peso temático, não autorização para fundir ou excluir automaticamente.

Há um ponto editorial concreto a reexaminar: T050, sobre suspensão de novos assentamentos, tem ambos os polos e quatro posições categóricas, mas foi excluída por redundância com T028. T028 também está fora do quiz. A justificativa de duplicar pontuação ativa merece revisão. T050 acrescentaria agricultura e uma comparação hoje ausente entre Renan Santos e Rui Costa Pimenta. A condição de produtividade e as evidências precisam de revisão antes de qualquer publicação.

## 3. O que acontece ao reduzir perguntas

Os subconjuntos de 10/15/20 abaixo são experimentos mecânicos: ordenar por número de posições, tamanho do polo minoritário e ID. Não são questionários recomendados, nem uma otimização de validade ou imparcialidade.

| Cenário | Células categóricas | Densidade | Pares sem base comum | Pares com oposição | Temas |
|---|---:|---:|---:|---:|---:|
| 30 atuais | 116 | 29,7% | 20 | 34 | 9 |
| 23 do núcleo existente | 102 | 34,1% | 20 | 34 | 9 |
| 20 por densidade | 93 | 35,8% | 20 | 34 | 8 |
| 15 por densidade | 74 | 37,9% | 21 | 32 | 8 |
| 10 por densidade | 54 | 41,5% | 25 | 26 | 7 |
| Todas as 70, incluindo drafts | 221 | 24,3% | 18 | 36 | 12 |

As sete complementares acrescentam 14 posições, mas não acrescentam pares com base comum nem pares com oposição. O núcleo de 23 é uma hipótese útil para testar uma experiência mais curta: mantém 87,9% das posições categóricas atuais. Ele também reduz contagens de certas candidaturas e modifica pesos relativos; não preserva necessariamente resultados ou ordenação.

Reduzir perguntas pode aumentar a porcentagem de cobertura simplesmente diminuindo o denominador. Nenhum subconjunto cria uma posição nova: Clariana continua com zero e Grassi com no máximo uma. Mesmo nas 70 formulações, ambos ficam em zero e duas. Ativar todos os drafts não é uma solução: muitos foram excluídos por problemas de escopo, redundância ou ausência de contraste.

**Recomendação editorial:** testar um núcleo mais curto, sem fixar antecipadamente 15, 20 ou 23. Selecionar conjuntamente por relevância para a Presidência, clareza, assunto único, diversidade temática, cobertura por candidatura, comparabilidade dos pares e contraste documental. Manter explicações acessíveis e evidências com página, trecho e hash. Mudar o significado exige nova versão da tese e não permite reaproveitar a resposta histórica como equivalente.

Não ampliar a base para entrevistas, ideologia ou histórico legislativo sem uma mudança explícita de escopo: o pedido mantém os planos oficiais como referência. Se o plano não decide uma tese, a posição deve continuar desconhecida. Consensos parciais podem ser informativos, mas sua inclusão não cria contraste entre candidaturas sem evidência.

## 4. Alternativas matemáticas

### A. Afinidade observada, cobertura e limites — recomendada

Para cada resposta não pulada `i`, sejam `wᵢ` seu peso e `sᵢ` a semelhança na escala atual: 1 para coincidência, 0,5 para distância intermediária e 0 para oposição. Seja `R` o conjunto respondido e `K` o subconjunto com posição categórica documentada da candidatura.

```text
W = soma dos pesos em R
Kpeso = soma dos pesos em K
P = soma, em K, de wᵢ × sᵢ

A = P / Kpeso                  afinidade observada; indefinida se Kpeso = 0
C = Kpeso / W                  cobertura ponderada das respostas
L = P / W                      contribuição concordante documentada
U = (P + W − Kpeso) / W         limite superior conservador
```

Exibir os valores multiplicados por 100. Calcular antes de arredondar. A identidade `L = A × C` usa A e C entre 0 e 1, não percentuais inteiros.

`[L, U]` contém as afinidades possíveis ao completar as posições desconhecidas na mesma escala. Não é intervalo estatístico de confiança nem previsão do voto; não cobre erros nas classificações já conhecidas. Sua largura é `1 − C`. A faixa conservadora admite qualquer semelhança desconhecida entre 0 e 1. Uma implementação pode estreitá-la por item: para resposta neutra do usuário, uma posição desconhecida nessa escala não pode produzir semelhança zero.

Exemplos com pesos iguais e respostas não neutras:

| Conhecido no conjunto de 30 respostas | Afinidade observada | Cobertura | Faixa conservadora |
|---|---:|---:|---:|
| Uma concordância | 100% | 3,3% | 3,3%–100% |
| Nove concordâncias | 100% | 30% | 30%–100% |
| 20 concordâncias e quatro discordâncias; seis desconhecidas (hipotético) | 83,3% | 80% | 66,7%–86,7% |
| 30 concordâncias | 100% | 100% | 100%–100% |

Também é possível representar três parcelas no mesmo denominador: concordância documentada `L`, distância documentada `C−L` e parte não comparável `1−C`. A parcela de distância inclui a distância intermediária de respostas neutras, portanto não deve ser rotulada simplesmente como quantidade de discordâncias.

Para 1/30, a mensagem principal deveria ser **“Concordância na única pergunta comparável; base insuficiente para uma conclusão geral”**, acompanhada de “1 de 30 respostas; 29 sem comparação”. O 100% pode ser explicado no detalhe como afinidade observada, mas não destacado como alinhamento global ou vencedor.

Contagem, cobertura ponderada e cobertura do questionário são medidas distintas. Uma pessoa que responde cinco e pula 25 pode ter 5/5 comparáveis para um candidato; isso não torna cinco assuntos representativos das 30 teses. Mostrar também quantas questões foram respondidas e quais temas ficaram cobertos.

### B. Um percentual penalizado por ausência — não recomendado como afinidade

Multiplicar afinidade por cobertura transformaria 100% em 1/30 em 3,3%. Isso é matematicamente válido como contribuição documentada ou limite inferior, mas não como estimativa da afinidade completa. Ordenar somente por esse valor favorece planos com mais posições identificáveis; não demonstra que a pessoa discorda das posições desconhecidas.

O indicador pode aparecer em uma barra de evidências, com seu significado explícito. Não deve substituir silenciosamente o atual percentual sob o mesmo rótulo.

### C. Suavização estatística ou outra distância — não recomendada agora

Trocar Manhattan por Euclidiana não cria evidência ausente. Uma média bayesiana puxando resultados escassos para 50% evita extremos, mas coloca uma suposição no lugar das posições faltantes. A força do prior muda o ranking. As teses são selecionadas editorialmente, podem ser correlacionadas e as omissões dos planos podem ser seletivas; não são uma amostra aleatória de ensaios independentes. Não há validação local para chamar esse número de confiança ou probabilidade de alinhamento.

## 5. Como limitar conclusões sem inventar um corte científico

Nenhum limiar universal para dados documentais esparsos foi identificado nas fontes consultadas. “Cinco comparações”, “dez questões” ou “50%” seriam escolhas de produto a justificar, não garantias de validade.

| Regra ilustrativa aplicada às 30 respostas de peso igual | Candidaturas que passam, de 13 |
|---|---:|
| Pelo menos cinco comparações | 9 |
| Pelo menos oito comparações | 7 |
| Pelo menos dez comparações | 6 |
| Cobertura de pelo menos 40% | 4 |
| Cobertura de pelo menos 50% | 3 |
| Cobertura de pelo menos 60% | 1 |
| Cobertura de pelo menos 80% | 0 |
| Cinco comparações, 40% de cobertura e três temas | 4 |

Um corte de 80% limita a largura da faixa conservadora a 20 pontos percentuais, mas não garante ranking estável, representatividade temática ou correção da codificação. A base atual não atende esse corte para nenhuma candidatura com as 30 respostas.

Para afirmar uma ordem sustentada mesmo pelas lacunas, é suficiente que o limite inferior de A supere o superior de B, no mesmo universo de respostas e pesos. Quando as faixas se sobrepõem, esse critério não determina a ordem. Pode haver resultados parcialmente ordenados, sem um primeiro lugar inequívoco. Comparar pares sobre interseções distintas e depois ordená-los globalmente pode gerar ciclos.

**Direção recomendada para o produto:** manter todas as candidaturas consultáveis, mostrar a base e as lacunas na tela principal e nos compartilhamentos, distinguir alguma evidência de suficiência e não anunciar “maior alinhamento” quando a comparação for inconclusiva. Enquanto a base não sustentar um ranking global, apresentar comparações documentais e por tema, com o alcance de cada conclusão. Afinidade observada pode ser consultada sem ser tratada como estimativa completa.

Um ranking completo só deve voltar a ser uma promessa do produto após uma seleção de questões e uma base documental que sustentem comparações suficientemente comuns. Se for adotado um corte pragmático em vez do critério conservador, ele precisa ser rotulado como regra editorial e avaliado em cenários de sensibilidade, sem escolher parâmetros para produzir um resultado político desejado.

## 6. Encaminhamento concreto

1. **Corrigir o contrato de apresentação e ranking.** Acrescentar pesos comparáveis/respondidos, cobertura, limites, status e versão metodológica; manter afinidade observada com semântica explícita. Aplicar a mesma regra no backend, na sessão, nos cartões, nos temas, nas imagens e nas legendas. Um resultado de uma comparação não deve produzir um destaque de 100% como afinidade geral.
2. **Revisar a seleção editorial.** Usar as 23 do núcleo como cenário inicial de avaliação, sem publicá-las automaticamente. Revisar concentração temática, pares com perfis idênticos, T050/T028 e possíveis formulações claras já sustentadas pelos planos. Preservar explicações e rastreabilidade. Usar revisão independente e adjudicação nas classificações que entrarem na edição final.
3. **Validar antes de publicar.** Medir sensibilidade à retirada de uma pergunta/tema, mudança de peso e ausência por candidato/tema. Cobertura maior não é prova de melhora se vier só da exclusão de perguntas. Comparar a distribuição de evidências por candidatura antes e depois, sem usar resultado desejado de partido como alvo.

Casos obrigatórios para implementação: 1/30 e 9/30; 0 comparações versus 0% observado; todos os itens pulados/rejeição do mínimo; pesos desiguais; usuário neutro; mudança da seleção de candidatos; igualdade na fronteira de regras; intervalos sobrepostos; empate; mesma interpretação no resultado, PNG e texto compartilhado. Não enviar respostas ou afinidades à telemetria.

Migração: `score_percent` é numérico obrigatório no parser atual. Acrescentar campos preserva compatibilidade técnica, mas clientes antigos continuarão a mostrar o percentual isolado. `rank=0` sozinho não resolve porque o cliente reordena. Resultados são calculados sob demanda; a persistência grava respostas e pesos. Reproduzir resultados históricos também exige identificar a versão do cálculo e da edição documental. Imagens já exportadas não podem ser alteradas retroativamente.

## 7. Referências metodológicas

- [Wahl-O-Mat — FAQ oficial da bpb](https://www.bpb.de/themen/wahl-o-mat/bundestagswahl-2025/558464/haeufig-gestellte-fragen-zum-wahl-o-mat/): pontuação por proximidade, peso duplo, distinção entre neutralidade e pular, seleção por relevância, compreensão, contraste e variedade temática. Os partidos respondem diretamente às teses. A semelhança da fórmula não valida automaticamente sua aplicação a planos muito incompletos.
- [Reiljan et al., 2020 — EU Profiler/euandi](https://api.unil.ch/iris/server/api/core/bitstreams/5be0403c-8ba4-42b0-8985-4d64cb73d6c5/content): combina autoavaliação partidária e avaliação independente, usa múltiplas fontes e distingue ausência de informação de neutralidade. É uma referência para qualidade de codificação; o escopo deste projeto continua restrito aos planos oficiais.
- [Walgrave, Nuytemans e Pepermans, 2009 — efeito da seleção de teses](https://medialibrary.uantwerpen.be/oldcontent/container2608/files/Walgrave%20et%20al%202009%20-%20voting%20aid%20applications.pdf): experimenta subconjuntos de teses e encontra sensibilidade dos resultados à composição do questionário. Não fornece um mínimo transferível ao caso brasileiro.
- [Bachmann, Sarasua e Bernstein, 2024 — questionários adaptativos](https://arxiv.org/html/2404.01872v1): pesquisa redução/adaptação usando dados suíços completos e ausências simuladas. Não valida imputar posições brasileiras ausentes dos planos; a transferência de contexto requer avaliação própria.
- [smartvote — FAQ oficial](https://demo.smartvote.org/en/wiki/demo-faq): usa outra distância e esclarece a interpretação do percentual. Reforça que o significado do número deve ser explicado; mudar a distância não elimina o problema documental.

Os limites determinísticos e a recomendação de produto deste estudo são análise própria. Não são apresentados como uma norma adotada por todas essas ferramentas.

## 8. Reprodução e verificações

Da raiz deste worktree:

```bash
python3 docs/research/2026-09-29-affinity-methodology/audit.py \
  --output /tmp/farol-coverage-audit.json
diff -u docs/research/2026-09-29-affinity-methodology/audit.json \
  /tmp/farol-coverage-audit.json
```

O script usa somente a biblioteca padrão, lê os arquivos versionados e grava somente o destino indicado. `audit.json` registra hashes das entradas, contagens por tese/candidatura/tema, pares, perdas por redução, limiares ilustrativos e itens do banco para revisão. Os filtros lexicais do banco são pistas de leitura, não uma classificação validada de temas.

Verificação do comportamento existente: 115 testes focados de `test_scoring.py`, `test_quiz.py`, `test_presidential_integration.py` e `test_presidential_full_review.py` passaram. Foram usados o Python do ambiente já existente no checkout original e `PYTHONPATH=.` apontando para o backend deste worktree. Não foi executada a suíte Flutter nem alegada validação visual ou publicação.
