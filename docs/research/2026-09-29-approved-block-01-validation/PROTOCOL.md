# Protocolo comum — B01 v1 aprovado

Cada responsável original revisa SOMENTE o seu plano oficial. Use a leitura integral anterior, o diário e o perfil como índices, pesquise o texto integral com sinônimos e releia trechos e contexto. Não alegue nova leitura integral se não a realizar. O usuário aprovou as quatro versões de `questions.json`, incluindo explicações. Não altere as perguntas. Não consulte outros candidatos, notícias ou reputações para inferir uma resposta. Nenhuma escrita em produção. Pablo Marçal excluído.

## Classificações

- `CONCORDA`: apoio explícito ou implicação clara que responde ao objeto exato.
- `DISCORDA`: rejeição explícita ou implicação clara contrária ao objeto exato.
- `CONDICIONAL_OU_MISTA`: condição ou tensão decisiva que impede um sinal único sobre a redação. Não usar apenas porque existem detalhes de implementação.
- `NAO_ENCONTRADA`: insuficiência documental para atribuir resposta. Nunca converter silêncio em discordância ou neutralidade.

Os botões do eleitor permanecem Concordo, Discordo, Neutro e Pular; estes códigos são de pesquisa, não novos botões. Não inferir diagnóstico, intenção moral ou ideologia. Atribuir as declarações ao plano. Raciocínio de implicação deve ser exposto, sem inventar premissas.

## Delimitações idênticas para todos

Q01 pergunta a existência de imposto específico sobre grandes fortunas. Limiares e alíquotas ficam abertos: um limiar proposto pelo plano pode ser detalhe de desenho, sem impedir concordância. Tributar renda alta, dividendos ou heranças não basta. Outros impostos não provam rejeição.

Q02 pergunta linhas de empréstimo voltadas a setores industriais priorizados pela política pública. Não exige subsídio de juros, dinheiro exclusivamente público, propriedade estatal de bancos ou seleção de firmas individuais. Reduzir certos programas subsidiados não equivale necessariamente a abolir toda linha direcionada. Crédito universal para empresas não prova seleção industrial. Condições e contraprestações devem ser preservadas, mas só mudam o código quando impedem responder ao objeto.

Q03 pergunta participação estrangeira na EXTRAÇÃO de minerais estratégicos; a própria explicação permite condições e limites. Investimento só no processamento não basta. Nacionalizar ativos passados não resolve automaticamente investimentos futuros. Uma proibição geral de capital estrangeiro pode implicar rejeição a esse subconjunto, mas é preciso justificar. Controle estatal dos recursos não exclui sozinho participações ou joint ventures.

Q04 pergunta suspensão dos pagamentos durante uma auditoria, em alcance geral. Auditar, renegociar, reduzir dívida/PIB ou cancelar definitivamente não são equivalentes. Suspensão limitada a grandes investidores não responde sozinha ao alcance geral. Se a suspensão começa antes da auditoria, verificar se permanece durante ela e registrar a sequência. Disciplina fiscal genérica não prova rejeição à suspensão.

## Entrega de cada agente

Escreva apenas `reviews/CID.json`, `reviews/CID.md` e, opcionalmente, `reviews/CID.checkpoint.json`. Não edite arquivos centrais, perguntas, aprovação, originais, perfis, código ou git. Informe conclusão ao orquestrador.

Estrutura JSON obrigatória (todos os quatro itens na ordem aprovada):

```json
{
  "schema_version": 1,
  "candidate_id": "CID",
  "candidate_name": "NOME",
  "agent_id": "/root/plan_original",
  "document_sha256": "SHA",
  "questions_sha256": "SHA do arquivo questions.json",
  "prior_full_read": "../2026-09-29-full-plan-validation/reviews/CID.json",
  "method": "Descrição honesta: diário integral anterior + busca integral + releitura contextual",
  "revisited_pages": [1],
  "full_text_search_completed": true,
  "answers": [
    {
      "question_id": "B01-Q01",
      "question_version": 1,
      "wording_sha256": "SHA da versão aprovada",
      "classification": "NAO_ENCONTRADA",
      "evidence_strength": "insufficient",
      "rationale": "Objeto, instrumento, alcance e razão do código",
      "conditions": [],
      "evidence": [
        {"page": 1, "quote": "Transcrição literal, sem reticências adicionadas", "role": "support", "interpretation": "Conexão ou limite"}
      ],
      "search_terms": ["termos e sinônimos realmente usados"],
      "searched_page_ranges": [[1, 100]],
      "counterevidence_or_limits": "Lacunas, limites, tensão ou trechos relacionados que não bastam",
      "reformulation_suggestion": null
    }
  ]
}
```

`evidence_strength`: `explicit`, `clear_implication`, `mixed` ou `insufficient`. `role`: `support`, `opposition`, `condition`, `context`, `counterevidence`. Citações em páginas físicas do PDF, base 1; se atravessam páginas, separar entradas. Deve haver evidência para qualquer código diferente de NAO_ENCONTRADA. Ausência pode ter citações de contexto, mas elas não são prova do silêncio integral. `searched_page_ranges` indica busca no documento completo; `revisited_pages` apenas páginas efetivamente relidas. Proposta de reformulação, se necessária: objeto com `proposed_statement`, `reason`, `meaning_change: true`; não classificar essa alternativa. MD deve resumir as quatro decisões com referências e limites.

O orquestrador verificará citações/hash e fará adjudicação sem sobrescrever a avaliação original. Mudanças de sentido exigem nova aprovação do usuário e nova distribuição da mesma versão a todos os treze.
