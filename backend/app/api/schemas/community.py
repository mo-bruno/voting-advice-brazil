from datetime import datetime

from pydantic import BaseModel, Field

_MAX_IMAGE_B64 = 700_000  # ~500 KB de imagem comprimida


class PostIn(BaseModel):
    content: str = Field(min_length=1, max_length=500)
    political_actor_id: int | None = Field(default=None, gt=0)
    theme_slug: str | None = None
    image_data: str | None = Field(default=None, max_length=_MAX_IMAGE_B64)


class CommentIn(BaseModel):
    content: str = Field(min_length=1, max_length=300)


class CommentEditIn(BaseModel):
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
    has_image: bool
    created_at: datetime


class PostDetailItemOut(PostOut):
    image_data: str | None


class CommentOut(BaseModel):
    id: str
    post_id: str
    anonymous_id: str
    content: str
    created_at: datetime


class PostDetailOut(BaseModel):
    post: PostDetailItemOut
    comments: list[CommentOut]


class PostListResponse(BaseModel):
    posts: list[PostOut]
    total_count: int
    page: int
    page_size: int
    has_next: bool
