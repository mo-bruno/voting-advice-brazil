import json
import traceback

import httpx
import pytest

from app.api import deps
from app.config import settings
from app.core.use_cases.interfaces import ModerationUnavailable
from app.infrastructure.llm.moderation_client import NvidiaNimModerationClient

_PRIVATE_MARKER = "private-provider-body-and-credential"


def _assert_unavailable_without_provider_details() -> None:
    with pytest.raises(ModerationUnavailable) as caught:
        NvidiaNimModerationClient(api_key=_PRIVATE_MARKER).moderate("Debate político")
    rendered = "".join(traceback.format_exception(caught.value))
    assert _PRIVATE_MARKER not in rendered
    assert caught.value.__cause__ is None


@pytest.mark.parametrize(
    "error_type",
    [
        httpx.ConnectError,
        httpx.ReadError,
        httpx.WriteError,
        httpx.CloseError,
        httpx.ConnectTimeout,
        httpx.ReadTimeout,
        httpx.WriteTimeout,
        httpx.PoolTimeout,
        httpx.RemoteProtocolError,
        httpx.LocalProtocolError,
        httpx.ProxyError,
        httpx.UnsupportedProtocol,
        httpx.DecodingError,
        httpx.TooManyRedirects,
    ],
)
def test_transport_failures_are_unavailable_without_provider_details(
    monkeypatch: pytest.MonkeyPatch,
    error_type: type[httpx.RequestError],
) -> None:
    def fail_post(*args: object, **kwargs: object) -> httpx.Response:
        raise error_type(_PRIVATE_MARKER)

    monkeypatch.setattr(httpx, "post", fail_post)
    _assert_unavailable_without_provider_details()


def test_http_status_failure_is_unavailable_without_provider_details(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    response = httpx.Response(
        503,
        text=_PRIVATE_MARKER,
        request=httpx.Request("POST", f"https://provider.invalid/{_PRIVATE_MARKER}"),
    )
    monkeypatch.setattr(httpx, "post", lambda *args, **kwargs: response)
    _assert_unavailable_without_provider_details()


def test_moderation_uses_bounded_nvidia_nim_request(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def record_post(
        url: str,
        *,
        json: dict[str, object],
        headers: dict[str, str],
        timeout: float,
    ) -> httpx.Response:
        assert url == "https://integrate.api.nvidia.com/v1/chat/completions"
        assert json["model"] == "nvidia/test-model"
        assert json["temperature"] == 0
        assert json["max_tokens"] == 512
        assert json["stream"] is False
        assert json["chat_template_kwargs"] == {"enable_thinking": True}
        assert headers == {
            "Authorization": "Bearer nvapi-test",
            "Accept": "application/json",
        }
        assert 0 < timeout <= 30
        messages = json["messages"]
        assert isinstance(messages, list)
        assert [message["role"] for message in messages] == ["system", "user"]
        assert messages[1]["content"] == "Debate político"
        return httpx.Response(
            200,
            json={"choices": [{"message": {"content": '{"approved": true}'}}]},
            request=httpx.Request("POST", url),
        )

    monkeypatch.setattr(httpx, "post", record_post)

    result = NvidiaNimModerationClient(
        api_key="nvapi-test", model="nvidia/test-model"
    ).moderate("Debate político")

    assert result.approved is True


def test_dependency_uses_configured_nvidia_model(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "moderation_mode", "enforce")
    monkeypatch.setattr(settings, "nvidia_api_key", "nvapi-test")
    monkeypatch.setattr(
        settings,
        "nvidia_moderation_model",
        "nvidia/configured-model",
    )

    def approve(
        url: str,
        *,
        json: dict[str, object],
        headers: dict[str, str],
        timeout: float,
    ) -> httpx.Response:
        assert json["model"] == "nvidia/configured-model"
        return httpx.Response(
            200,
            json={"choices": [{"message": {"content": '{"approved": true}'}}]},
            request=httpx.Request("POST", url),
        )

    monkeypatch.setattr(httpx, "post", approve)

    result = deps.get_moderation_client().moderate("Debate político")

    assert result.approved is True


@pytest.mark.parametrize(
    "body",
    [
        _PRIVATE_MARKER.encode(),
        b"\xff",
        b"null",
        b"[]",
        b"{}",
        b'{"choices": []}',
        b'{"choices": null}',
        b'{"choices": [{}]}',
        b'{"choices": [{"message": null}]}',
        b'{"choices": [{"message": {}}]}',
        b'{"choices": [{"message": {"content": null}}]}',
        b'{"choices": [{"message": {"content": 1}}]}',
    ],
)
def test_malformed_provider_envelope_is_unavailable(
    monkeypatch: pytest.MonkeyPatch,
    body: bytes,
) -> None:
    response = httpx.Response(
        200, content=body, request=httpx.Request("POST", "https://provider.invalid")
    )
    monkeypatch.setattr(httpx, "post", lambda *args, **kwargs: response)
    _assert_unavailable_without_provider_details()


@pytest.mark.parametrize(
    "content",
    [
        _PRIVATE_MARKER,
        "null",
        "[]",
        '"text"',
        "{}",
        '{"approved": "false"}',
        '{"approved": 1}',
        '{"approved": null}',
        '{"approved": false, "reason": []}',
        '{"approved": false, "reason": null}',
    ],
)
def test_malformed_model_decision_is_unavailable(
    monkeypatch: pytest.MonkeyPatch,
    content: str,
) -> None:
    response = httpx.Response(
        200,
        json={"choices": [{"message": {"content": content}}]},
        request=httpx.Request("POST", "https://provider.invalid"),
    )
    monkeypatch.setattr(httpx, "post", lambda *args, **kwargs: response)
    _assert_unavailable_without_provider_details()


@pytest.mark.parametrize(
    ("decision", "approved", "reason"),
    [
        ({"approved": True}, True, ""),
        ({"approved": False, "reason": "Fora de tema"}, False, "Fora de tema"),
        ({"approved": False, "reason": "x" * 250}, False, "x" * 200),
    ],
)
def test_valid_decisions_preserve_approval_rejection_and_reason_limit(
    monkeypatch: pytest.MonkeyPatch,
    decision: dict[str, object],
    approved: bool,
    reason: str,
) -> None:
    response = httpx.Response(
        200,
        json={"choices": [{"message": {"content": json.dumps(decision)}}]},
        request=httpx.Request("POST", "https://provider.invalid"),
    )
    monkeypatch.setattr(httpx, "post", lambda *args, **kwargs: response)
    result = NvidiaNimModerationClient(api_key="test", model="test-model").moderate(
        "Debate político", report_reasons=["spam"]
    )
    assert result.approved is approved
    assert result.reason == reason
    assert result.model_used == "test-model"
