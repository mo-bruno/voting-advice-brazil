# Comunidade Anônima — Fase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar fórum anônimo com posts políticos, moderação síncrona por IA (Groq), upvote/downvote, comentários e 3 telas Flutter.

**Architecture:** Clean Architecture existente — entidades em `core/entities/`, use cases em `core/use_cases/`, repositórios SQL em `infrastructure/database/`, router FastAPI em `api/routers/`. A moderação é síncrona: o Groq valida antes de salvar o post; comentários são salvos direto.

**Tech Stack:** Python 3.12, FastAPI, SQLAlchemy 2.0, Alembic, Groq API (llama-3.1-8b-instant), Flutter/Dart, pytest

**Spec:** `docs/superpowers/specs/2026-05-30-community-forum-design.md`

---

## Contexto de codebase relevante

- Entidades: frozen dataclasses em `app/core/entities/`
- Use cases: funções puras com repositórios injetados em `app/core/use_cases/`
- Interfaces dos repositórios: `app/core/use_cases/interfaces.py`
- Modelos SQLAlchemy 2.0 com `Mapped`: todos em `app/infrastructure/database/models.py`
- Repositórios SQL: arquivos separados por domínio em `app/infrastructure/database/`
- Deps FastAPI: `app/api/deps.py`
- Registro de routers: `app/main.py` com `app.include_router(router, prefix="/api/v1")`
- Header de identidade: `X-Farol-Anonymous-Id` → `anonymous_id` (não `device_token`)
- Migrations Alembic: `alembic/versions/`, última é `0004_iot_events`
- Testes: pytest com fakes (sem mocks de framework), fixtures em `conftest.py`
- Settings: `app/core/config.py` com `settings.groq_api_key`

---

## Task 1: Entidades do domínio + Interfaces de repositório

**Files:**
- Create: `backend/app/core/entities/community.py`
- Modify: `backend/app/core/use_cases/interfaces.py`

- [ ] **Step 1: Criar `community.py` com entidades**

```python
# backend/app/core/entities/community.py
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Post:
    id: str
    anonymous_id: str
    content: str
    political_actor_id: int | None
    theme_slug: str | None
    score: int
    created_at: datetime


@dataclass(frozen=True)
class Comment:
    id: str
    post_id: str
    anonymous_id: str
    content: str
    created_at: datetime


@dataclass(frozen=True)
class PostVote:
    post_id: str
    anonymous_id: str
    value: int  # +1 ou -1


@dataclass(frozen=True)
class ModerationResult:
    approved: bool
    reason: str  # string vazia se aprovado
    model_used: str
```

- [ ] **Step 2: Adicionar interfaces ao `interfaces.py`**

Abra `backend/app/core/use_cases/interfaces.py` e acrescente ao final (após os imports existentes de `ABC`, `abstractmethod` já presentes no arquivo):

```python
# Acrescentar ao final de interfaces.py

class PostRepository(ABC):
    @abstractmethod
    def create(self, post: "Post") -> "Post": ...

    @abstractmethod
    def get_by_id(self, post_id: str) -> "Post | None": ...

    @abstractmethod
    def list(
        self,
        page: int = 1,
        page_size: int = 20,
        political_actor_id: int | None = None,
        theme_slug: str | None = None,
    ) -> "tuple[list[Post], int]": ...

    @abstractmethod
    def update_score(self, post_id: str, new_score: int) -> None: ...


class CommentRepository(ABC):
    @abstractmethod
    def create(self, comment: "Comment") -> "Comment": ...

    @abstractmethod
    def list_by_post(self, post_id: str) -> "list[Comment]": ...


class PostVoteRepository(ABC):
    @abstractmethod
    def upsert(self, vote: "PostVote") -> int: ...  # retorna novo score

    @abstractmethod
    def get(self, post_id: str, anonymous_id: str) -> "PostVote | None": ...


class ModerationLogRepository(ABC):
    @abstractmethod
    def record(
        self,
        post_id: str | None,
        anonymous_id: str,
        content_hash: str,
        approved: bool,
        reason: str | None,
        model_used: str,
    ) -> None: ...
```

Adicionar os imports necessários no topo de `interfaces.py` (verifique se já existem antes de adicionar):
```python
from app.core.entities.community import Comment, Post, PostVote
```

- [ ] **Step 3: Commit**

```bash
cd backend
git add app/core/entities/community.py app/core/use_cases/interfaces.py
git commit -m "feat(community): entidades Post/Comment/PostVote/ModerationResult e interfaces de repositório"
```

---

## Task 2: Migration 0005_community + SQLAlchemy Models

**Files:**
- Create: `backend/alembic/versions/0005_community.py`
- Modify: `backend/app/infrastructure/database/models.py`

- [ ] **Step 1: Adicionar modelos SQLAlchemy em `models.py`**

Abra `backend/app/infrastructure/database/models.py`. Adicione os imports necessários no bloco de imports existente:

```python
from sqlalchemy import Boolean, SmallInteger  # acrescentar ao import existente de sqlalchemy
```

Adicione os quatro modelos ao final do arquivo (após os modelos existentes):

```python
class PostModel(Base):
    __tablename__ = "posts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    anonymous_id: Mapped[str] = mapped_column(String(64), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    political_actor_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("political_actors.id", ondelete="SET NULL"), nullable=True
    )
    theme_slug: Mapped[str | None] = mapped_column(String(64), nullable=True)
    score: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    comments: Mapped[list["CommentModel"]] = relationship(
        back_populates="post", cascade="all, delete-orphan"
    )
    votes: Mapped[list["PostVoteModel"]] = relationship(
        back_populates="post", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("ix_posts_anonymous_id", "anonymous_id"),
        Index("ix_posts_score_created", "score", "created_at"),
        Index("ix_posts_actor_id", "political_actor_id"),
    )


class CommentModel(Base):
    __tablename__ = "comments"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    post_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False
    )
    anonymous_id: Mapped[str] = mapped_column(String(64), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    post: Mapped["PostModel"] = relationship(back_populates="comments")

    __table_args__ = (Index("ix_comments_post_id", "post_id"),)


class PostVoteModel(Base):
    __tablename__ = "post_votes"

    post_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("posts.id", ondelete="CASCADE"), primary_key=True
    )
    anonymous_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    value: Mapped[int] = mapped_column(SmallInteger, nullable=False)

    post: Mapped["PostModel"] = relationship(back_populates="votes")


class ModerationLogModel(Base):
    __tablename__ = "moderation_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    post_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    anonymous_id: Mapped[str] = mapped_column(String(64), nullable=False)
    content_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    approved: Mapped[bool] = mapped_column(Boolean, nullable=False)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    model_used: Mapped[str] = mapped_column(String(128), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    __table_args__ = (Index("ix_moderation_log_post_id", "post_id"),)
```

- [ ] **Step 2: Criar migration `0005_community.py`**

