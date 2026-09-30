from dataclasses import replace
from datetime import datetime, timezone

from sqlalchemy import func, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from app.core.entities.community import (
    Comment,
    CommentReport,
    Post,
    PostReport,
    PostVote,
)
from app.core.use_cases.community_errors import PostRemovedError
from app.core.use_cases.interfaces import (
    CommentReportRepository,
    CommentRepository,
    ModerationLogRepository,
    PostReportRepository,
    PostRepository,
    PostVoteRepository,
)
from app.infrastructure.database.models import (
    CommentAdmissionLockModel,
    CommentModel,
    CommentReportModel,
    ModerationLogModel,
    PostModel,
    PostReportModel,
    PostVoteModel,
    ThemeModel,
)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _lock_author_admission(db: Session, anonymous_id: str) -> str:
    dialect = db.get_bind().dialect.name
    if dialect not in {"postgresql", "sqlite"}:
        raise NotImplementedError(f"Community admission is unsupported for {dialect}")
    # Reuse the existing persistent author lock for both independent quotas.
    insert_lock = pg_insert(CommentAdmissionLockModel) if dialect == "postgresql" else sqlite_insert(CommentAdmissionLockModel)
    db.execute(insert_lock.values(anonymous_id=anonymous_id).on_conflict_do_nothing(index_elements=["anonymous_id"]))
    db.execute(select(CommentAdmissionLockModel.anonymous_id).where(
        CommentAdmissionLockModel.anonymous_id == anonymous_id,
    ).with_for_update()).scalar_one()
    return dialect


def _lock_active_post(db: Session, post_id: str, dialect: str) -> None:
    if dialect == "postgresql":
        locked = db.execute(select(PostModel.removed_at).where(PostModel.id == post_id).with_for_update()).one_or_none()
    else:
        locked = db.execute(update(PostModel).where(PostModel.id == post_id)
                            .values(score=PostModel.score).returning(PostModel.removed_at)).one_or_none()
    if locked is None or locked[0] is not None:
        raise PostRemovedError()


def _to_post(m: PostModel) -> Post:
    return Post(
        id=m.id,
        anonymous_id=m.anonymous_id,
        content=m.content,
        political_actor_id=m.political_actor_id,
        theme_slug=m.theme_slug,
        score=m.score,
        created_at=m.created_at,
        removed_at=m.removed_at,
        removed_by=m.removed_by,
    )


