#pragma once

#define API_BASE_URL      "https://farol-politico-api-ia6m2uvoba-uk.a.run.app/api/v1"
#define MQTT_BROKER       "broker.hivemq.com"
#define MQTT_PORT         1883
#define MQTT_TOPIC_PREFIX "farol/"

#define UART_BAUD         115200
#define UART_RX_PIN       16
#define UART_TX_PIN       17

#define LED_PIN_R         25
#define LED_PIN_G         26
#define LED_PIN_B         27
#define BUTTON_PIN        4

#define NVS_NAMESPACE     "farol"
#define NVS_TOKEN_KEY     "device_token"

#define PAIRING_CODE_MIN  100000
#define PAIRING_CODE_MAX  999999
#define PAIRING_DEBOUNCE_MS 50
#define PAIRING_HOLD_MS   1500
#define PAIRING_CONFIRM_TIMEOUT_MS 60000
#define PAIRING_STATUS_POLL_MS 2000