```python
# backend/alembic/versions/0005_community.py
"""community_forum

Revision ID: 0005_community
Revises: 0004_iot_events
Create Date: 2026-05-30 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0005_community"
down_revision: Union[str, Sequence[str], None] = "0004_iot_events"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "posts",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("political_actor_id", sa.Integer(), nullable=True),
        sa.Column("theme_slug", sa.String(length=64), nullable=True),
        sa.Column("score", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["political_actor_id"],
            ["political_actors.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("posts") as batch_op:
        batch_op.create_index("ix_posts_anonymous_id", ["anonymous_id"])
        batch_op.create_index("ix_posts_score_created", ["score", "created_at"])
        batch_op.create_index("ix_posts_actor_id", ["political_actor_id"])

    op.create_table(
        "comments",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("post_id", sa.String(length=36), nullable=False),
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["post_id"], ["posts.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("comments") as batch_op:
        batch_op.create_index("ix_comments_post_id", ["post_id"])

    op.create_table(
        "post_votes",
        sa.Column("post_id", sa.String(length=36), nullable=False),
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("value", sa.SmallInteger(), nullable=False),
        sa.ForeignKeyConstraint(["post_id"], ["posts.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("post_id", "anonymous_id"),
    )

    op.create_table(
        "moderation_log",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("post_id", sa.String(length=36), nullable=True),
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("content_hash", sa.String(length=64), nullable=False),
        sa.Column("approved", sa.Boolean(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("model_used", sa.String(length=128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("moderation_log") as batch_op:
        batch_op.create_index("ix_moderation_log_post_id", ["post_id"])


def downgrade() -> None:
    op.drop_table("moderation_log")
    op.drop_table("post_votes")
    with op.batch_alter_table("comments") as batch_op:
        batch_op.drop_index("ix_comments_post_id")
    op.drop_table("comments")
    with op.batch_alter_table("posts") as batch_op:
        batch_op.drop_index("ix_posts_actor_id")
        batch_op.drop_index("ix_posts_score_created")
        batch_op.drop_index("ix_posts_anonymous_id")
    op.drop_table("posts")
```

- [ ] **Step 3: Aplicar migration e verificar**

```bash
cd backend
uv run alembic upgrade head
```

Esperado: `Running upgrade 0004_iot_events -> 0005_community, community_forum`

- [ ] **Step 4: Commit**

```bash
git add app/infrastructure/database/models.py alembic/versions/0005_community.py
git commit -m "feat(community): migration 0005 e modelos SQLAlchemy Post/Comment/PostVote/ModerationLog"
```

---

## Task 3: Repositórios SQL

**Files:**
- Create: `backend/app/infrastructure/database/community_repositories.py`

- [ ] **Step 1: Escrever teste de repositório que falha**

```python
# backend/tests/test_community_repositories.py
from datetime import datetime, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.infrastructure.database.models import Base
from app.infrastructure.database.community_repositories import (
    SqlPostRepository,
    SqlCommentRepository,
    SqlPostVoteRepository,
    SqlModerationLogRepository,
)
from app.core.entities.community import Post, Comment, PostVote


@pytest.fixture()
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    with Session() as session:
        yield session


def _make_post(**kwargs) -> Post:
    defaults = dict(
        id="post-1",
        anonymous_id="anon-1",
        content="Texto político válido",
        political_actor_id=None,
        theme_slug=None,
        score=0,
        created_at=datetime.now(timezone.utc),
    )
    defaults.update(kwargs)
    return Post(**defaults)


def test_post_create_and_get(db):
    repo = SqlPostRepository(db)
    post = _make_post()
    saved = repo.create(post)
    assert saved.id == "post-1"
    fetched = repo.get_by_id("post-1")
    assert fetched is not None
    assert fetched.content == "Texto político válido"


def test_post_get_returns_none_for_unknown(db):
    repo = SqlPostRepository(db)
    assert repo.get_by_id("nope") is None


def test_post_list_pagination(db):
    repo = SqlPostRepository(db)
    for i in range(3):
        repo.create(_make_post(id=f"post-{i}", anonymous_id="anon-1"))
    posts, total = repo.list(page=1, page_size=2)
    assert total == 3
    assert len(posts) == 2


def test_post_update_score(db):
    repo = SqlPostRepository(db)
    repo.create(_make_post())
    repo.update_score("post-1", 5)
    fetched = repo.get_by_id("post-1")
    assert fetched.score == 5


def test_comment_create_and_list(db):
    post_repo = SqlPostRepository(db)
    post_repo.create(_make_post())
    comment_repo = SqlCommentRepository(db)
    comment = Comment(
        id="c-1",
        post_id="post-1",
        anonymous_id="anon-1",
        content="Comentário",
        created_at=datetime.now(timezone.utc),
    )
    saved = comment_repo.create(comment)
    assert saved.id == "c-1"
    comments = comment_repo.list_by_post("post-1")
    assert len(comments) == 1


def test_vote_upsert_returns_score(db):
    post_repo = SqlPostRepository(db)
    post_repo.create(_make_post())
    vote_repo = SqlPostVoteRepository(db)
    score = vote_repo.upsert(PostVote(post_id="post-1", anonymous_id="anon-1", value=1))
    assert score == 1


def test_vote_upsert_replaces_previous(db):
    post_repo = SqlPostRepository(db)
    post_repo.create(_make_post())
    vote_repo = SqlPostVoteRepository(db)
    vote_repo.upsert(PostVote(post_id="post-1", anonymous_id="anon-1", value=1))
    score = vote_repo.upsert(PostVote(post_id="post-1", anonymous_id="anon-1", value=-1))
    assert score == -1


def test_vote_two_users(db):
    post_repo = SqlPostRepository(db)
    post_repo.create(_make_post())
    vote_repo = SqlPostVoteRepository(db)
    vote_repo.upsert(PostVote(post_id="post-1", anonymous_id="anon-1", value=1))
    score = vote_repo.upsert(PostVote(post_id="post-1", anonymous_id="anon-2", value=1))
    assert score == 2


def test_moderation_log_record(db):
    log_repo = SqlModerationLogRepository(db)
    log_repo.record(
        post_id="post-1",
        anonymous_id="anon-1",
        content_hash="abc123",
        approved=True,
        reason=None,
        model_used="fake",
    )
    # sem erro = ok
```

- [ ] **Step 2: Rodar para confirmar falha**

```bash
cd backend
uv run pytest tests/test_community_repositories.py -v
```

Esperado: `ERROR` ou `ImportError` — `community_repositories` não existe.

- [ ] **Step 3: Implementar `community_repositories.py`**

