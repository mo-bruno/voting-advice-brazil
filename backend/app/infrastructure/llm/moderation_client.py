import json
from abc import ABC, abstractmethod

import httpx

from app.core.entities.community import ModerationResult

_SYSTEM_PROMPT = """Você é um moderador de conteúdo para uma plataforma de debate político brasileiro.
Avalie o texto do usuário segundo dois critérios:

1. RELEVÂNCIA: O texto trata de política, governo, eleições, legislação, partidos
   ou figuras públicas do Brasil? Textos sobre outros assuntos devem ser rejeitados.

2. INTEGRIDADE: O texto contém afirmações factuais claramente falsas, números
   inventados, ou linguagem deliberadamente manipuladora sobre eventos políticos?

Responda SOMENTE com JSON, sem markdown, sem texto fora do JSON:
{"approved": true} se o texto passa em ambos os critérios, ou
{"approved": false, "reason": "explicação curta em português para o autor (máx 200 chars)"}"""

_GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
_TIMEOUT = 10.0


class ModerationPort(ABC):
    @abstractmethod
    def moderate(self, content: str) -> ModerationResult: ...


class GroqModerationClient(ModerationPort):
    def __init__(self, api_key: str, model: str = "llama-3.1-8b-instant") -> None:
        self._api_key = api_key
        self._model = model

    def moderate(self, content: str) -> ModerationResult:
        payload = {
            "model": self._model,
            "temperature": 0,
            "messages": [
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": content[:1000]},
            ],
        }
        try:
            resp = httpx.post(
                _GROQ_URL,
                json=payload,
                headers={"Authorization": f"Bearer {self._api_key}"},
                timeout=_TIMEOUT,
            )
            resp.raise_for_status()
        except (httpx.TimeoutException, httpx.HTTPStatusError) as exc:
            raise ModerationUnavailable("Groq indisponível") from exc

        raw = resp.json()["choices"][0]["message"]["content"].strip()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ModerationUnavailable("Resposta inválida do modelo") from exc

        approved = bool(data.get("approved", False))
        reason = str(data.get("reason", ""))[:200]
        return ModerationResult(
            approved=approved, reason=reason, model_used=self._model
        )


class FakeModerationClient(ModerationPort):
    """Fake para testes — zero chamadas HTTP."""

    def __init__(self, approved: bool = True, reason: str = "") -> None:
        self._approved = approved
        self._reason = reason

    def moderate(self, content: str) -> ModerationResult:
        return ModerationResult(
            approved=self._approved,
            reason=self._reason,
            model_used="fake",
        )


class ModerationUnavailable(Exception):
    """Raised when Groq is unreachable or returns an unparseable response."""
