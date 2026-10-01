#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RESEARCH = ROOT.parent
MATRIX_PATH = RESEARCH / "2026-09-30-v3-delta-validation" / "FINAL_MATRIX.json"
PROFILE_DIR = RESEARCH / "2026-09-29-thematic-profiles" / "profiles"
LENSES_PATH = ROOT / "question-lenses.json"

CLASSIFICATIONS = {
    "CONCORDA",
    "DISCORDA",
    "CONDICIONAL_OU_MISTA",
    "NAO_ENCONTRADA",
}
RELATIONS = {"APOIA", "CONTRADIZ", "QUALIFICA", "CONTEXTO"}
RECOMMENDATIONS = {
    "MANTER",
    "RECLASSIFICAR_CONCORDA",
    "RECLASSIFICAR_DISCORDA",
    "RECLASSIFICAR_CONDICIONAL",
}
CONFIDENCE = {"alta", "media", "baixa"}


def nonempty_text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def load(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_candidate(candidate_id: str) -> list[str]:
    errors: list[str] = []
    matrix = load(MATRIX_PATH)
    lenses = load(LENSES_PATH)
    profile = load(PROFILE_DIR / f"{candidate_id}.json")
    report_path = ROOT / "candidates" / f"{candidate_id}.json"
    if not report_path.exists():
        return [f"arquivo ausente: {report_path}"]
    report = load(report_path)

    matrix_questions = {q["question_id"]: q for q in matrix["questions"]}
    matrix_positions = {
        q["question_id"]: next(
            p for p in q["positions"] if p["candidate_id"] == candidate_id
        )
        for q in matrix["questions"]
    }
    lens_ids = {item["question_id"] for item in lenses["items"]}
    profile_positions = {item["id"]: item for item in profile["positions"]}

    if report.get("candidate_id") != candidate_id:
        errors.append("candidate_id divergente")
    if report.get("candidate_name") != profile.get("candidate_name"):
        errors.append("candidate_name divergente do perfil")
    if report.get("status") != "complete":
        errors.append("status deve ser complete")
    if not nonempty_text(report.get("reviewer_agent_id")):
        errors.append("reviewer_agent_id ausente")

    reviews = report.get("reviews")
    if not isinstance(reviews, list):
        return errors + ["reviews deve ser lista"]
    if len(reviews) != 20:
        errors.append(f"esperadas 20 fichas; recebidas {len(reviews)}")
    review_ids = [item.get("question_id") for item in reviews]
    if len(review_ids) != len(set(review_ids)):
        errors.append("question_id duplicado")
    if set(review_ids) != lens_ids:
        errors.append("conjunto de teses divergente das lentes")

    for index, item in enumerate(reviews, start=1):
        prefix = f"reviews[{index}]"
        question_id = item.get("question_id")
        if question_id not in matrix_questions:
            errors.append(f"{prefix}: question_id desconhecido")
            continue
        question = matrix_questions[question_id]
        current = matrix_positions[question_id]
        expected = {
            "display_number": question["display_number"],
            "statement": question["statement"],
            "category_id": question["category_id"],
            "current_classification": current["classification"],
            "current_rationale": current["rationale"],
        }
        for field, value in expected.items():
            if item.get(field) != value:
                errors.append(f"{prefix}: {field} diverge da matriz")

        if item.get("current_classification") not in CLASSIFICATIONS:
            errors.append(f"{prefix}: classificação inválida")
        for field in (
            "semantic_neighborhood_summary",
            "semantic_assessment",
            "human_review_question",
        ):
            if not nonempty_text(item.get(field)):
                errors.append(f"{prefix}: {field} vazio")
        for field in ("reasons_to_keep", "reasons_to_reconsider"):
            value = item.get(field)
            if not isinstance(value, list) or not value or not all(
                nonempty_text(entry) for entry in value
            ):
                errors.append(f"{prefix}: {field} deve conter argumentos")

        context = item.get("semantic_context")
        absence = item.get("semantic_context_absence_reason")
        if not isinstance(context, list):
            errors.append(f"{prefix}: semantic_context deve ser lista")
            context = []
        if not context and not nonempty_text(absence):
            errors.append(
                f"{prefix}: contexto vazio exige justificativa semântica de ausência"
            )
        for context_index, entry in enumerate(context, start=1):
            context_prefix = f"{prefix}.semantic_context[{context_index}]"
            if entry.get("relation") not in RELATIONS:
                errors.append(f"{context_prefix}: relation inválida")
            if not isinstance(entry.get("page"), int) or entry["page"] < 1:
                errors.append(f"{context_prefix}: page inválida")
            if not nonempty_text(entry.get("quote")):
                errors.append(f"{context_prefix}: quote vazio")
            if not nonempty_text(entry.get("semantic_relevance")):
                errors.append(f"{context_prefix}: semantic_relevance vazio")
            if entry.get("source") not in {"thematic_profile", "full_plan_review"}:
                errors.append(f"{context_prefix}: source inválida")
            position_id = entry.get("source_position_id")
            if entry.get("source") == "thematic_profile":
                if position_id not in profile_positions:
                    errors.append(f"{context_prefix}: position_id não existe no perfil")
                elif not any(
                    evidence.get("page") == entry.get("page")
                    and evidence.get("quote") == entry.get("quote")
                    for evidence in profile_positions[position_id].get("evidence", [])
                ):
                    errors.append(
                        f"{context_prefix}: citação não confere com a posição do perfil"
                    )

        if item.get("preliminary_recommendation") not in RECOMMENDATIONS:
            errors.append(f"{prefix}: recomendação inválida")
        if item.get("confidence") not in CONFIDENCE:
            errors.append(f"{prefix}: confiança inválida")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate")
    args = parser.parse_args()

    matrix = load(MATRIX_PATH)
    candidate_ids = [item["candidate_id"] for item in matrix["candidates"]]
    if args.candidate:
        candidate_ids = [args.candidate]

    all_errors: dict[str, list[str]] = {}
    for candidate_id in candidate_ids:
        errors = validate_candidate(candidate_id)
        if errors:
            all_errors[candidate_id] = errors

    result = {
        "valid": not all_errors,
        "candidates_checked": len(candidate_ids),
        "errors": all_errors,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if not all_errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
