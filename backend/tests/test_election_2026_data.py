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
VALID_POSITIONS = {"concordo", "discordo", "neutro", "sem_posicao"}
EXPECTED_THESES = (
    "B01-Q01", "B01-Q02", "B01-Q03", "B01-Q04", "FB-Q05",
    "FB-Q06", "FB-Q07", "FB-Q23", "FB-Q10", "FB-Q24",
    "FB-Q12", "FB-Q25", "FB-Q14", "FB-Q15", "FB-Q16",
    "FB-Q17", "FB-Q18", "FB-Q19", "FB-Q21", "FB-Q22",
)
EXPECTED_TOPICS = {
    "economia_desenvolvimento",
    "estado_gestao",
    "infraestrutura_territorio",
    "meio_ambiente_clima",
    "ciencia_tecnologia_inovacao",
    "bem_estar_social",
    "educacao_cultura_sociedade",
    "cidadania_direitos",
    "seguranca_publica",
    "soberania_relacoes_internacionais",
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


def test_published_roster_includes_replacement_and_excludes_pablo_marcal():
    candidate_ids = {candidate["id"] for candidate in _load_json(CANDIDATES_FILE)}

    assert "280002554479" in candidate_ids  # Leonardo Avalanche
    assert "280002553884" not in candidate_ids  # excluído por decisão editorial


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


def test_affinity_beta_publishes_the_approved_version_3_battery():
    payload = _load_json(THESES_FILE)
    metadata = payload["metadata"]
    theses = payload["theses"]

    assert metadata["election"] == 2026
    assert metadata["office"] == "presidente"
    assert metadata["battery_id"] == "full-battery-human-review-v3"
    assert metadata["battery_version"] == 3
    assert metadata["methodology_version"] == "affinity-beta-v1"
    assert metadata["battery_human_approved"] is True
    assert metadata["candidate_positions_human_reviewed"] is False
    assert metadata["response_buttons"] == [
        "Concordo", "Discordo", "Neutro", "Pular",
    ]
    assert metadata["reviewed_cells"] == 260
    assert metadata["published_theses"] == 20
    assert len(theses) == 20
    assert all(thesis["status"] == "approved" for thesis in theses)
    assert tuple(thesis["id"] for thesis in theses) == EXPECTED_THESES
    assert {thesis["topic"] for thesis in theses} == EXPECTED_TOPICS


def test_every_thesis_has_an_auditable_position_for_every_candidate():
    candidate_ids = {candidate["id"] for candidate in _load_json(CANDIDATES_FILE)}
    payload = _load_json(THESES_FILE)

    assert set(payload["metadata"]["analysed_documents"]) == candidate_ids
    for document in payload["metadata"]["analysed_documents"].values():
        assert document["pages_reviewed"] == list(
            range(1, document["pages_total"] + 1)
        )
        assert len(document["sha256"]) == 64

    for thesis in payload["theses"]:
        assert set(thesis["positions"]) == candidate_ids
        for position in thesis["positions"].values():
            assert position["position"] in VALID_POSITIONS
            assert position["analytical_position"] in {
                "CONCORDA", "DISCORDA", "CONDICIONAL_OU_MISTA", "NAO_ENCONTRADA",
            }
            review = position["review"]
            assert review["status"] == "full_document_reviewed_agent"
            assert review["reason"]
            assert review["full_text_search_completed"] is True
            assert review["document_id"].startswith("PG_2026_BR_")
            assert len(review["document_sha256"]) == 64
            assert position["source_url"].startswith("https://")


def test_only_unconditional_poles_are_scored_as_candidate_stances():
    payload = _load_json(THESES_FILE)

    for thesis in payload["theses"]:
        for position in thesis["positions"].values():
            analytical = position["analytical_position"]
            if analytical == "CONCORDA":
                assert position["position"] == "concordo"
            elif analytical == "DISCORDA":
                assert position["position"] == "discordo"
            else:
                # Uma posição condicionada não é a mesma coisa que a resposta
                # neutra do usuário; ambas as categorias ficam fora do score.
                assert position["position"] == "sem_posicao"

            if analytical in {"CONCORDA", "DISCORDA", "CONDICIONAL_OU_MISTA"}:
                assert position["quote"]
                assert position["evidence"]
                assert position["source_ref"]
            else:
                assert position["review"]["absence_reason"]
                assert position["review"]["search_terms"]


def test_ranking_rule_is_versioned_and_uses_comparable_categories():
    rule = _load_json(THESES_FILE)["metadata"]["ranking_eligibility"]

    assert rule == {
        "minimum_comparable_theses": 5,
        "minimum_comparable_categories": 4,
        "conditional_positions_are_comparable": False,
    }


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


def test_changed_legacy_editorial_input_still_requires_a_new_review(tmp_path):
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
