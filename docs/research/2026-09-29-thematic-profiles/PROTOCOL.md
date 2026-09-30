# Perfis programáticos nas dez categorias do usuário

## Objetivo e fonte

O usuário solicitou aos **mesmos 13 agentes** documentos sobre as posições políticas dos respectivos planos nas dez categorias de `taxonomy.json`, para depois construir teses com maior diversidade temática. Esta é uma ampliação documental da pesquisa, sem alteração do aplicativo. Pablo Marçal permanece excluído.

Cada responsável continua com o mesmo candidato, Astra/Ultra e o PDF oficial identificado no manifesto da auditoria anterior. Reutilize a leitura integral e seu diário, mas volte às páginas necessárias para conferir cada afirmação. Não é necessário simular outra leitura integral. Registre páginas efetivamente revisitadas nesta rodada. O corpus permanece o snapshot do TSE verificado em 29/09/2026; não acrescente entrevistas, histórico, redes sociais, livro externo ou ideologia partidária.

Use o **plano completo e o diário por página**, não apenas as 16 teses anteriores. O produto é um perfil do que o documento propõe, não um diagnóstico psicológico, um índice de afinidade ou a suposta opinião pessoal da candidatura. Autodefinições ideológicas só podem aparecer atribuídas ao próprio texto e com citação; não inferir rótulos gerais como esquerda/direita ou liberal/conservador.

## Perfil e evidências

- Cubra exatamente as dez categorias com os nomes e limites de `taxonomy.json`. Uma categoria pode ter propostas concretas, apenas objetivos genéricos ou nenhuma decisão identificada. Não é necessário preencher lacunas.
- Extraia as escolhas principais e distintas: em geral 2–4 por categoria quando houver material; use até 6 se necessário para não perder uma decisão importante. Isso é orientação de síntese, não meta mínima ou regra para inflar documentos curtos.
- O reagrupamento editorial entre categorias pode ultrapassar essa orientação sem criar novas posições: registre a exceção, preserve evidências e mantenha contagem única.
- Cada posição deve identificar uma decisão: objeto, instrumento, alcance e condições. Não confunda meta consensual (“melhorar saúde”) com escolha operacional (“contratar atendimento privado para filas”). Diferencie proposta, rejeição expressa, objetivo genérico e inferência lógica clara.
- Cada posição recebe ID exclusivo, uma categoria principal e eventuais referências a categorias secundárias. Não duplique a mesma posição em duas categorias: isso posteriormente duplicaria seu peso.
- Exija trecho literal e página física para toda posição. Não junte fragmentos como citação contínua nem invente reticências. As mesmas normalizações da auditoria anterior são permitidas: espaços e remoção de linhas consecutivas idênticas na extração sobreposta.
- Preserve restrições, grupos atingidos, transições e exceções. Papel futuro de banco público não determina preservação acionária; propriedade estatal não determina integração produtiva; compra de atendimento não determina gestão de unidade; condição sobre valor de benefício não decide substituição por trabalho.
- Registre tensões internas quando houver duas propostas realmente relacionadas. Não as resolva silenciosamente, mas também não chame de contradição uma coexistência ou transição possível.
- Uma tensão pode estar dentro de uma única posição (por exemplo, dois valores conflitantes em passagens sobre a mesma jornada). Nesse caso, cite somente essa posição; não acrescente uma segunda posição sem conflito para preencher o esquema.
- Nos limites de cada categoria, diga o que o documento não detalha. Lacuna de implementação não é posição neutra ou contrária. Registre ausência específica apenas após consultar o diário integral e os contextos pertinentes.

## Sementes de novas teses

Ao final, sugira até **8 teses possíveis**, priorizando decisões relevantes do seu plano que o recorte anterior não representava. Não precisa sugerir uma em toda categoria. Cada tese deve ser curta, neutra, respondível por concordância e discordância, centrada em **uma decisão** e ligada a posições do perfil. “Mais abrangente” significa ampliar temas e comparabilidade; não significa reunir várias políticas na mesma frase.

