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
        image_data=m.image_data,
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
            image_data=post.image_data,
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

    def get_by_id(self, comment_id: str) -> Comment | None:
        model = self._db.get(CommentModel, comment_id)
        return _to_comment(model) if model else None

    def delete(self, comment_id: str) -> None:
        model = self._db.get(CommentModel, comment_id)
        if model:
            self._db.delete(model)
            self._db.commit()

    def update_content(self, comment_id: str, new_content: str) -> Comment:
        model = self._db.get(CommentModel, comment_id)
        if model is None:
            raise ValueError(f"Comment {comment_id} not found")
        model.content = new_content
        self._db.commit()
        self._db.refresh(model)
        return _to_comment(model)

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
