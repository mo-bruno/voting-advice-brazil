import json
from urllib.parse import urlparse

import paho.mqtt.client as mqtt

from app.core.config import settings
from app.core.use_cases.interfaces import IotMqttPublisher


class PahoIotMqttPublisher(IotMqttPublisher):
    def __init__(self, broker_url: str | None = None) -> None:
        self._broker_url = broker_url or settings.mqtt_broker_url

    def publish(self, topic: str, payload: dict[str, str]) -> None:
        parsed = urlparse(self._broker_url)
        host = parsed.hostname or "broker.hivemq.com"
        port = parsed.port or (8883 if parsed.scheme == "mqtts" else 1883)

        client = mqtt.Client(getattr(mqtt, "CallbackAPIVersion").VERSION2)
        if parsed.scheme == "mqtts":
            client.tls_set()

        client.connect(host, port)
        client.loop_start()
        try:
            info = client.publish(topic, json.dumps(payload), qos=1)
            info.wait_for_publish()
        finally:
            client.loop_stop()
            client.disconnect()
