from datetime import datetime, timedelta, timezone

from app.core.entities.news import NewsArticle
from app.core.use_cases.interfaces import WeeklyNewsSource
from app.core.use_cases.list_weekly_news import format_period_label, list_weekly_news

NOW = datetime(2026, 9, 6, 12, 0, tzinfo=timezone.utc)


def _article(article_id: str, days_ago: float) -> NewsArticle:
    return NewsArticle(
        id=article_id,
        title=f"Titulo {article_id}",
        summary="Resumo",
        image_url=None,
        theme_slug="eleicoes",
        theme_label="ELEIÇÕES",
        published_at=NOW - timedelta(days=days_ago),
        reading_minutes=3,
        url=f"https://example.org/{article_id}",
    )


class _FakeSource(WeeklyNewsSource):
    def __init__(self, articles: list[NewsArticle]) -> None:
        self._articles = articles

    def fetch_recent(self) -> list[NewsArticle]:
        return list(self._articles)


def test_mantem_apenas_os_ultimos_sete_dias() -> None:
    source = _FakeSource([_article("dentro", 2), _article("fora", 9)])

    result = list_weekly_news(source, now=NOW)

    assert [a.id for a in result.articles] == ["dentro"]


def test_ordena_do_mais_recente_para_o_mais_antigo() -> None:
    source = _FakeSource([_article("velho", 5), _article("novo", 1)])

    result = list_weekly_news(source, now=NOW)

    assert [a.id for a in result.articles] == ["novo", "velho"]


def test_deduplica_por_id() -> None:
    source = _FakeSource([_article("mesmo", 1), _article("mesmo", 2)])

    result = list_weekly_news(source, now=NOW)

    assert len(result.articles) == 1


def test_respeita_o_limite() -> None:
    source = _FakeSource([_article(str(i), i) for i in range(1, 7)])

    result = list_weekly_news(source, now=NOW, limit=2)

    assert len(result.articles) == 2


def test_descarta_artigo_com_data_no_futuro() -> None:
    source = _FakeSource([_article("futuro", -1)])

    result = list_weekly_news(source, now=NOW)

    assert result.articles == []


def test_fonte_vazia_devolve_lista_vazia_sem_erro() -> None:
    result = list_weekly_news(_FakeSource([]), now=NOW)

    assert result.articles == []
    assert result.period_label


def test_rotulo_do_periodo_em_portugues() -> None:
    start = datetime(2026, 8, 30, tzinfo=timezone.utc)
    end = datetime(2026, 9, 6, tzinfo=timezone.utc)

    assert format_period_label(start, end) == "30 DE AGO A 6 DE SET DE 2026"


def test_periodo_calculado_cobre_sete_dias() -> None:
    result = list_weekly_news(_FakeSource([]), now=NOW)

    assert (result.period_end - result.period_start) == timedelta(days=7)
