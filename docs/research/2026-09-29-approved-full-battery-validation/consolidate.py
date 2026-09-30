#!/usr/bin/env python3
"""Consolidate thirteen validated plan reviews without calculating voter affinity."""

import collections
import datetime
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def main():
    state = read(ROOT / "STATE.json")
    questions = read(ROOT / "questions.json")
    validation = read(ROOT / "validation.json")
    assert validation["valid"] and validation["valid_reviews"] == 13

    candidates = {candidate["id"]: candidate for candidate in state["candidates"]}
    reviews = {
        candidate_id: read(ROOT / candidate["review_file"])
        for candidate_id, candidate in candidates.items()
    }
    answer_maps = {
        candidate_id: {answer["question_id"]: answer for answer in review["answers"]}
        for candidate_id, review in reviews.items()
    }

    consolidated_questions = []
    total_codes = collections.Counter()
    suggestions = []
    for question in questions["items"]:
        counts = collections.Counter()
        positions = []
        for candidate_id, candidate in candidates.items():
            answer = answer_maps[candidate_id][question["id"]]
            counts[answer["classification"]] += 1
            total_codes[answer["classification"]] += 1
            positions.append(
                {
                    "candidate_id": candidate_id,
                    "candidate_name": candidate["name"],
                    "classification": answer["classification"],
                    "evidence_strength": answer["evidence_strength"],
                    "rationale": answer["rationale"],
                    "conditions": answer["conditions"],
                    "evidence": answer["evidence"],
                    "counterevidence_or_limits": answer["counterevidence_or_limits"],
                }
            )
            if answer.get("reformulation_suggestion"):
                suggestions.append(
                    {
                        "question_id": question["id"],
                        "candidate_id": candidate_id,
                        "candidate_name": candidate["name"],
                        **answer["reformulation_suggestion"],
                    }
                )
        documented = 13 - counts["NAO_ENCONTRADA"]
        direction_count = sum(bool(counts[code]) for code in ["CONCORDA", "DISCORDA", "CONDICIONAL_OU_MISTA"])
        consolidated_questions.append(
            {
                "question_id": question["id"],
                "display_number": question["display_number"],
                "version": question["version"],
                "statement": question["statement"],
                "category_id": question["category_id"],
                "counts": {code: counts[code] for code in ["CONCORDA", "DISCORDA", "CONDICIONAL_OU_MISTA", "NAO_ENCONTRADA"]},
                "documented_plans": documented,
                "documented_share": round(documented / 13, 4),
                "observed_response_types": direction_count,
                "has_documented_opposition": counts["CONCORDA"] > 0 and counts["DISCORDA"] > 0,
                "positions": positions,
            }
        )

    result = {
        "schema_version": 1,
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "questions_sha256": validation["questions_sha256"],
        "plan_count": 13,
        "question_count": 20,
        "answer_count": 260,
        "classification_totals": dict(total_codes),
        "questions": consolidated_questions,
        "reformulation_suggestions": suggestions,
        "ranking_calculated": False,
        "production_changed": False,
    }
    write(ROOT / "CONSOLIDATION.json", result)

    lines = [
        "# Relatório da validação documental da bateria completa",
        "",
        "Treze planos oficiais foram confrontados com as vinte teses aprovadas. As contagens abaixo medem apenas posições documentadas; ausência de posição não é neutralidade.",
        "",
        "| Nº | Tese | Concorda | Discorda | Mista | Não encontrada | Cobertura | Oposição documentada |",
        "|---:|---|---:|---:|---:|---:|---:|:---:|",
    ]
    for item in consolidated_questions:
        counts = item["counts"]
        statement = item["statement"].replace("|", "\\|")
        lines.append(
            f"| {item['display_number']} | {statement} | {counts['CONCORDA']} | {counts['DISCORDA']} | {counts['CONDICIONAL_OU_MISTA']} | {counts['NAO_ENCONTRADA']} | {item['documented_plans']}/13 | {'sim' if item['has_documented_opposition'] else 'não'} |"
        )
    lines.extend([
        "",
        "## Limites",
        "",
        "A consolidação não calcula afinidade nem decide sozinha quais teses entram no produto. Itens com pouca cobertura, alta incidência de condições ou sugestões de reformulação voltam à análise editorial e, se o significado mudar, à aprovação humana.",
        "",
    ])
    (ROOT / "FINAL_REPORT.md").write_text("\n".join(lines))
    print(json.dumps({"questions": 20, "plans": 13, "answers": 260, "suggestions": len(suggestions)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
