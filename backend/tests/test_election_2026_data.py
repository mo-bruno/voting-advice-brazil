import hashlib
import json
import runpy
from pathlib import Path
from zipfile import ZipFile

import pytest

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DATA_ROOT = REPOSITORY_ROOT / "data"
CANDIDATES_FILE = DATA_ROOT / "propostas" / "2026" / "candidates.json"
THESES_FILE = DATA_ROOT / "theses" / "2026" / "theses.json"
SOURCE_BANK_MANIFEST = (
    DATA_ROOT / "theses" / "2026" / "source-bank-manifest-v3.json"
)
VALID_POSITIONS = {"concordo", "discordo", "neutro", "sem_posicao"}
EXPECTED_APPROVED_THESES = {
    "BR26-T001",
    "BR26-T002",
    "BR26-T003",
    "BR26-T005",
    "BR26-T011",
    "BR26-T015",
    "BR26-T017",
    "BR26-T018",
    "BR26-T026A",
    "BR26-T026B",
    "BR26-T034A",
    "BR26-T034B",
    "BR26-T036",
    "BR26-T038",
    "BR26-T041",
    "BR26-T042",
    "BR26-T043",
    "BR26-T044",
    "BR26-T054",
    "BR26-T056",
    "BR26-T057",
    "BR26-T058",
    "BR26-T061",
    "BR26-T062",
    "BR26-T063",
    "BR26-T064",
    "BR26-T065",
    "BR26-T066",
    "BR26-T067",
    "BR26-T068",
}


def _load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_presidential_2026_candidate_snapshot_is_complete_and_unique():
    candidates = _load_json(CANDIDATES_FILE)

    assert len(candidates) == 13
    assert len({candidate["id"] for candidate in candidates}) == len(candidates)
    assert len({candidate["number"] for candidate in candidates}) == len(candidates)
    assert {candidate["election_year"] for candidate in candidates} == {2026}
    assert {candidate["office"] for candidate in candidates} == {"presidente"}


def test_current_replacement_is_published_without_inheriting_old_positions():
    candidates = _load_json(CANDIDATES_FILE)
    candidate_ids = {candidate["id"] for candidate in candidates}

    assert "280002554479" in candidate_ids  # Leonardo Avalanche
    assert "280002553884" not in candidate_ids  # Pablo Marçal, substituído
    replacement = next(
        candidate for candidate in candidates if candidate["id"] == "280002554479"
    )
    assert replacement["official_status"] == "PENDENTE DE JULGAMENTO"
    assert replacement["inserted_on_ballot"] == "SIM"

    approved_theses = (
        thesis
        for thesis in _load_json(THESES_FILE)["theses"]
        if thesis["status"] == "approved"
    )
    for thesis in approved_theses:
        position = thesis["positions"]["280002554479"]
        assert position["review"]["source_position"] is None
        assert position["review"]["source_evidence"] == []
        assert position["review"]["document_id"] == "PG_2026_BR_280002554479_01"
        assert all(
            evidence["document_id"] == "PG_2026_BR_280002554479_01"
            for evidence in position["evidence"]
        )


def test_every_published_candidate_has_an_official_jpeg():
    candidates = _load_json(CANDIDATES_FILE)
    expected_photo_names = {f"{candidate['id']}.jpg" for candidate in candidates}

    for candidate in candidates:
        relative_url = candidate["photo_url"]
        assert relative_url == f"/data/fotos/2026/BR/{candidate['id']}.jpg"
        photo_path = DATA_ROOT / relative_url.removeprefix("/data/")
        assert photo_path.is_file(), f"foto ausente para {candidate['name']}"
        assert photo_path.read_bytes().startswith(b"\xff\xd8\xff")

    photo_dir = DATA_ROOT / "fotos" / "2026" / "BR"
    assert {path.name for path in photo_dir.glob("*.jpg")} == expected_photo_names


def test_photo_export_removes_jpegs_from_a_previous_roster(tmp_path):
    builder = runpy.run_path(
        str(REPOSITORY_ROOT / "scripts" / "build_presidential_2026_data.py")
    )
    extract_photos = builder["_extract_photos"]
    photos_zip = tmp_path / "photos.zip"
    output_dir = tmp_path / "BR"
    output_dir.mkdir()
    (output_dir / "replaced-candidate.jpg").write_bytes(b"old")
    with ZipFile(photos_zip, "w") as zipped:
        zipped.writestr("FBRcurrent-candidate_div.jpg", b"\xff\xd8\xffnew")

    extract_photos(photos_zip, [{"id": "current-candidate"}], output_dir)

    assert {path.name for path in output_dir.glob("*.jpg")} == {"current-candidate.jpg"}


