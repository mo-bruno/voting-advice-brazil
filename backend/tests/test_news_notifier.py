from datetime import datetime, timezone

from app.core.entities.iot_device import IotDeviceEvent, IotDeviceLink
from app.core.use_cases.news_notifier import push_news_for_user
from app.infrastructure.sources.gnews import NewsArticle
from tests.test_vote_notifier import FakeIotDeviceLinkRepository, FakeIotDeviceEventRepository, FakeIotMqttPublisher


def _make_link():
    return IotDeviceLink(
        device_token="dev-tok",
        anonymous_id="u1",
        status="linked",
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        last_seen_at=None,
    )


def test_push_news_publishes_mqtt():
    link_repo = FakeIotDeviceLinkRepository({"u1": _make_link()})
    event_repo = FakeIotDeviceEventRepository()
    publisher = FakeIotMqttPublisher()
    now = datetime.now(timezone.utc)

    push_news_for_user(
        anonymous_id="u1",
        now=now,
        link_repo=link_repo,
        event_repo=event_repo,
        publisher=publisher,
        fetch_themes=lambda anon_id: ["educacao", "saude"],
        fetch_articles=lambda themes: [NewsArticle("Titulo", "G1", "27/05")],
    )

    assert len(publisher.published) == 1
    assert publisher.published[0]["topic"] == "farol/dev-tok"
    assert publisher.published[0]["payload"]["type"] == "news_batch"


def test_push_news_skips_without_device():
    link_repo = FakeIotDeviceLinkRepository({})
    publisher = FakeIotMqttPublisher()
    event_repo = FakeIotDeviceEventRepository()

    push_news_for_user(
        anonymous_id="u-no-device",
        now=datetime.now(timezone.utc),
        link_repo=link_repo,
        event_repo=event_repo,
        publisher=publisher,
        fetch_themes=lambda _: ["saude"],
        fetch_articles=lambda _: [NewsArticle("T", "S", "01/01")],
    )

    assert publisher.published == []


def test_push_news_skips_without_themes():
    link_repo = FakeIotDeviceLinkRepository({"u1": _make_link()})
    publisher = FakeIotMqttPublisher()
    event_repo = FakeIotDeviceEventRepository()

    push_news_for_user(
        anonymous_id="u1",
        now=datetime.now(timezone.utc),
        link_repo=link_repo,
        event_repo=event_repo,
        publisher=publisher,
        fetch_themes=lambda _: [],
        fetch_articles=lambda _: [],
    )

    assert publisher.published == []
