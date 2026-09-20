"""Exercise the release script without contacting Google Cloud."""

import json
import runpy
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/deploy_presidential_backend.py"


def _run_rollout(monkeypatch, mode, env=(), traffic=None, fail_read=False, ready=True,
                 stale_service=False, revision=None, revision_error=False, created="api-new"):
    calls = []
    published = traffic if traffic is not None else [{"revisionName": "api-published", "percent": 100}]

    def run(command, **kwargs):
        calls.append(command)
        action = command[1:4]
        if action == ["run", "services", "describe"]:
            if fail_read:
                raise subprocess.CalledProcessError(1, command)
            result = {"status": {"traffic": published}}
        elif action == ["run", "revisions", "describe"]:
            if command[4] == "api-published":
                result = {"spec": {"containers": [{"env": list(env)}]}}
            else:
                assert command[4] == "api-new"
                if revision_error:
                    raise subprocess.CalledProcessError(1, command)
                # A no-traffic revision can be Ready while Active is False.
                result = revision if revision is not None else {
                    "metadata": {"name": "api-new", "generation": 1},
                    "status": {"observedGeneration": 1, "conditions": [
                        {"type": "Ready", "status": "True" if ready else "False"},
                        {"type": "Active", "status": "False", "reason": "Retired"},
                    ]},
                }
        elif command[1:3] == ["run", "deploy"]:
            result = {"status": {"latestReadyRevisionName": "api-new" if ready and not stale_service else "api-old", "latestCreatedRevisionName": created}}
        else:
            result = {}
        return subprocess.CompletedProcess(command, 0, stdout=json.dumps(result), stderr="")

    monkeypatch.setattr(subprocess, "run", run)
    assert SCRIPT.is_file(), "release script is missing"
    module = runpy.run_path(str(SCRIPT))
    return calls, lambda: module["main"]([mode, "--image", "example/image:build", "--region", "us-east4"])


@pytest.mark.parametrize("env,year", [
    ([], "2022"),
    ([{"name": "ACTIVE_ELECTION_YEAR", "value": "2026"}], "2026"),
])
def test_bridge_keeps_published_election_and_switches_all_traffic(monkeypatch, env, year):
    calls, execute = _run_rollout(monkeypatch, "bridge", env)
    execute()

    deploy = next(command for command in calls if command[1:3] == ["run", "deploy"])
    assert any(arg.startswith(f"--update-env-vars=DATA_DIR=/data,APP_ENV=prod,ACTIVE_ELECTION_YEAR={year},ACTIVE_ELECTION_OFFICE=presidente,") for arg in deploy)
    assert "--no-traffic" in deploy
    assert calls[-1][1:4] == ["run", "services", "update-traffic"]
    assert "--to-revisions=api-new=100" in calls[-1]


def test_final_activation_explicitly_uses_2026(monkeypatch):
    calls, execute = _run_rollout(monkeypatch, "activate")
    execute()

    assert any(arg.startswith("--update-env-vars=DATA_DIR=/data,APP_ENV=prod,ACTIVE_ELECTION_YEAR=2026,ACTIVE_ELECTION_OFFICE=presidente,") for arg in calls[0])
    assert "--to-revisions=api-new=100" in calls[-1]


@pytest.mark.parametrize("mode", ["bridge", "activate"])
def test_ready_no_traffic_revision_is_promoted_despite_stale_service_pointer(monkeypatch, mode):
    calls, execute = _run_rollout(monkeypatch, mode, stale_service=True)
    execute()

    assert calls[-2][1:5] == ["run", "revisions", "describe", "api-new"]
    assert calls[-1][1:4] == ["run", "services", "update-traffic"]
    assert "--to-revisions=api-new=100" in calls[-1]


def test_rollout_keeps_current_moderation_and_disabled_iot(monkeypatch):
    calls, execute = _run_rollout(monkeypatch, "activate")
    execute()
    deploy = calls[0]
    secrets = next(arg for arg in deploy if arg.startswith("--update-secrets="))
    assert "NVIDIA_API_KEY=nvidia-api-key:latest" in secrets
    assert "GROQ_API_KEY" not in secrets
    env = next(arg for arg in deploy if arg.startswith("--update-env-vars="))
    assert "IOT_FEATURE_ENABLED=false" in env
    assert "NVIDIA_MODERATION_MODEL=nvidia/nemotron-3-super-120b-a12b" in env