```python
# backend/app/infrastructure/database/community_repositories.py
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from app.core.entities.community import Comment, Post, PostVote
from app.core.use_cases.interfaces import (
    CommentRepository,
    ModerationLogRepository,
    PostRepository,
    PostVoteRepository,
)
from app.infrastructure.database.models import (
    CommentModel,
    ModerationLogModel,
    PostModel,
    PostVoteModel,
)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _to_post(m: PostModel) -> Post:
    return Post(
        id=m.id,
        anonymous_id=m.anonymous_id,
        content=m.content,
        political_actor_id=m.political_actor_id,
        theme_slug=m.theme_slug,
        score=m.score,
        created_at=m.created_at,
    )


def _to_comment(m: CommentModel) -> Comment:
    return Comment(
        id=m.id,
        post_id=m.post_id,
        anonymous_id=m.anonymous_id,
        content=m.content,
        created_at=m.created_at,
    )


class SqlPostRepository(PostRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def create(self, post: Post) -> Post:
        model = PostModel(
            id=post.id,
            anonymous_id=post.anonymous_id,
            content=post.content,
            political_actor_id=post.political_actor_id,
            theme_slug=post.theme_slug,
            score=post.score,
            created_at=post.created_at,
        )
        self._db.add(model)
        self._db.commit()
        self._db.refresh(model)
        return _to_post(model)

    def get_by_id(self, post_id: str) -> Post | None:
        model = self._db.get(PostModel, post_id)
        return _to_post(model) if model else None

    def list(
        self,
        page: int = 1,
        page_size: int = 20,
        political_actor_id: int | None = None,
        theme_slug: str | None = None,
    ) -> tuple[list[Post], int]:
        stmt = select(PostModel)
        if political_actor_id is not None:
            stmt = stmt.where(PostModel.political_actor_id == political_actor_id)
        if theme_slug is not None:
            stmt = stmt.where(PostModel.theme_slug == theme_slug)
        stmt = stmt.order_by(PostModel.score.desc(), PostModel.created_at.desc())
        total = self._db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        offset = (page - 1) * page_size
        rows = self._db.execute(stmt.offset(offset).limit(page_size)).scalars().all()
        return [_to_post(r) for r in rows], total

    def update_score(self, post_id: str, new_score: int) -> None:
        model = self._db.get(PostModel, post_id)
        if model:
            model.score = new_score
            self._db.commit()


class SqlCommentRepository(CommentRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def create(self, comment: Comment) -> Comment:
        model = CommentModel(
            id=comment.id,
            post_id=comment.post_id,
            anonymous_id=comment.anonymous_id,
            content=comment.content,
            created_at=comment.created_at,
        )
        self._db.add(model)
        self._db.commit()
        self._db.refresh(model)
        return _to_comment(model)

    def list_by_post(self, post_id: str) -> list[Comment]:
        rows = (
            self._db.execute(
                select(CommentModel)
                .where(CommentModel.post_id == post_id)
                .order_by(CommentModel.created_at)
            )
            .scalars()
            .all()
        )
        return [_to_comment(r) for r in rows]


class SqlPostVoteRepository(PostVoteRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def upsert(self, vote: PostVote) -> int:
        stmt = sqlite_insert(PostVoteModel).values(
            post_id=vote.post_id,
            anonymous_id=vote.anonymous_id,
            value=vote.value,
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=["post_id", "anonymous_id"],
            set_={"value": vote.value},
        )
        self._db.execute(stmt)
        self._db.commit()
        score = (
            self._db.scalar(
                select(func.sum(PostVoteModel.value)).where(
                    PostVoteModel.post_id == vote.post_id
                )
            )
            or 0
        )
        return int(score)

    def get(self, post_id: str, anonymous_id: str) -> PostVote | None:
        model = self._db.get(PostVoteModel, (post_id, anonymous_id))
        if model is None:
            return None
        return PostVote(
            post_id=model.post_id,
            anonymous_id=model.anonymous_id,
            value=model.value,
        )


class SqlModerationLogRepository(ModerationLogRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def record(
        self,
        post_id: str | None,
        anonymous_id: str,
        content_hash: str,
        approved: bool,
        reason: str | None,
        model_used: str,
    ) -> None:
        entry = ModerationLogModel(
            post_id=post_id,
            anonymous_id=anonymous_id,
            content_hash=content_hash,
            approved=approved,
            reason=reason,
            model_used=model_used,
            created_at=_utcnow(),
        )
        self._db.add(entry)
        self._db.commit()
```

- [ ] **Step 4: Rodar testes**

```bash
uv run pytest tests/test_community_repositories.py -v
```

Esperado: todos os testes passando.

- [ ] **Step 5: Commit**

```bash
git add app/infrastructure/database/community_repositories.py tests/test_community_repositories.py
git commit -m "feat(community): repositórios SQL Post/Comment/PostVote/ModerationLog com testes"
```

---

## Task 4: ModerationClient (Groq)

**Files:**
- Create: `backend/app/infrastructure/llm/__init__.py`
- Create: `backend/app/infrastructure/llm/moderation_client.py`

- [ ] **Step 1: Criar `__init__.py` e `moderation_client.py`**

```python
# backend/app/infrastructure/llm/__init__.py
```

```python
# backend/app/infrastructure/llm/moderation_client.py
import hashlib
import json
from abc import ABC, abstractmethod

import httpx

from app.core.entities.community import ModerationResult

_SYSTEM_PROMPT = """Você é um moderador de conteúdo para uma plataforma de debate político brasileiro.
Avalie o texto do usuário segundo dois critérios:

1. RELEVÂNCIA: O texto trata de política, governo, eleições, legislação, partidos
   ou figuras públicas do Brasil? Textos sobre outros assuntos devem ser rejeitados.

2. INTEGRIDADE: O texto contém afirmações factuais claramente falsas, números
   inventados, ou linguagem deliberadamente manipuladora sobre eventos políticos?

Responda SOMENTE com JSON, sem markdown, sem texto fora do JSON:
{"approved": true} se o texto passa em ambos os critérios, ou
{"approved": false, "reason": "explicação curta em português para o autor (máx 200 chars)"}"""

_GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
_TIMEOUT = 10.0


class ModerationPort(ABC):
    @abstractmethod
    def moderate(self, content: str) -> ModerationResult: ...


class GroqModerationClient(ModerationPort):
    def __init__(self, api_key: str, model: str = "llama-3.1-8b-instant") -> None:
        self._api_key = api_key
        self._model = model

    def moderate(self, content: str) -> ModerationResult:
        payload = {
            "model": self._model,
            "temperature": 0,
            "messages": [
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": content[:1000]},
            ],
        }
        try:
            resp = httpx.post(
                _GROQ_URL,
                json=payload,
                headers={"Authorization": f"Bearer {self._api_key}"},
                timeout=_TIMEOUT,
            )
            resp.raise_for_status()
        except (httpx.TimeoutException, httpx.HTTPStatusError) as exc:
            raise ModerationUnavailable("Groq indisponível") from exc

        raw = resp.json()["choices"][0]["message"]["content"].strip()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ModerationUnavailable("Resposta inválida do modelo") from exc

        approved = bool(data.get("approved", False))
        reason = str(data.get("reason", ""))[:200]
        return ModerationResult(approved=approved, reason=reason, model_used=self._model)


class FakeModerationClient(ModerationPort):
    """Fake para testes — zero chamadas HTTP."""

    def __init__(self, approved: bool = True, reason: str = "") -> None:
        self._approved = approved
        self._reason = reason

    def moderate(self, content: str) -> ModerationResult:
        return ModerationResult(
            approved=self._approved,
            reason=self._reason,
            model_used="fake",
        )


class ModerationUnavailable(Exception):
    """Raised when Groq is unreachable or returns an unparseable response."""
```

- [ ] **Step 2: Testar FakeModerationClient diretamente**

```bash
uv run python -c "
from app.infrastructure.llm.moderation_client import FakeModerationClient
c = FakeModerationClient(approved=True)
r = c.moderate('teste')
assert r.approved is True
assert r.model_used == 'fake'
print('ok')
"
```

Esperado: `ok`

- [ ] **Step 3: Commit**

```bash
git add app/infrastructure/llm/ 
git commit -m "feat(community): ModerationClient Groq + FakeModerationClient para testes"
```

---

## Task 5: Use cases de comunidade

**Files:**
- Create: `backend/app/core/use_cases/moderate_and_create_post.py`
- Create: `backend/app/core/use_cases/list_posts.py`
- Create: `backend/app/core/use_cases/get_post.py`
- Create: `backend/app/core/use_cases/create_comment.py`
- Create: `backend/app/core/use_cases/vote_post.py`
- Create: `backend/tests/test_community_use_cases.py`

- [ ] **Step 1: Escrever testes dos use cases**

