# Roteiro da Apresentacao Final - Farol Politico

Data: 2026-06-01
Status: aprovado para montagem dos slides
Escopo: roteiro e ordem dos slides da apresentacao final, sem criacao do deck.

## Objetivo

Montar uma apresentacao final de 10 minutos para o projeto Farol Politico, com ate 5 minutos de perguntas, cobrindo explicitamente os criterios de avaliacao da disciplina e priorizando os itens de maior peso.

O roteiro deve deixar claro que o projeto evoluiu de um MVP de quiz eleitoral para uma plataforma com app, backend, dados oficiais, acompanhamento parlamentar e prototipo IoT demonstrado por video curto.

## Criterios de Avaliacao

Segundo o arquivo `docs/interno/9 Projetos I Avaliacao 2.pdf`, relatorio e apresentacao devem conter pelo menos:

| Criterio | Peso |
| --- | ---: |
| Tema e Motivacao | 0.5 |
| Problema Tratado | 0.5 |
| Estado da Arte | 0.5 |
| Plano de Projeto e Resultados Esperados | 0.5 |
| Cronograma Atualizado | 0.5 |
| Conceitos e Tecnologias | 1 |
| Desenvolvimento | 2 |
| Testes e Validacao | 2 |
| Resultados | 2 |
| Conclusao e Proximos Passos | 0.5 |

Como Desenvolvimento, Testes e Validacao, e Resultados somam 6 pontos, a apresentacao deve concentrar mais tempo nesses blocos.

## Referencia de Testes e Validacao

O arquivo `docs/interno/7 Testes e Validacoes.pdf` reforca que a validacao deve ser tratada como processo continuo:

- Hipoteses: o que acreditamos ser verdade.
- Validacao e testes: processo de prova.
- Experimentos e aplicacoes: ferramentas praticas.
- Aprendizados: resultado para o projeto.

Tambem sao relevantes os conceitos de Value Proposition Canvas, Business Model Canvas, criterios de sucesso da hipotese, escada de validacao, entrevistas, experimentos de baixa fidelidade, MVP, metricas, A/B testing e validacao em producao com risco controlado.

Na apresentacao, esse conteudo deve aparecer no bloco de Testes e Validacao, conectando teoria da disciplina com evidencia real: analytics, formulario, testes automatizados, compilacao de firmware e feedback qualitativo.

## Abordagem Aprovada

Usar a rubrica como narrativa:

```text
Problema -> Solucao -> Arquitetura -> Desenvolvimento -> Testes/Validacao -> Resultados -> Proximos passos
```

Essa abordagem cobre todos os criterios explicitamente e ainda permite uma demo curta do app em producao e alguns segundos do video do IoT.

Os apresentadores nao precisam ficar limitados a areas fixas. A divisao de fala pode ser feita depois; os slides devem ser guiados pela rubrica.

## Roteiro Recomendado