def test_bridge_reports_exact_safe_rollback_revision(monkeypatch, capsys):
    _, execute = _run_rollout(monkeypatch, "bridge")
    execute()
    assert "SAFE_BRIDGE_REVISION=api-new" in capsys.readouterr().out


def test_unreadable_service_stops_before_any_deploy(monkeypatch):
    calls, execute = _run_rollout(monkeypatch, "bridge", fail_read=True)
    with pytest.raises(subprocess.CalledProcessError):
        execute()
    assert len(calls) == 1


def test_split_traffic_stops_before_any_deploy(monkeypatch):
    calls, execute = _run_rollout(monkeypatch, "bridge", traffic=[
        {"revisionName": "api-published", "percent": 50},
        {"revisionName": "another-revision", "percent": 50},
    ])
    with pytest.raises(ValueError, match="tráfego"):
        execute()
    assert len(calls) == 1


def test_unresolved_election_setting_stops_before_any_deploy(monkeypatch):
    calls, execute = _run_rollout(monkeypatch, "bridge", env=[
        {"name": "ACTIVE_ELECTION_YEAR", "valueFrom": {"secretKeyRef": {"name": "year"}}},
    ])
    with pytest.raises(ValueError, match="ACTIVE_ELECTION_YEAR"):
        execute()
    assert len(calls) == 2


def test_unready_new_revision_never_receives_traffic(monkeypatch):
    calls, execute = _run_rollout(monkeypatch, "activate", ready=False)
    with pytest.raises(ValueError, match="pronta"):
        execute()
    assert not any(command[1:4] == ["run", "services", "update-traffic"] for command in calls)


@pytest.mark.parametrize("conditions", [
    [],
    [{"type": "Ready", "status": "False"}],
    [{"type": "Ready", "status": "Unknown"}],
    [{"type": "Ready", "status": "True"}, {"type": "Ready", "status": "False"}],
])
def test_unconfirmed_revision_readiness_never_changes_traffic(monkeypatch, conditions):
    revision = {
        "metadata": {"name": "api-new", "generation": 1},
        "status": {"observedGeneration": 1, "conditions": conditions},
    }
    calls, execute = _run_rollout(monkeypatch, "activate", revision=revision)
    with pytest.raises(ValueError):
        execute()
    assert not any(command[1:4] == ["run", "services", "update-traffic"] for command in calls)


@pytest.mark.parametrize("name,generation,observed", [
    ("api-other", 1, 1),
    ("api-new", 2, 1),
    ("api-new", 1, None),
    ("api-new", None, None),
])
def test_unconfirmed_revision_identity_or_generation_never_changes_traffic(monkeypatch, name, generation, observed):
    revision = {
        "metadata": {"name": name, "generation": generation},
        "status": {"observedGeneration": observed, "conditions": [{"type": "Ready", "status": "True"}]},
    }
    calls, execute = _run_rollout(monkeypatch, "activate", revision=revision)
    with pytest.raises(ValueError):
        execute()
    assert not any(command[1:4] == ["run", "services", "update-traffic"] for command in calls)


def test_created_revision_read_failure_never_changes_traffic(monkeypatch):
    calls, execute = _run_rollout(monkeypatch, "activate", revision_error=True)
    with pytest.raises(subprocess.CalledProcessError):
        execute()
    assert not any(command[1:4] == ["run", "services", "update-traffic"] for command in calls)


@pytest.mark.parametrize("created", [None, ""])
def test_missing_created_revision_never_reads_or_promotes_old_revision(monkeypatch, created):
    calls, execute = _run_rollout(monkeypatch, "activate", created=created)
    with pytest.raises(ValueError):
        execute()
    assert len(calls) == 1


@pytest.mark.parametrize("name,value", [
    ("ACTIVE_ELECTION_YEAR", ""),
    ("ACTIVE_ELECTION_YEAR", "2024"),
    ("ACTIVE_ELECTION_OFFICE", "governador"),
])
def test_unknown_election_stops_before_any_deploy(monkeypatch, name, value):
    calls, execute = _run_rollout(monkeypatch, "bridge", env=[{"name": name, "value": value}])
    with pytest.raises(ValueError):
        execute()
    assert len(calls) == 2
