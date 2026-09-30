#!/usr/bin/env python3
"""Initialize the approved 20-item battery validation against 13 official plans."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RESEARCH = ROOT.parent
BATTERY_DIR = RESEARCH / "2026-09-29-full-thesis-battery"
PRIOR = RESEARCH / "2026-09-29-full-plan-validation"


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / "reviews").mkdir(exist_ok=True)
    if (ROOT / "STATE.json").exists():
        state = read(ROOT / "STATE.json")
        print(json.dumps({"status": "already_initialized", "questions": state["metrics"]["approved_questions"], "plans": state["metrics"]["expected_reviews"]}))
        return
    battery = read(BATTERY_DIR / "BATTERY.json")
    battery_approval = read(BATTERY_DIR / "APPROVAL.json")
    prior_state = read(PRIOR / "STATE.json")

    assert battery["status"] == "approved"
    assert battery["item_count"] == 20
    assert battery_approval["wording_fingerprint"]
    assert prior_state["plan_count"] == 13

    questions = {
        "schema_version": 1,
        "battery_id": battery["battery_id"],
        "battery_version": battery["battery_version"],
        "status": "approved",
        "response_buttons": battery["response_buttons"],
        "wording_fingerprint": battery_approval["wording_fingerprint"],
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
            for item in battery["items"]
        ],
    }
    write(ROOT / "questions.json", questions)
    questions_sha = sha(ROOT / "questions.json")

    approval = {
        "schema_version": 1,
        "decision": "approved",
        "user_message": battery_approval["user_message"],
        "approved_at": battery_approval["approved_at"],
        "battery_approval": "../2026-09-29-full-thesis-battery/APPROVAL.json",
        "battery_wording_fingerprint": battery_approval["wording_fingerprint"],
        "questions_sha256": questions_sha,
        "approved_question_versions": battery_approval["items"],
    }
    write(ROOT / "APPROVAL.json", approval)

    candidates = []
    for candidate in prior_state["candidates"]:
        candidates.append(
            {
                "id": candidate["id"],
                "name": candidate["name"],
                "party": candidate["party"],
                "pages": candidate["pages"],
                "sha256": candidate["sha256"],
                "corpus_directory": candidate["corpus_directory"],
                "context_owner_agent_id": candidate["agent_id"],
                "executor_agent_id": None,
                "executor_model": "gpt-5.6-sol",
                "executor_reasoning_effort": "xhigh",
                "status": "queued",
                "review_file": f"reviews/{candidate['id']}.json",
                "prior_context": {
                    "profile_json": f"../2026-09-29-thematic-profiles/profiles/{candidate['id']}.json",
                    "profile_md": f"../2026-09-29-thematic-profiles/profiles/{candidate['id']}.md",
                    "profile_checkpoint": f"../2026-09-29-thematic-profiles/profiles/{candidate['id']}.checkpoint.json",
                    "prior_full_validation": f"../2026-09-29-full-plan-validation/reviews/{candidate['id']}.json",
                },
            }
        )

    assert "280002553884" not in {candidate["id"] for candidate in candidates}
    state = {
        "schema_version": 1,
        "phase": "candidate_validation_in_progress",
        "model": "gpt-5.6-sol",
        "reasoning_effort": "xhigh",
        "same_plan_context_required": True,
        "battery_approval": "APPROVAL.json",
        "questions": "questions.json",
        "questions_sha256": questions_sha,
        "official_source_manifest": "../2026-09-29-full-plan-validation/source-manifest.json",
        "excluded_candidate_ids": ["280002553884"],
        "production_changes": False,
        "ranking_changes": False,
        "candidates": candidates,
        "metrics": {
            "approved_questions": 20,
            "expected_reviews": 13,
            "expected_answers": 260,
            "completed_reviews": 0,
            "valid_reviews": 0,
            "validated_answers": 0,
        },
    }
    write(ROOT / "STATE.json", state)

    battery["candidate_validation_dispatched"] = True
    battery["candidate_validation_record"] = "../2026-09-29-approved-full-battery-validation/STATE.json"
    write(BATTERY_DIR / "BATTERY.json", battery)
    battery_state = read(BATTERY_DIR / "STATE.json")
    battery_state["phase"] = "full_battery_candidate_validation_in_progress"
    battery_state["candidate_validation"]["status"] = "in_progress"
    battery_state["candidate_validation"]["full_battery_questions"] = 20
    battery_state["candidate_validation"]["expected_reviews"] = 13
    battery_state["candidate_validation"]["expected_answers"] = 260
    battery_state["candidate_validation"]["validation_record"] = "../2026-09-29-approved-full-battery-validation/STATE.json"
    battery_state["battery"]["sha256"] = sha(BATTERY_DIR / "BATTERY.json")
    write(BATTERY_DIR / "STATE.json", battery_state)

    print(json.dumps({"questions": 20, "plans": 13, "expected_answers": 260, "questions_sha256": questions_sha}))


if __name__ == "__main__":
    main()
