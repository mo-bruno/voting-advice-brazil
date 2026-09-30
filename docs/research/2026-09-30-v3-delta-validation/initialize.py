#!/usr/bin/env python3
"""Initialize validation of the four approved version-3 thesis changes."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RESEARCH = ROOT.parent
BATTERY_DIR = RESEARCH / "2026-09-29-full-thesis-battery"
PRIOR = RESEARCH / "2026-09-29-approved-full-battery-validation"
CORPUS_ROOT = Path("/tmp/farol-v3-delta-20260930")
CHANGED_IDS = ["FB-Q23", "FB-Q24", "FB-Q25", "FB-Q19"]


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / "reviews").mkdir(exist_ok=True)
    if (ROOT / "STATE.json").exists():
        print(json.dumps({"status": "already_initialized"}))
        return
    battery = read(BATTERY_DIR / "BATTERY.json")
    approval = read(BATTERY_DIR / "APPROVAL.json")
    prior_state = read(PRIOR / "STATE.json")
    source_manifest = read(RESEARCH / "2026-09-29-full-plan-validation" / "source-manifest.json")
    source_by_id = {candidate["id"]: candidate for candidate in source_manifest["candidates"]}

    assert battery["battery_version"] == 3 and battery["status"] == "approved"
    items_by_id = {item["id"]: item for item in battery["items"]}
    assert set(CHANGED_IDS) == set(battery["items_requiring_reclassification"])
    items = [items_by_id[item_id] for item_id in CHANGED_IDS]
    questions = {
        "schema_version": 1,
        "battery_id": battery["battery_id"],
        "battery_version": 3,
        "status": "approved",
        "response_buttons": battery["response_buttons"],
        "wording_fingerprint": approval["wording_fingerprint"],
        "items": [
            {
                key: item[key]
                for key in [
                    "id",
                    "display_number",
                    "version",
                    "statement",
                    "explanation",
                    "decision_object",
                    "category_id",
                    "family_ids",
                    "measurement_risks",
                    "wording_sha256",
                ]
            }
            for item in items
        ],
    }
    write(ROOT / "questions.json", questions)
    questions_sha = digest(ROOT / "questions.json")
    write(
        ROOT / "APPROVAL.json",
        {
            "schema_version": 1,
            "decision": "approved",
            "user_message": approval["user_message"],
            "approved_at": approval["approved_at"],
            "battery_approval": "../2026-09-29-full-thesis-battery/APPROVAL.json",
            "battery_wording_fingerprint": approval["wording_fingerprint"],
            "questions_sha256": questions_sha,
            "approved_question_versions": [
                {key: item[key] for key in ["id", "version", "wording_sha256"]}
                for item in items
            ],
        },
    )

    candidates = []
    for old in prior_state["candidates"]:
        source = source_by_id[old["id"]]
        candidates.append(
            {
                "id": old["id"],
                "name": old["name"],
                "party": old["party"],
                "pages": old["pages"],
                "sha256": old["sha256"],
                "corpus_directory": str(CORPUS_ROOT / old["id"]),
                "context_owner_agent_id": old["context_owner_agent_id"],
                "previous_executor_agent_id": old["executor_agent_id"],
                "executor_agent_id": None,
                "executor_model": "gpt-5.6-sol",
                "executor_reasoning_effort": "xhigh",
                "status": "queued",
                "review_file": f"reviews/{old['id']}.json",
                "prior_context": {
                    "profile_json": f"../2026-09-29-thematic-profiles/profiles/{old['id']}.json",
                    "profile_md": f"../2026-09-29-thematic-profiles/profiles/{old['id']}.md",
                    "profile_checkpoint": f"../2026-09-29-thematic-profiles/profiles/{old['id']}.checkpoint.json",
                    "prior_v2_review": f"../2026-09-29-approved-full-battery-validation/reviews/{old['id']}.json",
                },
                "official_member": source["member"],
            }
        )
    assert len(candidates) == 13
    assert "280002553884" not in {candidate["id"] for candidate in candidates}
    write(
        ROOT / "STATE.json",
        {
            "schema_version": 1,
            "phase": "delta_candidate_validation_in_progress",
            "model": "gpt-5.6-sol",
            "reasoning_effort": "xhigh",
            "same_plan_context_required": True,
            "questions": "questions.json",
            "questions_sha256": questions_sha,
            "official_source_manifest": "../2026-09-29-full-plan-validation/source-manifest.json",
            "source_check": "SOURCE_CHECK.json",
            "excluded_candidate_ids": ["280002553884"],
            "production_changes": False,
            "ranking_changes": False,
            "candidates": candidates,
            "metrics": {
                "approved_questions": 4,
                "expected_reviews": 13,
                "expected_answers": 52,
                "completed_reviews": 0,
                "valid_reviews": 0,
                "validated_answers": 0,
            },
        },
    )
    print(json.dumps({"questions": 4, "plans": 13, "expected_answers": 52, "questions_sha256": questions_sha}))


if __name__ == "__main__":
    main()
