#!/usr/bin/env python3
"""Persist dispatch and validation progress for the full-battery plan review."""

import argparse
import datetime
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
STATE = ROOT / "STATE.json"


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    dispatch = sub.add_parser("dispatch")
    dispatch.add_argument("candidate_id")
    dispatch.add_argument("executor_agent_id")
    sub.add_parser("sync")
    args = parser.parse_args()
    state = read(STATE)
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    if args.action == "dispatch":
        candidate = next(item for item in state["candidates"] if item["id"] == args.candidate_id)
        assert candidate["status"] in {"queued", "dispatched"}
        candidate["status"] = "dispatched"
        candidate["executor_agent_id"] = args.executor_agent_id
        candidate["dispatched_at"] = candidate.get("dispatched_at", now)
    else:
        validation = read(ROOT / "validation.json")
        by_id = {item["candidate_id"]: item for item in validation["results"]}
        for candidate in state["candidates"]:
            result = by_id[candidate["id"]]
            if result["status"] in {"valid", "invalid"}:
                candidate["status"] = result["status"]
                candidate["review_file"] = f"reviews/{candidate['id']}.json"
                candidate["validated_at"] = now
        state["metrics"]["completed_reviews"] = validation["completed_reviews"]
        state["metrics"]["valid_reviews"] = validation["valid_reviews"]
        state["metrics"]["validated_answers"] = validation["answers"]
        if validation["valid"]:
            state["phase"] = "candidate_validation_complete"
    state["updated_at"] = now
    write(STATE, state)
    print(json.dumps({"action": args.action, "updated_at": now, "metrics": state["metrics"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
