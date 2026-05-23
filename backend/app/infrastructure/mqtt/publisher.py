import json
import time
from urllib.parse import urlparse

import paho.mqtt.client as mqtt

from app.core.config import settings
from app.core.use_cases.interfaces import IotMqttPublisher


class PahoIotMqttPublisher(IotMqttPublisher):
    def __init__(
        self,
        broker_url: str | None = None,
        publish_timeout_seconds: float = 5.0,
    ) -> None:
        self._broker_url = broker_url or settings.mqtt_broker_url
        self._publish_timeout_seconds = publish_timeout_seconds

    def publish(self, topic: str, payload: dict[str, str]) -> None:
        parsed = urlparse(self._broker_url)
        host = parsed.hostname or "broker.hivemq.com"
        port = parsed.port or (8883 if parsed.scheme == "mqtts" else 1883)

        client = mqtt.Client(getattr(mqtt, "CallbackAPIVersion").VERSION2)
        if parsed.scheme == "mqtts":
            client.tls_set()

        client.connect(host, port, keepalive=30)
        client.loop_start()
        try:
            info = client.publish(topic, json.dumps(payload), qos=1)
            deadline = time.monotonic() + self._publish_timeout_seconds
            while not info.is_published():
                if time.monotonic() >= deadline:
                    raise TimeoutError("MQTT publish timed out")
                time.sleep(0.05)
        finally:
            client.loop_stop()
            client.disconnect()
