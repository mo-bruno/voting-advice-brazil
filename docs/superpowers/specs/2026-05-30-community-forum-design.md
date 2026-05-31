# Fase 3 — Comunidade Anônima com Moderação por IA

**Data:** 2026-05-30
**Branch:** feature/fase-3-community
**Projeto:** Farol Político — Mackenzie 2026-1

---

## Contexto

O Farol Político já entrega quiz de orientação de voto (Fase 1) e rastreamento de políticos em tempo real com IoT (Fase 2). A Fase 3 adiciona uma comunidade pública onde usuários anônimos podem discutir política brasileira. A identidade continua baseada em `device_token` (UUID v4 local), sem PII, mantendo conformidade com a LGPD.

---

## Escopo

### O que está incluído

- Posts de texto livre sobre qualquer tema político brasileiro
- Validação por IA antes da publicação (guardrails de relevância e desinformação)
- Comentários nos posts (sem moderação prévia)
- Sistema de upvote/downvote por post
- Vínculo opcional de post a um político (do tracker existente) ou tema do quiz
- Mensagem explicativa quando um post é rejeitado pela IA

### O que não está incluído

- Moderação humana / painel de administração
- Edição de posts após publicação
- Notificações push de novas respostas
- Denúncia de posts por outros usuários
- Perfis ou histórico público de autor

---

## Arquitetura

Segue o padrão Clean Architecture já estabelecido no projeto:

```
core/
  entities/         Post, Comment, PostVote, ModerationResult
  use_cases/        moderate_and_create_post, list_posts, get_post,
                    create_comment, vote_post
infrastructure/
  database/         PostModel, CommentModel, PostVoteModel, ModerationLogModel
                    repositórios correspondentes
  llm/              ModerationClient (encapsula chamada ao Groq)
api/
  routers/          community.py
  schemas/          PostIn, PostOut, CommentIn, CommentOut, VoteIn
```

`core/` não tem conhecimento de FastAPI, Groq ou SQLAlchemy. `ModerationClient` é injetado via `Depends()` assim como os repositórios.

---

## Banco de Dados

### Migration `0005_community`

**`posts`**
| Coluna | Tipo | Restrições |
|---|---|---|
| `id` | UUID | PK |
| `device_token` | VARCHAR | NOT NULL, FK → `devices.token` |
| `content` | TEXT | NOT NULL, max 500 chars |
| `political_actor_id` | INTEGER | NULL, FK → `political_actors.id` |
| `theme_slug` | VARCHAR | NULL |
| `score` | INTEGER | NOT NULL, default 0 |
| `created_at` | DATETIME | NOT NULL |

**`comments`**
| Coluna | Tipo | Restrições |
|---|---|---|
| `id` | UUID | PK |
| `post_id` | UUID | NOT NULL, FK → `posts.id` |
| `device_token` | VARCHAR | NOT NULL |
| `content` | TEXT | NOT NULL, max 300 chars |
| `created_at` | DATETIME | NOT NULL |

**`post_votes`**
| Coluna | Tipo | Restrições |
|---|---|---|
| `post_id` | UUID | NOT NULL, FK → `posts.id` |
| `device_token` | VARCHAR | NOT NULL |
| `value` | SMALLINT | NOT NULL, +1 ou -1 |
| **PK** | (post_id, device_token) | unique por par |

**`moderation_log`**
| Coluna | Tipo | Restrições |
|---|---|---|
| `id` | INTEGER | PK autoincrement |
| `post_id` | UUID | NULL (se rejeitado, post não existe) |
| `device_token` | VARCHAR | NOT NULL |
| `content_hash` | VARCHAR | NOT NULL (SHA-256 do conteúdo) |
| `approved` | BOOLEAN | NOT NULL |
| `reason` | TEXT | NULL se aprovado |
| `model_used` | VARCHAR | NOT NULL |
| `created_at` | DATETIME | NOT NULL |

---

## Moderação por IA

### Componente: `ModerationClient`

Localização: `app/infrastructure/llm/moderation_client.py`

Responsabilidade única: receber o texto de um post e retornar `ModerationResult(approved: bool, reason: str)`.

**System prompt:**
```
Você é um moderador de conteúdo para uma plataforma de debate político brasileiro.
Avalie o texto do usuário segundo dois critérios:

1. RELEVÂNCIA: O texto trata de política, governo, eleições, legislação, partidos
   ou figuras públicas do Brasil? Textos sobre outros assuntos devem ser rejeitados.

2. INTEGRIDADE: O texto contém afirmações factuais claramente falsas, números
   inventados, ou linguagem deliberadamente manipuladora sobre eventos políticos?

Responda SOMENTE com JSON no formato:
{"approved": true} se o texto passa em ambos os critérios, ou
{"approved": false, "reason": "explicação curta em português para o autor"}

Não inclua nada fora do JSON.
```

**Regras de implementação:**
- Timeout de 10 segundos na chamada ao Groq; se estourar, retorna HTTP 503 com mensagem "Serviço de moderação temporariamente indisponível"
- Temperatura 0 para respostas determinísticas
- Modelo padrão: `llama-3.1-8b-instant` (free tier, baixa latência)
- `reason` tem no máximo 200 caracteres; se o modelo retornar mais, trunca

