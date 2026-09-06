from datetime import datetime, timedelta, timezone

import httpx
import pytest
from fastapi.testclient import TestClient

from app.api.cache import cache_delete_prefix
from app.api.deps import get_weekly_news_source
from app.core.entities.news import NewsArticle
from app.core.use_cases.interfaces import WeeklyNewsSource
from app.main import app


def _article(article_id: str, days_ago: int, image: str | None) -> NewsArticle:
    return NewsArticle(
        id=article_id,
        title=f"Titulo {article_id}",
        summary="Resumo",
        image_url=image,
        theme_slug="eleicoes",
        theme_label="ELEIÇÕES",
        published_at=datetime.now(timezone.utc) - timedelta(days=days_ago),
        reading_minutes=3,
        url=f"https://example.org/{article_id}",
    )


class _FakeSource(WeeklyNewsSource):
    def __init__(self, articles: list[NewsArticle]) -> None:
        self._articles = articles

    def fetch_recent(self) -> list[NewsArticle]:
        return list(self._articles)


def _client(articles: list[NewsArticle]) -> TestClient:
    app.dependency_overrides[get_weekly_news_source] = lambda: _FakeSource(articles)
    return TestClient(app)


def setup_function() -> None:
    # `api/cache.py` é um dicionário de módulo e sobrevive entre testes:
    # sem isto, um teste enxerga a resposta cacheada do anterior.
    cache_delete_prefix("news:weekly")


def teardown_function() -> None:
    app.dependency_overrides.clear()
    cache_delete_prefix("news:weekly")


def test_devolve_os_artigos_da_semana() -> None:
    client = _client([_article("a", 1, "https://img/1.jpg"), _article("b", 30, None)])

    response = client.get("/api/v1/news/weekly")

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 1
    assert body["articles"][0]["id"] == "a"
    assert body["articles"][0]["theme_label"] == "ELEIÇÕES"
    assert body["period_label"]


def test_artigo_sem_imagem_serializa_como_null() -> None:
    client = _client([_article("sem", 1, None)])

    body = client.get("/api/v1/news/weekly").json()

    assert body["articles"][0]["image_url"] is None


def test_semana_vazia_e_200_com_lista_vazia() -> None:
    client = _client([])

    response = client.get("/api/v1/news/weekly")

    assert response.status_code == 200
    assert response.json()["articles"] == []
    assert response.json()["total"] == 0


def test_respeita_o_parametro_limit() -> None:
    client = _client([_article(str(i), 1, None) for i in range(5)])

    body = client.get("/api/v1/news/weekly?limit=2").json()

    assert body["total"] == 2


def test_limit_fora_do_intervalo_e_422() -> None:
    client = _client([])

    assert client.get("/api/v1/news/weekly?limit=0").status_code == 422
    assert client.get("/api/v1/news/weekly?limit=99").status_code == 422


# ── Proxy de imagens ───────────────────────────────────────────────────────
#
# A Camara serve as imagens sem `access-control-allow-origin`, entao o
# CanvasKit do Flutter Web nao consegue desenha-las. Este endpoint busca no
# servidor e reserve com o CORS da nossa API.


class _FakeUpstream:
    def __init__(self, content: bytes, content_type: str, status: int = 200) -> None:
        self.content = content
        self.headers = {"content-type": content_type}
        self._status = status

    def raise_for_status(self) -> None:
        if self._status >= 400:
            raise httpx.HTTPStatusError("erro", request=None, response=None)  # type: ignore[arg-type]


def test_proxy_devolve_a_imagem(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.api.routers.news.httpx.get",
        lambda *a, **k: _FakeUpstream(b"bytes-de-um-jpeg", "image/jpeg"),
    )
    client = TestClient(app)

    response = client.get(
        "/api/v1/news/image",
        params={"url": "https://www.camara.leg.br/midias/image/foto.jpg"},
    )

    assert response.status_code == 200
    assert response.headers["content-type"] == "image/jpeg"
    assert response.content == b"bytes-de-um-jpeg"
    assert "max-age" in response.headers.get("cache-control", "")


def test_proxy_recusa_host_fora_da_allowlist() -> None:
    client = TestClient(app)

    response = client.get(
        "/api/v1/news/image", params={"url": "https://evil.example.com/x.jpg"}
    )

    assert response.status_code == 400


def test_proxy_recusa_host_que_apenas_parece_da_camara() -> None:
    client = TestClient(app)

    for url in (
        "https://camara.leg.br.evil.com/x.jpg",
        "https://evil-camara.leg.br/x.jpg",
        "https://sub.camara.leg.br/x.jpg",
    ):
        assert client.get("/api/v1/news/image", params={"url": url}).status_code == 400


def test_proxy_recusa_esquema_nao_http() -> None:
    client = TestClient(app)

    for url in ("file:///etc/passwd", "gopher://camara.leg.br/x"):
        assert client.get("/api/v1/news/image", params={"url": url}).status_code == 400


def test_proxy_recusa_recurso_que_nao_e_imagem(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        "app.api.routers.news.httpx.get",
        lambda *a, **k: _FakeUpstream(b"<html>", "text/html"),
    )
    client = TestClient(app)

    response = client.get(
        "/api/v1/news/image",
        params={"url": "https://www.camara.leg.br/pagina.html"},
    )

    assert response.status_code == 415


def test_proxy_devolve_502_quando_a_origem_falha(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def _boom(*a: object, **k: object) -> None:
        raise httpx.ConnectError("sem rede")

    monkeypatch.setattr("app.api.routers.news.httpx.get", _boom)
    client = TestClient(app)

    response = client.get(
        "/api/v1/news/image",
        params={"url": "https://www.camara.leg.br/midias/image/foto.jpg"},
    )

    assert response.status_code == 502
