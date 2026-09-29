#!/usr/bin/env python3
"""Validate review completeness/provenance, not the political interpretation.

python validate.py --corpus /tmp/farol-plan-review-20260929
python validate.py --archive /path/to/proposta_governo_2026_BR_20260919.zip
Only standard Python and (for extraction) Poppler are needed.
"""
import argparse
from collections import Counter
import hashlib
from itertools import combinations
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
GROUPS = ("economy-social", "services-rights", "institutions-external", "labour-security")
CATEGORIES = {"CONCORDA", "DISCORDA", "CONDICIONAL_OU_MISTA", "NEUTRO_EXPLICITO", "NAO_ENCONTRADA"}
CAT = {"CONCORDA", "DISCORDA"}


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalized(text):
    return " ".join(text.split())


def variants(text):
    # Some PDFs paint identical text twice, producing consecutive duplicate lines.
    lines = text.splitlines()
    deduplicated = "\n".join(line for i, line in enumerate(lines) if not i or line != lines[i - 1])
    return [normalized(text), normalized(deduplicated)]


def extract(archive, directory, manifest):
    assert sha(archive) == manifest["archive_sha256"], "Wrong archive snapshot"
    with zipfile.ZipFile(archive) as z:
        for c in manifest["candidates"]:
            folder = directory / c["id"]
            folder.mkdir(parents=True, exist_ok=True)
            pdf = folder / "plan.pdf"
            pdf.write_bytes(z.read(c["member"]))
            assert sha(pdf) == c["sha256"], c["id"]
            for mode in ("layout", "raw"):
                target = folder / (mode + ".txt")
                result = subprocess.run(["pdftotext", "-" + mode, str(pdf), str(target)], capture_output=True, text=True)
                if result.returncode:
                    raise RuntimeError(f"pdftotext failed for {c['id']}: {result.stderr}")
                pages = target.read_text().split("\f")
                if not pages[-1].strip():
                    pages.pop()
                assert len(pages) == c["pages"], (c["id"], mode, len(pages))
                (folder / (mode + "-pages.json")).write_text(json.dumps(pages, ensure_ascii=False))


def counts(rows):
    return dict(Counter(r["category"] for r in rows))


def categorical(rows):
    return sum(r["category"] in CAT for r in rows)


