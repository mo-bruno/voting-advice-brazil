# Revisão editorial com validação humana

Continuação dos perfis concluídos: mapa comum das decisões e primeiro bloco de afirmações compatíveis com os quatro botões do aplicativo.

- [Documento central](ORCHESTRATION.md): estado do fluxo e limite da aprovação.
- [Bloco 1 para validar](BLOCK_01.md): quatro afirmações, explicações, origens e limites.
- [Revisão política e linguística](EDITORIAL_REVIEW.md): critérios e alterações de redação.
- [Mapa comum](DECISION_MAP.md): famílias de decisões nas dez categorias.
- [Protocolo](PROTOCOL.md): regras de interpretação e aprovação.

Os treze perfis anteriores foram preservados. Três dos agentes originais apenas organizaram os registros existentes em recortes editoriais; não classificaram candidaturas em relação às perguntas deste bloco. A nova rodada de confronto com os planos só começa com as versões aprovadas pelo usuário.

O mapa cobre os 636 registros selecionados no inventário, não todas as frases dos PDFs. As famílias incluem subdecisões que podem exigir perguntas separadas. Número de vínculos ou presença temática não mede afinidade, relevância ou cobertura da mesma redação.

## Reproduzir a conferência

Durante esta etapa, em que todos os itens estão pendentes de aprovação:

```bash
python docs/research/2026-09-29-question-editorial-review/assemble.py
```

O script verifica integridade do inventário, responsáveis, IDs, categorias, inclusão de todos os registros, páginas das origens e ausência de aprovações ou respostas inventadas. Também gera documentos de leitura e hashes de cada versão do texto apresentado. A revisão semântica está descrita em EDITORIAL_REVIEW.md; asserções de estrutura não a substituem.

Não executar essa rotina sem adaptação depois de registrar aprovações: ela exige o estado pendente desta primeira entrega. As futuras decisões do usuário precisam ser preservadas, nunca reinicializadas automaticamente.
