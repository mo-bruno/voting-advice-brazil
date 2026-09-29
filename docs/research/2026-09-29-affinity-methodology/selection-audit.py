"""Compare concrete question sets and provisional evidence thresholds.

This is a descriptive study, not a publication decision or scoring change.
Default output: /tmp/farol-selection-audit.json.
"""

import argparse
import copy
import hashlib
import itertools
import json
import math
from collections import Counter
from pathlib import Path

BINARY = {"CONCORDA", "DISCORDA"}
RULES = list(itertools.product((8, 10), (0.5, 0.6, 0.7), (3, 4)))
REMOVED_PROFILE_REPRESENTATIVES = {"BR26-T026B", "BR26-T044"}


def category(thesis, candidate):
    return thesis["positions"][candidate]["analytical_position"]


def measurements(theses, candidate_ids):
    counts = [
        sum(category(thesis, candidate) in BINARY for thesis in theses)
        for candidate in candidate_ids
    ]
    themes = [
        len(
            {
                thesis["topic"]
                for thesis in theses
                if category(thesis, candidate) in BINARY
            }
        )
        for candidate in candidate_ids
    ]
    pairs = []
    for first, second in itertools.combinations(range(len(candidate_ids)), 2):
        first_id, second_id = candidate_ids[first], candidate_ids[second]
        shared = [
            thesis
            for thesis in theses
            if category(thesis, first_id) in BINARY
            and category(thesis, second_id) in BINARY
        ]
        opposed = [
            thesis
            for thesis in shared
            if category(thesis, first_id) != category(thesis, second_id)
        ]
        pairs.append(
            {
                "first_index": first,
                "second_index": second,
                "shared": len(shared),
                "opposed": len(opposed),
                "shared_ids": [thesis["id"] for thesis in shared],
                "opposed_ids": [thesis["id"] for thesis in opposed],
            }
        )
    return counts, themes, pairs


def report(theses, candidates, baseline, sensitivity=None):
    ids = [candidate["id"] for candidate in candidates]
    names = [candidate["name"] for candidate in candidates]
    counts, themes, pairs = measurements(theses, ids)
    baseline_counts, _, _ = measurements(baseline, ids)
    topic_counts = Counter(thesis["topic"] for thesis in theses)
    baseline_topics = Counter(thesis["topic"] for thesis in baseline)
    eligibility = []
    for minimum, coverage, minimum_themes in RULES:
        required = max(minimum, math.ceil(len(theses) * coverage))
        eligible = [
            index
            for index in range(len(ids))
            if counts[index] >= required and themes[index] >= minimum_themes
        ]
        common_pairs = [
            pair
            for pair in pairs
            if pair["first_index"] in eligible and pair["second_index"] in eligible
        ]
        eligibility.append(
            {
                "min_count": minimum,
                "min_coverage": coverage,
                "min_themes": minimum_themes,
                "effective_min_count": required,
                "count": len(eligible),
                "included": [names[index] for index in eligible],
                "excluded": [
                    name for index, name in enumerate(names) if index not in eligible
                ],
                "pairs": len(common_pairs),
                "pairs_zero": sum(pair["shared"] == 0 for pair in common_pairs),
                "pairs_under3": sum(pair["shared"] < 3 for pair in common_pairs),
                "pairs_min": min(
                    (pair["shared"] for pair in common_pairs), default=None
                ),
                "pairs_mean": (
                    round(
                        sum(pair["shared"] for pair in common_pairs)
                        / len(common_pairs),
                        6,
                    )
                    if common_pairs
                    else None
                ),
                "pairs_opposed": sum(pair["opposed"] > 0 for pair in common_pairs),
            }
        )
    return {
        "sensitivity": sensitivity,
        "n": len(theses),
        "ids": [thesis["id"] for thesis in theses],
        "question_texts": {thesis["id"]: thesis["text"] for thesis in theses},
        "themes": dict(sorted(topic_counts.items())),
        "categories": dict(
            sorted(
                Counter(
                    category(thesis, candidate)
                    for thesis in theses
                    for candidate in ids
                ).items()
            )
        ),
        "categorical": sum(counts),
        "loss_vs_30": sum(baseline_counts) - sum(counts),
        "topic_question_loss_vs_30": {
            topic: count - topic_counts[topic]
            for topic, count in sorted(baseline_topics.items())
        },
        "by_candidate": {
            name: {
                "categorical": count,
                "themes": theme_count,
                "coverage": round(count / len(theses), 6),
                "loss_vs_30": original - count,
            }
            for name, count, theme_count, original in zip(
                names, counts, themes, baseline_counts
            )
        },
        "pairs_zero": sum(pair["shared"] == 0 for pair in pairs),
        "pairs_opposed": sum(pair["opposed"] > 0 for pair in pairs),
        "pair_details": [
            {
                "a": names[pair["first_index"]],
                "b": names[pair["second_index"]],
                **{
                    key: value
                    for key, value in pair.items()
                    if key not in {"first_index", "second_index"}
                },
            }
            for pair in pairs
        ],
        "eligibility": eligibility,
    }


