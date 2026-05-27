import pytest

from app.infrastructure.mqtt import publisher as publisher_module
from app.infrastructure.mqtt.publisher import PahoIotMqttPublisher


class FakePublishInfo:
    def __init__(self, publish_after_checks: int, rc: int = 0) -> None:
        self._publish_after_checks = publish_after_checks
        self._checks = 0
        self.rc = rc

    def is_published(self) -> bool:
        self._checks += 1
        return self._checks >= self._publish_after_checks


class FakeMqttClient:
    instances: list["FakeMqttClient"] = []
    publish_after_checks: list[int] = []
    publish_return_codes: list[int] = []

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
        rc = (
            FakeMqttClient.publish_return_codes.pop(0)
            if FakeMqttClient.publish_return_codes
            else publisher_module.mqtt.MQTT_ERR_SUCCESS
        )
        return FakePublishInfo(checks, rc=rc)

    def loop_stop(self) -> None:
        pass

    def disconnect(self) -> None:
        pass


@pytest.fixture(autouse=True)
def reset_fake_client(monkeypatch):
    FakeMqttClient.instances = []
    FakeMqttClient.publish_after_checks = []
    FakeMqttClient.publish_return_codes = []
    monkeypatch.setattr(publisher_module.mqtt, "Client", FakeMqttClient)


def test_publisher_retries_after_publish_error():
    FakeMqttClient.publish_after_checks = [1, 1]
    FakeMqttClient.publish_return_codes = [1, 0]

    publisher = PahoIotMqttPublisher(
        broker_url="mqtt://broker.hivemq.com:1883",
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
    assert client.published[0][2] == 0


def test_publisher_succeeds_without_waiting_for_puback(monkeypatch):
    FakeMqttClient.publish_after_checks = [999]

    publisher = PahoIotMqttPublisher(
        broker_url="mqtt://broker.hivemq.com:1883",
        publish_attempts=1,
    )

    publisher.publish("farol/device-token", {"type": "news_batch"})

    assert len(FakeMqttClient.instances) == 1
    assert FakeMqttClient.instances[0].published[0][2] == 0
