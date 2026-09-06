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
    removed_at: datetime | None = None
    removed_by: str | None = None  # "author" | "moderation"

    @property
    def removed(self) -> bool:
        return self.removed_at is not None


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


@dataclass(frozen=True)
class PostReport:
    post_id: str
    anonymous_id: str
    reason: str
    detail: str | None
    created_at: datetime
