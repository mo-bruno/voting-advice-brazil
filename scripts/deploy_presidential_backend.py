"""Publish the filtered API before importing 2026 into the shared database."""

from __future__ import annotations

import argparse
import json
import subprocess
from typing import Any

SERVICE = "farol-politico-api"


def _gcloud_json(*arguments: str) -> dict[str, Any]:
    result = subprocess.run(
        ["gcloud", *arguments, "--format=json", "--quiet"],
        check=True, stdout=subprocess.PIPE, text=True,
    )
    payload: dict[str, Any] = json.loads(result.stdout)
    return payload


def _published_year(region: str) -> str:
    service = _gcloud_json("run", "services", "describe", SERVICE, f"--region={region}")
    traffic = [item for item in service["status"]["traffic"] if item.get("percent", 0) > 0]
    if len(traffic) != 1 or traffic[0]["percent"] != 100 or not traffic[0].get("revisionName"):
        raise ValueError("A ponte exige uma única revisão publicada com 100% do tráfego")
    revision = _gcloud_json("run", "revisions", "describe", traffic[0]["revisionName"], f"--region={region}")
    containers = revision["spec"]["containers"]
    if len(containers) != 1:
        raise ValueError("Não foi possível identificar o contêiner da API publicada")
    environment = containers[0].get("env", [])

    def setting(name: str, default: str) -> str:
        entries = [item for item in environment if item["name"] == name]
        if not entries:
            return default
        if len(entries) != 1 or not isinstance(entries[0].get("value"), str):
            raise ValueError(f"Não foi possível ler {name} da revisão publicada")
        return str(entries[0]["value"])

    year = setting("ACTIVE_ELECTION_YEAR", "2022")
    if year not in {"2022", "2026"}:
        raise ValueError(f"ACTIVE_ELECTION_YEAR não suportado nesta transição: {year}")
    if setting("ACTIVE_ELECTION_OFFICE", "presidente") != "presidente":
        raise ValueError("A revisão publicada não está configurada para presidente")
    return year


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["bridge", "activate"])
    parser.add_argument("--image", required=True)
    parser.add_argument("--region", required=True)
    args = parser.parse_args(argv)
    year = _published_year(args.region) if args.mode == "bridge" else "2026"
    print(f"Publicando {args.mode}: eleição presidencial de {year}", flush=True)
    deployed = _gcloud_json(
        "run", "deploy", SERVICE,
        f"--image={args.image}", f"--region={args.region}", "--platform=managed",
        "--allow-unauthenticated", "--memory=512Mi", "--cpu=1",
        "--min-instances=0", "--max-instances=3", "--concurrency=80",
        "--timeout=60s", "--port=8080", "--no-traffic",
        f"--update-env-vars=DATA_DIR=/data,APP_ENV=prod,ACTIVE_ELECTION_YEAR={year},ACTIVE_ELECTION_OFFICE=presidente,IOT_FEATURE_ENABLED=false,NVIDIA_MODERATION_MODEL=nvidia/nemotron-3-super-120b-a12b",
        "--update-secrets=DATABASE_URL=database-url:latest,GNEWS_API_KEY=gnews-api-key:latest,NVIDIA_API_KEY=nvidia-api-key:latest",
    )
    status = deployed["status"]
    ready_revision = status.get("latestReadyRevisionName")
    if not ready_revision or ready_revision != status.get("latestCreatedRevisionName"):
        raise ValueError("A nova revisão não ficou pronta; tráfego preservado")
    # Pin the revision just created, not whichever revision happens to be LATEST.
    subprocess.run([
        "gcloud", "run", "services", "update-traffic", SERVICE,
        f"--region={args.region}", f"--to-revisions={ready_revision}=100", "--quiet",
    ], check=True)
    if args.mode == "bridge":
        print(f"SAFE_BRIDGE_REVISION={ready_revision}", flush=True)
    else:
        print(f"PUBLISHED_REVISION={ready_revision}", flush=True)


if __name__ == "__main__":
    main()
