#!/usr/bin/env python3
"""Publish the approved 2026 beta battery and its audited plan matrix."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
OFFICIAL_SOURCE_URL = (
    "https://cdn.tse.jus.br/estatistica/sead/odsele/proposta_governo/"
    "proposta_governo_2026_BR.zip"
)
POSITION_MAP = {
    "CONCORDA": "concordo",
    "DISCORDA": "discordo",
    # A posição condicionada preserva evidência, mas não equivale à resposta
    # neutra do usuário e não pode entrar no cálculo como se equivalesse.
    "CONDICIONAL_OU_MISTA": "sem_posicao",
    "NAO_ENCONTRADA": "sem_posicao",
}


def _read(path: Path) -> dict[str, Any] | list[dict[str, Any]]:
    return json.loads(path.read_text(encoding="utf-8"))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _json(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def _position(
    *,
    answer: dict[str, Any],
    candidate: dict[str, Any],
) -> dict[str, Any]:
    candidate_id = candidate["id"]
    document_id = f"PG_2026_BR_{candidate_id}_01"
    evidence = [
        {
            "page": item["page"],
            "quote": item["quote"],
            "role": item["role"],
            "interpretation": item["interpretation"],
            "document_id": document_id,
            "sha256": candidate["sha256"],
            "archive_member": candidate["official_member"],
            "url": OFFICIAL_SOURCE_URL,
        }
        for item in answer["evidence"]
    ]
    quote = "\n\n".join(
        f"[p. {item['page']}] {item['quote']}" for item in answer["evidence"]
    )
    source_ref = "; ".join(
        f"{document_id}#page={item['page']}" for item in answer["evidence"]
    )
    analytical = answer["classification"]
    return {
        "position": POSITION_MAP[analytical],
        "analytical_position": analytical,
        "justification": answer["rationale"],
        "quote": quote or None,
        "source_ref": source_ref or document_id,
        "source_url": OFFICIAL_SOURCE_URL,
        "evidence": evidence,
        "review": {
            "status": "full_document_reviewed_agent",
            "reason": answer["rationale"],
            "evidence_strength": answer["evidence_strength"],
            "conditions": answer["conditions"],
            "counterevidence_or_limits": answer["counterevidence_or_limits"],
            "search_terms": answer["search_terms"],
            "searched_page_ranges": answer["searched_page_ranges"],
            "absence_reason": (
                answer["rationale"] if analytical == "NAO_ENCONTRADA" else None
            ),
            "full_text_search_completed": True,
            "context_owner_agent_id": candidate["context_owner_agent_id"],
            "executor_agent_id": answer["executor_agent_id"],
            "document_id": document_id,
            "document_sha256": candidate["sha256"],
            "questions_sha256": answer["questions_sha256"],
        },
    }


def build(
    *,
    battery_path: Path,
    matrix_path: Path,
    state_path: Path,
    source_check_path: Path,
    candidates_path: Path,
) -> tuple[dict[str, Any], dict[str, Any]]:
    battery = _read(battery_path)
    matrix = _read(matrix_path)
    state = _read(state_path)
    source_check = _read(source_check_path)
    published_candidates = _read(candidates_path)
    assert isinstance(battery, dict)
    assert isinstance(matrix, dict)
    assert isinstance(state, dict)
    assert isinstance(source_check, dict)
    assert isinstance(published_candidates, list)

    assert battery["status"] == "approved"
    assert battery["battery_version"] == 3
    assert battery["item_count"] == 20
    assert matrix["question_count"] == 20
    assert matrix["candidate_count"] == 13
    assert matrix["answer_count"] == 260
    assert source_check["all_included_plan_hashes_unchanged"] is True
    assert source_check["official_download_url"] == OFFICIAL_SOURCE_URL

    candidate_state = {candidate["id"]: candidate for candidate in state["candidates"]}
    published_ids = {candidate["id"] for candidate in published_candidates}
    assert set(candidate_state) == published_ids
    assert "280002553884" not in published_ids

    matrix_candidates = {
        candidate["candidate_id"]: candidate for candidate in matrix["candidates"]
    }
    assert set(matrix_candidates) == published_ids
    items = {item["id"]: item for item in battery["items"]}
    assert list(items) == [question["question_id"] for question in matrix["questions"]]

    theses = []
    for question in matrix["questions"]:
        item = items[question["question_id"]]
        positions = {}
        for row in question["positions"]:
            candidate_id = row["candidate_id"]
            answer = dict(row)
            assert answer["context_owner_agent_id"] == candidate_state[candidate_id][
                "context_owner_agent_id"
            ]
            positions[candidate_id] = _position(
                answer=answer,
                candidate=candidate_state[candidate_id],
            )
        theses.append(
            {
                "id": item["id"],
                "version": item["version"],
                "text": item["statement"],
                "topic": item["category_id"],
                "status": "approved",
                "display_order": item["display_number"],
                "wording_sha256": item["wording_sha256"],
                "decision_object": item["decision_object"],
                "question_explanation": item["explanation"],
                "measurement_risks": item["measurement_risks"],
                "positions": positions,
            }
        )

    analysed_documents = {
        candidate_id: {
            "document_id": f"PG_2026_BR_{candidate_id}_01",
            "archive_member": candidate["official_member"],
            "pages_total": candidate["pages"],
            "pages_reviewed": list(range(1, candidate["pages"] + 1)),
            "sha256": candidate["sha256"],
        }
        for candidate_id, candidate in candidate_state.items()
    }
    coverage = {
        candidate_id: {
            "comparable_theses": candidate["comparable_positions"],
            "comparable_categories": candidate["comparable_categories"],
            "ranking_eligible": candidate["ranking_eligible"],
        }
        for candidate_id, candidate in matrix_candidates.items()
    }
    payload = {
        "metadata": {
            "election": 2026,
            "office": "presidente",
            "country": "BR",
            "version": 7,
            "edition_state": "beta",
            "generated_at": source_check["checked_at"],
            "battery_id": battery["battery_id"],
            "battery_version": battery["battery_version"],
            "methodology_version": "affinity-beta-v1",
            "battery_human_approved": True,
            "candidate_positions_human_reviewed": False,
            "documentary_review_status": "complete_agent_review",
            "response_buttons": battery["response_buttons"],
            "published_theses": len(theses),
            "reviewed_cells": len(theses) * len(published_ids),
            "excluded_candidate_ids": ["280002553884"],
            "ranking_eligibility": {
                "minimum_comparable_theses": 5,
                "minimum_comparable_categories": 4,
                "conditional_positions_are_comparable": False,
            },
            "source_archive": {
                "url": source_check["official_download_url"],
                "sha256": source_check["archive_sha256"],
                "last_modified": source_check["last_modified"],
                "all_included_plan_hashes_unchanged": True,
            },
            "editorial_inputs": {
                "battery_file": str(battery_path.relative_to(REPOSITORY_ROOT)),
                "battery_sha256": _sha256(battery_path),
                "matrix_file": str(matrix_path.relative_to(REPOSITORY_ROOT)),
                "matrix_sha256": _sha256(matrix_path),
                "state_file": str(state_path.relative_to(REPOSITORY_ROOT)),
                "state_sha256": _sha256(state_path),
            },
            "analysed_documents": analysed_documents,
            "candidate_coverage": coverage,
        },
        "theses": theses,
    }

    explanation_source = {
        "title": "TSE — propostas de governo para Presidente em 2026",
        "url": OFFICIAL_SOURCE_URL,
    }
    explanations = {
        "election_year": 2026,
        "updated_at": "2026-09-30",
        "explanations": [
            {
                "thesis_id": item["id"],
                "thesis_version": item["version"],
                "thesis_text": item["statement"],
                "paragraphs": [
                    item["explanation"],
                    (
                        f"A decisão comparada nesta tese é: {item['decision_object']} "
                        "A classificação de cada candidatura usa apenas o que está "
                        "documentado em seu plano oficial."
                    ),
                ],
                "sources": [explanation_source],
            }
            for item in battery["items"]
        ],
    }
    return payload, explanations


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    research = REPOSITORY_ROOT / "docs" / "research"
    parser.add_argument(
        "--battery",
        type=Path,
        default=research / "2026-09-29-full-thesis-battery" / "BATTERY.json",
    )
    parser.add_argument(
        "--matrix",
        type=Path,
        default=research / "2026-09-30-v3-delta-validation" / "FINAL_MATRIX.json",
    )
    parser.add_argument(
        "--state",
        type=Path,
        default=research / "2026-09-30-v3-delta-validation" / "STATE.json",
    )
    parser.add_argument(
        "--source-check",
        type=Path,
        default=research / "2026-09-30-v3-delta-validation" / "SOURCE_CHECK.json",
    )
    parser.add_argument(
        "--candidates",
        type=Path,
        default=REPOSITORY_ROOT / "data" / "propostas" / "2026" / "candidates.json",
    )
    parser.add_argument(
        "--theses-output",
        type=Path,
        default=REPOSITORY_ROOT / "data" / "theses" / "2026" / "theses.json",
    )
    parser.add_argument(
        "--explanations-output",
        type=Path,
        default=REPOSITORY_ROOT / "data" / "theses" / "2026" / "explanations.json",
    )
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    payload, explanations = build(
        battery_path=args.battery.resolve(),
        matrix_path=args.matrix.resolve(),
        state_path=args.state.resolve(),
        source_check_path=args.source_check.resolve(),
        candidates_path=args.candidates.resolve(),
    )
    rendered = {
        args.theses_output: _json(payload),
        args.explanations_output: _json(explanations),
    }
    if args.check:
        mismatches = [
            str(path) for path, content in rendered.items()
            if not path.exists() or path.read_text(encoding="utf-8") != content
        ]
        if mismatches:
            raise SystemExit("Snapshots desatualizados: " + ", ".join(mismatches))
        print("Snapshots de afinidade beta estão atualizados.")
        return
    for path, content in rendered.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    print(f"Publicadas {len(payload['theses'])} teses e {len(explanations['explanations'])} explicações.")


if __name__ == "__main__":
    main()
