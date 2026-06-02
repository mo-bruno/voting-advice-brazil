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
