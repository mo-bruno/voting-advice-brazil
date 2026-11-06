"""Evaluate synthetic moderation cases against NVIDIA; never publish community data."""

import argparse
import hashlib
import json
import statistics
import sys
from datetime import datetime, timezone
from pathlib import Path
from time import perf_counter

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from app.config import Settings  # noqa: E402
from app.infrastructure.llm import moderation_client  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--repeat", type=int, choices=(1, 2, 3), default=2)
    parser.add_argument("--case", action="append", dest="case_ids", help="Run only this case ID; repeat the flag to select more.")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    try:
        settings = Settings(_env_file=ROOT / "backend/.env")
    except ValueError:
        print("Invalid local environment configuration; no requests sent.")
        return 2
    if not settings.nvidia_api_key:
        print("Configure NVIDIA_API_KEY in the environment or backend/.env.")
        return 2

    fixture = ROOT / "backend/tests/fixtures/nvidia_moderation_cases.json"
    cases = json.loads(fixture.read_text(encoding="utf-8"))
    if args.case_ids:
        unknown = set(args.case_ids) - {case["id"] for case in cases}
        if unknown:
            parser.error("Unknown case ID")
        cases = [case for case in cases if case["id"] in args.case_ids]
    client = moderation_client.NvidiaNimModerationClient(
        settings.nvidia_api_key, model=settings.nvidia_moderation_model,
    )
    report = {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "model": settings.nvidia_moderation_model,
        "client_sha256": hashlib.sha256(Path(moderation_client.__file__).read_bytes()).hexdigest(),
        "fixtures_sha256": hashlib.sha256(fixture.read_bytes()).hexdigest(),
        "case_count": len(cases),
        "repeat": args.repeat,
        "status": "RUNNING",
        "results": [],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    for repetition in range(1, args.repeat + 1):
        for case in cases:
            row = {"id": case["id"], "repetition": repetition, "expected": case["approved"]}
            started = perf_counter()
            try:
                decision = (
                    client.moderate_comment(case["content"], case["parent_content"])
                    if "parent_content" in case else client.moderate(case["content"])
                )
                row.update(approved=decision.approved, reason=decision.reason.replace(settings.nvidia_api_key, "[REDACTED]"))
                row["passed"] = decision.approved is case["approved"] and (
                    decision.approved or bool(decision.reason.strip())
                )
            except Exception as error:
                # Provider bodies and exception messages can contain credentials.
                row.update(passed=False, error_type=type(error).__name__)
                cause = error.__context__
                if cause is not None:
                    row["cause_type"] = type(cause).__name__
                if isinstance(cause, moderation_client.httpx.HTTPStatusError):
                    row["http_status"] = cause.response.status_code
            row["elapsed_seconds"] = round(perf_counter() - started, 3)
            row["passed"] = row["passed"] and row["elapsed_seconds"] <= 20
            report["results"].append(row)
            args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(json.dumps({key: row[key] for key in ("id", "repetition", "passed", "elapsed_seconds")}), flush=True)

    rows = report["results"]
    failed = sum(not row["passed"] for row in rows)
    report.update(
        status="PASSED_SAMPLE" if not failed else "FAILED_SAMPLE",
        passed=len(rows) - failed,
        failed=failed,
        median_seconds=round(statistics.median(row["elapsed_seconds"] for row in rows), 3),
        max_seconds=max(row["elapsed_seconds"] for row in rows),
    )
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("status", "passed", "failed", "median_seconds", "max_seconds")}))
    return int(failed > 0)


if __name__ == "__main__":
    raise SystemExit(main())
