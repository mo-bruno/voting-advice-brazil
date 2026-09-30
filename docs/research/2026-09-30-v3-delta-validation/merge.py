#!/usr/bin/env python3
"""Merge 16 reusable v2 answers with four newly validated v3 answers."""

import collections
import datetime
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RESEARCH = ROOT.parent
PRIOR = RESEARCH / "2026-09-29-approved-full-battery-validation"
BATTERY = RESEARCH / "2026-09-29-full-thesis-battery" / "BATTERY.json"
CATEGORICAL = {"CONCORDA", "DISCORDA"}
DELTA_IDS = {"FB-Q23", "FB-Q24", "FB-Q25", "FB-Q19"}


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def main():
    validation = read(ROOT / "validation.json")
    assert validation["valid"] and validation["valid_reviews"] == 13
    battery = read(BATTERY)
    state = read(ROOT / "STATE.json")
    assert battery["battery_version"] == 3
    candidate_by_id = {candidate["id"]: candidate for candidate in state["candidates"]}

    candidate_answers = {}
    for candidate_id in candidate_by_id:
        prior = read(PRIOR / "reviews" / f"{candidate_id}.json")
        delta = read(ROOT / "reviews" / f"{candidate_id}.json")
        prior_by_id = {answer["question_id"]: answer for answer in prior["answers"]}
        delta_by_id = {answer["question_id"]: answer for answer in delta["answers"]}
        assert set(delta_by_id) == DELTA_IDS
        merged = []
        for item in battery["items"]:
            source_review = delta if item["id"] in DELTA_IDS else prior
            answer = dict(
                delta_by_id[item["id"]]
                if item["id"] in DELTA_IDS
                else prior_by_id[item["id"]]
            )
            assert answer["question_version"] == item["version"]
            assert answer["wording_sha256"] == item["wording_sha256"]
            answer["context_owner_agent_id"] = source_review["context_owner_agent_id"]
            answer["executor_agent_id"] = source_review["executor_agent_id"]
            answer["questions_sha256"] = source_review["questions_sha256"]
            merged.append(answer)
        candidate_answers[candidate_id] = merged

    question_rows = []
    for index, item in enumerate(battery["items"]):
        positions = []
        counts = collections.Counter()
        for candidate_id, answers in candidate_answers.items():
            answer = answers[index]
            counts[answer["classification"]] += 1
            positions.append(
                {
                    "candidate_id": candidate_id,
                    "candidate_name": candidate_by_id[candidate_id]["name"],
                    **answer,
                }
            )
        question_rows.append(
            {
                "question_id": item["id"],
                "display_number": item["display_number"],
                "version": item["version"],
                "statement": item["statement"],
                "category_id": item["category_id"],
                "counts": dict(counts),
                "comparable_plans": sum(counts[code] for code in CATEGORICAL),
                "positions": positions,
            }
        )

    candidates = []
    for candidate_id, answers in candidate_answers.items():
        counts = collections.Counter(answer["classification"] for answer in answers)
        categories = collections.Counter(
            item["category_id"]
            for item, answer in zip(battery["items"], answers)
            if answer["classification"] in CATEGORICAL
        )
        comparable = sum(counts[code] for code in CATEGORICAL)
        candidates.append(
            {
                "candidate_id": candidate_id,
                "candidate_name": candidate_by_id[candidate_id]["name"],
                "party": candidate_by_id[candidate_id]["party"],
                "counts": dict(counts),
                "comparable_positions": comparable,
                "comparable_categories": len(categories),
                "category_counts": dict(categories),
                "ranking_eligible": comparable >= 5 and len(categories) >= 4,
                "answers": answers,
            }
        )
    candidates.sort(key=lambda row: (-row["comparable_positions"], row["candidate_name"]))
    candidates_by_executor = collections.defaultdict(set)
    for row in candidates:
        for answer in row["answers"]:
            candidates_by_executor[answer["executor_agent_id"]].add(
                row["candidate_id"]
            )
    assert all(
        len(candidate_ids) == 1
        for candidate_ids in candidates_by_executor.values()
    ), "An executor agent was reused across candidates"
    result = {
        "schema_version": 1,
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "battery_id": battery["battery_id"],
        "battery_version": 3,
        "question_count": 20,
        "candidate_count": 13,
        "answer_count": 260,
        "reused_v2_answers": 208,
        "new_v3_answers": 52,
        "excluded_candidate_ids": ["280002553884"],
        "agent_exclusivity": {
            "validated": True,
            "executor_count": len(candidates_by_executor),
            "cross_candidate_reuse": False,
        },
        "ranking_eligibility_rule": {
            "minimum_comparable_positions": 5,
            "minimum_comparable_categories": 4,
            "conditional_positions_are_comparable": False,
            "status": "adopted_affinity_beta_v1",
        },
        "questions": question_rows,
        "candidates": candidates,
        "production_changed": False,
        "ranking_calculated": False,
    }
    write(ROOT / "FINAL_MATRIX.json", result)

    lines = [
        "# Matriz documental final — bateria versão 3",
        "",
        "A matriz combina 208 respostas reutilizadas da versão 2 e 52 respostas reclassificadas para as quatro teses alteradas. Ausência de posição não é neutralidade.",
        "",
        "## Cobertura por tese",
        "",
        "| Nº | Tese | Concorda | Discorda | Mista | Não encontrada | Cobertura |",
        "|---:|---|---:|---:|---:|---:|---:|",
    ]
    for row in question_rows:
        c = row["counts"]
        lines.append(
            f"| {row['display_number']} | {row['statement']} | {c.get('CONCORDA', 0)} | {c.get('DISCORDA', 0)} | {c.get('CONDICIONAL_OU_MISTA', 0)} | {c.get('NAO_ENCONTRADA', 0)} | {row['comparable_plans']}/13 |"
        )
    lines.extend(
        [
            "",
            "## Cobertura por candidatura",
            "",
            "| Candidatura | Posições comparáveis | Categorias | Elegível no beta 5/4 |",
            "|---|---:|---:|:---:|",
        ]
    )
    for row in candidates:
        lines.append(
            f"| {row['candidate_name']} | {row['comparable_positions']}/20 | {row['comparable_categories']}/10 | {'sim' if row['ranking_eligible'] else 'não'} |"
        )
    lines.extend(
        [
            "",
            "A edição beta adota o piso de cinco posições comparáveis em quatro categorias. Posições condicionais ou mistas permanecem documentadas, mas não entram como resposta neutra nem como comparação no ranking.",
            "",
        ]
    )
    (ROOT / "FINAL_REPORT.md").write_text("\n".join(lines))
    print(json.dumps({"questions": 20, "candidates": 13, "answers": 260, "eligible": sum(row["ranking_eligible"] for row in candidates)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