```python
# backend/tests/test_community_use_cases.py
from datetime import datetime, timezone
import pytest

from app.core.entities.community import Comment, Post, PostVote
from app.infrastructure.llm.moderation_client import FakeModerationClient


# ──── Fakes de repositório ────

class FakePostRepository:
    def __init__(self):
        self._store: dict[str, Post] = {}

    def create(self, post: Post) -> Post:
        self._store[post.id] = post
        return post

    def get_by_id(self, post_id: str) -> Post | None:
        return self._store.get(post_id)

    def list(self, page=1, page_size=20, political_actor_id=None, theme_slug=None):
        posts = list(self._store.values())
        return posts, len(posts)

    def update_score(self, post_id: str, new_score: int) -> None:
        p = self._store[post_id]
        self._store[post_id] = Post(
            id=p.id, anonymous_id=p.anonymous_id, content=p.content,
            political_actor_id=p.political_actor_id, theme_slug=p.theme_slug,
            score=new_score, created_at=p.created_at,
        )


class FakeCommentRepository:
    def __init__(self):
        self._store: list[Comment] = []

    def create(self, comment: Comment) -> Comment:
        self._store.append(comment)
        return comment

    def list_by_post(self, post_id: str) -> list[Comment]:
        return [c for c in self._store if c.post_id == post_id]


class FakeVoteRepository:
    def __init__(self):
        self._store: dict[tuple, PostVote] = {}

    def upsert(self, vote: PostVote) -> int:
        self._store[(vote.post_id, vote.anonymous_id)] = vote
        return sum(v.value for v in self._store.values() if v.post_id == vote.post_id)

    def get(self, post_id: str, anonymous_id: str) -> PostVote | None:
        return self._store.get((post_id, anonymous_id))


class FakeModerationLogRepository:
    def __init__(self):
        self.records: list[dict] = []

    def record(self, post_id, anonymous_id, content_hash, approved, reason, model_used):
        self.records.append(dict(
            post_id=post_id, anonymous_id=anonymous_id,
            approved=approved, reason=reason,
        ))


# ──── moderate_and_create_post ────

def test_approved_post_is_saved():
    from app.core.use_cases.moderate_and_create_post import moderate_and_create_post
    post_repo = FakePostRepository()
    log_repo = FakeModerationLogRepository()
    moderator = FakeModerationClient(approved=True)

    post, result = moderate_and_create_post(
        post_repo, log_repo, moderator,
        anonymous_id="anon-1",
        content="PT votou contra a PEC da reforma administrativa",
    )

    assert post is not None
    assert result.approved is True
    assert len(log_repo.records) == 1
    assert log_repo.records[0]["approved"] is True
    assert log_repo.records[0]["post_id"] == post.id


def test_rejected_post_not_saved():
    from app.core.use_cases.moderate_and_create_post import moderate_and_create_post
    post_repo = FakePostRepository()
    log_repo = FakeModerationLogRepository()
    moderator = FakeModerationClient(approved=False, reason="Conteúdo fora do tema político")

    post, result = moderate_and_create_post(
        post_repo, log_repo, moderator,
        anonymous_id="anon-1",
        content="Receita de bolo de cenoura",
    )

    assert post is None
    assert result.approved is False
    assert result.reason == "Conteúdo fora do tema político"
    assert log_repo.records[0]["post_id"] is None


# ──── list_posts ────

def test_list_posts_returns_all():
    from app.core.use_cases.list_posts import list_posts
    repo = FakePostRepository()
    now = datetime.now(timezone.utc)
    repo.create(Post(id="p1", anonymous_id="a", content="x", political_actor_id=None,
                     theme_slug=None, score=0, created_at=now))
    posts, total = list_posts(repo)
    assert total == 1
    assert posts[0].id == "p1"


# ──── get_post ────

def test_get_post_with_comments():
    from app.core.use_cases.get_post import get_post
    post_repo = FakePostRepository()
    comment_repo = FakeCommentRepository()
    now = datetime.now(timezone.utc)
    post_repo.create(Post(id="p1", anonymous_id="a", content="x", political_actor_id=None,
                          theme_slug=None, score=0, created_at=now))
    comment_repo.create(Comment(id="c1", post_id="p1", anonymous_id="a",
                                content="ótimo post", created_at=now))
    result = get_post(post_repo, comment_repo, "p1")
    assert result is not None
    post, comments = result
    assert post.id == "p1"
    assert len(comments) == 1


def test_get_post_returns_none_if_missing():
    from app.core.use_cases.get_post import get_post
    result = get_post(FakePostRepository(), FakeCommentRepository(), "nope")
    assert result is None


# ──── create_comment ────

def test_create_comment_saved():
    from app.core.use_cases.create_comment import create_comment
    post_repo = FakePostRepository()
    comment_repo = FakeCommentRepository()
    now = datetime.now(timezone.utc)
    post_repo.create(Post(id="p1", anonymous_id="a", content="x", political_actor_id=None,
                          theme_slug=None, score=0, created_at=now))
    comment = create_comment(post_repo, comment_repo, "p1", "anon-2", "boa observação")
    assert comment is not None
    assert comment.content == "boa observação"


def test_create_comment_returns_none_if_post_missing():
    from app.core.use_cases.create_comment import create_comment
    result = create_comment(FakePostRepository(), FakeCommentRepository(), "nope", "anon", "x")
    assert result is None


# ──── vote_post ────

def test_upvote_increases_score():
    from app.core.use_cases.vote_post import vote_post
    post_repo = FakePostRepository()
    vote_repo = FakeVoteRepository()
    now = datetime.now(timezone.utc)
    post_repo.create(Post(id="p1", anonymous_id="a", content="x", political_actor_id=None,
                          theme_slug=None, score=0, created_at=now))
    updated = vote_post(post_repo, vote_repo, "p1", "anon-1", 1)
    assert updated is not None
    assert updated.score == 1


def test_vote_replaces_previous():
    from app.core.use_cases.vote_post import vote_post
    post_repo = FakePostRepository()
    vote_repo = FakeVoteRepository()
    now = datetime.now(timezone.utc)
    post_repo.create(Post(id="p1", anonymous_id="a", content="x", political_actor_id=None,
                          theme_slug=None, score=0, created_at=now))
    vote_post(post_repo, vote_repo, "p1", "anon-1", 1)
    updated = vote_post(post_repo, vote_repo, "p1", "anon-1", -1)
    assert updated.score == -1


def test_vote_returns_none_if_post_missing():
    from app.core.use_cases.vote_post import vote_post
    result = vote_post(FakePostRepository(), FakeVoteRepository(), "nope", "anon", 1)
    assert result is None
```

- [ ] **Step 2: Rodar para confirmar falha**

```bash
uv run pytest tests/test_community_use_cases.py -v
```

Esperado: `ImportError` — módulos não existem ainda.

- [ ] **Step 3: Implementar os 5 use cases**

```python
# backend/app/core/use_cases/moderate_and_create_post.py
import hashlib
import uuid
from datetime import datetime, timezone

from app.core.entities.community import ModerationResult, Post
from app.core.use_cases.interfaces import ModerationLogRepository, PostRepository
from app.infrastructure.llm.moderation_client import ModerationPort


def moderate_and_create_post(
    post_repo: PostRepository,
    log_repo: ModerationLogRepository,
    moderation_client: ModerationPort,
    anonymous_id: str,
    content: str,
    political_actor_id: int | None = None,
    theme_slug: str | None = None,
) -> tuple[Post | None, ModerationResult]:
    result = moderation_client.moderate(content)
    content_hash = hashlib.sha256(content.encode()).hexdigest()

    if not result.approved:
        log_repo.record(
            post_id=None,
            anonymous_id=anonymous_id,
            content_hash=content_hash,
            approved=False,
            reason=result.reason,
            model_used=result.model_used,
        )
        return None, result

    post = Post(
        id=str(uuid.uuid4()),
        anonymous_id=anonymous_id,
        content=content,
        political_actor_id=political_actor_id,
        theme_slug=theme_slug,
        score=0,
        created_at=datetime.now(timezone.utc),
    )
    saved = post_repo.create(post)
    log_repo.record(
        post_id=saved.id,
        anonymous_id=anonymous_id,
        content_hash=content_hash,
        approved=True,
        reason=None,
        model_used=result.model_used,
    )
    return saved, result
```

