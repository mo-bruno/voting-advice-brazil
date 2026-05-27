from datetime import datetime, timezone

from app.core.use_cases.interfaces import IotDeviceLinkRepository, IotMqttPublisher
from app.core.use_cases.quiz_pulse import publish_quiz_pulse


class FakeLinkRepo(IotDeviceLinkRepository):
    def __init__(self, link=None):
        self._link = link

    def get_by_anonymous_id(self, anonymous_id):
        return self._link

    def get_by_token(self, device_token): ...
    def get_conflicting_link(self, anonymous_id, device_token): ...
    def set_link(self, anonymous_id, device_token, now): ...
    def delete_by_anonymous_id(self, anonymous_id): ...


class FakePublisher(IotMqttPublisher):
    def __init__(self):
        self.calls = []

    def publish(self, topic, payload):
        self.calls.append((topic, payload))


def test_publish_quiz_pulse_sends_mqtt():
    from app.core.entities.iot_device import IotDeviceLink

    link = IotDeviceLink(
        device_token="abc-token",
        anonymous_id="user-1",
        status="linked",
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        last_seen_at=None,
    )
    repo = FakeLinkRepo(link=link)
    publisher = FakePublisher()

    publish_quiz_pulse(
        anonymous_id="user-1",
        answer="agree",
        current=7,
        total=30,
        link_repo=repo,
        publisher=publisher,
    )

    assert len(publisher.calls) == 1
    topic, payload = publisher.calls[0]
    assert topic == "farol/abc-token"
    assert payload["type"] == "quiz_answer"
    assert payload["answer"] == "agree"
    assert payload["current"] == "7"
    assert payload["total"] == "30"


def test_publish_quiz_pulse_silent_when_no_device():
    repo = FakeLinkRepo(link=None)
    publisher = FakePublisher()

    publish_quiz_pulse(
        anonymous_id="user-no-device",
        answer="disagree",
        current=1,
        total=30,
        link_repo=repo,
        publisher=publisher,
    )

    assert publisher.calls == []
