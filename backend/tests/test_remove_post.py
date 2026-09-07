from datetime import datetime, timezone

import pytest

from app.core.entities.community import Post
from app.core.use_cases.remove_post import NotThePostAuthorError, remove_own_post

NOW = datetime(2026, 9, 6, 12, 0, tzinfo=timezone.utc)


def _post(removed_by: str | None = None) -> Post:
    return Post(
        id="p1",
        anonymous_id="autor",
        content="conteudo",
        political_actor_id=None,
        theme_slug=None,
        score=0,
        created_at=NOW,
        removed_at=NOW if removed_by else None,
        removed_by=removed_by,
    )


class _FakePostRepo:
    def __init__(self, post: Post | None) -> None:
        self.post = post
        self.removed: list[tuple[str, str]] = []

    def get_by_id(self, post_id: str) -> Post | None:
        return self.post

    def mark_removed(self, post_id: str, removed_by: str, now: datetime) -> None:
        self.removed.append((post_id, removed_by))


def test_autor_remove_o_proprio_post() -> None:
    repo = _FakePostRepo(_post())

    ok = remove_own_post(repo, post_id="p1", anonymous_id="autor", now=NOW)  # type: ignore[arg-type]

    assert ok is True
    assert repo.removed == [("p1", "author")]


def test_terceiro_nao_remove() -> None:
    repo = _FakePostRepo(_post())

    with pytest.raises(NotThePostAuthorError):
        remove_own_post(repo, post_id="p1", anonymous_id="outro", now=NOW)  # type: ignore[arg-type]

    assert repo.removed == []


def test_post_inexistente_devolve_false() -> None:
    repo = _FakePostRepo(None)

    assert remove_own_post(repo, post_id="p1", anonymous_id="autor", now=NOW) is False  # type: ignore[arg-type]


def test_remover_de_novo_e_idempotente() -> None:
    repo = _FakePostRepo(_post(removed_by="author"))

    ok = remove_own_post(repo, post_id="p1", anonymous_id="autor", now=NOW)  # type: ignore[arg-type]

    assert ok is True
    assert repo.removed == []


def test_removido_pela_moderacao_mantem_o_motivo() -> None:
    # O autor apagar depois nao pode reescrever o motivo: senao seria possivel
    # apagar o rastro de uma remocao por moderacao.
    repo = _FakePostRepo(_post(removed_by="moderation"))

    remove_own_post(repo, post_id="p1", anonymous_id="autor", now=NOW)  # type: ignore[arg-type]

    assert repo.removed == []
