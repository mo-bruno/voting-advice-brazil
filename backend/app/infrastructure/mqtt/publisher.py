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
        publish_attempts: int = 3,
    ) -> None:
        self._broker_url = broker_url or settings.mqtt_broker_url
        self._publish_timeout_seconds = publish_timeout_seconds
        self._publish_attempts = max(1, publish_attempts)

    def publish(self, topic: str, payload: dict[str, str]) -> None:
        parsed = urlparse(self._broker_url)
        host = parsed.hostname or "broker.hivemq.com"
        port = parsed.port or (8883 if parsed.scheme == "mqtts" else 1883)

        last_error: Exception | None = None
        for attempt in range(1, self._publish_attempts + 1):
            client = mqtt.Client(getattr(mqtt, "CallbackAPIVersion").VERSION2)
            if parsed.scheme == "mqtts":
                client.tls_set()

            try:
                rc = client.connect(host, port, keepalive=30)
                if rc != mqtt.MQTT_ERR_SUCCESS:
                    raise ConnectionError(f"MQTT connect failed rc={rc}")
                client.loop_start()
                info = client.publish(topic, json.dumps(payload), qos=1)
                deadline = time.monotonic() + self._publish_timeout_seconds
                while not info.is_published():
                    if time.monotonic() >= deadline:
                        raise TimeoutError("MQTT publish timed out")
                    time.sleep(0.05)
                return
            except Exception as exc:
                last_error = exc
                if attempt == self._publish_attempts:
                    raise
                time.sleep(0.2 * attempt)
            finally:
                client.loop_stop()
                client.disconnect()

        if last_error is not None:
            raise last_error
