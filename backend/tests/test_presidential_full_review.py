"""Publication gates: reject incomplete documentary review and preserve provenance."""

import csv
import hashlib
import io
import json
import runpy
import shutil
import subprocess
import sys
from pathlib import Path
from zipfile import ZipFile

import pytest

ROOT = Path(__file__).resolve().parents[2]
CORE = ("001", "002", "003", "011", "017", "018", "026B", "034A", "036")
EXTENSION = (
    "004",
    "005",
    "006",
    "007",
    "008",
    "009",
    "010",
    "012",
    "013",
    "014",
    "015",
    "016",
    "019",
    "020",
    "021",
    "022",
    "023",
    "024",
    "025",
    "026A",
    "027",
    "028",
    "029",
    "030",
    "031",
    "032",
    "033",
    "034B",
    "035",
)


@pytest.fixture
def cli_case(review_case, tmp_path):
    _, kwargs, _, content = review_case
    experiment = tmp_path / "experiment"
    dispute = experiment / "disputas" / "BR_PRESIDENTE_2026"
    dispute.mkdir(parents=True)
    (experiment / "fontes").mkdir()
    for source, destination in (
        (kwargs["positions_path"], dispute / "posicoes.jsonl"),
        (kwargs["source_theses_path"], dispute / "teses_selecionadas.json"),
        (kwargs["documents_path"], experiment / "fontes" / "documentos.jsonl"),
    ):
        shutil.copyfile(source, destination)
    full_dir = tmp_path / "full-review"
    full_dir.mkdir()
    for group in "abcd":
        _write(
            full_dir / f"group-{group}.json",
            content
            if group == "a"
            else {"reviewer": "automated_full_document_review", "candidates": {}},
        )
    extension_dir = tmp_path / "full-review-v2"
    extension_dir.mkdir()
    extension_content = json.loads(kwargs["extension_review_paths"][0].read_text())
    for group in "abcd":
        _write(
            extension_dir / f"group-{group}.json",
            extension_content
            if group == "a"
            else {
                "reviewer": "automated_complete_matrix_review",
                "reviewed_at": "2026-09-26",
                "method": "Fixture sem candidaturas neste grupo.",
                "candidates": {},
            },
        )
    expansion_dir = tmp_path / "expansion-review-v3"
    expansion_dir.mkdir()
    expansion_content = json.loads(kwargs["expansion_review_paths"][0].read_text())
    for group in "abc":
        _write(
            expansion_dir / f"group-{group}.json",
            expansion_content
            if group == "a"
            else {
                "reviewer": "automated_expansion_review",
                "reviewed_at": "2026-09-26",
                "method": "Fixture sem propostas neste grupo.",
                "proposals": {},
            },
        )
    rows = [
        {
            "SQ_CANDIDATO": candidate_id,
            "ANO_ELEICAO": "2026",
            "NR_TURNO": "1",
            "DS_CARGO": "PRESIDENTE",
            "NR_CANDIDATO": str(index + 10),
            "NM_COLIGACAO": "PARTIDO ISOLADO",
            "SG_PARTIDO": f"P{index}",
            "NM_URNA_CANDIDATO": f"Candidate {candidate_id}",
            "NM_CANDIDATO": f"Candidate {candidate_id}",
            "NM_PARTIDO": "Party",
            "NR_PARTIDO": str(index + 10),
            "DS_COMPOSICAO_COLIGACAO": "",
            "DT_GERACAO": "20/09/2026",
            "HH_GERACAO": "00:00:00",
            "ST_CANDIDATO_INSERIDO_URNA": "SIM",
            "ST_SUBSTITUIDO": "N",
            "DS_SITUACAO_JULGAMENTO": "DEFERIDO",
        }
        for index, candidate_id in enumerate(kwargs["candidate_ids"])
    ]
    csv_content = io.StringIO()
    writer = csv.DictWriter(csv_content, fieldnames=list(rows[0]), delimiter=";")
    writer.writeheader()
    writer.writerows(rows)
    roster = tmp_path / "roster.zip"
    with ZipFile(roster, "w") as zipped:
        zipped.writestr("roster_BR.csv", csv_content.getvalue().encode("latin-1"))
    photos = tmp_path / "photos.zip"
    output = tmp_path / "output"
    command = [
        sys.executable,
        str(ROOT / "scripts/build_presidential_2026_data.py"),
        "--candidates-zip",
        str(roster),
        "--complement-zip",
        str(roster),
        "--plans-zip",
        str(kwargs["plans_zip"]),
        "--photos-zip",
        str(photos),
        "--experiment-dir",
        str(experiment),
        "--data-dir",
        str(output),
        "--review-file",
        str(kwargs["review_path"]),
        "--full-review-dir",
        str(full_dir),
        "--extension-review-dir",
        str(extension_dir),
        "--selection-file",
        str(kwargs["selection_path"]),
        "--expansion-review-dir",
        str(expansion_dir),
        "--source-bank-manifest",
        str(kwargs["source_bank_path"]),
    ]
    return command, photos, output, kwargs["candidate_ids"]


