# Protocolo comum — bateria completa aprovada

Cada responsável valida somente um plano oficial contra as vinte afirmações aprovadas em `questions.json`. O plano foi lido integralmente na rodada anterior; o agente deve recuperar seu perfil, checkpoint e parecer integral anteriores, pesquisar novamente o texto completo com termos e sinônimos adequados a cada tese e reler todas as páginas usadas como evidência.

Não altere as afirmações. Não consulte posições públicas, entrevistas, notícias, reputação, partido ou outros candidatos. Não derive uma resposta de rótulos ideológicos. A única fonte para a classificação é o plano oficial identificado pelo hash registrado em `STATE.json`.

## Classificações

- `CONCORDA`: apoio explícito ou implicação clara que responde ao objeto exato.
- `DISCORDA`: rejeição explícita ou implicação clara contrária ao objeto exato.
- `CONDICIONAL_OU_MISTA`: condição, recorte ou tensão decisiva impede um sinal único para a redação aprovada.
- `NAO_ENCONTRADA`: o plano não oferece base suficiente para atribuir uma resposta.

Silêncio nunca significa neutralidade, discordância ou concordância. Propostas apenas relacionadas tematicamente não respondem automaticamente à tese. Diagnóstico, finalidade, instrumento, público, alcance e condições devem coincidir o bastante para sustentar a classificação.

Os botões do eleitor continuam `Concordo`, `Discordo`, `Neutro` e `Pular`. Os quatro códigos acima pertencem à pesquisa documental e não criam novos botões.

## Leitura das perguntas

A afirmação e a explicação formam uma única versão aprovada. `decision_object` resume o objeto medido. `measurement_risks` informa limites editoriais, mas não autoriza ampliar o significado. Quando uma condição do plano for apenas detalhe de implementação, registre-a sem transformar automaticamente a resposta em mista. Use `CONDICIONAL_OU_MISTA` somente quando a condição mudar a resposta ao objeto aprovado.

Para as três versões 2:

- `FB-Q07` pergunta se a lei deve admitir demissão por baixo desempenho comprovado, com avaliação periódica e defesa; avaliar desempenho sem consequência de demissão não basta.
- `FB-Q08` pergunta por financiamento federal destinado à gratuidade universal do transporte coletivo urbano municipal; tarifa zero sem participação federal ou subsídio focalizado não responde integralmente.
- `FB-Q17` pergunta pela existência de algum prazo gestacional de descriminalização do aborto voluntário; exceções já previstas em lei ou atendimento médico sem decisão penal geral não bastam.

## Contexto obrigatório de cada plano

Antes de classificar, leia os quatro arquivos indicados em `STATE.json` para o candidato: perfil JSON, perfil legível, checkpoint e parecer da leitura integral anterior. Depois use `raw.txt`, `layout.txt`, `raw-pages.json` e `layout-pages.json` do corpus oficial para a busca e a releitura. O contexto anterior é índice; a citação literal e sua página devem ser reconfirmadas no corpus.

## Entrega individual

Escreva somente `reviews/CID.json`, `reviews/CID.md` e, se necessário, `reviews/CID.checkpoint.json`. Não edite perguntas, aprovação, estado central, perfis, pareceres anteriores, código ou Git.

O JSON deve conter:

```json
{
  "schema_version": 1,
  "candidate_id": "CID",
  "candidate_name": "NOME",
  "context_owner_agent_id": "/root/plan_original",
  "executor_agent_id": "/root/plan_original_ou_reidratado",
  "document_sha256": "SHA",
  "questions_sha256": "SHA de questions.json",
  "prior_context_files": ["quatro caminhos de STATE.json"],
  "method": "Descrição honesta da recuperação de contexto, busca integral e releitura",
  "revisited_pages": [1],
  "full_text_search_completed": true,
  "answers": [
    {
      "question_id": "B01-Q01",
      "question_version": 1,
      "wording_sha256": "SHA aprovado",
      "classification": "NAO_ENCONTRADA",
      "evidence_strength": "insufficient",
      "rationale": "Conexão exata entre plano e objeto ou razão da insuficiência",
      "conditions": [],
      "evidence": [
        {
          "page": 1,
          "quote": "Transcrição literal sem reticências inventadas",
          "role": "context",
          "interpretation": "O que o trecho prova e o que não prova"
        }
      ],
      "search_terms": ["termos efetivamente pesquisados"],
      "searched_page_ranges": [[1, 100]],
      "counterevidence_or_limits": "Lacunas e trechos relacionados insuficientes",
      "reformulation_suggestion": null
    }
  ]
}
```

São obrigatórias exatamente vinte respostas na ordem de `questions.json`. `evidence_strength` aceita `explicit`, `clear_implication`, `mixed` ou `insufficient`. `role` aceita `support`, `opposition`, `condition`, `context` ou `counterevidence`. Toda classificação diferente de `NAO_ENCONTRADA` precisa de citação literal. As faixas de busca devem cobrir todas as páginas físicas do PDF. Propostas de reformulação ficam separadas em `reformulation_suggestion`, sempre com `meaning_change: true`; o agente não classifica a redação alternativa.
