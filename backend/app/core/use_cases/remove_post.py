"""Remoção do próprio post, em forma de lápide.

`PostModel.comments` usa `cascade="all, delete-orphan"`, então um DELETE real
destruiria os comentários de terceiros junto. A lápide apaga o conteúdo e
preserva a discussão.
"""

from __future__ import annotations

from datetime import datetime

from app.core.use_cases.interfaces import PostRepository


class NotThePostAuthorError(PermissionError):
    """Quem pediu a remoção não é o autor do post."""


def remove_own_post(
    post_repo: PostRepository,
    *,
    post_id: str,
    anonymous_id: str,
    now: datetime,
) -> bool:
    """Devolve False se o post não existe; True se removeu ou já estava removido."""
    post = post_repo.get_by_id(post_id)
    if post is None:
        return False

    if post.anonymous_id != anonymous_id:
        raise NotThePostAuthorError(post_id)

    # Idempotente, e nao reescreve o motivo de quem removeu primeiro.
    if post.removed_at is None:
        post_repo.mark_removed(post_id, removed_by="author", now=now)
    return True
