from __future__ import annotations

import json

from google import genai
from google.genai import types

from app.core.entities.political_actor import OfficialEvidence, SectionSummary

GEMINI_MODEL = "gemini-2.5-flash"
_SECTION_ERROR_SUMMARY = "Não foi possível gerar o resumo neste momento."
_SYNTHESIS_ERROR_SUMMARY = "Não foi possível gerar a síntese neste momento."
_INSUFFICIENT_DATA_SUMMARY = "Sem registros suficientes neste período."
_UNVERIFIABLE_SUMMARY = "Sem registros verificáveis neste período."

_SYSTEM_PROMPT = """Você é o Sentinela, um agente de análise política estritamente factual.

REGRAS ABSOLUTAS:
- Sua ÚNICA fonte de verdade são os dados fornecidos nesta mensagem.
- NUNCA use conhecimento geral ou de treinamento sobre este político.
- NUNCA infira, extrapole ou suponha além do que está nos dados.
- Se os dados forem insuficientes para uma afirmação, escreva exatamente: "Sem registros suficientes neste período."
- Cada afirmação factual DEVE referenciar um source_id dos dados fornecidos.
- Responda SOMENTE em JSON válido, sem texto fora do JSON."""

_EVIDENCE_TYPE_LABELS = {
    "vote": "votações nominais",
    "proposition": "proposições apresentadas",
    "expense": "despesas parlamentares",
}

_SYNTHESIS_PROMPT = """Você é o Sentinela, um agente de análise política estritamente factual.

Com base nos três resumos abaixo (votos, proposições e despesas), escreva um parágrafo de síntese
de 3 a 5 frases em português brasileiro descrevendo a atuação do deputado no período indicado.
Use APENAS as informações presentes nos resumos. Responda com uma string de texto simples, sem JSON."""


def _serialize_evidence(evidence_list: list[OfficialEvidence]) -> str:
    items = []
    for e in evidence_list:
        items.append({
            "source_id": e.source_id,
            "date": e.evidence_date.isoformat() if e.evidence_date else None,
            "title": e.title,
            "summary": e.summary,
            "source_url": e.source_url,
        })
    return json.dumps(items, ensure_ascii=False, indent=2)


def _validate_citations(
    section: SectionSummary,
    evidence_list: list[OfficialEvidence],
) -> SectionSummary:
    valid_pairs = {
        (e.source_id, e.source_url)
        for e in evidence_list
        if e.source_id and e.source_url
    }
    valid_citations: list[dict[str, str]] = []
    for citation in section.citations:
        source_id = citation.get("source_id")
        source_url = citation.get("source_url")
        label = citation.get("label")
        if (
            isinstance(source_id, str)
            and isinstance(source_url, str)
            and isinstance(label, str)
            and (source_id, source_url) in valid_pairs
        ):
            valid_citations.append({
                "label": label,
                "source_id": source_id,
                "source_url": source_url,
            })

    if not valid_citations and section.summary != _INSUFFICIENT_DATA_SUMMARY:
        return SectionSummary(
            summary=_UNVERIFIABLE_SUMMARY,
            citations=[],
        )
    return SectionSummary(summary=section.summary, citations=valid_citations)


def generate_section_summary(
    api_key: str,
    actor_name: str,
    evidence_type: str,
    evidence_list: list[OfficialEvidence],
    period_label: str,
) -> SectionSummary:
    if not evidence_list:
        return SectionSummary(summary="Sem registros neste período.", citations=[])

    type_label = _EVIDENCE_TYPE_LABELS.get(evidence_type, evidence_type)
    prompt = (
        f"Deputado: {actor_name}\n"
        f"Período: {period_label}\n"
        f"Categoria: {type_label}\n\n"
        f"REGISTROS (total: {len(evidence_list)}):\n"
        f"{_serialize_evidence(evidence_list)}\n\n"
        "Gere um resumo factual em português brasileiro.\n"
        'Schema obrigatório: {"summary": "string", "citations": [{"label": "string", "source_id": "string", "source_url": "string"}]}'
    )

    try:
        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=_SYSTEM_PROMPT,
                temperature=0.1,
                response_mime_type="application/json",
            ),
        )
        if not response.text:
            return SectionSummary(summary=_SECTION_ERROR_SUMMARY, citations=[])
        data = json.loads(response.text)
        raw_section = SectionSummary(
            summary=str(data.get("summary", "Sem resumo disponível.")),
            citations=data.get("citations", []),
        )
        return _validate_citations(raw_section, evidence_list)
    except Exception:
        return SectionSummary(
            summary=_SECTION_ERROR_SUMMARY,
            citations=[],
        )


def generate_synthesis(
    api_key: str,
    actor_name: str,
    votes_summary: str,
    propositions_summary: str,
    expenses_summary: str,
    period_label: str,
) -> str:
    prompt = (
        f"Deputado: {actor_name}\n"
        f"Período: {period_label}\n\n"
        f"Resumo de votações: {votes_summary}\n"
        f"Resumo de proposições: {propositions_summary}\n"
        f"Resumo de despesas: {expenses_summary}\n"
    )

    try:
        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=_SYNTHESIS_PROMPT,
                temperature=0.1,
            ),
        )
        if not response.text:
            return _SYNTHESIS_ERROR_SUMMARY
        text = response.text.strip()
        if not text:
            return _SYNTHESIS_ERROR_SUMMARY
        return text
    except Exception:
        return _SYNTHESIS_ERROR_SUMMARY
