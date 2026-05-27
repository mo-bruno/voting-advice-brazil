import pytest

from app.infrastructure.mqtt import publisher as publisher_module
from app.infrastructure.mqtt.publisher import PahoIotMqttPublisher


class FakePublishInfo:
    def __init__(self, publish_after_checks: int) -> None:
        self._publish_after_checks = publish_after_checks
        self._checks = 0

    def is_published(self) -> bool:
        self._checks += 1
        return self._checks >= self._publish_after_checks


class FakeMqttClient:
    instances: list["FakeMqttClient"] = []
    publish_after_checks: list[int] = []

    def __init__(self, *args, **kwargs) -> None:
        self.published: list[tuple[str, str, int]] = []
        self.tls_enabled = False
        self.connected_to: tuple[str, int, int] | None = None
        FakeMqttClient.instances.append(self)

    def tls_set(self) -> None:
        self.tls_enabled = True

    def connect(self, host: str, port: int, keepalive: int) -> int:
        self.connected_to = (host, port, keepalive)
        return publisher_module.mqtt.MQTT_ERR_SUCCESS

    def loop_start(self) -> None:
        pass

    def publish(self, topic: str, payload: str, qos: int) -> FakePublishInfo:
        self.published.append((topic, payload, qos))
        checks = FakeMqttClient.publish_after_checks.pop(0)
        return FakePublishInfo(checks)

    def loop_stop(self) -> None:
        pass

    def disconnect(self) -> None:
        pass


@pytest.fixture(autouse=True)
def reset_fake_client(monkeypatch):
    FakeMqttClient.instances = []
    FakeMqttClient.publish_after_checks = []
    monkeypatch.setattr(publisher_module.mqtt, "Client", FakeMqttClient)


def test_publisher_retries_after_publish_timeout(monkeypatch):
    FakeMqttClient.publish_after_checks = [999, 1]
    monkeypatch.setattr(publisher_module.time, "sleep", lambda _: None)

    publisher = PahoIotMqttPublisher(
        broker_url="mqtt://broker.hivemq.com:1883",
        publish_timeout_seconds=0.0,
        publish_attempts=2,
    )

    publisher.publish("farol/device-token", {"type": "news_batch"})

    assert len(FakeMqttClient.instances) == 2
    assert FakeMqttClient.instances[0].published[0][0] == "farol/device-token"
    assert FakeMqttClient.instances[1].published[0][0] == "farol/device-token"


def test_publisher_uses_plain_mqtt_without_tls():
    FakeMqttClient.publish_after_checks = [1]

    publisher = PahoIotMqttPublisher(
        broker_url="mqtt://broker.hivemq.com:1883",
        publish_attempts=1,
    )

    publisher.publish("farol/device-token", {"type": "quiz_answer"})

    client = FakeMqttClient.instances[0]
    assert client.connected_to == ("broker.hivemq.com", 1883, 30)
    assert client.tls_enabled is False