### Fluxo de `moderate_and_create_post`

```
POST /api/v1/community/posts
        │
        ▼
ModerationClient.moderate(content)
        │
   approved?
   ┌─────┴──────┐
  não           sim
   │             │
HTTP 422        salva Post no banco
{"detail":      grava ModerationLog (approved=True)
 reason}        retorna PostOut (HTTP 201)
   │
grava ModerationLog (approved=False, post_id=None)
```

---

## Endpoints

### `POST /api/v1/community/posts`

**Headers:** `X-Device-Token: <uuid>`
**Body:** `PostIn { content: str, political_actor_id?: int, theme_slug?: str }`
**201:** `PostOut` com post criado
**422:** `{ "detail": "<motivo em português>" }` — post rejeitado pela IA
**503:** moderação indisponível (timeout Groq)

### `GET /api/v1/community/posts`

**Query params:** `page` (default 1), `page_size` (default 20, max 50), `political_actor_id?`, `theme_slug?`
**200:** lista paginada de `PostOut` ordenada por `score DESC, created_at DESC`

### `GET /api/v1/community/posts/{id}`

**200:** `PostDetailOut { post: PostOut, comments: list[CommentOut] }`
**404:** post não encontrado

### `POST /api/v1/community/posts/{id}/votes`

**Headers:** `X-Device-Token: <uuid>`
**Body:** `VoteIn { value: 1 | -1 }`
**200:** `PostOut` com score atualizado
Comportamento: upsert — se o device já votou, troca o voto; score é recalculado como `SUM(value)` dos votos.

### `POST /api/v1/community/posts/{id}/comments`

**Headers:** `X-Device-Token: <uuid>`
**Body:** `CommentIn { content: str }`
**201:** `CommentOut` — sem moderação prévia
**404:** post não encontrado

---

## Mobile (Flutter)

### Novas telas em `mobile/lib/features/community/`

**`community_feed_page.dart`**
- Feed paginado de posts (scroll infinito)
- Filtros: "Todos", "Meus políticos seguidos", por tema do quiz
- Card: conteúdo truncado a 3 linhas, score, contagem de comentários, badge de político/tema se vinculado
- FAB "Novo post"
- Acessível a partir da `home_page`

**`post_detail_page.dart`**
- Post completo com botões +1 / -1 (estado local otimista, confirmado pela API)
- Comentários em ordem cronológica
- Campo de texto inline no rodapé para novo comentário; após envio aparece imediatamente na lista

**`create_post_page.dart`**
- Campo de texto com contador de caracteres (max 500)
- Seletor opcional: busca de político (reusa `PoliticalActorSearchPage`) ou dropdown de temas
- Botão "Publicar" → estado de loading com spinner (IA validando)
- Aprovação: navega para o feed com o post no topo
- Rejeição: exibe card de erro em vermelho com a mensagem da IA, campo permanece editável

**`CommunitySession`** — singleton de estado:
- Cache do feed atual (lista de `PostSummary`)
- Página atual e flag `hasMore` para scroll infinito
- Invalida o cache após criação de post bem-sucedida

---

## Testes

### Backend

**`tests/test_moderate_and_create_post.py`**
- Post aprovado pela `FakeModerationClient` é persistido e retorna 201
- Post rejeitado retorna 422 com a razão da `FakeModerationClient`
- `ModerationLog` é gravado em ambos os casos
- Timeout do Groq resulta em 503

**`tests/test_community_api.py`**
- `GET /posts` retorna lista vazia para banco limpo
- `GET /posts` retorna posts ordenados por score
- `GET /posts/{id}` retorna post com comentários
- `GET /posts/{id}` retorna 404 para id inexistente
- `POST /posts/{id}/comments` salva comentário e retorna 201

**`tests/test_vote_post.py`**
- Upvote incrementa score
- Downvote decrementa score
- Segundo voto do mesmo device substitui o anterior (score não acumula)
- Votos de devices diferentes acumulam corretamente

**`FakeModerationClient`** — implementa a interface `ModerationPort`, configurável para aprovar ou rejeitar com razão pré-definida. Zero chamadas HTTP.

### Mobile

**`community_session_test.dart`** — cache e invalidação após post criado
**`create_post_page_test.dart`** — loading state, exibição da mensagem de rejeição, navegação em aprovação
**`api_client_community_test.dart`** — serialização de `PostIn`, desserialização de `PostOut` e erro 422

---

## Decisões de Design

| Decisão | Escolha | Motivo |
|---|---|---|
| Moderação síncrona vs assíncrona | Síncrona | Feedback imediato; sem canal de notificação para async |
| Moderação de comentários | Sem moderação prévia | Reduz latência; comentários são mais curtos e contextuais |
| Score de post | `SUM(votes.value)` em tempo real | Simples; volume acadêmico não exige cache de contagem |
| Identidade do autor | `device_token` existente | Sem PII, LGPD-compliant, reutiliza infraestrutura |
| Modelo Groq | `llama-3.1-8b-instant` | Baixa latência (~1s), free tier, suficiente para classificação |
| Rejeição por timeout | HTTP 503 | Falha explícita é preferível a publicar conteúdo não moderado |
