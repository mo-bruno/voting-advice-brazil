import json

import httpx

from app.core.entities.community import ModerationResult
from app.core.use_cases.interfaces import (
    ModerationPort as ModerationPort,
)
from app.core.use_cases.interfaces import (
    ModerationUnavailable as ModerationUnavailable,
)

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


class GroqModerationClient(ModerationPort):
    def __init__(self, api_key: str, model: str = "llama-3.1-8b-instant") -> None:
        self._api_key = api_key
        self._model = model

    def moderate(
        self,
        content: str,
        report_reasons: list[str] | None = None,
    ) -> ModerationResult:
        user_content = content[:1000]
        if report_reasons:
            # So os motivos enumerados entram aqui. Texto livre de terceiros num
            # prompt e vetor de injecao.
            motivos = ", ".join(sorted(set(report_reasons)))
            user_content = (
                user_content
                + "\n\n[Este texto foi denunciado por outros usuários. "
                + f"Motivos alegados: {motivos}. Reavalie com atenção.]"
            )
        payload = {
            "model": self._model,
            "temperature": 0,
            "messages": [
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
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
        except httpx.HTTPError:
            # Provider errors may embed credentials, URLs or response content.
            raise ModerationUnavailable("Groq indisponível") from None

        try:
            raw = resp.json()["choices"][0]["message"]["content"]
            if not isinstance(raw, str):
                raise ValueError("Expected model content as text")
            data = json.loads(raw)
            if not isinstance(data, dict) or not isinstance(data.get("approved"), bool):
                raise ValueError("Expected a boolean moderation decision")
            approved = data["approved"]
            reason = data.get("reason", "")
            if not isinstance(reason, str):
                raise ValueError("Expected a textual moderation reason")
        except (ValueError, KeyError, IndexError, TypeError):
            raise ModerationUnavailable("Resposta inválida do modelo") from None

        return ModerationResult(approved=approved, reason=reason[:200], model_used=self._model)


class FakeModerationClient(ModerationPort):
    """Fake para testes — zero chamadas HTTP."""

    def __init__(self, approved: bool = True, reason: str = "") -> None:
        self._approved = approved
        self._reason = reason

    def moderate(
        self,
        content: str,
        report_reasons: list[str] | None = None,
    ) -> ModerationResult:
        return ModerationResult(
            approved=self._approved,
            reason=self._reason,
            model_used="fake",
        )


class UnavailableModerationClient(ModerationPort):
    """Usado quando `MODERATION_MODE=enforce` e nao ha chave configurada.

    Levanta a mesma excecao do Groq fora do ar, de proposito: assim o 503 que o
    router ja trata cobre os dois casos, sem ramo novo.
    """

    def moderate(
        self,
        content: str,
        report_reasons: list[str] | None = None,
    ) -> ModerationResult:
        raise ModerationUnavailable("Moderacao exigida mas nao configurada.")
