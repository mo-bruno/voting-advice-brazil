from unittest.mock import patch, MagicMock

from app.infrastructure.sources.gnews import fetch_news_for_themes, NewsArticle, _CACHE


def _mock_response(articles):
    mock = MagicMock()
    mock.status_code = 200
    mock.json.return_value = {"articles": articles}
    return mock


def test_fetch_news_returns_articles():
    _CACHE.clear()
    fake_articles = [
        {
            "title": "Reforma aprovada",
            "source": {"name": "G1"},
            "publishedAt": "2026-05-27T10:00:00Z",
        }
    ]
    with patch("httpx.get", return_value=_mock_response(fake_articles)):
        result = fetch_news_for_themes(["educacao"], api_key="fake-key")

    assert len(result) == 1
    assert result[0].title == "Reforma aprovada"
    assert result[0].source == "G1"
    assert result[0].date == "27/05"


def test_fetch_news_returns_empty_without_key():
    result = fetch_news_for_themes(["saude"], api_key="")
    assert result == []


def test_fetch_news_cache_is_used():
    _CACHE.clear()
    fake_articles = [
        {"title": "Noticia", "source": {"name": "Folha"}, "publishedAt": "2026-05-27T00:00:00Z"}
    ]
    with patch("httpx.get", return_value=_mock_response(fake_articles)) as mock_get:
        fetch_news_for_themes(["saude"], api_key="k")
        fetch_news_for_themes(["saude"], api_key="k")

    assert mock_get.call_count == 1