def test_editorial_payload_keeps_all_source_theses_and_a_quizable_core():
    payload = _load_json(THESES_FILE)
    theses = payload["theses"]

    assert payload["metadata"]["election"] == 2026
    assert payload["metadata"]["office"] == "presidente"
    assert len(theses) == 70
    assert payload["metadata"]["reviewed_formulations"] == 70
    assert payload["metadata"]["reviewed_cells"] == 910
    assert payload["metadata"]["published_theses"] == 30
    assert sum(thesis["status"] == "approved" for thesis in theses) == 30
    assert sum(thesis["status"] == "draft" for thesis in theses) == 40
    assert len({thesis["id"] for thesis in theses}) == len(theses)
    assert {
        thesis["id"] for thesis in theses if thesis["status"] == "approved"
    } == EXPECTED_APPROVED_THESES


def test_expansion_is_bound_to_the_versioned_source_bank():
    payload = _load_json(THESES_FILE)
    manifest = _load_json(SOURCE_BANK_MANIFEST)
    entries = manifest["text_sha256_by_bank_id"]
    expansion = [
        thesis for thesis in payload["theses"] if thesis.get("source_bank_ids")
    ]

    assert manifest["source_count"] == len(entries) == 111
    assert all(
        set(thesis["source_bank_ids"]) <= set(entries) for thesis in expansion
    )
    assert payload["metadata"]["editorial_inputs"]["source_bank"] == {
        "file": SOURCE_BANK_MANIFEST.name,
        "sha256": hashlib.sha256(SOURCE_BANK_MANIFEST.read_bytes()).hexdigest(),
        "source_count": 111,
        "source_sha256": manifest["source_sha256"],
    }


def test_every_thesis_has_a_valid_position_for_every_candidate():
    candidate_ids = {candidate["id"] for candidate in _load_json(CANDIDATES_FILE)}
    theses = _load_json(THESES_FILE)["theses"]

    for thesis in theses:
        assert set(thesis["positions"]) == candidate_ids
        assert {
            position["position"] for position in thesis["positions"].values()
        } <= VALID_POSITIONS
        assert all(
            position["analytical_position"] != "PENDENTE"
            and position["review"]["status"] == "full_document_reviewed_automated"
            for position in thesis["positions"].values()
        )


def test_question_selection_is_evidence_driven_and_preserved_in_the_snapshot():
    payload = _load_json(THESES_FILE)
    theses = payload["theses"]

    assert {
        selection: sum(thesis["selection"] == selection for thesis in theses)
        for selection in {"nucleus", "complementary", "rejected"}
    } == {"nucleus": 23, "complementary": 7, "rejected": 40}
    assert {
        thesis["id"] for thesis in theses if thesis["selection"] == "complementary"
    } == {
        "BR26-T034A",
        "BR26-T034B",
        "BR26-T054",
        "BR26-T057",
        "BR26-T061",
        "BR26-T062",
        "BR26-T068",
    }
    for thesis in theses:
        categorical_positions = [
            position["position"]
            for position in thesis["positions"].values()
            if position["position"] in {"concordo", "discordo"}
        ]
        categorical = set(categorical_positions)
        if thesis["selection"] == "nucleus":
            assert categorical == {"concordo", "discordo"}
            assert len(categorical_positions) >= 3
            assert thesis["status"] == "approved"
        elif thesis["selection"] == "complementary":
            assert categorical == {"concordo", "discordo"}
            assert len(categorical_positions) == 2
            assert thesis["status"] == "approved"
        else:
            assert thesis["status"] == "draft"
            if categorical == {"concordo", "discordo"}:
                assert thesis.get("editorial_problems")


def test_approved_theses_are_atomic_contrasting_and_evidence_backed():
    theses = _load_json(THESES_FILE)["theses"]

    for thesis in (item for item in theses if item["status"] == "approved"):
        assert "[" not in thesis["text"] and "]" not in thesis["text"]
        positions = thesis["positions"].values()
        categorical = {
            position["position"]
            for position in positions
            if position["position"] in {"concordo", "discordo"}
        }
        assert categorical == {"concordo", "discordo"}
        for position in thesis["positions"].values():
            if position["position"] in categorical:
                assert position["quote"]
                assert position["source_ref"]


def test_conditional_bolsa_familia_evidence_is_not_scored_as_categorical():
    theses = _load_json(THESES_FILE)["theses"]
    thesis = next(item for item in theses if item["id"] == "BR26-T011")

    assert thesis["positions"]["280002552487"]["position"] == "sem_posicao"


