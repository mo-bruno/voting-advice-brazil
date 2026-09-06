"""Denúncia de post, com reavaliação por IA ao atingir o limiar.

Sem painel de administração, uma fila de denúncias que ninguém lê seria teatro.
Aqui o limiar devolve o conteúdo ao moderador que já existe — a decisão final é
do modelo, não da contagem, o que impede um grupo de derrubar post legítimo por
volume.
"""

from __future__ import annotations

import hashlib
from datetime import datetime
from typing import Final

from app.core.entities.community import PostReport
from app.core.use_cases.interfaces import (
    ModerationLogRepository,
    PostReportRepository,
    PostRepository,
)
from app.infrastructure.llm.moderation_client import (
    ModerationPort,
    ModerationUnavailable,
)

REPORT_THRESHOLD: Final[int] = 3

VALID_REASONS: Final[frozenset[str]] = frozenset(
    {"desinformacao", "discurso_de_odio", "spam", "outro"}
)


def report_post(
    *,
    report_repo: PostReportRepository,
    post_repo: PostRepository,
    log_repo: ModerationLogRepository,
    moderation_client: ModerationPort,
    post_id: str,
    anonymous_id: str,
    reason: str,
    detail: str | None,
    now: datetime,
) -> None:
    report_repo.upsert(
        PostReport(
            post_id=post_id,
            anonymous_id=anonymous_id,
            reason=reason,
            detail=detail,
            created_at=now,
        )
    )

    post = post_repo.get_by_id(post_id)
    if post is None or post.removed_at is not None:
        return

    if report_repo.count_distinct_reporters(post_id) < REPORT_THRESHOLD:
        return

    try:
        result = moderation_client.moderate(
            post.content,
            report_reasons=report_repo.reasons_for_post(post_id),
        )
    except ModerationUnavailable:
        # Nao ha o que recusar: o post ja esta publicado. Como o gatilho e
        # "contagem >= limiar E ainda nao removido", a proxima denuncia tenta de
        # novo — nada se perde.
        return

    log_repo.record(
        post_id=post_id,
        anonymous_id=anonymous_id,
        content_hash=hashlib.sha256(post.content.encode()).hexdigest(),
        approved=result.approved,
        reason=result.reason or None,
        model_used=result.model_used,
    )

    if not result.approved:
        post_repo.mark_removed(post_id, removed_by="moderation", now=now)
