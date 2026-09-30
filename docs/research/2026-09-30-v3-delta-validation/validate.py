#!/usr/bin/env python3
"""Validate individual plan reviews for the four approved version-3 changes."""

import argparse
import collections
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PRIOR = ROOT.parent / "2026-09-29-full-plan-validation"


def read(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def norm(value):
    return " ".join(value.split())


def variants(value):
    lines = value.splitlines()
    deduplicated = "\n".join(line for index, line in enumerate(lines) if not index or line != lines[index - 1])
    return [norm(value), norm(deduplicated)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-pending", action="store_true")
    args = parser.parse_args()
    state = read(ROOT / "STATE.json")
    questions = read(ROOT / "questions.json")
    approval = read(ROOT / "APPROVAL.json")
    prior_candidates = {candidate["id"]: candidate for candidate in read(PRIOR / "STATE.json")["candidates"]}

    assert len(questions["items"]) == 4
    assert digest(ROOT / "questions.json") == approval["questions_sha256"] == state["questions_sha256"]
    assert questions["wording_fingerprint"] == approval["battery_wording_fingerprint"]
    assert [
        {"id": item["id"], "version": item["version"], "wording_sha256": item["wording_sha256"]}
        for item in questions["items"]
    ] == approval["approved_question_versions"]
    assert len(state["candidates"]) == 13
    assert "280002553884" not in {candidate["id"] for candidate in state["candidates"]}
    executor_ids = [candidate["executor_agent_id"] for candidate in state["candidates"]]
    assert len(executor_ids) == len(set(executor_ids)), (
        "Each candidate must have an exclusive executor agent"
    )

    results = []
    for candidate in state["candidates"]:
        review_path = ROOT / candidate["review_file"]
        if not review_path.exists():
            results.append({"candidate_id": candidate["id"], "status": "pending", "errors": []})
            continue
        review = read(review_path)
        errors = []
        counts = collections.Counter()
        quotes = 0

        def check(ok, message):
            if not ok:
                errors.append(message)

        corpus = Path(candidate["corpus_directory"])
        check(digest(corpus / "plan.pdf") == candidate["sha256"] == review.get("document_sha256"), "Official PDF hash")
        check(review.get("candidate_id") == candidate["id"] and review.get("candidate_name") == candidate["name"], "Candidate identity")
        check(review.get("context_owner_agent_id") == candidate["context_owner_agent_id"] == prior_candidates[candidate["id"]]["agent_id"], "Original context owner")
        check(
            review.get("executor_agent_id") == candidate["executor_agent_id"],
            "Exclusive executor agent",
        )
        check(review.get("schema_version") == 1, "Schema version")
        check(review.get("questions_sha256") == approval["questions_sha256"], "Questions hash")
        check(review.get("prior_context_files") == list(candidate["prior_context"].values()), "Prior context files")
        prior = read(PRIOR / "reviews" / f"{candidate['id']}.json")
        check(prior["full_read_completed"] and set(prior["pages_read"]) == set(range(1, candidate["pages"] + 1)), "Prior full read")
        check(review.get("full_text_search_completed") is True, "Full text search")
        check(bool(review.get("method")), "Method")
        revisited = review.get("revisited_pages", [])
        check(all(isinstance(page, int) and 1 <= page <= candidate["pages"] for page in revisited), "Revisited pages")
        pages = {mode: read(corpus / f"{mode}-pages.json") for mode in ["layout", "raw"]}
        check(all(len(value) == candidate["pages"] for value in pages.values()), "Physical page count")

        answers = review.get("answers", [])
        check([answer.get("question_id") for answer in answers] == [item["id"] for item in questions["items"]], "Exactly four ordered answers")
        for answer, question in zip(answers, questions["items"]):
            prefix = question["id"] + ": "
            code = answer.get("classification")
            counts[code] += 1
            check(code in {"CONCORDA", "DISCORDA", "CONDICIONAL_OU_MISTA", "NAO_ENCONTRADA"}, prefix + "Classification")
            check(answer.get("question_version") == question["version"] and answer.get("wording_sha256") == question["wording_sha256"], prefix + "Wording version")
            check(answer.get("evidence_strength") in {"explicit", "clear_implication", "mixed", "insufficient"}, prefix + "Strength")
            check(bool(answer.get("rationale")) and bool(answer.get("search_terms")) and "counterevidence_or_limits" in answer, prefix + "Reason/search/limits")
            check(isinstance(answer.get("conditions"), list), prefix + "Conditions")
            searched = set()
            for start, end in answer.get("searched_page_ranges", []):
                check(1 <= start <= end <= candidate["pages"], prefix + "Search range")
                searched.update(range(start, end + 1))
            check(searched == set(range(1, candidate["pages"] + 1)), prefix + "Full document search range")
            evidence = answer.get("evidence", [])
            check(code == "NAO_ENCONTRADA" or bool(evidence), prefix + "Evidence required")
            if code == "NAO_ENCONTRADA":
                check(answer.get("evidence_strength") == "insufficient", prefix + "Missing evidence strength")
            for entry in evidence:
                page = entry.get("page")
                quotes += 1
                check(isinstance(page, int) and 1 <= page <= candidate["pages"], prefix + "Evidence page")
                check(page in revisited, prefix + "Quote page revisited")
                check(entry.get("role") in {"support", "opposition", "condition", "context", "counterevidence"}, prefix + "Evidence role")
                check(bool(entry.get("interpretation")), prefix + "Interpretation")
                if isinstance(page, int) and 1 <= page <= candidate["pages"]:
                    quote = norm(entry.get("quote", ""))
                    matched = bool(quote) and any(quote in variant for mode in pages for variant in variants(pages[mode][page - 1]))
                    check(matched, prefix + f"Literal quote mismatch page {page}: " + entry.get("quote", "")[:90])
            suggestion = answer.get("reformulation_suggestion")
            check(suggestion is None or isinstance(suggestion, dict) and suggestion.get("meaning_change") is True, prefix + "Separate meaning change")

        check(review_path.with_suffix(".md").exists(), "Readable report")
        results.append(
            {
                "candidate_id": candidate["id"],
                "status": "valid" if not errors else "invalid",
                "errors": errors,
                "answers": len(answers),
                "quotes": quotes,
                "counts": dict(counts),
                "review_sha256": digest(review_path),
                "markdown_sha256": digest(review_path.with_suffix(".md")) if review_path.with_suffix(".md").exists() else None,
            }
        )

    report = {
        "schema_version": 1,
        "approved_questions": 4,
        "questions_sha256": approval["questions_sha256"],
        "completed_reviews": sum(result["status"] != "pending" for result in results),
        "valid_reviews": sum(result["status"] == "valid" for result in results),
        "answers": sum(result.get("answers", 0) for result in results),
        "quote_occurrences": sum(result.get("quotes", 0) for result in results),
        "valid": all(result["status"] == "valid" for result in results),
        "results": results,
    }
    (ROOT / "validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({key: value for key, value in report.items() if key != "results"}, ensure_ascii=False))
    for result in results:
        if result["errors"]:
            print(result["candidate_id"], json.dumps(result["errors"], ensure_ascii=False))
    if any(result["status"] == "invalid" for result in results) or (not args.allow_pending and not report["valid"]):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
