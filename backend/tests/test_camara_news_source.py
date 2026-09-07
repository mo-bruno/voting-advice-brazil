from datetime import timezone
from pathlib import Path

import pytest

from app.infrastructure.sources.camara_news import (
    extract_image_url,
    parse_feed,
    parse_pub_date,
    reading_minutes,
)

FIXTURE = Path(__file__).parent / "fixtures" / "camara_eleicoes.xml"

MINIMAL_FEED = b"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <item>
      <title><![CDATA[Eleicoes 2026: conheca as regras]]></title>
      <link>https://www.camara.leg.br/noticias/1302574-regras</link>
      <guid>https://www.camara.leg.br/noticias/1302574-regras</guid>
      <pubDate>Fri, 04 Sep 2026 12:49:00 GMT</pubDate>
      <description><![CDATA[Manual traz orientacoes sobre propaganda]]></description>
      <content:encoded><![CDATA[<div><img src="https://www.camara.leg.br/foto.jpg" alt="x" /></div><p>uma duas tres</p>]]></content:encoded>
    </item>
    <item>
      <title><![CDATA[Sem imagem]]></title>
      <link>https://www.camara.leg.br/noticias/2-sem-imagem</link>
      <guid>https://www.camara.leg.br/noticias/2-sem-imagem</guid>
      <pubDate>Tue, 01 Sep 2026 21:44:00 GMT</pubDate>
      <description><![CDATA[Resumo curto]]></description>
      <content:encoded><![CDATA[<p>texto sem figura</p>]]></content:encoded>
    </item>
  </channel>
</rss>
"""


def test_extrai_a_primeira_imagem_do_corpo() -> None:
    html = '<div><img style="w" src="https://a/1.jpg" /><img src="https://a/2.jpg" /></div>'

    assert extract_image_url(html) == "https://a/1.jpg"


def test_sem_imagem_devolve_none() -> None:
    assert extract_image_url("<p>nada aqui</p>") is None


def test_tempo_de_leitura_arredonda_por_duzentas_palavras() -> None:
    corpo = "<p>" + " ".join(["palavra"] * 471) + "</p>"

    assert reading_minutes(corpo) == 2


def test_tempo_de_leitura_tem_minimo_de_um() -> None:
    assert reading_minutes("<p>tres palavras aqui</p>") == 1


def test_data_rfc822_vira_datetime_utc() -> None:
    dt = parse_pub_date("Fri, 04 Sep 2026 12:49:00 GMT")

    assert dt is not None
    assert dt.year == 2026 and dt.month == 9 and dt.day == 4
    assert dt.tzinfo == timezone.utc


def test_data_invalida_devolve_none() -> None:
    assert parse_pub_date("nao e uma data") is None


def test_parse_feed_monta_os_artigos() -> None:
    articles = parse_feed(MINIMAL_FEED, theme_slug="eleicoes", theme_label="ELEIÇÕES")

    assert len(articles) == 2
    primeiro = articles[0]
    assert primeiro.title == "Eleicoes 2026: conheca as regras"
    assert primeiro.summary == "Manual traz orientacoes sobre propaganda"
    assert primeiro.image_url == "https://www.camara.leg.br/foto.jpg"
    assert primeiro.theme_slug == "eleicoes"
    assert primeiro.theme_label == "ELEIÇÕES"
    assert primeiro.url == "https://www.camara.leg.br/noticias/1302574-regras"
    assert primeiro.id and len(primeiro.id) == 40


def test_parse_feed_aceita_item_sem_imagem() -> None:
    articles = parse_feed(MINIMAL_FEED, theme_slug="eleicoes", theme_label="ELEIÇÕES")

    assert articles[1].image_url is None


def test_parse_feed_ignora_xml_invalido() -> None:
    assert parse_feed(b"<rss><nao fechado>", theme_slug="x", theme_label="X") == []


@pytest.mark.skipif(not FIXTURE.exists(), reason="fixture do feed nao capturada")
def test_parse_do_feed_real() -> None:
    articles = parse_feed(
        FIXTURE.read_bytes(), theme_slug="eleicoes", theme_label="ELEIÇÕES"
    )

    assert len(articles) == 10
    assert all(a.title and a.url and a.reading_minutes >= 1 for a in articles)
    assert any(a.image_url for a in articles)
