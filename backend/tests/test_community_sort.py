from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app.api.deps import get_post_repo
from app.core.entities.community import Post
from app.main import app

NOW = datetime(2026, 9, 6, 12, 0, tzinfo=timezone.utc)


def _post(post_id: str, score: int, days_ago: int) -> Post:
    return Post(
        id=post_id,
        anonymous_id="alguem",
        content=f"conteudo {post_id}",
        political_actor_id=None,
        theme_slug=None,
        score=score,
        created_at=NOW - timedelta(days=days_ago),
    )


# "velho" tem a maior pontuacao; "novo" e o mais recente. Se a ordenacao mudar
# de verdade, a primeira posicao troca entre os dois.
POSTS = [_post("velho", score=99, days_ago=10), _post("novo", score=1, days_ago=0)]


class _FakePostRepo:
    def __init__(self) -> None:
        self.last_sort: str | None = None

    def list(
        self,
        page: int = 1,
        page_size: int = 20,
        political_actor_id: int | None = None,
        theme_slug: str | None = None,
        sort: str = "score",
    ) -> tuple[list[Post], int]:
        self.last_sort = sort
        if sort == "recent":
            ordenados = sorted(POSTS, key=lambda p: p.created_at, reverse=True)
        else:
            ordenados = sorted(
                POSTS, key=lambda p: (p.score, p.created_at), reverse=True
            )
        return ordenados, len(ordenados)


def teardown_function() -> None:
    app.dependency_overrides.clear()


def _client(repo: _FakePostRepo) -> TestClient:
    app.dependency_overrides[get_post_repo] = lambda: repo
    return TestClient(app)


def test_padrao_ordena_por_pontuacao() -> None:
    repo = _FakePostRepo()
    body = _client(repo).get("/api/v1/community/posts").json()

    assert repo.last_sort == "score"
    assert body["posts"][0]["id"] == "velho"


def test_recent_ordena_por_data() -> None:
    repo = _FakePostRepo()
    body = _client(repo).get("/api/v1/community/posts?sort=recent").json()

    assert repo.last_sort == "recent"
    assert body["posts"][0]["id"] == "novo"


def test_score_explicito_ordena_por_pontuacao() -> None:
    repo = _FakePostRepo()
    body = _client(repo).get("/api/v1/community/posts?sort=score").json()

    assert body["posts"][0]["id"] == "velho"


def test_valor_fora_do_vocabulario_e_422() -> None:
    r = _client(_FakePostRepo()).get("/api/v1/community/posts?sort=aleatorio")

    assert r.status_code == 422
