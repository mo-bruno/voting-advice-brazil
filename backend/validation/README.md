# Validação da moderação NVIDIA Lightning

A migração substitui `nvidia/nemotron-3-super-120b-a12b` por `nvidia/nemotron-3.5-lightning-30b-a3b`, exige JSON Schema estrito e esclarece que ausência de dados não equivale a informação falsa. Opiniões, perguntas e pedidos de explicação continuam sujeitos às regras de relevância e civilidade.

O orçamento de raciocínio passa de 256 para 512 tokens, e o limite total de saída passa de 512 para 1024. O timeout permanece em 20 segundos. A análise com 256 tokens foi capturada interrompida antes de chegar ao critério de civilidade; o modelo aprovou indevidamente um ataque. A captura sugere que o orçamento curto contribuiu para a falha. A ampliação é uma mitigação avaliada nos testes, sem garantir que todo raciocínio futuro termine ou que toda classificação esteja correta.

O esquema exige `approved` booleano e `reason` textual, ambos obrigatórios, sem campos adicionais. JSON simples não fixa os campos e tipos; a NVIDIA descreve essa diferença na [documentação de saída estruturada](https://docs.nvidia.com/nim/large-language-models/2.0.13/get-started/advanced/get-started-nemotron-3.5-super-vl.html). O endpoint hospedado do Lightning aceitou o esquema nos testes reais. A validação local continua rejeitando JSON malformado, decisão não booleana e justificativa fornecida em formato não textual. O parser local preserva a compatibilidade anterior com justificativa ausente e campos adicionais; o esquema solicitado ao provedor é mais restrito.

## Reprodução

Na raiz do repositório, configure `NVIDIA_API_KEY` no ambiente ou no arquivo local `backend/.env`, ignorado pelo Git. A avaliação chama o cliente real, sem substituir seus parâmetros, e não publica posts/comentários nem acessa o banco:

```sh
uv run --project backend python scripts/validate_nvidia_moderation.py \
  --report backend/validation/resultado-local.json --repeat 2
```

Para verificar uma regressão isolada, use `--case post-informal --repeat 3`. Repita `--case` para selecionar outros IDs de [fixtures sintéticas](../tests/fixtures/nvidia_moderation_cases.json).

O processo retorna 0 quando todas as decisões coincidem com as expectativas, rejeições incluem justificativa e cada chamada termina em até 20 segundos. Retorna 1 quando há falha na amostra e 2 quando não há credencial/configuração utilizável. Relatórios registram o modelo e hashes SHA-256 do cliente e das fixtures; não contêm a chave, headers ou corpos de erros do provedor.

## Etapas anteriores à configuração final

| Arquivo | Resultado | Observação |
|---|---|---|
| [Primeira rodada](lightning-2026-11-06.json) | 67/68 | `comment-injecao-pai` retornou `ModerationUnavailable`; a causa original não foi capturada. |
| [Segunda rodada](lightning-2026-11-06-repeat.json) | 67/68 | `post-informal` foi rejeitado indevidamente por não apresentar dados verificáveis. |
| [Prompt esclarecido, orçamento antigo](lightning-policy-final-2026-11-06.json) | 38/39; interrompida | Aprovação indevida de `post-ataque`; a análise com orçamento de 256 tokens não chegou à civilidade. O arquivo com nome histórico `policy-final` não representa a configuração final. |
| [Orçamento ampliado, JSON simples](lightning-final-2026-11-06.json) | 75/76 | Uma resposta de `comment-ataque-pai-removido` não passou na validação local (`ValueError`). Esse arquivo com nome histórico `final` precede a adoção de JSON Schema. |

Os erros dessas rodadas permanecem nos relatórios. A primeira indisponibilidade não demonstra que a chave expirou nem permite afirmar se houve falha HTTP, transporte ou resposta inválida. Na chamada de controle da investigação, o modelo antigo retornou HTTP 404 com uma chave que acessou o Lightning.

## Regressões dirigidas

| Arquivo | Resultado | Observação |
|---|---|---|
| [Clareza da política](lightning-regression-2026-11-06.json) | 15/15 | Críticas e pedidos de dados aprovados; política estrangeira rejeitada. Essa amostra foi feita antes da ampliação do orçamento. |
| [Orçamento ampliado](lightning-budget-regression-2026-11-06.json) | 11/12 | As 11 decisões recebidas estavam corretas; uma chamada teve `ReadTimeout` e continuou bloqueada como indisponível. |

Os totais incluem falhas de disponibilidade e de formato; uma chamada sem decisão não é contada como aprovada. Os relatórios anteriores são mantidos, em vez de apresentar somente repetições bem-sucedidas.

## Correção e limites

O prompt agora explicita que:

- menções genéricas a governo, Congresso, deputados e projetos de lei usam o contexto brasileiro da plataforma, salvo indicação de outro país;
- ausência de afirmações factuais ou de dados não viola a integridade;
- opiniões e pedidos de explicação não precisam apresentar provas; afirmações claramente falsas, números inventados e ataques continuam rejeitados.

A classificação de opiniões não dispensa a análise de afirmações factuais presentes no mesmo texto. A fixture `regression-false-fact-as-opinion` cobre essa distinção. Os exemplos adicionais também preservam a rejeição de política explicitamente estrangeira.

Uma amostra sintética não garante acerto em todo texto real, gíria ou evento recente. O modelo não substitui verificação factual. Falhas do provedor e respostas inválidas continuam impedindo a publicação com 503; conteúdo rejeitado retorna 422.

As chamadas foram feitas com a nova chave local. A chave existente no Secret Manager `nvidia-api-key` não foi lida nem alterada. Antes de ativar a migração em produção, um operador autorizado deve validar essa credencial com o Lightning ou configurar a credencial testada. A oferta gratuita da NVIDIA é destinada a prototipagem, conforme suas [condições oficiais](https://docs.api.nvidia.com/nim/docs/product).

## Verificação local

- 650 testes aprovados, 8 ignorados, cobertura global 94,12%.
- Ruff e mypy sem erros.
- No Windows, a execução completa usou `PYTHONUTF8=1` e Poppler (`pdfinfo` e `pdftotext`), equivalente às ferramentas instaladas no CI. Uma comparação de caminhos do teste de fotos foi normalizada com `as_posix()` para preservar a mesma asserção em Windows e Linux.
- Os 8 testes ignorados dependem da configuração PostgreSQL usada pelo CI; não foram apresentados como executados localmente.

## Resultado da configuração final

[Rodada final completa](lightning-schema-final-2026-11-06.json): **76/76 chamadas aprovadas nos critérios de teste**, com 38 casos executados duas vezes. Mediana de 7.285 segundos e máximo de 13.823 segundos. Nenhum timeout, resposta inválida ou decisão divergente foi registrado nessa rodada.

A configuração final usa 1024 tokens de saída total e 512 de raciocínio, além de JSON Schema estrito e do esclarecimento da política. As rodadas anteriores com falhas permanecem documentadas acima; não são contadas como sucessos da configuração final.

Os hashes SHA-256 registrados correspondem aos bytes dos arquivos locais executados; terminações de linha podem variar entre checkouts Windows e Linux.