@pytest.mark.parametrize("fault", ["missing", "invalid"])
def test_cli_rejects_bad_photos_without_touching_any_output(cli_case, fault):
    command, photos, output, ids = cli_case
    with ZipFile(photos, "w") as zipped:
        for candidate_id in ids:
            if candidate_id == ids[-1] and fault == "missing":
                continue
            zipped.writestr(
                f"FBR{candidate_id}_div.jpg",
                b"invalid"
                if (candidate_id == ids[-1] and fault == "invalid")
                else b"\xff\xd8\xffnew",
            )
    expected = {
        "propostas/2026/candidates.json": b"previous candidates",
        "theses/2026/theses.json": b"previous theses",
        "theses/2026/review-audit.json": b"previous audit",
        "fotos/2026/BR/previous.jpg": b"previous photo",
    }
    for relative, content in expected.items():
        path = output / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode != 0
    assert (
        "Foto oficial ausente" if fault == "missing" else "Arquivo não é JPEG"
    ) in result.stderr
    assert {
        str(path.relative_to(output)): path.read_bytes()
        for path in output.rglob("*")
        if path.is_file()
    } == expected


def test_cli_writes_all_outputs_after_validating_all_photos(cli_case):
    command, photos, output, ids = cli_case
    with ZipFile(photos, "w") as zipped:
        for candidate_id in ids:
            zipped.writestr(f"FBR{candidate_id}_div.jpg", b"\xff\xd8\xffnew")
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert (
        len(json.loads((output / "propostas/2026/candidates.json").read_text())) == 13
    )
    assert (
        json.loads((output / "theses/2026/review-audit.json").read_text())[
            "active_cells"
        ]
        == 143
    )
    assert {path.name for path in (output / "fotos/2026/BR").glob("*.jpg")} == {
        f"{candidate_id}.jpg" for candidate_id in ids
    }


def _pdf():
    """Two physical pages, with searchable text on page 2."""
    page_two_stream = b"BT /F1 10 Tf 5 50 Td (Proposta documental) Tj ET"
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] "
        b"/Resources << /Font << /F1 5 0 R >> >> >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] "
        b"/Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        b"<< /Length "
        + str(len(page_two_stream)).encode()
        + b" >>\nstream\n"
        + page_two_stream
        + b"\nendstream",
    ]
    result = b"%PDF-1.4\n"
    offsets = [0]
    for index, obj in enumerate(objects, 1):
        offsets.append(len(result))
        result += f"{index} 0 obj\n".encode() + obj + b"\nendobj\n"
    xref = len(result)
    result += f"xref\n0 {len(objects) + 1}\n".encode()
    result += b"0000000000 65535 f \n"
    result += b"".join(f"{offset:010d} 00000 n \n".encode() for offset in offsets[1:])
    return (
        result
        + f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
        f"startxref\n{xref}\n%%EOF\n".encode()
    )


def _write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")