```python
# backend/app/core/use_cases/list_posts.py
from app.core.entities.community import Post
from app.core.use_cases.interfaces import PostRepository


def list_posts(
    repo: PostRepository,
    page: int = 1,
    page_size: int = 20,
    political_actor_id: int | None = None,
    theme_slug: str | None = None,
) -> tuple[list[Post], int]:
    return repo.list(
        page=page,
        page_size=page_size,
        political_actor_id=political_actor_id,
        theme_slug=theme_slug,
    )
```

```python
# backend/app/core/use_cases/get_post.py
from app.core.entities.community import Comment, Post
from app.core.use_cases.interfaces import CommentRepository, PostRepository


def get_post(
    post_repo: PostRepository,
    comment_repo: CommentRepository,
    post_id: str,
) -> tuple[Post, list[Comment]] | None:
    post = post_repo.get_by_id(post_id)
    if post is None:
        return None
    comments = comment_repo.list_by_post(post_id)
    return post, comments
```

```python
# backend/app/core/use_cases/create_comment.py
import uuid
from datetime import datetime, timezone

from app.core.entities.community import Comment
from app.core.use_cases.interfaces import CommentRepository, PostRepository


def create_comment(
    post_repo: PostRepository,
    comment_repo: CommentRepository,
    post_id: str,
    anonymous_id: str,
    content: str,
) -> Comment | None:
    if post_repo.get_by_id(post_id) is None:
        return None
    comment = Comment(
        id=str(uuid.uuid4()),
        post_id=post_id,
        anonymous_id=anonymous_id,
        content=content,
        created_at=datetime.now(timezone.utc),
    )
    return comment_repo.create(comment)
```

```python
# backend/app/core/use_cases/vote_post.py
from app.core.entities.community import Post, PostVote
from app.core.use_cases.interfaces import PostRepository, PostVoteRepository


def vote_post(
    post_repo: PostRepository,
    vote_repo: PostVoteRepository,
    post_id: str,
    anonymous_id: str,
    value: int,
) -> Post | None:
    post = post_repo.get_by_id(post_id)
    if post is None:
        return None
    new_score = vote_repo.upsert(
        PostVote(post_id=post_id, anonymous_id=anonymous_id, value=value)
    )
    post_repo.update_score(post_id, new_score)
    return post_repo.get_by_id(post_id)
```

- [ ] **Step 4: Rodar testes**

```bash
uv run pytest tests/test_community_use_cases.py -v
```

Esperado: todos passando.

- [ ] **Step 5: Commit**

```bash
git add app/core/use_cases/moderate_and_create_post.py \
        app/core/use_cases/list_posts.py \
        app/core/use_cases/get_post.py \
        app/core/use_cases/create_comment.py \
        app/core/use_cases/vote_post.py \
        tests/test_community_use_cases.py
git commit -m "feat(community): 5 use cases com testes (moderate, list, get, comment, vote)"
```

---

## Task 6: Schemas, Router, Deps e registro em main.py

**Files:**
- Create: `backend/app/api/schemas/community.py`
- Create: `backend/app/api/routers/community.py`
- Modify: `backend/app/api/deps.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1: Criar schemas**

```python
# backend/app/api/schemas/community.py
from datetime import datetime
from pydantic import BaseModel, Field


class PostIn(BaseModel):
    content: str = Field(min_length=1, max_length=500)
    political_actor_id: int | None = Field(default=None, gt=0)
    theme_slug: str | None = None


class CommentIn(BaseModel):
    content: str = Field(min_length=1, max_length=300)


class VoteIn(BaseModel):
    value: int = Field(ge=-1, le=1)


class PostOut(BaseModel):
    id: str
    anonymous_id: str
    content: str
    political_actor_id: int | None
    theme_slug: str | None
    score: int
    created_at: datetime


class CommentOut(BaseModel):
    id: str
    post_id: str
    anonymous_id: str
    content: str
    created_at: datetime


class PostDetailOut(BaseModel):
    post: PostOut
    comments: list[CommentOut]


class PostListResponse(BaseModel):
    posts: list[PostOut]
    total_count: int
    page: int
    page_size: int
    has_next: bool
```

- [ ] **Step 2: Criar router**

```python
# backend/app/api/routers/community.py
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from app.api.deps import (
    get_comment_repo,
    get_moderation_client,
    get_moderation_log_repo,
    get_post_repo,
    get_vote_repo,
)
from app.api.schemas.community import (
    CommentIn,
    CommentOut,
    PostDetailOut,
    PostIn,
    PostListResponse,
    PostOut,
    VoteIn,
)
from app.core.use_cases.create_comment import create_comment
from app.core.use_cases.get_post import get_post
from app.core.use_cases.list_posts import list_posts
from app.core.use_cases.moderate_and_create_post import moderate_and_create_post
from app.core.use_cases.vote_post import vote_post
from app.infrastructure.llm.moderation_client import ModerationUnavailable

router = APIRouter(prefix="/community", tags=["Comunidade"])
AnonymousHeader = Annotated[str, Header(min_length=1, max_length=64)]


def _post_out(post) -> PostOut:
    return PostOut(
        id=post.id,
        anonymous_id=post.anonymous_id,
        content=post.content,
        political_actor_id=post.political_actor_id,
        theme_slug=post.theme_slug,
        score=post.score,
        created_at=post.created_at,
    )


def _comment_out(comment) -> CommentOut:
    return CommentOut(
        id=comment.id,
        post_id=comment.post_id,
        anonymous_id=comment.anonymous_id,
        content=comment.content,
        created_at=comment.created_at,
    )


@router.post("/posts", response_model=PostOut, status_code=status.HTTP_201_CREATED)
def create_post_endpoint(
    body: PostIn,
    x_farol_anonymous_id: AnonymousHeader,
    post_repo=Depends(get_post_repo),
    log_repo=Depends(get_moderation_log_repo),
    moderation_client=Depends(get_moderation_client),
) -> PostOut:
    try:
        post, result = moderate_and_create_post(
            post_repo,
            log_repo,
            moderation_client,
            x_farol_anonymous_id,
            body.content,
            body.political_actor_id,
            body.theme_slug,
        )
    except ModerationUnavailable:
        raise HTTPException(
            status_code=503,
            detail="Serviço de moderação temporariamente indisponível.",
        )
    if post is None:
        raise HTTPException(status_code=422, detail=result.reason)
    return _post_out(post)


@router.get("/posts", response_model=PostListResponse)
def list_posts_endpoint(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=50),
    political_actor_id: int | None = Query(default=None),
    theme_slug: str | None = Query(default=None),
    post_repo=Depends(get_post_repo),
) -> PostListResponse:
    posts, total = list_posts(
        post_repo,
        page=page,
        page_size=page_size,
        political_actor_id=political_actor_id,
        theme_slug=theme_slug,
    )
    return PostListResponse(
        posts=[_post_out(p) for p in posts],
        total_count=total,
        page=page,
        page_size=page_size,
        has_next=(page * page_size) < total,
    )


