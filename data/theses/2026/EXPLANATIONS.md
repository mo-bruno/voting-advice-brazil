# Explicações em linguagem simples

`explanations.json` contém a ajuda opcional das 30 teses aprovadas da edição
presidencial de 2026. O conteúdo é estático, em português brasileiro, igual para
todas as pessoas. Não depende de IA, não usa as respostas do participante e não
altera teses, posições de candidatos, pesos ou afinidades.

## Critérios editoriais

- Explicar os termos da pergunta, o contexto de leis citadas e o que a proposta
  significa, sem recomendar uma resposta ou listar argumentos a favor e contra.
- Usar de dois a quatro parágrafos curtos, sem presumir conhecimento prévio.
- Distinguir a regra existente da mudança proposta e um objetivo de um resultado
  garantido. Não inventar detalhes que a tese não define.
- Incluir de uma a quatro fontes primárias, com título legível e endereço HTTPS.
  Os links são exibidos em “Fontes para consultar”; não são necessários para ler
  a explicação. Uma fonte sobre a regra atual não significa apoio à proposta.
- Revisar o conteúdo e suas fontes quando uma lei, um contexto ou uma tese mudar.
  A data `updated_at` registra a atualização do catálogo, não uma aprovação humana.

## Vínculo com a edição publicada

Cada item referencia `thesis_id`, `thesis_version` e `thesis_text` de
`theses.json`. A API só anexa a explicação quando ano, identificador editorial,
versão e texto coincidem exatamente. Não se usam IDs numéricos do banco para
vincular o conteúdo. A publicação de novas teses exige revisar a ajuda
correspondente, preservando o histórico editorial original.

O catálogo é validado e mantido em memória por processo. Para publicar alterações,
é necessário incluir o arquivo em um novo deploy/reinício do backend. Catálogo
ausente/inválido ou vínculo desatualizado resulta em `explanation: null`, sem
bloquear o quiz; o cliente esconde a ajuda ausente. A ausência do campo em versões
anteriores da API também é aceita.

## Interface e verificação

“Entenda esta pergunta” expande uma caixa na própria página, sem chat ou modal.
As respostas permanecem em uma área fixa. Em alturas muito curtas ou texto muito
ampliado, essa área também pode ser rolada para manter todos os controles acessíveis.
A caixa começa recolhida a cada troca de pergunta. Cores, tipografia e componentes
reutilizam `AppTheme`, incluindo os cantos retos e os botões monocromáticos.

`backend/tests/test_thesis_explanations.py` verifica cobertura do catálogo,
vínculos e falhas seguras; `test_presidential_integration.py` verifica o retorno
real da API. `mobile/test/quiz_explanation_test.dart` cobre abertura, respostas,
navegação, links, teclado, semântica, telas pequenas e ampliação de texto.
