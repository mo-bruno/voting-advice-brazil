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
Avalie o texto do usuário segundo três critérios:

1. RELEVÂNCIA: O texto trata de política, governo, eleições, legislação, partidos
   ou figuras públicas do Brasil? Textos sobre outros assuntos devem ser rejeitados.

2. INTEGRIDADE: O texto contém afirmações factuais claramente falsas, números
   inventados, ou linguagem deliberadamente manipuladora sobre eventos políticos?

3. CIVILIDADE E SEGURANÇA: Rejeite ataques contra pessoas ou grupos, incluindo
   xingamentos direcionados, humilhação sexual, ameaças ou incentivo à violência,
   desumanização, assédio e discurso de ódio. Referências explícitas a sexo ou
   violência usadas para degradar alguém contam como ataque mesmo sem uma ameaça
   gramaticalmente completa. Reconheça essas violações apesar de
   erros de ortografia, abreviações e gírias do português brasileiro.

Críticas duras a ideias, projetos e atos públicos são permitidas, inclusive com
sarcasmo ou linguagem coloquial, desde que não ataquem pessoas ou grupos.

Exemplos:
APROVAR: "As propostas desse partido são péssimas e seus representantes precisam explicar os impactos."
APROVAR: "O governo foi incompetente nessa decisão."
REJEITAR: "Esses políticos merecem apanhar."
REJEITAR: "Esse deputado é um lixo humano."

Responda SOMENTE com JSON, sem markdown, sem texto fora do JSON:
{"approved": true} se o texto passa nos três critérios, ou
{"approved": false, "reason": "explicação curta em português para o autor (máx 200 chars)"}"""

_NVIDIA_NIM_URL = "https://integrate.api.nvidia.com/v1/chat/completions"
_TIMEOUT = 20.0


class NvidiaNimModerationClient(ModerationPort):
    def __init__(
        self,
        api_key: str,
        model: str = "nvidia/nemotron-3-super-120b-a12b",
    ) -> None:
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
            "max_tokens": 512,
            "stream": False,
            "reasoning_effort": "high",
            # Reserve half of the output budget for the required JSON decision.
            "reasoning_budget": 256,
            "messages": [
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
            ],
        }
        try:
            resp = httpx.post(
                _NVIDIA_NIM_URL,
                json=payload,
                headers={
                    "Authorization": f"Bearer {self._api_key}",
                    "Accept": "application/json",
                },
                timeout=_TIMEOUT,
            )
            resp.raise_for_status()
        except httpx.HTTPError:
            # Provider errors may embed credentials, URLs or response content.
            raise ModerationUnavailable("NVIDIA NIM indisponível") from None

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

    Levanta a mesma excecao do NIM fora do ar, de proposito: assim o 503 que o
    router ja trata cobre os dois casos, sem ramo novo.
    """

    def moderate(
        self,
        content: str,
        report_reasons: list[str] | None = None,
    ) -> ModerationResult:
        raise ModerationUnavailable("Moderacao exigida mas nao configurada.")