@router.get("/posts/{post_id}", response_model=PostDetailOut)
def get_post_endpoint(
    post_id: str,
    post_repo=Depends(get_post_repo),
    comment_repo=Depends(get_comment_repo),
) -> PostDetailOut:
    result = get_post(post_repo, comment_repo, post_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Post não encontrado.")
    post, comments = result
    return PostDetailOut(
        post=_post_out(post),
        comments=[_comment_out(c) for c in comments],
    )


@router.post("/posts/{post_id}/votes", response_model=PostOut)
def vote_post_endpoint(
    post_id: str,
    body: VoteIn,
    x_farol_anonymous_id: AnonymousHeader,
    post_repo=Depends(get_post_repo),
    vote_repo=Depends(get_vote_repo),
) -> PostOut:
    updated = vote_post(post_repo, vote_repo, post_id, x_farol_anonymous_id, body.value)
    if updated is None:
        raise HTTPException(status_code=404, detail="Post não encontrado.")
    return _post_out(updated)


@router.post(
    "/posts/{post_id}/comments",
    response_model=CommentOut,
    status_code=status.HTTP_201_CREATED,
)
def create_comment_endpoint(
    post_id: str,
    body: CommentIn,
    x_farol_anonymous_id: AnonymousHeader,
    post_repo=Depends(get_post_repo),
    comment_repo=Depends(get_comment_repo),
) -> CommentOut:
    comment = create_comment(post_repo, comment_repo, post_id, x_farol_anonymous_id, body.content)
    if comment is None:
        raise HTTPException(status_code=404, detail="Post não encontrado.")
    return _comment_out(comment)
```

- [ ] **Step 3: Adicionar deps e registrar router**

Abra `backend/app/api/deps.py` e acrescente ao final:

```python
# Acrescentar ao final de deps.py

from app.infrastructure.database.community_repositories import (
    SqlCommentRepository,
    SqlModerationLogRepository,
    SqlPostRepository,
    SqlPostVoteRepository,
)
from app.infrastructure.llm.moderation_client import (
    FakeModerationClient,
    GroqModerationClient,
    ModerationPort,
)


def get_post_repo(db: Session = Depends(get_db)) -> SqlPostRepository:
    return SqlPostRepository(db)


def get_comment_repo(db: Session = Depends(get_db)) -> SqlCommentRepository:
    return SqlCommentRepository(db)


def get_vote_repo(db: Session = Depends(get_db)) -> SqlPostVoteRepository:
    return SqlPostVoteRepository(db)


def get_moderation_log_repo(db: Session = Depends(get_db)) -> SqlModerationLogRepository:
    return SqlModerationLogRepository(db)


def get_moderation_client() -> ModerationPort:
    if settings.groq_api_key:
        return GroqModerationClient(settings.groq_api_key)
    return FakeModerationClient(approved=True)
```

Abra `backend/app/main.py` e adicione o import e o `include_router`:

```python
# Adicionar no bloco de imports de routers:
from app.api.routers import community  # acrescentar

# Adicionar após os outros include_router:
app.include_router(community.router, prefix=PREFIX)
```

- [ ] **Step 4: Smoke test — servidor sobe e /docs carrega**

```bash
uv run fastapi dev app/main.py &
sleep 3
curl -s http://localhost:8000/openapi.json | python -c "import sys,json; d=json.load(sys.stdin); paths=list(d['paths'].keys()); print([p for p in paths if 'community' in p])"
kill %1
```

Esperado: lista com `/api/v1/community/posts` e rotas relacionadas.

- [ ] **Step 5: Commit**

```bash
git add app/api/schemas/community.py app/api/routers/community.py app/api/deps.py app/main.py
git commit -m "feat(community): schemas Pydantic, router FastAPI e registro em main.py"
```

---

## Task 7: Testes de API

**Files:**
- Create: `backend/tests/test_community_api.py`

- [ ] **Step 1: Escrever testes de API**

```python
# backend/tests/test_community_api.py
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.api.deps import get_db, get_moderation_client
from app.infrastructure.database.models import Base
from app.infrastructure.llm.moderation_client import FakeModerationClient
from app.main import app

ANON = "test-device-001"
HEADERS = {"x-farol-anonymous-id": ANON}


@pytest.fixture()
def client():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)

    def override_db():
        with TestSession() as db:
            yield db

    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_moderation_client] = lambda: FakeModerationClient(approved=True)
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture()
def client_rejecting():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)

    def override_db():
        with TestSession() as db:
            yield db

    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_moderation_client] = lambda: FakeModerationClient(
        approved=False, reason="Conteúdo fora do tema político"
    )
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def test_create_post_approved(client):
    resp = client.post(
        "/api/v1/community/posts",
        json={"content": "PT votou contra a reforma administrativa"},
        headers=HEADERS,
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["content"] == "PT votou contra a reforma administrativa"
    assert data["score"] == 0


def test_create_post_rejected(client_rejecting):
    resp = client_rejecting.post(
        "/api/v1/community/posts",
        json={"content": "Receita de bolo"},
        headers=HEADERS,
    )
    assert resp.status_code == 422
    assert "Conteúdo fora do tema político" in resp.json()["detail"]


def test_list_posts_empty(client):
    resp = client.get("/api/v1/community/posts")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_count"] == 0
    assert data["posts"] == []


def test_list_posts_after_create(client):
    client.post(
        "/api/v1/community/posts",
        json={"content": "Lula assinou decreto X"},
        headers=HEADERS,
    )
    resp = client.get("/api/v1/community/posts")
    assert resp.json()["total_count"] == 1


def test_get_post_with_comment(client):
    create_resp = client.post(
        "/api/v1/community/posts",
        json={"content": "Bolsonaro votou sim na PEC"},
        headers=HEADERS,
    )
    post_id = create_resp.json()["id"]

    client.post(
        f"/api/v1/community/posts/{post_id}/comments",
        json={"content": "Interessante!"},
        headers=HEADERS,
    )

    resp = client.get(f"/api/v1/community/posts/{post_id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["post"]["id"] == post_id
    assert len(data["comments"]) == 1
    assert data["comments"][0]["content"] == "Interessante!"


def test_get_post_not_found(client):
    resp = client.get("/api/v1/community/posts/nope")
    assert resp.status_code == 404


def test_vote_increases_score(client):
    post_id = client.post(
        "/api/v1/community/posts",
        json={"content": "Câmara aprovou PL de armas"},
        headers=HEADERS,
    ).json()["id"]

    resp = client.post(
        f"/api/v1/community/posts/{post_id}/votes",
        json={"value": 1},
        headers=HEADERS,
    )
    assert resp.status_code == 200
    assert resp.json()["score"] == 1


def test_vote_replaces_previous(client):
    post_id = client.post(
        "/api/v1/community/posts",
        json={"content": "Senado aprovou reforma tributária"},
        headers=HEADERS,
    ).json()["id"]

    client.post(f"/api/v1/community/posts/{post_id}/votes",
                json={"value": 1}, headers=HEADERS)
    resp = client.post(f"/api/v1/community/posts/{post_id}/votes",
                       json={"value": -1}, headers=HEADERS)
    assert resp.json()["score"] == -1


def test_comment_on_missing_post(client):
    resp = client.post(
        "/api/v1/community/posts/nope/comments",
        json={"content": "comentário"},
        headers=HEADERS,
    )
    assert resp.status_code == 404
```

- [ ] **Step 2: Rodar testes**

```bash
uv run pytest tests/test_community_api.py -v
```

Esperado: todos passando.

- [ ] **Step 3: Rodar suite completa para checar regressões**

```bash
uv run pytest --cov=app --cov-report=term-missing -q
```

Esperado: ≥ 80% coverage, sem falhas.

- [ ] **Step 4: Commit**

```bash
git add tests/test_community_api.py
git commit -m "test(community): testes de API end-to-end (create, list, get, vote, comment)"
```

---

## Task 8: Mobile — Modelos, CommunitySession e extensões do ApiClient

**Files:**
- Create: `mobile/lib/features/community/models/community_models.dart`
- Create: `mobile/lib/features/community/community_session.dart`
- Modify: `mobile/lib/core/api_client.dart`

- [ ] **Step 1: Criar modelos Dart**

```dart
// mobile/lib/features/community/models/community_models.dart
class PostSummary {
  final String id;
  final String anonymousId;
  final String content;
  final int? politicalActorId;
  final String? themeSlug;
  final int score;
  final DateTime createdAt;

  const PostSummary({
    required this.id,
    required this.anonymousId,
    required this.content,
    this.politicalActorId,
    this.themeSlug,
    required this.score,
    required this.createdAt,
  });

  factory PostSummary.fromJson(Map<String, dynamic> json) => PostSummary(
        id: json['id'] as String,
        anonymousId: json['anonymous_id'] as String,
        content: json['content'] as String,
        politicalActorId: json['political_actor_id'] as int?,
        themeSlug: json['theme_slug'] as String?,
        score: json['score'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class PostComment {
  final String id;
  final String postId;
  final String anonymousId;
  final String content;
  final DateTime createdAt;

  const PostComment({
    required this.id,
    required this.postId,
    required this.anonymousId,
    required this.content,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        anonymousId: json['anonymous_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class PostDetail {
  final PostSummary post;
  final List<PostComment> comments;

  const PostDetail({required this.post, required this.comments});

  factory PostDetail.fromJson(Map<String, dynamic> json) => PostDetail(
        post: PostSummary.fromJson(json['post'] as Map<String, dynamic>),
        comments: (json['comments'] as List)
            .map((c) => PostComment.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}
```

- [ ] **Step 2: Criar CommunitySession**

```dart
// mobile/lib/features/community/community_session.dart
import 'community_models.dart';

class CommunitySession {
  static final CommunitySession _instance = CommunitySession._();
  factory CommunitySession() => _instance;
  CommunitySession._();

  List<PostSummary> _feed = [];
  int _currentPage = 1;
  bool _hasMore = true;

  List<PostSummary> get feed => List.unmodifiable(_feed);
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;

  void setFeed(List<PostSummary> posts, {required bool hasMore, required int page}) {
    _feed = posts;
    _hasMore = hasMore;
    _currentPage = page;
  }

  void appendFeed(List<PostSummary> posts, {required bool hasMore, required int page}) {
    _feed = [..._feed, ...posts];
    _hasMore = hasMore;
    _currentPage = page;
  }

  void invalidate() {
    _feed = [];
    _currentPage = 1;
    _hasMore = true;
  }

  void updatePost(PostSummary updated) {
    _feed = _feed.map((p) => p.id == updated.id ? updated : p).toList();
  }
}
```

- [ ] **Step 3: Adicionar métodos ao ApiClient**

Abra `mobile/lib/core/api_client.dart` e adicione os seguintes métodos à classe `ApiClient`:

```dart
// Adicionar à classe ApiClient em api_client.dart

Future<Map<String, dynamic>> createPost({
  required String content,
  int? politicalActorId,
  String? themeSlug,
}) async {
  final body = <String, dynamic>{'content': content};
  if (politicalActorId != null) body['political_actor_id'] = politicalActorId;
  if (themeSlug != null) body['theme_slug'] = themeSlug;
  return _post('/community/posts', body);
}

Future<Map<String, dynamic>> listPosts({
  int page = 1,
  int pageSize = 20,
  int? politicalActorId,
  String? themeSlug,
}) async {
  final params = <String, String>{
    'page': '$page',
    'page_size': '$pageSize',
    if (politicalActorId != null) 'political_actor_id': '$politicalActorId',
    if (themeSlug != null) 'theme_slug': themeSlug,
  };
  return _get('/community/posts', queryParams: params);
}

Future<Map<String, dynamic>> getPost(String postId) async {
  return _get('/community/posts/$postId');
}

Future<Map<String, dynamic>> votePost(String postId, int value) async {
  return _post('/community/posts/$postId/votes', {'value': value});
}

Future<Map<String, dynamic>> createComment(String postId, String content) async {
  return _post('/community/posts/$postId/comments', {'content': content});
}
```

- [ ] **Step 4: Commit**

```bash
cd ..  # raiz do projeto
git add mobile/lib/features/community/models/community_models.dart \
        mobile/lib/features/community/community_session.dart \
        mobile/lib/core/api_client.dart
git commit -m "feat(community): modelos Dart, CommunitySession e métodos ApiClient"
```

---

## Task 9: Mobile — Telas Flutter

**Files:**
- Create: `mobile/lib/features/community/community_feed_page.dart`
- Create: `mobile/lib/features/community/post_detail_page.dart`
- Create: `mobile/lib/features/community/create_post_page.dart`
- Modify: `mobile/lib/features/home/home_page.dart`

- [ ] **Step 1: Criar `create_post_page.dart`**

```dart
// mobile/lib/features/community/create_post_page.dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/device_identity_store.dart';
import 'community_session.dart';
import 'models/community_models.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final anonymousId = await DeviceIdentityStore().getOrCreateId();
      final client = ApiClient(anonymousId: anonymousId);
      await client.createPost(content: content);
      CommunitySession().invalidate();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final message = e.toString().contains('422')
          ? _extractRejectionReason(e.toString())
          : 'Erro ao publicar. Tente novamente.';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractRejectionReason(String error) {
    try {
      final start = error.indexOf('"detail":"') + 10;
      final end = error.indexOf('"', start);
      if (start > 10 && end > start) return error.substring(start, end);
    } catch (_) {}
    return 'Post rejeitado pela moderação.';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = 500 - _controller.text.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Novo post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              maxLength: 500,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Escreva sobre política brasileira...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Criar `post_detail_page.dart`**

```dart
// mobile/lib/features/community/post_detail_page.dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/device_identity_store.dart';
import 'community_session.dart';
import 'models/community_models.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  PostDetail? _detail;
  bool _loading = true;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final anonymousId = await DeviceIdentityStore().getOrCreateId();
    final client = ApiClient(anonymousId: anonymousId);
    final data = await client.getPost(widget.postId);
    if (mounted) {
      setState(() {
        _detail = PostDetail.fromJson(data);
        _loading = false;
      });
    }
  }

  Future<void> _vote(int value) async {
    final anonymousId = await DeviceIdentityStore().getOrCreateId();
    final client = ApiClient(anonymousId: anonymousId);
    final data = await client.votePost(widget.postId, value);
    final updated = PostSummary.fromJson(data);
    CommunitySession().updatePost(updated);
    if (mounted) {
      setState(() {
        _detail = PostDetail(post: updated, comments: _detail!.comments);
      });
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    final anonymousId = await DeviceIdentityStore().getOrCreateId();
    final client = ApiClient(anonymousId: anonymousId);
    final data = await client.createComment(widget.postId, content);
    final comment = PostComment.fromJson(data);
    _commentController.clear();
    if (mounted) {
      setState(() {
        _detail = PostDetail(
          post: _detail!.post,
          comments: [..._detail!.comments, comment],
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final post = _detail!.post;
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(post.content, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.thumb_up_outlined),
                      onPressed: () => _vote(1),
                    ),
                    Text('${post.score}'),
                    IconButton(
                      icon: const Icon(Icons.thumb_down_outlined),
                      onPressed: () => _vote(-1),
                    ),
                  ],
                ),
                const Divider(),
                ..._detail!.comments.map(
                  (c) => ListTile(
                    title: Text(c.content),
                    subtitle: Text(c.createdAt.toLocal().toString()),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Adicionar comentário...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Criar `community_feed_page.dart`**

```dart
// mobile/lib/features/community/community_feed_page.dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/device_identity_store.dart';
import 'community_session.dart';
import 'create_post_page.dart';
import 'models/community_models.dart';
import 'post_detail_page.dart';

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  final _session = CommunitySession();
  bool _loading = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPage(1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _session.hasMore &&
        !_loading) {
      _loadPage(_session.currentPage + 1);
    }
  }

  Future<void> _loadPage(int page) async {
    setState(() => _loading = true);
    final anonymousId = await DeviceIdentityStore().getOrCreateId();
    final client = ApiClient(anonymousId: anonymousId);
    final data = await client.listPosts(page: page, pageSize: 20);
    final posts = (data['posts'] as List)
        .map((p) => PostSummary.fromJson(p as Map<String, dynamic>))
        .toList();
    final hasNext = data['has_next'] as bool;
    if (page == 1) {
      _session.setFeed(posts, hasMore: hasNext, page: page);
    } else {
      _session.appendFeed(posts, hasMore: hasNext, page: page);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostPage()),
    );
    if (created == true) _loadPage(1);
  }

  @override
  Widget build(BuildContext context) {
    final feed = _session.feed;
    return Scaffold(
      appBar: AppBar(title: const Text('Comunidade')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.edit),
      ),
      body: _loading && feed.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadPage(1),
              child: ListView.separated(
                controller: _scrollController,
                itemCount: feed.length + (_session.hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == feed.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final post = feed[index];
                  return ListTile(
                    title: Text(
                      post.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('Score: ${post.score}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailPage(postId: post.id),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
```

- [ ] **Step 4: Adicionar entrada na home**

Abra `mobile/lib/features/home/home_page.dart` e adicione um botão/card de navegação para `CommunityFeedPage`. Adicione o import e o item de navegação no mesmo padrão dos outros itens existentes na home:

```dart
// Adicionar import
import '../community/community_feed_page.dart';

// Adicionar no método de build, junto com os outros cards/botões de navegação:
// (adapte ao padrão visual existente na HomePage)
ElevatedButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CommunityFeedPage()),
  ),
  child: const Text('Comunidade'),
),
```

- [ ] **Step 5: Compilar Flutter para checar erros**

```bash
cd mobile
flutter pub get
flutter analyze
```

Esperado: sem erros.

- [ ] **Step 6: Commit**

```bash
cd ..
git add mobile/lib/features/community/ mobile/lib/features/home/home_page.dart
git commit -m "feat(community): telas Flutter feed, detalhe, criação de post e entrada na home"
```

---

## Task 10: Testes Flutter

**Files:**
- Create: `mobile/test/community_session_test.dart`
- Create: `mobile/test/community_models_test.dart`

- [ ] **Step 1: Escrever testes**

```dart
// mobile/test/community_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/community/models/community_models.dart';

void main() {
  group('PostSummary.fromJson', () {
    test('parses all fields', () {
      final json = {
        'id': 'abc',
        'anonymous_id': 'anon-1',
        'content': 'Texto',
        'political_actor_id': null,
        'theme_slug': null,
        'score': 3,
        'created_at': '2026-05-30T10:00:00Z',
      };
      final post = PostSummary.fromJson(json);
      expect(post.id, 'abc');
      expect(post.score, 3);
    });
  });

  group('PostDetail.fromJson', () {
    test('parses post and comments', () {
      final json = {
        'post': {
          'id': 'p1', 'anonymous_id': 'a', 'content': 'x',
          'political_actor_id': null, 'theme_slug': null,
          'score': 0, 'created_at': '2026-05-30T10:00:00Z',
        },
        'comments': [
          {
            'id': 'c1', 'post_id': 'p1', 'anonymous_id': 'a',
            'content': 'ótimo', 'created_at': '2026-05-30T10:01:00Z',
          }
        ],
      };
      final detail = PostDetail.fromJson(json);
      expect(detail.post.id, 'p1');
      expect(detail.comments.length, 1);
      expect(detail.comments[0].content, 'ótimo');
    });
  });
}
```

```dart
// mobile/test/community_session_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/community/community_session.dart';
import 'package:mobile/features/community/models/community_models.dart';

PostSummary _post(String id, int score) => PostSummary(
      id: id,
      anonymousId: 'a',
      content: 'x',
      score: score,
      createdAt: DateTime.now(),
    );

void main() {
  setUp(() => CommunitySession().invalidate());

  test('setFeed populates feed', () {
    CommunitySession().setFeed([_post('p1', 0)], hasMore: false, page: 1);
    expect(CommunitySession().feed.length, 1);
  });

  test('appendFeed adds to existing feed', () {
    CommunitySession().setFeed([_post('p1', 0)], hasMore: true, page: 1);
    CommunitySession().appendFeed([_post('p2', 0)], hasMore: false, page: 2);
    expect(CommunitySession().feed.length, 2);
  });

  test('invalidate clears feed', () {
    CommunitySession().setFeed([_post('p1', 0)], hasMore: false, page: 1);
    CommunitySession().invalidate();
    expect(CommunitySession().feed, isEmpty);
  });

  test('updatePost replaces post in feed', () {
    CommunitySession().setFeed([_post('p1', 0)], hasMore: false, page: 1);
    CommunitySession().updatePost(_post('p1', 5));
    expect(CommunitySession().feed.first.score, 5);
  });
}
```

- [ ] **Step 2: Rodar testes**

```bash
cd mobile
flutter test test/community_models_test.dart test/community_session_test.dart
```

Esperado: todos passando.

- [ ] **Step 3: Commit**

```bash
cd ..
git add mobile/test/community_models_test.dart mobile/test/community_session_test.dart
git commit -m "test(community): testes de modelos Dart e CommunitySession"
```

---

## Checklist de auto-revisão pós-plano

- [x] Task 1 cobre spec §Arquitetura (entidades + interfaces)
- [x] Task 2 cobre spec §Banco de Dados (4 tabelas)
- [x] Task 3 cobre repositórios SQL com TDD
- [x] Task 4 cobre spec §Moderação por IA (GroqModerationClient + FakeModerationClient)
- [x] Task 5 cobre 5 use cases com testes puros
- [x] Task 6 cobre spec §Endpoints (5 rotas) + schemas Pydantic
- [x] Task 7 cobre testes de API end-to-end
- [x] Tasks 8-10 cobrem spec §Mobile (3 telas + CommunitySession + modelos)
- [x] Sem placeholders ou TBDs
- [x] Tipos consistentes (Post, Comment, PostVote, ModerationResult usados uniformemente)
- [x] FakeModerationClient usado em todos os testes (sem chamada HTTP real)