def search(theses, candidate_ids):
    """Exhaustive, identity-independent selection; eligibility never breaks ties."""
    topics = sorted({thesis["topic"] for thesis in theses})
    groups = [
        [index for index, thesis in enumerate(theses) if thesis["topic"] == topic]
        for topic in topics
    ]
    choices = [
        [
            (sum(1 << index for index in combination), size)
            for size in range(1, min(4, len(group)) + 1)
            for combination in itertools.combinations(group, size)
        ]
        for group in groups
    ]
    known = [
        sum(
            1 << index
            for index, thesis in enumerate(theses)
            if category(thesis, candidate) in BINARY
        )
        for candidate in candidate_ids
    ]
    candidate_pairs = list(itertools.combinations(range(len(candidate_ids)), 2))
    shared_masks = [known[first] & known[second] for first, second in candidate_pairs]
    opposed_masks = [
        sum(
            1 << index
            for index, thesis in enumerate(theses)
            if category(thesis, candidate_ids[first]) in BINARY
            and category(thesis, candidate_ids[second]) in BINARY
            and category(thesis, candidate_ids[first])
            != category(thesis, candidate_ids[second])
        )
        for first, second in candidate_pairs
    ]
    topic_masks = [sum(1 << index for index in group) for group in groups]
    selected = {}
    counts_by_size = Counter()
    best_balance = {}
    frontier = {}
    for choice in itertools.product(*choices):
        size = sum(value[1] for value in choice)
        if not 12 <= size <= 20:
            continue
        counts_by_size[size] += 1
        mask = sum(value[0] for value in choice)
        balance = sum(value[1] ** 2 for value in choice)
        available = [(candidate & mask).bit_count() for candidate in known]
        theme_counts = [
            sum(bool(candidate & mask & topic) for topic in topic_masks)
            for candidate in known
        ]
        qualified_counts = [
            sum(
                count >= max(minimum, math.ceil(size * coverage))
                and theme_count >= minimum_themes
                for count, theme_count in zip(available, theme_counts)
            )
            for minimum, coverage, minimum_themes in RULES
        ]
        if size not in frontier:
            frontier[size] = {
                "maximum_eligible_any_balance": [0] * len(RULES),
                "maximum_eligible_minimum_imbalance": [0] * len(RULES),
                "sets_at_minimum_imbalance": 0,
            }
        entry = frontier[size]
        entry["maximum_eligible_any_balance"] = [
            max(old, new)
            for old, new in zip(entry["maximum_eligible_any_balance"], qualified_counts)
        ]
        if size not in best_balance or balance < best_balance[size]:
            best_balance[size] = balance
            entry["sets_at_minimum_imbalance"] = 0
            entry["maximum_eligible_minimum_imbalance"] = [0] * len(RULES)
        if balance != best_balance[size]:
            continue
        entry["sets_at_minimum_imbalance"] += 1
        entry["maximum_eligible_minimum_imbalance"] = [
            max(old, new)
            for old, new in zip(
                entry["maximum_eligible_minimum_imbalance"], qualified_counts
            )
        ]
        subset_ids = tuple(
            thesis["id"] for index, thesis in enumerate(theses) if mask & (1 << index)
        )
        key = (
            balance,
            -sum(bool(mask & opposed) for opposed in opposed_masks),
            -sum((mask & shared).bit_count() >= 3 for shared in shared_masks),
            -sum(available),
            subset_ids,
        )
        if size not in selected or key < selected[size][0]:
            selected[size] = (key, mask)
    return (
        {
            size: [thesis for index, thesis in enumerate(theses) if mask & (1 << index)]
            for size, (_, mask) in sorted(selected.items())
        },
        {
            str(size): {
                "examined_sets": counts_by_size[size],
                "minimum_imbalance": best_balance[size],
                "selected_key": list(selected[size][0][:4]),
                **frontier[size],
            }
            for size in sorted(selected)
        },
    )


