"""Reproduce descriptive coverage measurements without changing product data.

Run from any directory:
    python docs/research/2026-09-29-affinity-methodology/audit.py

The default output is /tmp/farol-coverage-audit.json. Pass --output to save a
different artifact and --root to inspect another checkout of the same dataset.
"""

import argparse
import hashlib
import itertools
import json
import statistics
from collections import Counter
from pathlib import Path

CATEGORICAL = frozenset({"CONCORDA", "DISCORDA"})
CATEGORIES = (
    "CONCORDA",
    "DISCORDA",
    "CONDICIONAL_OU_MISTA",
    "NEUTRO_EXPLICITO",
    "NAO_ENCONTRADA",
    "PENDENTE",
)


def category(thesis, candidate_id):
    return thesis["positions"][candidate_id]["analytical_position"]


def category_counts(values):
    counts = Counter(values)
    unknown = set(counts) - set(CATEGORIES)
    if unknown:
        raise ValueError(f"Unexpected analytical categories: {sorted(unknown)}")
    return {key: counts[key] for key in CATEGORIES}


def thesis_counts(thesis):
    return category_counts(
        value["analytical_position"] for value in thesis["positions"].values()
    )


def categorical_count(counts):
    return sum(counts[key] for key in CATEGORICAL)


def minority_pole(thesis):
    counts = thesis_counts(thesis)
    return min(counts["CONCORDA"], counts["DISCORDA"])


def audit_subset(theses, candidates):
    """Count availability assuming every selected question was answered."""
    candidate_ids = [candidate["id"] for candidate in candidates]
    names = {candidate["id"]: candidate["name"] for candidate in candidates}
    counts = category_counts(
        category(thesis, candidate_id)
        for thesis in theses
        for candidate_id in candidate_ids
    )
    by_candidate = {}
    theme_counts = {}
    for candidate_id in candidate_ids:
        candidate_counts = category_counts(
            category(thesis, candidate_id) for thesis in theses
        )
        categorical = categorical_count(candidate_counts)
        name = names[candidate_id]
        by_candidate[name] = {
            "id": candidate_id,
            "denominator": len(theses),
            "categories": candidate_counts,
            "categorical": categorical,
            "coverage": round(categorical / len(theses), 6),
            "agree": candidate_counts["CONCORDA"],
            "disagree": candidate_counts["DISCORDA"],
            "conditional": candidate_counts["CONDICIONAL_OU_MISTA"],
            "neutral_explicit": candidate_counts["NEUTRO_EXPLICITO"],
            "not_found": candidate_counts["NAO_ENCONTRADA"],
            "pending": candidate_counts["PENDENTE"],
        }
        theme_counts[name] = len(
            {
                thesis["topic"]
                for thesis in theses
                if category(thesis, candidate_id) in CATEGORICAL
            }
        )

    pairs = []
    for first, second in itertools.combinations(candidate_ids, 2):
        shared = [
            thesis
            for thesis in theses
            if category(thesis, first) in CATEGORICAL
            and category(thesis, second) in CATEGORICAL
        ]
        opposed = [
            thesis
            for thesis in shared
            if category(thesis, first) != category(thesis, second)
        ]
        pairs.append(
            {
                "a": names[first],
                "b": names[second],
                "shared": len(shared),
                "opposed": len(opposed),
                "theses": [thesis["id"] for thesis in shared],
                "opposed_theses": [thesis["id"] for thesis in opposed],
            }
        )

    by_topic = {}
    for topic in sorted({thesis["topic"] for thesis in theses}):
        topic_theses = [thesis for thesis in theses if thesis["topic"] == topic]
        topic_counts = category_counts(
            category(thesis, candidate_id)
            for thesis in topic_theses
            for candidate_id in candidate_ids
        )
        coverage = {
            names[candidate_id]: sum(
                category(thesis, candidate_id) in CATEGORICAL for thesis in topic_theses
            )
            for candidate_id in candidate_ids
        }
        by_topic[topic] = {
            "theses": len(topic_theses),
            "ids": [thesis["id"] for thesis in topic_theses],
            "cells": len(topic_theses) * len(candidate_ids),
            "categories": topic_counts,
            "categorical": categorical_count(topic_counts),
            "conditional": topic_counts["CONDICIONAL_OU_MISTA"],
            "neutral_explicit": topic_counts["NEUTRO_EXPLICITO"],
            "not_found": topic_counts["NAO_ENCONTRADA"],
            "covered_candidates": sum(value > 0 for value in coverage.values()),
            "candidate_categorical_counts": coverage,
        }

    available_counts = [value["categorical"] for value in by_candidate.values()]
    combined_grid = []
    for minimum_items, minimum_coverage in itertools.product(
        (5, 8, 10), (0.4, 0.5, 0.6)
    ):
        eligible = [
            name
            for name, value in by_candidate.items()
            if value["categorical"] >= minimum_items
            and value["categorical"] / len(theses) >= minimum_coverage
            and theme_counts[name] >= 3
        ]
        combined_grid.append(
            {
                "min_items": minimum_items,
                "min_coverage": minimum_coverage,
                "min_themes": 3,
                "count": len(eligible),
                "candidates": eligible,
            }
        )
    thresholds = {
        "min_items": {
            str(minimum): sum(value >= minimum for value in available_counts)
            for minimum in (5, 8, 10)
        },
        "min_coverage": {
            str(minimum): sum(
                value / len(theses) >= minimum for value in available_counts
            )
            for minimum in (0.4, 0.5, 0.6)
        },
        "min_3_themes": sum(value >= 3 for value in theme_counts.values()),
        "combined_grid": combined_grid,
    }
    shared_counts = [pair["shared"] for pair in pairs]
    categorical = categorical_count(counts)
    return {
        "n_theses": len(theses),
        "n_topics": len(by_topic),
        "ids": [thesis["id"] for thesis in theses],
        "counts": counts,
        "categorical": categorical,
        "density": round(categorical / (len(theses) * len(candidate_ids)), 6),
        "candidate_min_median_max": [
            min(available_counts),
            statistics.median(available_counts),
            max(available_counts),
        ],
        "candidates_zero": available_counts.count(0),
        "candidates_le_1": sum(value <= 1 for value in available_counts),
        "candidates_lt_5": sum(value < 5 for value in available_counts),
        "pairs_total": len(pairs),
        "pairs_zero": shared_counts.count(0),
        "pairs_shared_1": shared_counts.count(1),
        "pairs_shared_ge3": sum(value >= 3 for value in shared_counts),
        "pairs_shared_ge5": sum(value >= 5 for value in shared_counts),
        "pairs_opposed_ge1": sum(pair["opposed"] > 0 for pair in pairs),
        "shared_sum": sum(shared_counts),
        "shared_mean": round(statistics.mean(shared_counts), 6),
        "shared_median": statistics.median(shared_counts),
        "shared_max": max(shared_counts),
        "by_candidate": by_candidate,
        "by_topic": by_topic,
        "theme_counts": theme_counts,
        "thresholds": thresholds,
        "pairs": pairs,
    }