def _to_comment(m: CommentModel) -> Comment:
    return Comment(
        id=m.id,
        post_id=m.post_id,
        anonymous_id=m.anonymous_id,
        content=m.content,
        created_at=m.created_at,
        removed_at=m.removed_at,
        removed_by=m.removed_by,
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

    def create_with_rate_limit(self, post: Post, since: datetime, max_posts: int) -> Post | None:
        try:
            _lock_author_admission(self._db, post.anonymous_id)
            if self.count_by_author_since(post.anonymous_id, since) >= max_posts:
                self._db.rollback()
                return None
            return self.create(post)
        except Exception:
            self._db.rollback()
            raise

    def enrich(self, posts: list[Post], viewer_id: str | None) -> list[Post]:
        if not posts:
            return posts
        post_ids = [post.id for post in posts]
        counts = (
            select(CommentModel.post_id, func.count().label("comment_count"))
            .where(CommentModel.post_id.in_(post_ids))
            .group_by(CommentModel.post_id).subquery()
        )
        # One metadata query for the page. Removed comments remain in detail and
        # therefore remain in the count; an absent viewer cannot match a vote.
        rows = self._db.execute(
            select(
                PostModel.id, func.coalesce(PostVoteModel.value, 0),
                func.coalesce(counts.c.comment_count, 0), ThemeModel.name,
            )
            .outerjoin(PostVoteModel, (PostVoteModel.post_id == PostModel.id) &
                       (PostVoteModel.anonymous_id == viewer_id))
            .outerjoin(counts, counts.c.post_id == PostModel.id)
            .outerjoin(ThemeModel, ThemeModel.slug == PostModel.theme_slug)
            .where(PostModel.id.in_(post_ids))
        ).all()
        metadata = {row[0]: (int(row[1]), int(row[2]), row[3]) for row in rows}
        return [replace(
            post, my_vote=metadata[post.id][0], comment_count=metadata[post.id][1],
            theme_name=metadata[post.id][2],
        ) for post in posts]

    def list(
        self,
        page: int = 1,
        page_size: int = 20,
        political_actor_id: int | None = None,
        theme_slug: str | None = None,
        sort: str = "score",
    ) -> tuple[list[Post], int]:
        stmt = select(PostModel)
        if political_actor_id is not None:
            stmt = stmt.where(PostModel.political_actor_id == political_actor_id)
        if theme_slug is not None:
            stmt = stmt.where(PostModel.theme_slug == theme_slug)
        if sort == "recent":
            stmt = stmt.order_by(PostModel.created_at.desc())
        else:
            stmt = stmt.order_by(
                PostModel.score.desc(), PostModel.created_at.desc()
            )
        total = self._db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        offset = (page - 1) * page_size
        rows = self._db.execute(stmt.offset(offset).limit(page_size)).scalars().all()
        return [_to_post(r) for r in rows], total

    def update_score(self, post_id: str, new_score: int) -> None:
        model = self._db.get(PostModel, post_id)
        if model:
            model.score = new_score
            self._db.commit()


    def count_by_author_since(self, anonymous_id: str, since: datetime) -> int:
        stmt = (
            select(func.count())
            .select_from(PostModel)
            .where(
                PostModel.anonymous_id == anonymous_id,
                PostModel.created_at >= since,
            )
        )
        return int(self._db.execute(stmt).scalar_one())

    def mark_removed(self, post_id: str, removed_by: str, now: datetime) -> None:
        self._db.execute(update(PostModel).where(
            PostModel.id == post_id, PostModel.removed_at.is_(None),
        ).values(removed_at=now, removed_by=removed_by, content=""))
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

    def create_with_rate_limit(
        self, comment: Comment, since: datetime, max_comments: int,
    ) -> Comment | None:
        try:
            # Consistent order: author admission lock, then parent row. The parent
            # can change during moderation and must stay active through insertion.
            dialect = _lock_author_admission(self._db, comment.anonymous_id)
            _lock_active_post(self._db, comment.post_id, dialect)
            if self.count_by_author_since(comment.anonymous_id, since) >= max_comments:
                self._db.rollback()
                return None
            # create commits both admission and comment, releasing the DB lock.
            return self.create(comment)
        except Exception:
            self._db.rollback()
            raise

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

    def get_by_id(self, comment_id: str) -> Comment | None:
        model = self._db.get(CommentModel, comment_id)
        return _to_comment(model) if model else None

    def mark_removed(self, comment_id: str, removed_by: str, now: datetime) -> None:
        # Preserve whichever removal won the race, as well as the discussion row.
        self._db.execute(
            update(CommentModel).where(CommentModel.id == comment_id, CommentModel.removed_at.is_(None))
            .values(removed_at=now, removed_by=removed_by, content="")
        )
        self._db.commit()

    def count_by_author_since(self, anonymous_id: str, since: datetime) -> int:
        stmt = (
            select(func.count())
            .select_from(CommentModel)
            .where(
                CommentModel.anonymous_id == anonymous_id,
                CommentModel.created_at >= since,
            )
        )
        return int(self._db.execute(stmt).scalar_one())


class SqlPostVoteRepository(PostVoteRepository):
    updates_post_score_atomically = True

    def __init__(self, db: Session) -> None:
        self._db = db

    def upsert(self, vote: PostVote) -> int:
        dialect = self._db.get_bind().dialect.name
        if dialect not in {"postgresql", "sqlite"}:
            raise NotImplementedError(f"Voting is unsupported for {dialect}")
        insert_vote = pg_insert(PostVoteModel) if dialect == "postgresql" else sqlite_insert(PostVoteModel)
        try:
            # Serialize votes for a post, including the aggregate update. SQLite
            # obtains its writer lock with a no-op update; PostgreSQL locks the row.
            _lock_active_post(self._db, vote.post_id, dialect)
            self._db.execute(
                insert_vote.values(
                    post_id=vote.post_id, anonymous_id=vote.anonymous_id, value=vote.value,
                ).on_conflict_do_update(
                    index_elements=["post_id", "anonymous_id"], set_={"value": vote.value},
                )
            )
            score = self._db.scalar(
                select(func.sum(PostVoteModel.value)).where(
                    PostVoteModel.post_id == vote.post_id
                )
            ) or 0
            self._db.execute(
                update(PostModel).where(PostModel.id == vote.post_id).values(score=score)
            )
            self._db.commit()
            return int(score)
        except Exception:
            self._db.rollback()
            raise

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


class SqlPostReportRepository(PostReportRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def upsert(self, report: PostReport) -> None:
        dialect = self._db.get_bind().dialect.name
        if dialect not in {"postgresql", "sqlite"}:
            raise NotImplementedError(f"Post reporting is unsupported for {dialect}")
        insert_report = pg_insert(PostReportModel) if dialect == "postgresql" else sqlite_insert(PostReportModel)
        try:
            self._db.execute(insert_report.values(
                post_id=report.post_id, anonymous_id=report.anonymous_id,
                reason=report.reason, detail=report.detail, created_at=report.created_at,
            ).on_conflict_do_update(index_elements=["post_id", "anonymous_id"],
                                    set_={"reason": report.reason, "detail": report.detail}))
            self._db.commit()
        except Exception:
            self._db.rollback()
            raise

    def count_distinct_reporters(self, post_id: str) -> int:
        stmt = (
            select(func.count())
            .select_from(PostReportModel)
            .where(PostReportModel.post_id == post_id)
        )
        return int(self._db.execute(stmt).scalar_one())

    def reasons_for_post(self, post_id: str) -> list[str]:
        stmt = select(PostReportModel.reason).where(
            PostReportModel.post_id == post_id
        )
        return list(self._db.execute(stmt).scalars().all())


class SqlCommentReportRepository(CommentReportRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def upsert(self, report: CommentReport) -> None:
        dialect = self._db.get_bind().dialect.name
        if dialect not in {"postgresql", "sqlite"}:
            raise NotImplementedError(f"Comment reporting is unsupported for {dialect}")
        insert_report = pg_insert(CommentReportModel) if dialect == "postgresql" else sqlite_insert(CommentReportModel)
        try:
            self._db.execute(
                insert_report.values(
                    comment_id=report.comment_id, anonymous_id=report.anonymous_id,
                    reason=report.reason, detail=report.detail, created_at=report.created_at,
                ).on_conflict_do_update(
                    index_elements=["comment_id", "anonymous_id"],
                    set_={"reason": report.reason, "detail": report.detail},
                )
            )
            self._db.commit()
        except Exception:
            self._db.rollback()
            raise

    def count_distinct_reporters(self, comment_id: str) -> int:
        return int(self._db.execute(
            select(func.count()).select_from(CommentReportModel)
            .where(CommentReportModel.comment_id == comment_id)
        ).scalar_one())

    def reasons_for_comment(self, comment_id: str) -> list[str]:
        return list(self._db.execute(
            select(CommentReportModel.reason).where(CommentReportModel.comment_id == comment_id)
            .order_by(CommentReportModel.anonymous_id)
        ).scalars().all())
