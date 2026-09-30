#!/usr/bin/env python3
"""Record the user's approval of the complete battery without changing wording."""

import datetime
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BATTERY = ROOT / "BATTERY.json"
APPROVAL = ROOT / "APPROVAL.json"
STATE = ROOT / "STATE.json"
MARKDOWN = ROOT / "BATTERY.md"
USER_MESSAGE = "aprovada chefe"


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def fingerprint(items, buttons):
    payload = {
        "items": [
            {
                "id": item["id"],
                "version": item["version"],
                "wording_sha256": item["wording_sha256"],
            }
            for item in items
        ],
        "response_buttons": buttons,
    }
    return hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True).encode()
    ).hexdigest()


def main():
    battery = read(BATTERY)
    state = read(STATE)
    assert battery["battery_version"] == 2
    assert battery["item_count"] == len(battery["items"]) == 20

    items_record = [
        {
            "id": item["id"],
            "version": item["version"],
            "wording_sha256": item["wording_sha256"],
        }
        for item in battery["items"]
    ]
    wording_fingerprint = fingerprint(battery["items"], battery["response_buttons"])

    if APPROVAL.exists():
        approval = read(APPROVAL)
        assert approval["wording_fingerprint"] == wording_fingerprint
        assert approval["user_message"] == USER_MESSAGE
        print(json.dumps({"status": "already_recorded", "wording_fingerprint": wording_fingerprint}))
        return

    approved_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    approval = {
        "schema_version": 1,
        "battery_id": battery["battery_id"],
        "battery_version": battery["battery_version"],
        "decision": "approved",
        "user_message": USER_MESSAGE,
        "approved_at": approved_at,
        "scope": "As 20 afirmações e explicações, com os quatro botões já definidos.",
        "item_count": 20,
        "response_buttons": battery["response_buttons"],
        "wording_fingerprint": wording_fingerprint,
        "items": items_record,
    }
    write(APPROVAL, approval)

    battery["status"] = "approved"
    battery["approved_item_count"] = 20
    battery["pending_item_count"] = 0
    battery["approval_record"] = "APPROVAL.json"
    battery["approved_at"] = approved_at
    for item in battery["items"]:
        if not item["anchor_approved"]:
            item["status"] = "approved"
        item["full_battery_user_decision"] = {
            "decision": "approved",
            "version": item["version"],
            "wording_sha256": item["wording_sha256"],
            "user_message": USER_MESSAGE,
            "recorded_at": approved_at,
        }
    write(BATTERY, battery)

    state["phase"] = "approved_ready_for_candidate_validation"
    state["battery"]["approved_item_count"] = 20
    state["battery"]["pending_user_review_count"] = 0
    state["candidate_validation"]["status"] = "ready_to_resume"
    state["tasks"][-1]["status"] = "complete"
    state["tasks"][-1]["approval_record"] = "APPROVAL.json"
    state["battery"]["sha256"] = hashlib.sha256(BATTERY.read_bytes()).hexdigest()
    write(STATE, state)

    text = MARKDOWN.read_text()
    text = text.replace(
        "# Bateria completa para validação humana\n\nSão 20 afirmações apresentadas numa única rodada. As quatro primeiras já foram aprovadas; as outras 16 aguardam decisão. Afirmação e explicação formam uma única versão.",
        "# Bateria completa aprovada\n\nAs 20 afirmações e suas explicações foram aprovadas pelo usuário. As versões e os hashes estão congelados em `APPROVAL.json`.",
    )
    text = text.replace("*Estado: aguarda aprovação.", "*Estado: aprovada.")
    MARKDOWN.write_text(text)

    print(json.dumps({"status": "approved", "items": 20, "wording_fingerprint": wording_fingerprint}))


if __name__ == "__main__":
    main()
