from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.api.deps import (
    get_moderation_client,
    get_moderation_log_repo,
    get_post_repo,
    get_post_report_repo,
)
from app.core.entities.community import ModerationResult, Post, PostReport
from app.core.use_cases.interfaces import ModerationLogRepository
from app.infrastructure.llm.moderation_client import (
    ModerationPort,
    ModerationUnavailable,
)
from app.main import app

NOW = datetime.now(timezone.utc)
HEADERS = {"X-Farol-Anonymous-Id": "dispositivo-1"}


def _post(anonymous_id: str = "dispositivo-1", removed: bool = False) -> Post:
    return Post(
        id="p1",
        anonymous_id=anonymous_id,
        content="conteudo",
        political_actor_id=None,
        theme_slug=None,
        score=0,
        created_at=NOW,
        removed_at=NOW if removed else None,
        removed_by="author" if removed else None,
    )


class _FakePostRepo:
    def __init__(self, post: Post | None, recent: int = 0) -> None:
        self.post = post
        self.recent = recent
        self.removed: list[tuple[str, str]] = []
        self.created: list[Post] = []

    def get_by_id(self, post_id: str) -> Post | None:
        return self.post

    def create(self, post: Post) -> Post:
        self.created.append(post)
        return post

    def list(self, **kwargs: object) -> tuple[list[Post], int]:
        return ([], 0)

    def update_score(self, post_id: str, new_score: int) -> None:
        return None

    def count_by_author_since(self, anonymous_id: str, since: datetime) -> int:
        return self.recent

    def mark_removed(self, post_id: str, removed_by: str, now: datetime) -> None:
        self.removed.append((post_id, removed_by))


class _FakeReportRepo:
    def __init__(self) -> None:
        self.saved: list[PostReport] = []

    def upsert(self, report: PostReport) -> None:
        self.saved = [
            r for r in self.saved if r.anonymous_id != report.anonymous_id
        ] + [report]

    def count_distinct_reporters(self, post_id: str) -> int:
        return len({r.anonymous_id for r in self.saved})

    def reasons_for_post(self, post_id: str) -> list[str]:
        return [r.reason for r in self.saved]


class _OkModeration(ModerationPort):
    def moderate(
        self, content: str, report_reasons: list[str] | None = None
    ) -> ModerationResult:
        return ModerationResult(approved=True, reason="", model_used="fake")


class _DownModeration(ModerationPort):
    def moderate(
        self, content: str, report_reasons: list[str] | None = None
    ) -> ModerationResult:
        raise ModerationUnavailable("fora do ar")


class _FakeModerationLog(ModerationLogRepository):
    """Log de moderacao em memoria.

    Sem ele o endpoint resolve `get_moderation_log_repo` pela sessao real e
    grava em `sqlite:///./voting_advice.db` — o banco de desenvolvimento de quem
    roda os testes. Na maquina do autor esse arquivo existe com as tabelas e o
    teste passava; num checkout limpo o SQLite cria um arquivo vazio e o INSERT
    morre em "no such table: moderation_log". Era assim que o CI falhava.
    """

    def __init__(self) -> None:
        self.registros: list[tuple[str | None, str, bool]] = []

    def record(
        self,
        post_id: str | None,
        anonymous_id: str,
        content_hash: str,
        approved: bool,
        reason: str | None,
        model_used: str,
    ) -> None:
        self.registros.append((post_id, anonymous_id, approved))


def teardown_function() -> None:
    app.dependency_overrides.clear()


def _client(post_repo: _FakePostRepo, report_repo: _FakeReportRepo) -> TestClient:
    app.dependency_overrides[get_post_repo] = lambda: post_repo
    app.dependency_overrides[get_post_report_repo] = lambda: report_repo
    app.dependency_overrides[get_moderation_client] = _OkModeration
    app.dependency_overrides[get_moderation_log_repo] = _FakeModerationLog
    return TestClient(app)


def test_denuncia_devolve_204() -> None:
    client = _client(_FakePostRepo(_post()), _FakeReportRepo())

    r = client.post(
        "/api/v1/community/posts/p1/reports",
        json={"reason": "spam"},
        headers=HEADERS,
    )

    assert r.status_code == 204


def test_denuncia_repetida_tambem_devolve_204() -> None:
    client = _client(_FakePostRepo(_post()), _FakeReportRepo())

    for _ in range(3):
        r = client.post(
            "/api/v1/community/posts/p1/reports",
            json={"reason": "spam"},
            headers=HEADERS,
        )
        assert r.status_code == 204


def test_motivo_fora_do_vocabulario_e_422() -> None:
    client = _client(_FakePostRepo(_post()), _FakeReportRepo())

    r = client.post(
        "/api/v1/community/posts/p1/reports",
        json={"reason": "nao_gostei"},
        headers=HEADERS,
    )

    assert r.status_code == 422


def test_denuncia_em_post_inexistente_e_404() -> None:
    client = _client(_FakePostRepo(None), _FakeReportRepo())

    r = client.post(
        "/api/v1/community/posts/p1/reports",
        json={"reason": "spam"},
        headers=HEADERS,
    )

    assert r.status_code == 404


def test_autor_apaga_o_proprio_post() -> None:
    repo = _FakePostRepo(_post(anonymous_id="dispositivo-1"))
    client = _client(repo, _FakeReportRepo())

    r = client.delete("/api/v1/community/posts/p1", headers=HEADERS)

    assert r.status_code == 204
    assert repo.removed == [("p1", "author")]


def test_apagar_post_alheio_e_403() -> None:
    repo = _FakePostRepo(_post(anonymous_id="outro-dispositivo"))
    client = _client(repo, _FakeReportRepo())

    r = client.delete("/api/v1/community/posts/p1", headers=HEADERS)

    assert r.status_code == 403
    assert repo.removed == []


def test_apagar_post_inexistente_e_404() -> None:
    client = _client(_FakePostRepo(None), _FakeReportRepo())

    r = client.delete("/api/v1/community/posts/p1", headers=HEADERS)

    assert r.status_code == 404


def test_sexto_post_na_janela_e_429() -> None:
    repo = _FakePostRepo(_post(), recent=5)
    client = _client(repo, _FakeReportRepo())

    r = client.post(
        "/api/v1/community/posts",
        json={"content": "mais um post"},
        headers=HEADERS,
    )

    assert r.status_code == 429
    assert r.headers["Retry-After"] == "600"
    assert repo.created == []


def test_dentro_do_limite_publica() -> None:
    repo = _FakePostRepo(_post(), recent=4)
    client = _client(repo, _FakeReportRepo())

    r = client.post(
        "/api/v1/community/posts",
        json={"content": "mais um post"},
        headers=HEADERS,
    )

    assert r.status_code == 201


def test_moderacao_indisponivel_recusa_publicacao() -> None:
    app.dependency_overrides[get_post_repo] = lambda: _FakePostRepo(_post())
    app.dependency_overrides[get_post_report_repo] = _FakeReportRepo
    app.dependency_overrides[get_moderation_client] = _DownModeration
    app.dependency_overrides[get_moderation_log_repo] = _FakeModerationLog
    client = TestClient(app)

    r = client.post(
        "/api/v1/community/posts",
        json={"content": "conteudo"},
        headers=HEADERS,
    )

    assert r.status_code == 503