def t005_sensitivity(theses):
    """Apply a hypothetical recoding only to an in-memory copy of two scenarios."""
    changed = copy.deepcopy(theses)
    for thesis in changed:
        if thesis["id"] != "BR26-T005":
            continue
        thesis["text"] = (
            "O limite legal geral da jornada de trabalho deve ser de 36 horas "
            "semanais ou menos, sem redução salarial."
        )
        for candidate in ("280002541457", "280002538811", "280002552487"):
            thesis["positions"][candidate]["analytical_position"] = "CONCORDA"
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", type=Path, default=Path(__file__).resolve().parents[3]
    )
    parser.add_argument(
        "--output", type=Path, default=Path("/tmp/farol-selection-audit.json")
    )
    args = parser.parse_args()
    paths = {
        "theses": args.root / "data/theses/2026/theses.json",
        "candidates": args.root / "data/propostas/2026/candidates.json",
    }
    all_theses = json.loads(paths["theses"].read_text())["theses"]
    candidates = json.loads(paths["candidates"].read_text())
    active = [thesis for thesis in all_theses if thesis["status"] == "approved"]
    core = [thesis for thesis in active if thesis["selection"] == "nucleus"]
    deduplicated = [
        thesis for thesis in core if thesis["id"] not in REMOVED_PROFILE_REPRESENTATIVES
    ]
    balanced, frontier = search(deduplicated, [item["id"] for item in candidates])
    scenarios = {
        "active30": report(active, candidates, active),
        "core23": report(core, candidates, active),
        "deduplicated21": report(deduplicated, candidates, active),
    }
    scenarios.update(
        {
            f"balanced{size}": report(subset, candidates, active)
            for size, subset in balanced.items()
        }
    )
    draft050 = next(thesis for thesis in all_theses if thesis["id"] == "BR26-T050")
    for size in (18, 20):
        scenarios[f"balanced{size}_plus_draft050"] = report(
            sorted(balanced[size] + [draft050], key=lambda thesis: thesis["id"]),
            candidates,
            active,
            "Draft T050 added for sensitivity only; no editorial approval is implied.",
        )
        scenarios[f"balanced{size}_preliminary_t005"] = report(
            t005_sensitivity(balanced[size]),
            candidates,
            active,
            (
                "Hypothetical T005 wording <=36 hours without reduced pay, following "
                "a separate preliminary PDF reading reported in the study: Hertz "
                "and Samara become categorical agree; Rui changes disagree to agree. "
                "Lula/Zema disagreement is retained as an unverified scope assumption; "
                "a 40-hour goal or 44-hour alternative regime does not alone establish "
                "opposition to the broader wording. These poles may not survive review. "
                "Not an approved coding or new publication. Subset selection was NOT "
                "rerun on these assumptions. Original checked-in data are unchanged."
            ),
        )
    result = {
        "schema_version": 1,
        "inputs": {
            name: {
                "path": str(path.relative_to(args.root)),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
            for name, path in paths.items()
        },
        "method": {
            "assumptions": (
                "Every question answered; unweighted documentary availability only. "
                "Only CONCORDA/DISCORDA count. Thresholds are provisional beta rules, "
                "not validated confidence levels. No vote/affinity score is calculated."
            ),
            "duplicates": (
                "Use the nucleus; retain lower stable ID for each equal categorical "
                "profile T026A/B and T043/044. This deterministic representative choice "
                "does not establish semantic interchangeability or editorial priority."
            ),
            "search_universe": (
                "Every subset of the 21-item deduplicated nucleus with 12..20 questions, "
                "all nine existing topics, at most four questions per topic."
            ),
            "selection_objective_in_order": [
                "Minimize sum of squared topic question counts, at fixed size.",
                "Maximize distinct candidature pairs with at least one direct opposition.",
                "Maximize pairs with at least three shared categorical questions.",
                "Maximize total categorical positions.",
                "Break remaining ties by ascending thesis IDs.",
            ],
            "identity_and_eligibility": (
                "Selection objective never uses names, parties, vote scores or eligibility. "
                "Eligibility is evaluated afterwards. Frontier upper bounds count eligible "
                "candidatures anonymously for diagnosis only and do not select scenarios."
            ),
            "frontier_rules": [
                {"min_count": minimum, "min_coverage": coverage, "min_themes": themes}
                for minimum, coverage, themes in RULES
            ],
            "tradeoffs": (
                "Preserving all nine existing topics does not fill absent environment, "
                "agriculture or infrastructure coverage. Equal topic importance is an "
                "editorial assumption. Availability thresholds prevent one-item ranking "
                "but do not make different evidence bases identical."
            ),
        },
        "search_frontier": frontier,
        "scenarios": scenarios,
    }
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"Wrote {args.output}")
    print(
        "Examined",
        sum(value["examined_sets"] for value in frontier.values()),
        "subsets",
    )
    for label, scenario in scenarios.items():
        selected = next(
            rule
            for rule in scenario["eligibility"]
            if (rule["min_count"], rule["min_coverage"], rule["min_themes"])
            == (10, 0.5, 4)
        )
        print(
            f"{label}: questions={scenario['n']}, categorical={scenario['categorical']}, "
            f"eligible_min10_50pct_4themes={selected['count']}"
        )


if __name__ == "__main__":
    main()