def loss_against(baseline, subset):
    return {
        "categorical_positions": baseline["categorical"] - subset["categorical"],
        "by_candidate": {
            name: value["categorical"] - subset["by_candidate"][name]["categorical"]
            for name, value in baseline["by_candidate"].items()
        },
        "by_topic": {
            topic: {
                "theses": value["theses"]
                - subset["by_topic"].get(topic, {}).get("theses", 0),
                "categorical": value["categorical"]
                - subset["by_topic"].get(topic, {}).get("categorical", 0),
            }
            for topic, value in baseline["by_topic"].items()
        },
    }


def audit(root):
    """Build the entire study from checked-in inputs using only the stdlib."""
    paths = {
        "theses": Path("data/theses/2026/theses.json"),
        "candidates": Path("data/propostas/2026/candidates.json"),
        "source_bank": Path("data/theses/2026/source-bank-v3.jsonl"),
    }
    theses = json.loads((root / paths["theses"]).read_text())["theses"]
    candidates = json.loads((root / paths["candidates"]).read_text())
    bank = [
        json.loads(line)
        for line in (root / paths["source_bank"]).read_text().splitlines()
    ]
    candidate_ids = [candidate["id"] for candidate in candidates]
    names = {candidate["id"]: candidate["name"] for candidate in candidates}
    if len(set(candidate_ids)) != len(candidate_ids):
        raise ValueError("Candidate IDs must be unique")
    if len({thesis["id"] for thesis in theses}) != len(theses):
        raise ValueError("Thesis IDs must be unique")
    for thesis in theses:
        if set(thesis["positions"]) != set(candidate_ids):
            raise ValueError(f"Incomplete candidate matrix: {thesis['id']}")
        thesis_counts(thesis)

    active = [thesis for thesis in theses if thesis["status"] == "approved"]
    core = [thesis for thesis in active if thesis["selection"] == "nucleus"]
    ranked = sorted(
        active,
        key=lambda thesis: (
            -categorical_count(thesis_counts(thesis)),
            -minority_pole(thesis),
            thesis["id"],
        ),
    )
    subsets = {"active30": active, "core23": core, "all70": theses}
    subsets.update({f"density{size}": ranked[:size] for size in (10, 15, 20)})
    results = {
        label: audit_subset(subset, candidates) for label, subset in subsets.items()
    }
    for label, result in results.items():
        if label != "all70":
            result["loss_vs_active30"] = loss_against(results["active30"], result)

    equal_profiles = []
    opposite_profiles = []
    inverse = {"CONCORDA": "DISCORDA", "DISCORDA": "CONCORDA", None: None}
    for first, second in itertools.combinations(active, 2):
        first_values = [
            value if value in CATEGORICAL else None
            for value in (category(first, candidate) for candidate in candidate_ids)
        ]
        second_values = [
            value if value in CATEGORICAL else None
            for value in (category(second, candidate) for candidate in candidate_ids)
        ]
        record = [
            first["id"],
            second["id"],
            categorical_count(thesis_counts(first)),
        ]
        if first_values == second_values:
            equal_profiles.append(record)
        if [inverse[value] for value in first_values] == second_values:
            opposite_profiles.append(record)

    single_poles = Counter()
    for thesis in active:
        counts = thesis_counts(thesis)
        for pole in ("CONCORDA", "DISCORDA"):
            if counts[pole] == 1:
                candidate_id = next(
                    candidate_id
                    for candidate_id in candidate_ids
                    if category(thesis, candidate_id) == pole
                )
                single_poles[names[candidate_id]] += 1

    environment_terms = (
        "ambient",
        "clima",
        "climát",
        "florest",
        "desmat",
        "poluen",
        "indígen",
        "indigen",
        "petróleo",
        "agric",
        "agrár",
        "sustenta",
        "energia",
        "fertiliz",
        "mineraç",
    )
    return {
        "schema_version": 1,
        "method": {
            "universe": (
                "Current checked-in documentary classifications. Only CONCORDA and "
                "DISCORDA are categorical. Explicit neutral, conditional/mixed, "
                "missing and pending categories remain separate. All selected "
                "questions are assumed answered. Counts are unweighted availability, "
                "not an affinity score or verification of the classifications."
            ),
            "subset_labels": (
                "Labels refer to the 2026-09-29 snapshot; n_theses is recomputed "
                "from the supplied data and is authoritative."
            ),
            "density_subsets": (
                "Order approved theses by categorical count descending, minority "
                "pole size descending, ID ascending; take first k. This maximizes "
                "total available categorical cells at fixed k. It does not optimize "
                "fairness, thematic balance, semantic redundancy or validity."
            ),
            "thresholds": (
                "Illustrative, unvalidated thresholds. Coverage is categorical "
                "positions divided by selected questions. Theme coverage counts "
                "topics with at least one categorical position. Combined grid "
                "requires all three criteria simultaneously."
            ),
            "redundancy": (
                "Equal profiles mean identical categorical signs and availability "
                "across candidates; other categories are collapsed to missing for "
                "this specific comparison. This does not prove semantic equivalence "
                "or identical voter answers."
            ),
            "source_bank": (
                "The 111 source formulations are not a 111-by-13 classified matrix. "
                "Source labels and claim IDs are historical editorial leads, not "
                "validated positions of current candidacies. Environment search "
                "matches the listed substrings in source theme plus text."
            ),
            "environment_search_terms": list(environment_terms),
        },
        "inputs": {
            key: {
                "path": str(path),
                "sha256": hashlib.sha256((root / path).read_bytes()).hexdigest(),
            }
            for key, path in paths.items()
        },
        "subsets": results,
        "by_thesis": [
            {
                "id": thesis["id"],
                "selection": thesis["selection"],
                "topic": thesis["topic"],
                "text": thesis["text"],
                "counts": thesis_counts(thesis),
                "categorical": categorical_count(thesis_counts(thesis)),
                "minority_pole": minority_pole(thesis),
                "categorical_candidates": [
                    names[candidate_id]
                    for candidate_id in candidate_ids
                    if category(thesis, candidate_id) in CATEGORICAL
                ],
            }
            for thesis in active
        ],
        "equal_profiles": equal_profiles,
        "opposite_profiles": opposite_profiles,
        "minority_pole_count_distribution": dict(
            sorted(Counter(minority_pole(thesis) for thesis in active).items())
        ),
        "single_categorical_pole_by_candidate": dict(sorted(single_poles.items())),
        "categorical_count_distribution": dict(
            sorted(
                Counter(
                    categorical_count(thesis_counts(thesis)) for thesis in active
                ).items()
            )
        ),
        "drafts_for_low_coverage_candidates": {
            names[candidate_id]: [
                {
                    "id": thesis["id"],
                    "category": category(thesis, candidate_id),
                    "text": thesis["text"],
                    "topic": thesis["topic"],
                    "editorial_note": thesis["editorial_note"],
                    "editorial_problems": thesis.get("editorial_problems", []),
                }
                for thesis in theses
                if thesis["status"] == "draft"
                and category(thesis, candidate_id) in CATEGORICAL
            ]
            for candidate_id in candidate_ids
            if results["active30"]["by_candidate"][names[candidate_id]]["categorical"]
            <= 5
        },
        "source_bank": {
            "count": len(bank),
            "type_counts": dict(sorted(Counter(item["tipo"] for item in bank).items())),
            "editorial_state_counts": dict(
                sorted(Counter(item["estado_editorial"] for item in bank).items())
            ),
            "environmental_energy_and_land_items": [
                item
                for item in bank
                if any(
                    term in (item["tema"] + " " + item["texto_tese"]).lower()
                    for term in environment_terms
                )
            ],
        },
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", type=Path, default=Path(__file__).resolve().parents[3]
    )
    parser.add_argument(
        "--output", type=Path, default=Path("/tmp/farol-coverage-audit.json")
    )
    args = parser.parse_args()
    result = audit(args.root.resolve())
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"Wrote {args.output}")
    for label, subset in result["subsets"].items():
        print(
            f"{label}: questions={subset['n_theses']}, "
            f"categorical={subset['categorical']}, "
            f"density={subset['density']:.2%}, "
            f"pairs_without_common_position={subset['pairs_zero']}"
        )


if __name__ == "__main__":
    main()
