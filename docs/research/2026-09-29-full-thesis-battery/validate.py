#!/usr/bin/env python3
"""Validate the human-review battery without classifying candidates."""

import collections
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MAP = ROOT.parent / "2026-09-29-question-editorial-review" / "DECISION_MAP.json"
ANCHORS = ROOT.parent / "2026-09-29-question-editorial-review" / "BLOCK_01.json"


def read(path):
    return json.loads(path.read_text())


def digest(item, buttons):
    payload = {
        "id": item["id"],
        "version": item["version"],
        "statement": item["statement"],
        "explanation": item["explanation"],
        "response_buttons": buttons,
    }
    return hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True).encode()
    ).hexdigest()


def main():
    battery = read(ROOT / "BATTERY.json")
    decision_map = read(MAP)
    anchors = read(ANCHORS)
    family_ids = {family["id"] for family in decision_map["families"]}
    anchor_by_id = {item["id"]: item for item in anchors["items"]}
    items = battery["items"]

    assert battery["status"] == "pending_user_review"
    assert battery["item_count"] == len(items) == 22
    assert battery["approved_anchor_count"] == 4
    assert battery["pending_item_count"] == 18
    assert battery["published_theses_used"] is False
    assert battery["candidate_validation_dispatched"] is False
    assert battery["response_buttons"] == ["Concordo", "Discordo", "Neutro", "Pular"]
    assert [item["display_number"] for item in items] == list(range(1, 23))
    assert len({item["id"] for item in items}) == 22
    assert len({item["statement"] for item in items}) == 22
    assert len({item["wording_sha256"] for item in items}) == 22

    category_counts = collections.Counter()
    for item in items:
        assert item["statement"].strip().endswith(".")
        assert item["explanation"].strip().endswith(".")
        assert item["family_ids"] and set(item["family_ids"]) <= family_ids
        assert item["wording_sha256"] == digest(item, battery["response_buttons"])
        category_counts[item["category_id"]] += 1
        if item["anchor_approved"]:
            source = anchor_by_id[item["id"]]
            assert item["status"] == "approved_anchor"
            assert item["version"] == source["version"]
            assert item["statement"] == source["statement"]
            assert item["explanation"] == source["explanation"]
            assert item["wording_sha256"] == source["wording_sha256"]
        else:
            assert item["status"] == "pending_user_review"
            assert item["version"] == 1

    assert len(category_counts) == 10
    result = {
        "schema_version": 1,
        "valid": True,
        "item_count": len(items),
        "anchor_count": sum(item["anchor_approved"] for item in items),
        "pending_count": sum(not item["anchor_approved"] for item in items),
        "unique_family_count": len({family for item in items for family in item["family_ids"]}),
        "category_counts": dict(category_counts),
        "battery_sha256": hashlib.sha256((ROOT / "BATTERY.json").read_bytes()).hexdigest(),
        "published_theses_used": False,
        "candidate_answers_created": 0,
    }
    (ROOT / "validation.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    )
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