@pytest.fixture
def review_case(tmp_path):
    builder = runpy.run_path(str(ROOT / "scripts/build_presidential_2026_data.py"))
    ids = [str(100 + number) for number in range(13)]
    pdf = _pdf()
    digest = hashlib.sha256(pdf).hexdigest()
    plans = tmp_path / "plans.zip"
    with ZipFile(plans, "w") as zipped:
        for candidate_id in ids:
            zipped.writestr(f"BR/2026BR{candidate_id}_01.pdf", pdf)
    docs = tmp_path / "documents.jsonl"
    docs.write_text(
        "\n".join(
            json.dumps(
                {
                    "documento_id": f"PG_2026_BR_{candidate_id}_01",
                    "candidato_id": candidate_id,
                    "disputa_id": "BR_PRESIDENTE_2026",
                    "arquivo_zip_membro": f"BR/2026BR{candidate_id}_01.pdf",
                    "paginas": 2,
                    "sha256": digest,
                    "url_documento": "https://example.test/official.zip",
                    "coletado_em": "2026-09-20",
                }
            )
            for candidate_id in ids[:-1]
        ),
        encoding="utf-8",
    )
    positions = tmp_path / "positions.jsonl"
    positions.write_text(
        "\n".join(
            json.dumps(
                {
                    "tese_id": f"BR26-T{number:03d}",
                    "candidato_id": candidate_id,
                    "versao_tese": 1,
                    "texto_tese": "Formulação V1 preservada",
                    "posicao": "DISCORDA",
                    "justificativa_curta": "Justificativa V1 preservada",
                    "evidencias": [],
                }
            )
            for number in range(1, 37)
            for candidate_id in ids[:-1]
        ),
        encoding="utf-8",
    )
    source = tmp_path / "source.json"
    _write(
        source,
        {"teses": [{"tese_id": f"BR26-T{number:03d}"} for number in range(1, 37)]},
    )
    review = tmp_path / "review.json"

    def decision(category):
        return {
            "category": category,
            "reason": "Decisão documental independente",
            "conditions": [],
            "scope_difference": None,
            "evidence": [
                {"page": 2, "quote": "Proposta documental", "verification": "fixture"}
            ]
            if category != "NAO_ENCONTRADA"
            else [],
            "search_terms": ["tema", "sinônimo"],
            "absence_reason": "Leitura integral não encontrou decisão específica."
            if category == "NAO_ENCONTRADA"
            else None,
        }

    _write(
        review,
        {
            "input_sha256": {
                key: hashlib.sha256(path.read_bytes()).hexdigest()
                for key, path in {
                    "positions": positions,
                    "documents": docs,
                    "source_theses": source,
                }.items()
            },
            "review_id": "legacy-review",
            "reviewed_at": "2026-09-20",
            "scope": "Passagens",
            "method": "Método legado",
            "previous_export": {"categorical_positions": {}},
            "theses": {
                suffix: {
                    "text": builder["THESIS_TEXTS"][suffix],
                    "version": 2,
                    "decisions": {
                        ids[0]: decision("CONCORDA"),
                        ids[1]: decision("DISCORDA"),
                    },
                }
                for suffix in CORE
            },
        },
    )
    full = tmp_path / "group-test.json"
    content = {
        "reviewer": "automated_full_document_review",
        "candidates": {
            candidate_id: {
                "name": f"Candidate {candidate_id}",
                "document_id": f"PG_2026_BR_{candidate_id}_01",
                "sha256": digest,
                "pages_total": 2,
                "pages_reviewed": [1, 2],
                "reading_notes": ["Leitura integral automatizada"],
                "decisions": {
                    suffix: decision(
                        "CONCORDA"
                        if candidate_id in {ids[0], ids[-1]}
                        else "DISCORDA"
                        if candidate_id == ids[1]
                        else "NAO_ENCONTRADA"
                    )
                    for suffix in CORE
                },
            }
            for candidate_id in ids
        },
    }
    _write(full, content)
    extension = tmp_path / "group-test-v2.json"
    extension_content = {
        "reviewer": "automated_complete_matrix_review",
        "reviewed_at": "2026-09-26",
        "method": "Reavaliação da formulação exata das teses fora do núcleo.",
        "candidates": {
            candidate_id: {
                "name": f"Candidate {candidate_id}",
                "decisions": {
                    suffix: decision(
                        (
                            "CONCORDA"
                            if candidate_id == ids[-1]
                            else "DISCORDA"
                            if candidate_id == ids[1]
                            else "NAO_ENCONTRADA"
                        )
                        if suffix == "004"
                        else "CONCORDA"
                        if candidate_id == ids[0]
                        else "NAO_ENCONTRADA"
                    )
                    for suffix in EXTENSION
                },
            }
            for candidate_id in ids
        },
    }
    _write(extension, extension_content)
    selection = tmp_path / "question-selection.json"
    _write(
        selection,
        {
            "review_id": "presidential-complete-document-2026-09-26-r1",
            "reviewed_at": "2026-09-26",
            "method": "Seleção por contraste categórico e cobertura documental.",
            "theses": {
                suffix: {
                    "classification": (
                        "nucleus"
                        if suffix in CORE
                        else "complementary"
                        if suffix == "004"
                        else "rejected"
                    ),
                    "reason": "Decisão editorial auditável da fixture.",
                }
                for suffix in builder["THESIS_TEXTS"]
            },
        },
    )
    expansion = tmp_path / "group-expansion-test.json"
    _write(
        expansion,
        {
            "reviewer": "automated_expansion_review",
            "reviewed_at": "2026-09-26",
            "method": "Auditoria de nova formulação contra os treze planos.",
            "proposals": {
                "fixture-037": {
                    "id": "BR26-T037",
                    "bank_ids": ["BR26-BANCO-TEST-001"],
                    "text": "Uma nova decisão pública deve ser adotada.",
                    "topic": "economia",
                    "version": 1,
                    "recommendation": "complementary",
                    "reason": "Há dois polos documentados, com baixa cobertura.",
                    "problems": [],
                    "decisions": {
                        candidate_id: decision(
                            "CONCORDA"
                            if candidate_id == ids[-1]
                            else "DISCORDA"
                            if candidate_id == ids[1]
                            else "NAO_ENCONTRADA"
                        )
                        for candidate_id in ids
                    },
                }
            },
        },
    )
    source_bank = tmp_path / "source-bank-manifest.json"
    source_bank_text = "Formulação de origem da fixture"
    source_bank_file = tmp_path / "fixture-bank.jsonl"
    source_bank_file.write_text(
        json.dumps(
            {
                "banco_id": "BR26-BANCO-TEST-001",
                "disputa_id": "BR_PRESIDENTE_2026",
                "texto_tese": source_bank_text,
            },
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )
    _write(
        source_bank,
        {
            "schema_version": 1,
            "dispute_id": "BR_PRESIDENTE_2026",
            "source_count": 1,
            "source_file": "fixture-bank.jsonl",
            "source_sha256": hashlib.sha256(
                source_bank_file.read_bytes()
            ).hexdigest(),
            "text_sha256_by_bank_id": {
                "BR26-BANCO-TEST-001": hashlib.sha256(
                    source_bank_text.encode()
                ).hexdigest()
            },
        },
    )
    kwargs = dict(
        candidate_ids=ids,
        positions_path=positions,
        source_theses_path=source,
        resource_hashes={
            key: "archive-digest"
            for key in ("candidates", "complement", "plans", "photos")
        },
        review_path=review,
        documents_path=docs,
        plans_zip=plans,
        extension_review_paths=[extension],
        selection_path=selection,
        expansion_review_paths=[expansion],
        source_bank_path=source_bank,
    )
    return builder, kwargs, full, content


def test_full_review_publishes_new_candidate_only_from_own_document(review_case):
    builder, kwargs, full, _ = review_case
    payload = builder["_build_theses"](
        **kwargs, full_review_paths=[full], require_full_review=True
    )
    active = [item for item in payload["theses"] if item["status"] == "approved"]
    assert len(active) == 11
    assert sum(len(item["positions"]) for item in active) == 143
    for thesis in active:
        newcomer = thesis["positions"]["112"]
        assert newcomer["position"] == "concordo"
        assert newcomer["review"]["source_position"] is None
        assert newcomer["evidence"][0]["document_id"] == "PG_2026_BR_112_01"
        assert newcomer["review"]["status"] == "full_document_reviewed_automated"
        assert thesis["positions"]["100"]["review"]["source_position"] == (
            None if thesis["id"] == "BR26-T037" else "DISCORDA"
        )
        assert thesis["positions"]["100"]["position"] == (
            "sem_posicao" if thesis["id"] in {"BR26-T004", "BR26-T037"} else "concordo"
        )
        assert all(
            p["analytical_position"] != "PENDENTE" for p in thesis["positions"].values()
        )
    assert payload["metadata"]["human_reviewed"] is False
    assert payload["metadata"]["documentary_review_status"] == "complete_automated"
    assert (
        payload["metadata"]["editorial_inputs"]["full_review"][0]["sha256"]
        == hashlib.sha256(full.read_bytes()).hexdigest()
    )
    assert payload["metadata"]["editorial_inputs"]["source_bank"]["sha256"] == (
        hashlib.sha256(kwargs["source_bank_path"].read_bytes()).hexdigest()
    )
    assert payload["metadata"]["analysed_documents"]["PG_2026_BR_112_01"][
        "pages_reviewed"
    ] == [1, 2]
    candidates = [{"id": value, "name": value} for value in kwargs["candidate_ids"]]
    audit = builder["_audit_summary"](payload, candidates)
    assert audit["documentary_review_status"] == "complete_automated"
    assert audit["pages_reviewed_total"] == 26
    assert audit["categories"].get("PENDENTE", 0) == 0
    assert audit["all_reviewed_cells"] == 507
    assert audit["all_reviewed_categories"].get("PENDENTE", 0) == 0
    assert audit["selection"] == {
        "nucleus": 9,
        "complementary": 2,
        "rejected": 28,
    }
    assert sum(len(item["positions"]) for item in payload["theses"]) == 507
    assert all(
        position["analytical_position"] != "PENDENTE"
        for thesis in payload["theses"]
        for position in thesis["positions"].values()
    )
    complementary = next(
        item for item in payload["theses"] if item["id"] == "BR26-T004"
    )
    assert complementary["selection"] == "complementary"
    rejected = next(item for item in payload["theses"] if item["id"] == "BR26-T005")
    assert rejected["status"] == "draft"
    assert rejected["selection"] == "rejected"
    assert rejected["positions"]["100"]["review"]["status"] == (
        "full_document_reviewed_automated"
    )
    expansion = next(item for item in payload["theses"] if item["id"] == "BR26-T037")
    assert expansion["status"] == "approved"
    assert expansion["selection"] == "complementary"
    assert expansion["source_bank_ids"] == ["BR26-BANCO-TEST-001"]
    assert expansion["positions"]["112"]["position"] == "concordo"
    assert expansion["positions"]["112"]["review"]["document_id"] == (
        "PG_2026_BR_112_01"
    )


@pytest.mark.parametrize(
    "fault",
    [
        "missing_extension_decision",
        "missing_selection",
        "missing_expansion_decision",
        "unknown_bank_id",
        "altered_bank_source",
    ],
)
def test_complete_review_rejects_partial_matrix_or_selection(review_case, fault):
    builder, kwargs, full, _ = review_case
    if fault == "missing_extension_decision":
        extension = json.loads(kwargs["extension_review_paths"][0].read_text())
        del extension["candidates"]["100"]["decisions"]["004"]
        _write(kwargs["extension_review_paths"][0], extension)
    elif fault == "missing_selection":
        selection = json.loads(kwargs["selection_path"].read_text())
        del selection["theses"]["004"]
        _write(kwargs["selection_path"], selection)
    elif fault == "missing_expansion_decision":
        expansion = json.loads(kwargs["expansion_review_paths"][0].read_text())
        del expansion["proposals"]["fixture-037"]["decisions"]["100"]
        _write(kwargs["expansion_review_paths"][0], expansion)
    elif fault == "unknown_bank_id":
        expansion = json.loads(kwargs["expansion_review_paths"][0].read_text())
        expansion["proposals"]["fixture-037"]["bank_ids"] = [
            "BR26-BANCO-UNKNOWN"
        ]
        _write(kwargs["expansion_review_paths"][0], expansion)
    else:
        (kwargs["source_bank_path"].parent / "fixture-bank.jsonl").write_text(
            '{"changed": true}\n', encoding="utf-8"
        )

    with pytest.raises(ValueError):
        builder["_build_theses"](
            **kwargs, full_review_paths=[full], require_full_review=True
        )


@pytest.mark.parametrize(
    ("suffix", "classification"),
    [("004", "nucleus"), ("005", "complementary")],
)
def test_complete_review_enforces_selection_criteria(
    review_case, suffix, classification
):
    builder, kwargs, full, _ = review_case
    selection = json.loads(kwargs["selection_path"].read_text())
    selection["theses"][suffix]["classification"] = classification
    _write(kwargs["selection_path"], selection)

    with pytest.raises(ValueError, match="(?i)seleção editorial"):
        builder["_build_theses"](
            **kwargs, full_review_paths=[full], require_full_review=True
        )


def test_complete_review_rejects_stale_selection_metrics(review_case):
    builder, kwargs, full, _ = review_case
    selection = json.loads(kwargs["selection_path"].read_text())
    selection["theses"]["004"]["metrics"] = {
        "agree": 99,
        "disagree": 0,
        "conditional": 0,
        "not_found": 0,
    }
    _write(kwargs["selection_path"], selection)

    with pytest.raises(ValueError, match="(?i)métricas da seleção"):
        builder["_build_theses"](
            **kwargs, full_review_paths=[full], require_full_review=True
        )


def test_reformulated_un_question_keeps_old_version_hash(review_case):
    builder, kwargs, full, _ = review_case
    payload = builder["_build_theses"](**kwargs, full_review_paths=[full])
    thesis = next(item for item in payload["theses"] if item["id"] == "BR26-T034A")
    assert thesis["text"] == "O Conselho de Segurança da ONU deve continuar existindo."
    assert thesis["version"] == 3
    assert thesis["supersedes"]["version"] == 2
    assert (
        thesis["supersedes"]["text"]
        == "O Conselho de Segurança da ONU deve ser mantido."
    )
    assert (
        thesis["supersedes"]["text_sha256"]
        == hashlib.sha256(
            "O Conselho de Segurança da ONU deve ser mantido.".encode()
        ).hexdigest()
    )


@pytest.mark.parametrize(
    "fault",
    [
        "missing_candidate",
        "extra_candidate",
        "duplicate_candidate",
        "short_roster",
        "missing_thesis",
        "pending",
        "hash",
        "page_gap",
        "wrong_pdf_count",
        "document_owner",
        "missing_absence_reason",
        "evidence_page",
        "evidence_quote",
    ],
)
def test_full_review_rejects_incomplete_or_unbound_review(review_case, fault):
    builder, kwargs, full, content = review_case
    candidate = content["candidates"]["100"]
    paths = [full]
    if fault == "missing_candidate":
        del content["candidates"]["112"]
    elif fault == "extra_candidate":
        content["candidates"]["999"] = candidate
    elif fault == "duplicate_candidate":
        paths.append(full)
    elif fault == "short_roster":
        kwargs["candidate_ids"] = kwargs["candidate_ids"][:-1]
        del content["candidates"]["112"]
    elif fault == "missing_thesis":
        del candidate["decisions"]["036"]
    elif fault == "pending":
        candidate["decisions"]["036"]["category"] = "PENDENTE"
    elif fault == "hash":
        candidate["sha256"] = "0" * 64
    elif fault == "page_gap":
        candidate["pages_reviewed"] = [1, 1]
    elif fault == "wrong_pdf_count":
        candidate["pages_total"] = 1
        candidate["pages_reviewed"] = [1]
    elif fault == "document_owner":
        candidate["document_id"] = "PG_2026_BR_101_01"
    elif fault == "missing_absence_reason":
        content["candidates"]["102"]["decisions"]["001"]["absence_reason"] = None
    elif fault == "evidence_page":
        candidate["decisions"]["001"]["evidence"][0]["page"] = 3
    elif fault == "evidence_quote":
        candidate["decisions"]["001"]["evidence"][0]["quote"] = (
            "Trecho inventado que não existe no PDF"
        )
    _write(full, content)
    with pytest.raises(ValueError):
        builder["_build_theses"](
            **kwargs, full_review_paths=paths, require_full_review=True
        )


def test_publication_requires_full_review_but_legacy_builder_remains_available(
    review_case,
):
    builder, kwargs, _, _ = review_case
    legacy_kwargs = {
        key: value
        for key, value in kwargs.items()
        if key
        not in {
            "extension_review_paths",
            "selection_path",
            "expansion_review_paths",
            "source_bank_path",
        }
    }
    legacy = builder["_build_theses"](**legacy_kwargs)
    assert legacy["theses"][0]["positions"]["112"]["analytical_position"] == "PENDENTE"
    with pytest.raises(ValueError, match="(?i)revisão integral"):
        builder["_build_theses"](**legacy_kwargs, require_full_review=True)


def test_full_review_cannot_reuse_v1_evidence_when_new_evidence_is_missing(review_case):
    builder, kwargs, full, content = review_case
    positions = kwargs["positions_path"]
    rows = [json.loads(line) for line in positions.read_text().splitlines()]
    rows[0]["evidencias"] = [
        {
            "documento_id": "PG_2026_BR_100_01",
            "pagina_fisica": 1,
            "trecho_literal": "Trecho antigo não revisto",
        }
    ]
    positions.write_text("\n".join(json.dumps(row) for row in rows))
    legacy = json.loads(kwargs["review_path"].read_text())
    legacy["input_sha256"]["positions"] = hashlib.sha256(
        positions.read_bytes()
    ).hexdigest()
    _write(kwargs["review_path"], legacy)
    del content["candidates"]["100"]["decisions"]["001"]["evidence"]
    _write(full, content)
    with pytest.raises(ValueError, match="(?i)evidência"):
        builder["_build_theses"](**kwargs, full_review_paths=[full])


def test_full_review_rejects_evidence_attributed_to_another_document(review_case):
    builder, kwargs, full, content = review_case
    content["candidates"]["100"]["decisions"]["001"]["evidence"][0]["document_id"] = (
        "PG_2026_BR_101_01"
    )
    _write(full, content)
    with pytest.raises(ValueError, match="(?i)evidência"):
        builder["_build_theses"](**kwargs, full_review_paths=[full])