Indique a resposta que o próprio plano sustenta, as condições que precisam acompanhar a comparação e o contraste a pesquisar nos demais planos. Não invente o que outros candidatos pensam nem declare uma tese pronta ou validada para todos. Metas genéricas desejáveis por todos, pergunta sob medida para uma só candidatura e mera reprodução de número arbitrário não devem ser priorizadas para um questionário de afinidade. Sugestões anteriores podem ser retomadas se continuarem úteis, mas não se limite a elas.

## Arquivos e formato

Escreva somente `profiles/<id>.checkpoint.json`, `profiles/<id>.json` e `profiles/<id>.md` nesta pasta. Pode gerar imagens temporárias no corpus do seu candidato. Não altere auditoria anterior, estado central, taxonomia, outros perfis ou produção. Não faça commit nem delegue. Os resumos Markdown devem ter síntese inicial, dez seções, propostas com IDs/páginas, lacunas/condições, tensões e sementes de teses. Evite retórica promocional.

JSON final:

```json
{
  "schema_version": 1,
  "candidate_id": "ID",
  "candidate_name": "Nome",
  "agent_id": "/root/plan_nome",
  "model_requested": "gpt-6-astra",
  "reasoning_effort_requested": "ultra",
  "document_sha256": "HASH DO PDF",
  "taxonomy_sha256": "HASH DO ARQUIVO taxonomy.json",
  "prior_full_review": "../2026-09-29-full-plan-validation/reviews/ID.json",
  "reading_basis": "prior_full_read_and_contextual_reinspection",
  "revisited_pages": [1],
  "status": "complete",
  "overview": {"text": "Síntese documental", "position_ids": ["P01"]},
  "categories": [
    {
      "id": "economia_desenvolvimento",
      "presence": "substantive",
      "summary": "Síntese fiel da categoria",
      "position_ids": ["P01"],
      "gaps": [{"topic": "Limite ou ausência relevante", "reason": "O que falta decidir", "context_pages": [1]}]
    }
  ],
  "positions": [
    {
      "id": "P01",
      "category_id": "economia_desenvolvimento",
      "secondary_category_ids": [],
      "policy_dimension": "Escolha específica que permitiria comparação",
      "statement": "O plano propõe...",
      "support_level": "explicit_proposal",
      "instrument": "Mecanismo proposto, ou não especificado",
      "scope": "Público, período e alcance identificáveis",
      "conditions": [],
      "evidence": [{"page": 1, "quote": "Trecho literal contínuo"}],
      "context_pages": [1]
    }
  ],
  "tensions": [{"description": "Tensão sem solução imputada", "position_ids": ["P01", "P02"], "interpretation_limit": "O que não pode ser concluído"}],
  "thesis_seeds": [
    {
      "id": "S01",
      "category_id": "economia_desenvolvimento",
      "statement": "Uma decisão normativa neutra.",
      "candidate_response": "CONCORDA",
      "position_ids": ["P01"],
      "necessary_conditions": [],
      "contrast_to_investigate": "Decisão alternativa a buscar, sem atribuí-la a ninguém",
      "why_useful": "Por que a escolha é material e distinta",
      "requires_cross_plan_validation": true
    }
  ],
  "limitations": []
}
```

`presence`: `substantive`, `general_only` ou `not_addressed`. `support_level`: `explicit_proposal`, `explicit_rejection`, `general_goal` ou `clear_implication`. Respostas das sementes: `CONCORDA`, `DISCORDA` ou `CONDICIONAL_OU_MISTA`. Listas de tensões, lacunas e sementes podem ser vazias quando isso refletir o documento; nunca use exemplos do esquema como dados reais. Todas as dez categorias são obrigatórias, e cada posição deve constar na categoria principal exatamente uma vez.

Mantenha checkpoint durante o trabalho com categorias concluídas, páginas revisitadas, decisões e pendências. Execute `python docs/research/2026-09-29-thematic-profiles/validate.py --candidate ID` quando o validador estiver disponível e corrija sua entrega. Ao retornar, informe categorias com material substantivo, quantidade de posições/sementes, principais escolhas recuperadas e limitações. Não despeje o documento inteiro no chat principal.