| # | Slide | Tempo | Criterio principal | Conteudo |
| ---: | --- | ---: | --- | --- |
| 1 | Capa | 0:15 | Tema | Farol Politico, integrantes, disciplina e data. |
| 2 | Motivacao | 0:35 | Tema e Motivacao | Excesso de informacao politica, propostas longas e linguagem dificil. |
| 3 | Problema Tratado | 0:40 | Problema | Como reduzir a assimetria informacional entre eleitor, propostas oficiais e atuacao parlamentar. |
| 4 | Estado da Arte | 0:40 | Estado da Arte | VAAs como Wahl-O-Mat e Vote Compass; lacuna brasileira em dados oficiais e acompanhamento pos-eleicao. |
| 5 | Proposta de Solucao | 0:40 | Plano / Resultados esperados | App de compatibilidade eleitoral, dados oficiais, rastreador parlamentar e Farol IoT. |
| 6 | Plano e Cronograma Atualizado | 0:40 | Plano / Cronograma | O que foi planejado e o que foi entregue: MVP, app, backend, Camara, IoT e validacao. |
| 7 | Conceitos e Tecnologias | 0:50 | Conceitos e Tecnologias | Flutter, FastAPI, SQLAlchemy/Alembic, Firebase, Cloud Run, MQTT, ESP32/Mega, Camara API e GNews. |
| 8 | Arquitetura Geral | 0:45 | Desenvolvimento | Usuario -> app -> backend -> banco/APIs publicas -> MQTT -> dispositivo. |
| 9 | Desenvolvimento: Quiz e Matching | 0:45 | Desenvolvimento | 30 teses, 12 candidatos, metodologia Wahl-O-Mat, City Block Distance e pesos por tese. |
| 10 | Desenvolvimento: App e API | 0:45 | Desenvolvimento | Fluxo de quiz, pesos, selecao de partidos, ranking, comparacao e politicos acompanhados. |
| 11 | Desenvolvimento: Farol IoT | 0:45 | Desenvolvimento | Pareamento por QR/codigo, MQTT, LED/display, eventos de quiz, voto e noticias; mostrar 8-12 segundos do video. |
| 12 | Demo ao Vivo | 1:15 | Desenvolvimento / Resultados | Abrir app em producao e mostrar fluxo principal sem consumir tempo excessivo. |
| 13 | Testes Automatizados | 0:55 | Testes e Validacao | Backend: 188 testes, 88,87% de cobertura; mobile: 52 testes; Ruff, mypy e flutter analyze limpos; firmware ESP32/Mega compila. |
| 14 | Validacao com Usuarios | 0:55 | Testes e Validacao | Hipotese, experimento, metricas e aprendizado: GA4, formulario, funil, NPS e feedback qualitativo. |
| 15 | Resultados Obtidos | 0:55 | Resultados | MVP em producao, 85 visitantes no funil, 27 viram resultado, 28 respostas no formulario, nota media 8,89 e 96,4% de conclusao no formulario. |
| 16 | Conclusao e Proximos Passos | 0:40 | Conclusao | Aprendizados: glossario, escala mais granular, expansao legislativa/eleicoes futuras, robustez IoT e validacao longitudinal. |

Tempo total estimado: 10 minutos.

## Demo Ao Vivo

A demo deve provar que existe produto em producao, nao substituir a apresentacao.

Fluxo recomendado:

1. Abrir o app ja carregado.
2. Mostrar a home.
3. Entrar no quiz.
4. Responder 2 ou 3 teses.
5. Ir para resultado usando estado preparado, se possivel.
6. Mostrar rapidamente "Acompanhar politicos" ou "Meu Farol".
7. Voltar aos slides.

O video do IoT deve entrar no slide 11, por poucos segundos, como evidencia visual. Nao deve ser tratado como a demo principal.

## Slides de Backup

Depois do encerramento, deixar slides extras para perguntas:

- Lista de endpoints da API.
- Tabela de testes por camada.
- Prints do app.
- Frames do video IoT.
- Funil GA4 completo.
- Arquitetura do banco e migrations.
- Detalhes do algoritmo de score.

## Evidencias Tecnicas Levantadas

Verificacao local realizada em 2026-06-01:

- `uv run pytest`: 188 testes passaram; cobertura total 88,87%; minimo exigido no projeto: 80%.
- `uv run ruff check .`: sem issues.
- `uv run mypy app/`: sem issues em 59 arquivos.
- `flutter test`: 52 testes passaram.
- `flutter analyze`: sem issues.
- `pio run --project-dir firmware/esp32`: build passou; uso estimado de 14,4% RAM e 71,4% flash.
- `pio run --project-dir firmware/mega`: build passou; uso estimado de 9,1% RAM e 11,2% flash.

## Decisoes Pendentes

- Escolher qual pessoa fala cada trecho.
- Separar prints e video curto do IoT.
- Definir se a demo usara dados reais ao vivo ou estado preparado.
- Atualizar o cronograma visual com status final de cada entrega.
- Decidir se o roteiro sera convertido para deck HTML reaproveitando o modelo do MVP ou montado manualmente em outra ferramenta.
