import hashlib
from datetime import datetime

from app.core.entities.community import CommentReport
from app.core.use_cases.interfaces import (
    CommentReportRepository,
    CommentRepository,
    ModerationLogRepository,
    ModerationPort,
    ModerationUnavailable,
    PostRepository,
)
from app.core.use_cases.report_post import REPORT_THRESHOLD


def report_comment(
    *,
    report_repo: CommentReportRepository,
    comment_repo: CommentRepository,
    post_repo: PostRepository,
    log_repo: ModerationLogRepository,
    moderation_client: ModerationPort,
    post_id: str,
    comment_id: str,
    anonymous_id: str,
    reason: str,
    detail: str | None,
    now: datetime,
) -> bool:
    comment = comment_repo.get_by_id(comment_id)
    post = post_repo.get_by_id(post_id)
    if comment is None or comment.post_id != post_id or post is None:
        return False
    report_repo.upsert(CommentReport(comment_id, anonymous_id, reason, detail, now))
    if (
        comment.removed
        or report_repo.count_distinct_reporters(comment_id) < REPORT_THRESHOLD
    ):
        return True
    try:
        result = moderation_client.moderate_comment(
            comment.content,
            post.content if not post.removed else None,
            report_reasons=report_repo.reasons_for_comment(comment_id),
        )
    except ModerationUnavailable:
        # An existing comment remains available. A later report retries the decision.
        return True
    log_repo.record(
        post_id=post_id,
        anonymous_id=anonymous_id,
        content_hash=hashlib.sha256(comment.content.encode()).hexdigest(),
        approved=result.approved,
        reason=result.reason or None,
        model_used=result.model_used,
    )
    if not result.approved:
        comment_repo.mark_removed(comment_id, removed_by="moderation", now=now)
    return True