def test_documented_positions_survive_editorial_export_with_full_passages():
    theses = {item["id"]: item for item in _load_json(THESES_FILE)["theses"]}
    fiscal = theses["BR26-T001"]["positions"]["280002540694"]
    labor = theses["BR26-T003"]["positions"]["280002538811"]
    health = theses["BR26-T026B"]["positions"]["280002538811"]

    assert fiscal["position"] == "discordo"
    assert "substituir o arcabouço fiscal" in fiscal["quote"]
    assert labor["position"] == "concordo"
    assert "TRABALHISTA" in labor["quote"]
    assert "#page=12" in labor["source_ref"]
    assert "#page=13" in labor["source_ref"]
    assert health["position"] == "concordo"
    assert "gestão direta e pública" in health["quote"]


def test_publication_has_complete_documentary_review_without_claiming_human_review():
    payload = _load_json(THESES_FILE)
    assert payload["metadata"]["documentary_review_status"] == "complete_automated"
    assert payload["metadata"]["human_reviewed"] is False
    assert len(payload["metadata"]["analysed_documents"]) == 13
    for document in payload["metadata"]["analysed_documents"].values():
        assert document["pages_reviewed"] == list(range(1, document["pages_total"] + 1))
    assert payload["metadata"]["reviewed_cells"] == 910
    for thesis in payload["theses"]:
        for position in thesis["positions"].values():
            assert position["analytical_position"] != "PENDENTE"
            assert position["review"]["status"] == "full_document_reviewed_automated"
            if position["analytical_position"] == "NAO_ENCONTRADA":
                assert position["review"]["absence_reason"]
                assert position["review"]["search_terms"]


def test_conditional_evidence_and_original_classification_are_preserved():
    thesis = next(
        item for item in _load_json(THESES_FILE)["theses"] if item["id"] == "BR26-T011"
    )
    position = thesis["positions"]["280002552487"]
    assert position.get("analytical_position") == "CONDICIONAL_OU_MISTA"
    assert position["evidence"]
    assert position["review"]["source_position"] == "DISCORDA"
    assert "enquanto durar" in position["quote"]


def test_plan_verification_rejects_same_document_id_with_changed_bytes(tmp_path):
    builder = runpy.run_path(
        str(REPOSITORY_ROOT / "scripts" / "build_presidential_2026_data.py")
    )
    verify = builder.get("_verify_plan_snapshot")
    assert callable(verify), "o exportador precisa validar os PDFs analisados"
    documents = tmp_path / "documents.jsonl"
    documents.write_text(
        json.dumps(
            {
                "documento_id": "PG_2026_BR_123_01",
                "candidato_id": "123",
                "disputa_id": "BR_PRESIDENTE_2026",
                "arquivo_zip_membro": "BR/2026BR123_01.pdf",
                "sha256": hashlib.sha256(b"reviewed PDF bytes").hexdigest(),
            }
        )
        + "\n"
    )
    plans = tmp_path / "plans.zip"
    with ZipFile(plans, "w") as zipped:
        zipped.writestr("BR/2026BR123_01.pdf", b"different PDF bytes")
    with pytest.raises(ValueError, match="(?i)hash|sha|documento alterado"):
        verify(plans, documents)


def test_every_active_cell_has_explicit_audit_and_document_provenance():
    payload = _load_json(THESES_FILE)
    assert payload["metadata"].get("editorial_inputs")
    for thesis in payload["theses"]:
        if thesis["status"] != "approved":
            continue
        for position in thesis["positions"].values():
            assert position.get("analytical_position")
            assert position.get("review", {}).get("reason")
            for evidence in position.get("evidence", []):
                assert len(evidence["sha256"]) == 64


def test_changed_editorial_input_requires_a_new_review(tmp_path):
    builder = runpy.run_path(
        str(REPOSITORY_ROOT / "scripts" / "build_presidential_2026_data.py")
    )
    changed_positions = tmp_path / "posicoes.jsonl"
    changed_positions.write_text('{"changed": true}\n')
    experiment = REPOSITORY_ROOT / "experimento-eleicoes-2026"
    with pytest.raises(ValueError, match="Entrada editorial mudou"):
        builder["_build_theses"](
            candidate_ids=[],
            positions_path=changed_positions,
            source_theses_path=experiment
            / "disputas/BR_PRESIDENTE_2026/teses_selecionadas.json",
            resource_hashes={},
            review_path=THESES_FILE.parent / "editorial-review-2026-09-20.json",
            documents_path=experiment / "fontes/documentos.jsonl",
            plans_zip=experiment
            / "fontes/arquivos/proposta_governo_2026_BR_20260919.zip",
        )