def transitions(before, after, names):
    old = {r["candidate_id"]: r["category"] for r in before}
    return [{"candidate_id": r["candidate_id"], "name": names[r["candidate_id"]],
             "before": old[r["candidate_id"]], "after": r["category"]}
            for r in after if old[r["candidate_id"]] != r["category"]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--corpus", type=Path)
    source.add_argument("--archive", type=Path)
    parser.add_argument("--output", type=Path, default=HERE / "validation.json")
    args = parser.parse_args()
    manifest = read(HERE / "corpus-manifest.json")
    source_data = read(ROOT / "data/theses/2026/theses.json")
    baseline = {t["id"]: t for t in source_data["theses"] if t["status"] == "approved"}
    cs = {c["id"]: c for c in manifest["candidates"]}
    names = {cid: c["name"] for cid, c in cs.items()}
    temp = tempfile.TemporaryDirectory(prefix="farol-review-") if args.archive else None
    corpus = Path(temp.name) if temp else args.corpus
    if args.archive:
        extract(args.archive, corpus, manifest)
    pages = {}
    for cid, c in cs.items():
        folder = corpus / cid
        assert sha(folder / "plan.pdf") == c["sha256"], (cid, "PDF hash mismatch")
        expected = source_data["metadata"]["analysed_documents"][c["document_id"]]
        assert c["sha256"] == expected["sha256"]
        assert c["member"] == expected["archive_member"]
        assert c["pages"] == expected["pages_total"]
        extracted = [read(folder / (mode + "-pages.json")) for mode in ("layout", "raw")]
        assert all(len(p) == c["pages"] for p in extracted), cid
        pages[cid] = [[v for mode_pages in extracted for v in variants(mode_pages[n])]
                      for n in range(c["pages"])]
    theses = []
    errors = []
    quote_matches = Counter()
    records = 0
    inspected = {cid: set() for cid in cs}

    def check(condition, reason):
        if not condition:
            errors.append(reason)

    def verify_rows(rows, label, original=False, thesis=None):
        nonlocal records
        ids = [r["candidate_id"] for r in rows]
        check(len(ids) == len(cs) and set(ids) == set(cs), label + ": expected each of 13 candidates exactly once")
        for r in rows:
            records += 1
            cid = r["candidate_id"]
            key = label + "/" + cid
            if cid not in cs:
                continue
            check(r["category"] in CATEGORIES, key + ": invalid category")
            check(bool(r["reason"].strip()), key + ": missing rationale")
            check(bool(r["inspected_pages"]), key + ": no context inspected")
            check(all(isinstance(n, int) and 1 <= n <= cs[cid]["pages"] for n in r["inspected_pages"]), key + ": page range")
            inspected[cid].update(r["inspected_pages"])
            if original:
                check(r["baseline_category"] == thesis["positions"][cid]["analytical_position"], key + ": changed baseline")
            check(r["category"] == "NAO_ENCONTRADA" or bool(r["evidence"]), key + ": substantive category without evidence")
            for e in r["evidence"]:
                n = e["page"]
                check(n in r["inspected_pages"], key + f": evidence page {n} not inspected")
                if not isinstance(n, int) or not 1 <= n <= cs[cid]["pages"]:
                    errors.append(key + ": evidence page out of range")
                    continue
                quote = normalized(e["quote"])
                found = next((i for i, variant in enumerate(pages[cid][n - 1]) if quote and quote in variant), None)
                if found is None:
                    errors.append(key + f": quotation not found on page {n}: " + quote)
                else:
                    quote_matches[["layout", "layout_dedup", "raw", "raw_dedup"][found]] += 1

    for group in GROUPS:
        path = HERE / (group + ".json")
        if not path.exists():
            errors.append("Missing group: " + group)
            continue
        data = read(path)
        check(data["schema_version"] == 1, group + ": schema")
        for t in data["theses"]:
            tid = t["id"]
            if tid not in baseline:
                errors.append("Unexpected thesis " + tid)
                continue
            b = baseline[tid]
            check(t["baseline_text"] == b["text"], tid + ": baseline text differs")
            check(t["action"] in {"keep", "reformulate", "replace", "remove_from_shortlist"}, tid + ": action")
            check(bool(t["search_terms"]), tid + ": no searches")
            check(len(t["alternatives"]) <= 2, tid + ": too many alternatives")
            check(sum(a["recommendation"] == "recommend" for a in t["alternatives"]) <= 1, tid + ": multiple final alternatives")
            verify_rows(t["original_review"], tid + "/original", True, b)
            for i, a in enumerate(t["alternatives"]):
                check(a["recommendation"] in {"recommend", "explore", "reject"}, tid + ": invalid recommendation")
                verify_rows(a["positions"], tid + "/alternative-" + str(i))
            for v in t.get("visual_checks", []):
                check(v["candidate_id"] in cs and 1 <= v["page"] <= cs[v["candidate_id"]]["pages"], tid + ": invalid visual check")
            theses.append(t)
    ids = [t["id"] for t in theses]
    check(len(ids) == len(set(ids)), "Duplicate thesis")
    check(set(ids) == set(baseline), "Not all 30 approved theses covered")
    candidate_counts = {cid: dict(name=names[cid], published=0, reviewed_originals=0,
                                  suggested_wordings_all_30=0, proposed_shortlist=0) for cid in cs}
    summaries = []
    shortlist = {}
    for t in sorted(theses, key=lambda t: t["id"]):
        b = baseline[t["id"]]
        old = [{"candidate_id": cid, "category": p["analytical_position"]} for cid, p in b["positions"].items()]
        reviewed = t["original_review"]
        final = next((a["positions"] for a in t["alternatives"] if a["recommendation"] == "recommend"), reviewed)
        for collection, field in [(old, "published"), (reviewed, "reviewed_originals"), (final, "suggested_wordings_all_30")]:
            for row in collection:
                candidate_counts[row["candidate_id"]][field] += row["category"] in CAT
        if t["action"] != "remove_from_shortlist":
            shortlist[t["id"]] = {r["candidate_id"]: r["category"] for r in final}
            for row in final:
                candidate_counts[row["candidate_id"]]["proposed_shortlist"] += row["category"] in CAT
        summary = dict(id=t["id"], action=t["action"], published_categorical=categorical(old),
                       reviewed_categorical=categorical(reviewed), reviewed_counts=counts(reviewed),
                       corrections=transitions(old, reviewed, names), alternatives=[])
        for a in t["alternatives"]:
            summary["alternatives"].append(dict(text=a["text"], recommendation=a["recommendation"],
                                                categorical=categorical(a["positions"]), counts=counts(a["positions"]),
                                                changes_from_reviewed=transitions(reviewed, a["positions"], names)))
        summaries.append(summary)
    shortlist_size = len(shortlist)
    themes = Counter(baseline[tid]["topic"] for tid in shortlist)
    candidate_themes = {cid: sorted({baseline[tid]["topic"] for tid, rows in shortlist.items() if rows[cid] in CAT}) for cid in cs}
    eligibility = {cid: dict(comparable_themes=candidate_themes[cid],
                            eligible_under_prior_beta_proposal=(candidate_counts[cid]["proposed_shortlist"] >= 8
                                and candidate_counts[cid]["proposed_shortlist"] * 2 >= shortlist_size
                                and len(candidate_themes[cid]) >= 3)) for cid in cs}
    pair_comparisons = []
    for a, b in combinations(cs, 2):
        common = [rows for rows in shortlist.values() if rows[a] in CAT and rows[b] in CAT]
        pair_comparisons.append(dict(candidate_ids=[a, b], common=len(common),
                                     opposing=sum(rows[a] != rows[b] for rows in common)))
    result = dict(schema_version=1, valid=not errors, errors=errors,
                  source_archive_sha256=manifest["archive_sha256"],
                  source_theses_sha256=sha(ROOT / "data/theses/2026/theses.json"),
                  review_files_sha256={g: sha(HERE / (g + ".json")) for g in GROUPS if (HERE / (g + ".json")).exists()},
                  candidates=len(cs), source_pages=sum(c["pages"] for c in cs.values()),
                  theses=len(theses), original_cells=sum(len(t["original_review"]) for t in theses),
                  alternative_count=sum(len(t["alternatives"]) for t in theses), reviewed_records=records,
                  quotation_matches=dict(quote_matches),
                  unique_context_pages_by_candidate={cid: sorted(ns) for cid, ns in inspected.items()},
                  actions=dict(Counter(t["action"] for t in theses)),
                  proposed_shortlist_count=sum(t["action"] != "remove_from_shortlist" for t in theses),
                  proposed_shortlist_ids=list(shortlist), proposed_shortlist_themes=dict(themes),
                  hypothetical_eligibility=eligibility, proposed_shortlist_pairs=pair_comparisons,
                  candidate_counts=candidate_counts, theses_summary=summaries,
                  caveat="Literal verification is not semantic or human approval. Counts reflect this proposed review, not production data. The proposed shortlist is not a validated questionnaire.")
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: result[k] for k in ["valid", "theses", "original_cells", "alternative_count", "reviewed_records", "quotation_matches", "actions"]}, ensure_ascii=False, indent=2))
    for error in errors:
        print(error)
    if temp:
        temp.cleanup()
    raise SystemExit(0 if not errors else 1)


if __name__ == "__main__":
    main()
