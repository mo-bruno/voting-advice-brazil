"""Build the published 2026 presidential snapshot from official TSE files.

The script deliberately keeps editorial choices explicit.  It refreshes the
candidate roster and portraits from the latest official snapshot, then exports
only evidence-backed, contrasting theses as active quiz questions. Every
supplied thesis remains in the payload with a complete documentary
classification, including formulations rejected from the questionnaire.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
import subprocess
import unicodedata
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from zipfile import ZipFile

REVIEW_FILE = "editorial-review-2026-09-20.json"
FULL_REVIEW_CORE = {"001", "002", "003", "011", "017", "018", "026B", "034A", "036"}
FULL_REVIEW_CATEGORIES = {
    "CONCORDA",
    "DISCORDA",
    "NEUTRO_EXPLICITO",
    "CONDICIONAL_OU_MISTA",
    "NAO_ENCONTRADA",
}
CONTINUITY_THESIS_TEXT = "O Conselho de Segurança da ONU deve continuar existindo."

ELECTION_YEAR = 2026
OFFICE = "presidente"
OFFICIAL_DATA_URL = (
    "https://cdn.tse.jus.br/estatistica/sead/odsele/consulta_cand/"
    "consulta_cand_2026.zip"
)
OFFICIAL_COMPLEMENT_URL = (
    "https://cdn.tse.jus.br/estatistica/sead/odsele/consulta_cand_complementar/"
    "consulta_cand_complementar_2026.zip"
)
OFFICIAL_PLANS_URL = (
    "https://cdn.tse.jus.br/estatistica/sead/odsele/proposta_governo/"
    "proposta_governo_2026_BR.zip"
)
OFFICIAL_PHOTOS_URL = (
    "https://cdn.tse.jus.br/estatistica/sead/eleicoes/eleicoes2026/fotos/"
    "foto_cand2026_BR_div.zip"
)


THESIS_TEXTS = {
    "001": "O governo federal deve manter o arcabouço fiscal previsto na Lei Complementar nº 200/2023.",
    "002": "Todas as empresas estatais devem ser transferidas ao controle privado.",
    "003": "As mudanças introduzidas pela reforma trabalhista de 2017 devem ser revogadas.",
    "004": "A escala de seis dias de trabalho para um dia de descanso deve ser extinta, sem redução salarial.",
    "005": "O limite legal geral da jornada de trabalho deve ser de 30 horas semanais, sem redução salarial.",
    "006": "O vínculo de emprego entre trabalhadores de plataformas digitais e as empresas responsáveis por essas plataformas deve ser reconhecido.",
    "007": "O valor do salário mínimo nacional deve ser dobrado.",
    "008": "A União deve instituir um imposto sobre grandes fortunas.",
    "009": "O pagamento da dívida pública a grandes investidores deve ser suspenso.",
    "010": "As apostas realizadas pela internet devem ser proibidas.",
    "011": "O Bolsa Família deve ser substituído, para seus beneficiários em idade economicamente ativa, por um programa público de trabalho remunerado.",
    "012": "O transporte público coletivo deve operar sem cobrança de tarifa aos passageiros.",
    "013": "Imóveis urbanos ociosos ou mantidos para especulação devem ser expropriados para moradia popular.",
    "014": "O aborto deve ser permitido por lei.",
    "015": "A idade mínima para responder criminalmente como adulto deve ser de 16 anos em crimes graves.",
    "016": "As polícias militares devem passar a ter organização e regime civis.",
    "017": "O número de escolas cívico-militares deve aumentar.",
    "018": "A reserva de vagas com base em critérios raciais na educação e no serviço público deve ser encerrada.",
    "019": "O consumo de maconha deve ser permitido por lei.",
    "020": "A legislação brasileira deve classificar as facções criminosas como organizações terroristas.",
    "021": "O uso de câmeras corporais nas atividades policiais deve ser ampliado.",
    "022": "Os órgãos de segurança pública devem utilizar sistemas de reconhecimento facial.",
    "023": "A oferta de vagas na educação básica em tempo integral deve ser ampliada.",
    "024": "O método fônico deve ter prioridade sobre outros métodos de alfabetização.",
    "025": "O SUS deve adotar uma fila nacional digital de atendimento, com prioridade baseada no risco clínico.",
    "026A": "A gestão de serviços públicos de saúde por organizações sociais deve ser encerrada.",
    "026B": "A gestão de serviços públicos de saúde por empresas em parcerias público-privadas deve ser encerrada.",
    "027": "A exploração de petróleo na Margem Equatorial brasileira deve ser autorizada.",
    "028": "O governo federal deve ampliar a reforma agrária por meio de novos assentamentos e da desapropriação de terras.",
    "029": "Todas as terras indígenas cuja demarcação esteja pendente devem ser demarcadas.",
    "030": "A exploração de terras raras deve estar sob controle estatal.",
    "031": "A produção de fertilizantes no Brasil deve ser ampliada.",
    "032": "O governo federal deve ampliar a regulação de redes sociais e plataformas digitais.",
    "033": "A reeleição para mandatos consecutivos no mesmo cargo do Poder Executivo deve ser proibida.",
    "034A": "O Conselho de Segurança da ONU deve ser mantido.",
    "034B": "O Conselho de Segurança da ONU deve ser reformado.",
    "035": "As eleições legislativas devem combinar representantes eleitos por distritos com representantes eleitos proporcionalmente por listas partidárias.",
    "036": "A autonomia institucional do Banco Central estabelecida pela Lei Complementar nº 179/2021 deve ser revogada.",
}

TOPICS = {
    "001": "economia",
    "002": "economia",
    "003": "trabalho",
    "004": "trabalho",
    "005": "trabalho",
    "006": "trabalho",
    "007": "trabalho",
    "008": "economia",
    "009": "economia",
    "010": "governanca",
    "011": "politica_social",
    "012": "infraestrutura",
    "013": "direitos_sociais",
    "014": "direitos_sociais",
    "015": "seguranca",
    "016": "seguranca",
    "017": "educacao",
    "018": "direitos_sociais",
    "019": "seguranca",
    "020": "seguranca",
    "021": "seguranca",
    "022": "seguranca",
    "023": "educacao",
    "024": "educacao",
    "025": "saude",
    "026A": "saude",
    "026B": "saude",
    "027": "meio_ambiente",
    "028": "agricultura",
    "029": "direitos_sociais",
    "030": "economia",
    "031": "agricultura",
    "032": "governanca",
    "033": "governanca",
    "034A": "politica_externa",
    "034B": "politica_externa",
    "035": "governanca",
    "036": "economia",
}

SOURCE_THESIS = {key: f"BR26-T{key[:3]}" for key in THESIS_TEXTS}

DRAFT_REASONS = {
    "004": "Não há discordância explícita no mesmo escopo entre os planos revisados.",
    "005": "Metas alternativas de jornada não foram classificadas de forma suficientemente uniforme.",
    "006": "O grupo de trabalhadores e as condições para reconhecimento do vínculo ainda precisam ser delimitados.",
    "007": "A referência, o prazo e a natureza do aumento de 100% ainda precisam ser delimitados.",
    "008": "Há apoio explícito, mas não foi encontrada oposição explícita no mesmo escopo.",
    "009": "Quem seria atingido, quais pagamentos seriam suspensos e a duração da medida ainda precisam ser delimitados.",
    "010": "As modalidades de aposta alcançadas pela proibição ainda precisam ser delimitadas.",
    "012": "Os serviços de transporte abrangidos ainda precisam ser delimitados e não há oposição explícita.",
    "013": "Os critérios de ociosidade, especulação e indenização ainda precisam ser definidos pela fonte.",
    "014": "As situações, condições e eventual limite gestacional ainda precisam ser delimitados.",
    "015": "A categoria de crimes e o tratamento de propostas com idades diferentes ainda precisam ser harmonizados.",
    "016": "Há apoio explícito, mas não foi encontrada oposição explícita no mesmo escopo.",
    "019": "Finalidade, público, cultivo e comercialização ainda precisam ser delimitados.",
    "020": "Há apoio explícito, mas não foi encontrada oposição explícita no mesmo escopo.",
    "021": "Há apoio explícito, mas não foi encontrada oposição explícita no mesmo escopo.",
    "022": "Os usos de reconhecimento facial ainda precisam ser delimitados.",
    "023": "Há apoio explícito, mas não foi encontrada oposição explícita no mesmo escopo.",
    "024": "Há apoio explícito, mas não foi encontrada oposição explícita no mesmo escopo.",
    "025": "Os atendimentos abrangidos e o caráter nacional ou integrado da fila ainda precisam ser delimitados.",
    "026A": "Há apoio explícito ao fim das organizações sociais, mas não foi encontrada oposição explícita no mesmo escopo.",
    "027": "A substituição da candidatura que sustentava a concordância eliminou o contraste desta edição; área e etapa também exigem delimitação.",
    "028": "Há apoio ou propostas condicionais, mas não foi encontrada oposição explícita no mesmo escopo.",
    "029": "O conjunto de demarcações pendentes ainda precisa ser delimitado e não há oposição explícita.",
    "030": "A modalidade de controle estatal ainda precisa ser delimitada e não há oposição explícita.",
    "031": "Há apoio explícito, mas não foi encontrada oposição explícita no mesmo escopo.",
    "032": "O objeto da regulação de plataformas ainda precisa ser delimitado.",
    "033": "Há apoio ou propostas condicionais, mas não foi encontrada oposição explícita no mesmo escopo.",
    "034B": "A mudança institucional pretendida ainda precisa ser especificada pela fonte.",
    "035": "Os cargos e o desenho do sistema misto ainda precisam ser delimitados; não há oposição explícita.",
}

FULL_REVIEW_EXTENSION = set(THESIS_TEXTS) - FULL_REVIEW_CORE
SELECTION_CLASSES = {"nucleus", "complementary", "rejected"}
EXPANSION_REVIEWER = "automated_expansion_review"
VALID_TOPICS = set(TOPICS.values())


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _read_br_csv(archive: Path) -> list[dict[str, str]]:
    with ZipFile(archive) as zipped:
        members = [name for name in zipped.namelist() if name.endswith("_BR.csv")]
        if len(members) != 1:
            raise ValueError(
                f"Esperado um CSV de BR em {archive}, encontrados: {members}"
            )
        content = zipped.read(members[0]).decode("latin-1")
    return list(csv.DictReader(io.StringIO(content), delimiter=";"))


def _is_active(row: dict[str, str]) -> bool:
    return row["ST_CANDIDATO_INSERIDO_URNA"] == "SIM" and row["ST_SUBSTITUIDO"] == "N"


def _display_name(value: str) -> str:
    particles = {"da", "das", "de", "do", "dos", "e"}
    words = value.lower().split()
    return " ".join(
        word if index and word in particles else word.capitalize()
        for index, word in enumerate(words)
    )


def _party_asset_name(acronym: str) -> str:
    normalized = unicodedata.normalize("NFKD", acronym)
    ascii_name = "".join(char for char in normalized if not unicodedata.combining(char))
    return re.sub(r"[^A-Z0-9]+", "_", ascii_name.upper()).strip("_")


def _build_candidates(
    candidates_zip: Path,
    complement_zip: Path,
) -> list[dict[str, Any]]:
    rows = _read_br_csv(candidates_zip)
    complement = {row["SQ_CANDIDATO"]: row for row in _read_br_csv(complement_zip)}

    def active_for_office(office: str) -> list[dict[str, str]]:
        selected = []
        for row in rows:
            status = complement.get(row["SQ_CANDIDATO"])
            if (
                row["ANO_ELEICAO"] == str(ELECTION_YEAR)
                and row["NR_TURNO"] == "1"
                and row["DS_CARGO"] == office
                and status is not None
                and _is_active(status)
            ):
                selected.append(row)
        return selected

    presidents = active_for_office("PRESIDENTE")
    running_mates = active_for_office("VICE-PRESIDENTE")
    mate_by_number = {row["NR_CANDIDATO"]: row for row in running_mates}
    if len(presidents) != 13:
        raise ValueError(
            f"Snapshot oficial deveria conter 13 presidenciáveis ativos, contém {len(presidents)}"
        )

    result: list[dict[str, Any]] = []
    for row in sorted(presidents, key=lambda item: int(item["NR_CANDIDATO"])):
        candidate_id = row["SQ_CANDIDATO"]
        status = complement[candidate_id]
        mate = mate_by_number.get(row["NR_CANDIDATO"])
        coalition = row["NM_COLIGACAO"].strip()
        if coalition == "PARTIDO ISOLADO":
            coalition = ""
        party_asset = _party_asset_name(row["SG_PARTIDO"])
        result.append(
            {
                "id": candidate_id,
                "name": _display_name(row["NM_URNA_CANDIDATO"]),
                "legal_name": row["NM_CANDIDATO"].strip(),
                "party": row["SG_PARTIDO"].strip(),
                "party_name": " ".join(row["NM_PARTIDO"].split()),
                "party_number": int(row["NR_PARTIDO"]),
                "party_logo_url": f"/data/logos/partidos/{party_asset}.png",
                "coalition": _display_name(coalition) if coalition else None,
                "coalition_composition": row["DS_COMPOSICAO_COLIGACAO"].strip(),
                "number": int(row["NR_CANDIDATO"]),
                "running_mate": _display_name(mate["NM_URNA_CANDIDATO"])
                if mate
                else None,
                "office": OFFICE,
                "state": "BR",
                "election_year": ELECTION_YEAR,
                "election_round": 1,
                "photo_url": f"/data/fotos/2026/BR/{candidate_id}.jpg",
                "pdf_file": f"2026BR{candidate_id}_01.pdf",
                "official_status": status["DS_SITUACAO_JULGAMENTO"],
                "inserted_on_ballot": status["ST_CANDIDATO_INSERIDO_URNA"],
                "replaced": status["ST_SUBSTITUIDO"],
                "source_url": OFFICIAL_DATA_URL,
                "source_snapshot": f"{row['DT_GERACAO']} {row['HH_GERACAO']}",
            }
        )
    return result


def _load_positions(path: Path) -> dict[tuple[str, str], dict[str, Any]]:
    result = {}
    with path.open(encoding="utf-8") as source:
        for line in source:
            row = json.loads(line)
            key = (row["tese_id"], row["candidato_id"])
            if key in result:
                raise ValueError(f"Célula editorial duplicada: {key}")
            result[key] = row
    return result


def _verify_plan_snapshot(
    plans_zip: Path, documents_path: Path
) -> dict[str, dict[str, Any]]:
    """Bind every previously analysed presidential PDF to its original bytes."""
    verified = {}
    with ZipFile(plans_zip) as zipped:
        for line in documents_path.read_text(encoding="utf-8").splitlines():
            document = json.loads(line)
            if document["disputa_id"] != "BR_PRESIDENTE_2026":
                continue
            member = document.get("arquivo_zip_membro") or (
                "BR/" + Path(document["arquivo_relativo"]).name
            )
            try:
                digest = hashlib.sha256(zipped.read(member)).hexdigest()
            except KeyError as error:
                raise ValueError(f"PDF analisado ausente: {member}") from error
            if digest != document["sha256"]:
                raise ValueError(
                    f"SHA-256 divergente para o documento analisado: {member}"
                )
            verified[document["documento_id"]] = dict(
                document, arquivo_zip_membro=member
            )
    return verified


def _reviewed_evidence(
    row: dict[str, Any], decision: dict[str, Any], documents: dict[str, dict[str, Any]]
) -> list[dict[str, Any]]:
    source_evidence = row.get("evidencias") or []
    items = decision.get("evidence")
    if items is not None:
        document_id = f"PG_2026_BR_{row['candidato_id']}_01"
        items = [dict(item, document_id=document_id) for item in items]
    else:
        items = [
            {
                "document_id": item["documento_id"],
                "page": item["pagina_fisica"],
                "quote": item["trecho_literal"],
            }
            for item in source_evidence
        ]
    evidence = []
    for item in items:
        document = documents.get(item["document_id"])
        if document is None or document["candidato_id"] != row["candidato_id"]:
            raise ValueError(f"Evidência sem PDF analisado e verificado: {item}")
        if not 1 <= item["page"] <= document["paginas"] or not item["quote"].strip():
            raise ValueError(f"Página ou trecho inválido: {item}")
        evidence.append(
            {
                **item,
                "verification": item.get("verification", "text_lookup_layout_or_raw"),
                "sha256": document["sha256"],
                "archive_member": document["arquivo_zip_membro"],
                "url": document.get("url_documento_individual")
                or document["url_documento"],
            }
        )
    return evidence


def _load_full_review(
    paths: list[Path], candidate_ids: list[str], plans_zip: Path
) -> tuple[dict[str, dict[str, Any]], list[dict[str, str]]]:
    """Require complete coverage and bind the review to the official PDF bytes."""
    if len(candidate_ids) != 13 or len(set(candidate_ids)) != 13:
        raise ValueError("Revisão integral exige exatamente 13 candidaturas únicas")
    candidates: dict[str, dict[str, Any]] = {}
    inputs = []
    for path in paths:
        if not path.is_file():
            raise ValueError(f"Arquivo de revisão integral ausente: {path}")
        content = json.loads(path.read_text(encoding="utf-8"))
        if content.get("reviewer") != "automated_full_document_review":
            raise ValueError(f"Tipo de revisão integral inválido: {path}")
        inputs.append({"file": path.name, "sha256": _sha256(path)})
        for candidate_id, review in content["candidates"].items():
            if candidate_id in candidates:
                raise ValueError(
                    f"Candidatura duplicada na revisão integral: {candidate_id}"
                )
            candidates[candidate_id] = review
    if set(candidates) != set(candidate_ids):
        raise ValueError(
            "Candidaturas da revisão integral diferem do retrato oficial ativo"
        )
    with ZipFile(plans_zip) as zipped:
        for candidate_id, review in candidates.items():
            if review.get("document_id") != f"PG_2026_BR_{candidate_id}_01":
                raise ValueError(f"Documento de outra candidatura: {candidate_id}")
            total = review.get("pages_total")
            if (
                type(total) is not int
                or total < 1
                or review.get("pages_reviewed") != list(range(1, total + 1))
            ):
                raise ValueError(
                    f"Leitura integral sem todas as páginas contíguas: {candidate_id}"
                )
            member = f"BR/2026BR{candidate_id}_01.pdf"
            try:
                pdf = zipped.read(member)
            except KeyError as error:
                raise ValueError(
                    f"PDF da revisão integral ausente: {member}"
                ) from error
            if hashlib.sha256(pdf).hexdigest() != review.get("sha256"):
                raise ValueError(f"SHA-256 divergente na revisão integral: {member}")
            try:
                info = subprocess.run(
                    ["pdfinfo", "-"], input=pdf, capture_output=True, check=True
                ).stdout.decode("utf-8", errors="replace")
            except (OSError, subprocess.CalledProcessError) as error:
                raise ValueError(
                    f"Não foi possível validar o PDF com pdfinfo: {member}"
                ) from error
            count = re.search(r"^Pages:\s+(\d+)\s*$", info, re.MULTILINE)
            if not count or int(count.group(1)) != total:
                raise ValueError(f"Contagem física do PDF difere da revisão: {member}")
            if set(review.get("decisions", {})) != FULL_REVIEW_CORE:
                raise ValueError(
                    f"Revisão integral exige as nove decisões: {candidate_id}"
                )
            for suffix, decision in review["decisions"].items():
                if decision.get("category") not in FULL_REVIEW_CATEGORIES:
                    raise ValueError(
                        f"Categoria pendente ou inválida: {candidate_id}/{suffix}"
                    )
                if not decision.get("reason") or not decision.get("search_terms"):
                    raise ValueError(
                        f"Decisão sem justificativa ou registro de busca: {candidate_id}/{suffix}"
                    )
                if decision["category"] == "NAO_ENCONTRADA" and not decision.get(
                    "absence_reason"
                ):
                    raise ValueError(
                        f"Ausência sem justificativa de leitura integral: {candidate_id}/{suffix}"
                    )
                evidence = decision.get("evidence")
                if not isinstance(evidence, list):
                    raise ValueError(
                        f"Revisão integral sem lista explícita de evidência: {candidate_id}/{suffix}"
                    )
                for item in evidence:
                    if (
                        item.get("document_id", review["document_id"])
                        != review["document_id"]
                    ):
                        raise ValueError(
                            f"Evidência atribuída a outro documento: {candidate_id}/{suffix}"
                        )
    return candidates, inputs


def _validate_extension_decision(
    candidate_id: str,
    suffix: str,
    decision: dict[str, Any],
    document_id: str,
) -> None:
    if decision.get("category") not in FULL_REVIEW_CATEGORIES:
        raise ValueError(f"Categoria pendente ou inválida: {candidate_id}/{suffix}")
    if not decision.get("reason") or not decision.get("search_terms"):
        raise ValueError(
            f"Decisão sem justificativa ou registro de busca: {candidate_id}/{suffix}"
        )
    if decision["category"] == "NAO_ENCONTRADA" and not decision.get("absence_reason"):
        raise ValueError(
            f"Ausência sem justificativa de leitura integral: {candidate_id}/{suffix}"
        )
    evidence = decision.get("evidence")
    if not isinstance(evidence, list):
        raise ValueError(
            f"Revisão integral sem lista explícita de evidência: {candidate_id}/{suffix}"
        )
    for item in evidence:
        if item.get("document_id", document_id) != document_id:
            raise ValueError(
                f"Evidência atribuída a outro documento: {candidate_id}/{suffix}"
            )


def _load_extension_review(
    paths: list[Path],
    candidate_ids: list[str],
    full_review: dict[str, dict[str, Any]],
) -> tuple[dict[str, dict[str, Any]], list[dict[str, str]]]:
    candidates: dict[str, dict[str, Any]] = {}
    inputs = []
    for path in paths:
        if not path.is_file():
            raise ValueError(f"Arquivo da matriz completa ausente: {path}")
        content = json.loads(path.read_text(encoding="utf-8"))
        if content.get("reviewer") != "automated_complete_matrix_review":
            raise ValueError(f"Tipo de extensão de revisão inválido: {path}")
        if not content.get("reviewed_at") or not content.get("method"):
            raise ValueError(f"Extensão de revisão sem método ou data: {path}")
        inputs.append({"file": path.name, "sha256": _sha256(path)})
        for candidate_id, review in content.get("candidates", {}).items():
            if candidate_id in candidates:
                raise ValueError(
                    f"Candidatura duplicada na extensão da revisão: {candidate_id}"
                )
            candidates[candidate_id] = review
    if set(candidates) != set(candidate_ids):
        raise ValueError(
            "Candidaturas da extensão de revisão diferem do retrato oficial ativo"
        )
    for candidate_id, review in candidates.items():
        decisions = review.get("decisions", {})
        if set(decisions) != FULL_REVIEW_EXTENSION:
            raise ValueError(f"Extensão exige as 29 decisões restantes: {candidate_id}")
        document_id = full_review[candidate_id]["document_id"]
        for suffix, decision in decisions.items():
            _validate_extension_decision(candidate_id, suffix, decision, document_id)
    return candidates, inputs


def _load_selection(path: Path) -> tuple[dict[str, Any], dict[str, str]]:
    if not path.is_file():
        raise ValueError(f"Arquivo de seleção editorial ausente: {path}")
    content = json.loads(path.read_text(encoding="utf-8"))
    if not all(content.get(key) for key in ("review_id", "reviewed_at", "method")):
        raise ValueError("Seleção editorial sem identidade, data ou método")
    theses = content.get("theses", {})
    if set(theses) != set(THESIS_TEXTS):
        raise ValueError("Seleção editorial deve decidir as 38 formulações")
    for suffix, item in theses.items():
        if item.get("classification") not in SELECTION_CLASSES or not item.get(
            "reason"
        ):
            raise ValueError(f"Seleção editorial inválida: {suffix}")
    return content, {"file": path.name, "sha256": _sha256(path)}


def _load_source_bank_manifest(
    path: Path,
) -> tuple[set[str], dict[str, str | int]]:
    if not path.is_file():
        raise ValueError(f"Manifesto do banco de teses ausente: {path}")
    content = json.loads(path.read_text(encoding="utf-8"))
    entries = content.get("text_sha256_by_bank_id")
    if (
        content.get("schema_version") != 1
        or content.get("dispute_id") != "BR_PRESIDENTE_2026"
        or not isinstance(entries, dict)
        or content.get("source_count") != len(entries)
        or not entries
        or not isinstance(content.get("source_file"), str)
        or not re.fullmatch(r"[0-9a-f]{64}", content.get("source_sha256", ""))
    ):
        raise ValueError("Manifesto do banco de teses inválido")
    for bank_id, text_hash in entries.items():
        if not re.fullmatch(r"BR26-BANCO-[A-Z]+-\d{3}", bank_id) or not re.fullmatch(
            r"[0-9a-f]{64}", text_hash if isinstance(text_hash, str) else ""
        ):
            raise ValueError(f"Entrada inválida no banco de teses: {bank_id}")
    source_path = path.parent / content["source_file"]
    if not source_path.is_file() or _sha256(source_path) != content["source_sha256"]:
        raise ValueError("Arquivo versionado do banco de teses ausente ou alterado")
    source_entries: dict[str, str] = {}
    for line_number, line in enumerate(
        source_path.read_text(encoding="utf-8").splitlines(), 1
    ):
        try:
            source = json.loads(line)
        except json.JSONDecodeError as error:
            raise ValueError(
                f"JSON inválido no banco de teses, linha {line_number}"
            ) from error
        bank_id = source.get("banco_id")
        text = source.get("texto_tese")
        if (
            not isinstance(bank_id, str)
            or not isinstance(text, str)
            or source.get("disputa_id") != "BR_PRESIDENTE_2026"
            or bank_id in source_entries
        ):
            raise ValueError(f"Registro inválido no banco de teses: linha {line_number}")
        source_entries[bank_id] = hashlib.sha256(text.encode("utf-8")).hexdigest()
    if source_entries != entries:
        raise ValueError("Conteúdo do banco de teses diverge do manifesto")
    return set(entries), {
        "file": path.name,
        "sha256": _sha256(path),
        "source_count": content["source_count"],
        "source_sha256": content["source_sha256"],
    }


def _load_expansion_review(
    paths: list[Path],
    candidate_ids: list[str],
    full_review: dict[str, dict[str, Any]],
    source_bank_ids: set[str],
) -> tuple[dict[str, dict[str, Any]], list[dict[str, str]], dict[str, str]]:
    proposals: dict[str, dict[str, Any]] = {}
    published_ids: set[str] = set()
    inputs = []
    reviewed_at: set[str] = set()
    methods = []
    base_ids = {f"BR26-T{suffix}" for suffix in THESIS_TEXTS}
    for path in paths:
        if not path.is_file():
            raise ValueError(f"Arquivo da expansão editorial ausente: {path}")
        content = json.loads(path.read_text(encoding="utf-8"))
        if content.get("reviewer") != EXPANSION_REVIEWER:
            raise ValueError(f"Tipo de revisão de expansão inválido: {path}")
        if not content.get("reviewed_at") or not content.get("method"):
            raise ValueError(f"Revisão de expansão sem método ou data: {path}")
        reviewed_at.add(content["reviewed_at"])
        methods.append(content["method"])
        inputs.append({"file": path.name, "sha256": _sha256(path)})
        for proposal_key, proposal in content.get("proposals", {}).items():
            if proposal_key in proposals:
                raise ValueError(
                    f"Proposta duplicada na expansão editorial: {proposal_key}"
                )
            published_id = proposal.get("id")
            if (
                not isinstance(published_id, str)
                or not re.fullmatch(r"BR26-T\d{3}", published_id)
                or published_id in base_ids
                or published_id in published_ids
            ):
                raise ValueError(
                    f"Identidade inválida ou duplicada na expansão: {proposal_key}"
                )
            if (
                not proposal.get("text")
                or proposal.get("topic") not in VALID_TOPICS
                or type(proposal.get("version")) is not int
                or proposal["version"] < 1
                or not isinstance(proposal.get("bank_ids"), list)
                or not proposal["bank_ids"]
                or not all(
                    isinstance(bank_id, str) and bank_id in source_bank_ids
                    for bank_id in proposal["bank_ids"]
                )
                or not proposal.get("reason")
                or proposal.get("recommendation") not in SELECTION_CLASSES
                or not isinstance(proposal.get("problems"), list)
            ):
                raise ValueError(f"Proposta de expansão inválida: {proposal_key}")
            decisions = proposal.get("decisions", {})
            if set(decisions) != set(candidate_ids):
                raise ValueError(
                    f"Expansão exige decisões das 13 candidaturas: {proposal_key}"
                )
            categories: Counter[str] = Counter()
            for candidate_id, decision in decisions.items():
                _validate_extension_decision(
                    candidate_id,
                    proposal_key,
                    decision,
                    full_review[candidate_id]["document_id"],
                )
                categories[decision["category"]] += 1
            categorical_count = categories["CONCORDA"] + categories["DISCORDA"]
            has_both_poles = bool(categories["CONCORDA"] and categories["DISCORDA"])
            recommendation = proposal["recommendation"]
            if recommendation == "nucleus" and not (
                has_both_poles and categorical_count >= 3
            ):
                raise ValueError(
                    f"Expansão marcada como núcleo sem cobertura suficiente: {proposal_key}"
                )
            if recommendation == "complementary" and not (
                has_both_poles and categorical_count == 2
            ):
                raise ValueError(
                    f"Expansão complementar sem exatamente dois polos: {proposal_key}"
                )
            if (
                recommendation == "rejected"
                and has_both_poles
                and not proposal["problems"]
            ):
                raise ValueError(
                    "Expansão rejeitada apesar do contraste precisa registrar o "
                    f"problema editorial: {proposal_key}"
                )
            published_ids.add(published_id)
            proposals[proposal_key] = proposal
    if len(reviewed_at) != 1:
        raise ValueError("Arquivos da expansão editorial usam datas diferentes")
    if not proposals:
        raise ValueError("Expansão editorial não contém propostas auditadas")
    date = next(iter(reviewed_at))
    return (
        proposals,
        inputs,
        {
            "reviewed_at": date,
            "review_id": f"presidential-expanded-document-{date}-r1",
            "method": " ".join(dict.fromkeys(methods)),
        },
    )


def _position_payload(
    row: dict[str, Any] | None,
    decision: dict[str, Any] | None,
    documents: dict[str, dict[str, Any]],
    review_id: str,
    active: bool,
    candidate_id: str | None = None,
) -> dict[str, Any]:
    category = decision["category"] if decision else "PENDENTE"
    reason = (
        decision["reason"]
        if decision
        else (
            "Revisão documental pendente: esta candidatura não fazia parte da matriz analisada; não herda posições de candidatura substituída."
            if row is None
            else "Revisão desta formulação pendente; a classificação anterior está preservada como histórico e não foi confirmada por nova leitura integral nesta rodada."
            if active
            else "Tese fora do núcleo comparativo; revisão da formulação e das posições pendente. A análise anterior permanece preservada."
        )
    )
    evidence = (
        _reviewed_evidence(row or {"candidato_id": candidate_id}, decision, documents)
        if decision and (row or candidate_id)
        else []
    )
    if (
        category in {"CONCORDA", "DISCORDA", "NEUTRO_EXPLICITO", "CONDICIONAL_OU_MISTA"}
        and not evidence
    ):
        raise ValueError("Decisão substantiva sem evidência documental verificada")
    position = {
        "CONCORDA": "concordo",
        "DISCORDA": "discordo",
        "NEUTRO_EXPLICITO": "neutro",
        "CONDICIONAL_OU_MISTA": "sem_posicao",
        "NAO_ENCONTRADA": "sem_posicao",
        "PENDENTE": "sem_posicao",
    }[category]
    references = list(
        dict.fromkeys(f"{item['document_id']}#page={item['page']}" for item in evidence)
    )
    return {
        "position": position,
        "analytical_position": category,
        "justification": reason,
        "quote": "\n\n".join(
            f"[p. {item['page']}] {item['quote']}" for item in evidence
        )
        or None,
        "source_ref": "; ".join(references) or None,
        "source_url": evidence[0]["url"] if evidence else None,
        "evidence": evidence,
        "conditions": decision.get("conditions", []) if decision else [],
        "scope_difference": decision.get("scope_difference") if decision else None,
        "review": {
            "id": review_id,
            "status": "cited_passages_reviewed" if decision else "pending",
            "reason": reason,
            "source_thesis_version": row["versao_tese"] if row else None,
            "source_thesis_text": row["texto_tese"] if row else None,
            "source_position": row["posicao"] if row else None,
            "source_justification": row["justificativa_curta"] if row else None,
            "source_conditions": row.get("ressalvas", []) if row else [],
            "source_evidence": row.get("evidencias", []) if row else [],
            "source_missing_reason": row.get("motivo_informacao_ausente")
            if row
            else None,
        },
    }


def _normalise_literal_text(value: str) -> str:
    normalised = unicodedata.normalize("NFKC", value).replace("\u00ad", "")
    return re.sub(r"\s+", "", normalised.casefold())


def _extract_pdf_text_pages(pdf_bytes: bytes, *, layout: bool) -> list[str]:
    command = ["pdftotext"]
    if layout:
        command.append("-layout")
    command.extend(["-", "-"])
    result = subprocess.run(command, input=pdf_bytes, capture_output=True, check=False)
    if result.returncode != 0:
        error = result.stderr.decode("utf-8", errors="replace").strip()
        raise ValueError(f"Falha ao extrair texto do plano oficial: {error}")
    return result.stdout.decode("utf-8", errors="replace").split("\f")


def _validate_literal_evidence(
    payload: dict[str, Any], plans_zip: Path
) -> None:
    evidence_by_document: dict[str, list[tuple[str, int, str]]] = {}
    for thesis in payload["theses"]:
        for position in thesis["positions"].values():
            for evidence in position.get("evidence", []):
                evidence_by_document.setdefault(evidence["document_id"], []).append(
                    (thesis["id"], evidence["page"], evidence["quote"])
                )

    documents = payload["metadata"]["analysed_documents"]
    with ZipFile(plans_zip) as zipped:
        for document_id, evidence_items in evidence_by_document.items():
            document = documents.get(document_id)
            if document is None:
                raise ValueError(f"Documento da evidência não analisado: {document_id}")
            try:
                pdf_bytes = zipped.read(document["archive_member"])
            except KeyError as error:
                raise ValueError(
                    f"PDF da evidência ausente no pacote: {document_id}"
                ) from error
            extracted = [
                _extract_pdf_text_pages(pdf_bytes, layout=layout)
                for layout in (True, False)
            ]
            for thesis_id, page, quote in evidence_items:
                page_texts = [
                    pages[page - 1] if 0 < page <= len(pages) else ""
                    for pages in extracted
                ]
                literal = _normalise_literal_text(quote)
                if not literal or not any(
                    literal in _normalise_literal_text(page_text)
                    for page_text in page_texts
                ):
                    raise ValueError(
                        "Citação não localizada na página do PDF oficial: "
                        f"{thesis_id}/{document_id}/p.{page}"
                    )


def _build_theses(
    candidate_ids: list[str],
    positions_path: Path,
    source_theses_path: Path,
    resource_hashes: dict[str, str],
    review_path: Path,
    documents_path: Path,
    plans_zip: Path,
    full_review_paths: list[Path] | None = None,
    extension_review_paths: list[Path] | None = None,
    selection_path: Path | None = None,
    expansion_review_paths: list[Path] | None = None,
    source_bank_path: Path | None = None,
    require_full_review: bool = False,
) -> dict[str, Any]:
    if require_full_review and (
        not full_review_paths
        or not extension_review_paths
        or selection_path is None
        or not expansion_review_paths
        or source_bank_path is None
    ):
        raise ValueError(
            "A edição publicável exige revisão integral, seleção e expansão editorial"
        )
    review = json.loads(review_path.read_text(encoding="utf-8"))
    input_paths = {
        "positions": positions_path,
        "source_theses": source_theses_path,
        "documents": documents_path,
    }
    editorial_inputs: dict[str, Any] = {}
    for key, path in input_paths.items():
        digest = _sha256(path)
        if digest != review["input_sha256"][key]:
            raise ValueError(f"Entrada editorial mudou após a revisão: {path}")
        editorial_inputs[key] = {"file": path.name, "sha256": digest}
    editorial_inputs["review"] = {
        "file": review_path.name,
        "sha256": _sha256(review_path),
    }
    documents = _verify_plan_snapshot(plans_zip, documents_path)
    full_review: dict[str, dict[str, Any]] = {}
    complete_review = False
    selection: dict[str, Any] | None = None
    expansion_review: dict[str, dict[str, Any]] = {}
    expansion_meta: dict[str, str] | None = None
    if full_review_paths:
        full_review, full_inputs = _load_full_review(
            full_review_paths, candidate_ids, plans_zip
        )
        editorial_inputs["full_review"] = full_inputs
        if set(review["theses"]) != FULL_REVIEW_CORE:
            raise ValueError(
                "Núcleo editorial difere das nove teses da revisão integral"
            )
        for candidate_id, document_review in full_review.items():
            document_id = document_review["document_id"]
            documents[document_id] = {
                **documents.get(document_id, {}),
                "candidato_id": candidate_id,
                "documento_id": document_id,
                "arquivo_zip_membro": f"BR/2026BR{candidate_id}_01.pdf",
                "sha256": document_review["sha256"],
                "paginas": document_review["pages_total"],
                "pages_reviewed": document_review["pages_reviewed"],
                "reading_notes": document_review.get("reading_notes", []),
                "url_documento": OFFICIAL_PLANS_URL,
            }
        documents = {
            key: value
            for key, value in documents.items()
            if value["candidato_id"] in candidate_ids
        }
    if extension_review_paths or selection_path is not None:
        if not full_review or not extension_review_paths or selection_path is None:
            raise ValueError(
                "Matriz completa exige núcleo, extensão e seleção editorial"
            )
        extension_review, extension_inputs = _load_extension_review(
            extension_review_paths, candidate_ids, full_review
        )
        editorial_inputs["extension_review"] = extension_inputs
        selection, selection_input = _load_selection(selection_path)
        editorial_inputs["selection"] = selection_input
        for candidate_id, candidate_review in full_review.items():
            candidate_review["decisions"] = {
                **candidate_review["decisions"],
                **extension_review[candidate_id]["decisions"],
            }
        complete_review = True
    if expansion_review_paths:
        if not complete_review:
            raise ValueError(
                "Expansão editorial exige a matriz completa das 38 formulações"
            )
        if source_bank_path is None:
            raise ValueError("Expansão editorial exige o manifesto do banco de teses")
        source_bank_ids, source_bank_input = _load_source_bank_manifest(
            source_bank_path
        )
        editorial_inputs["source_bank"] = source_bank_input
        expansion_review, expansion_inputs, expansion_meta = _load_expansion_review(
            expansion_review_paths, candidate_ids, full_review, source_bank_ids
        )
        editorial_inputs["expansion_review"] = expansion_inputs
    effective_review_id = (
        expansion_meta["review_id"]
        if expansion_meta
        else selection["review_id"]
        if selection
        else f"presidential-full-document-{review['reviewed_at']}-r1"
        if full_review
        else review["review_id"]
    )
    positions = _load_positions(positions_path)
    source_payload = json.loads(source_theses_path.read_text(encoding="utf-8"))
    source_ids = {item["tese_id"] for item in source_payload["teses"]}
    expected_source_ids = {f"BR26-T{number:03d}" for number in range(1, 37)}
    if source_ids != expected_source_ids:
        raise ValueError(
            "O conjunto editorial de origem não contém exatamente as 36 teses esperadas"
        )

    theses = []
    for suffix, text in THESIS_TEXTS.items():
        reviewed_thesis = review["theses"].get(suffix)
        selection_item = selection["theses"][suffix] if selection else None
        selection_class = (
            selection_item["classification"]
            if selection_item
            else "nucleus"
            if reviewed_thesis is not None
            else "rejected"
        )
        approved = (
            selection_class in {"nucleus", "complementary"}
            if complete_review
            else reviewed_thesis is not None
        )
        if reviewed_thesis and reviewed_thesis["text"] != text:
            raise ValueError(f"Formulação mudou após a revisão: BR26-T{suffix}")
        source_id = SOURCE_THESIS[suffix]
        thesis_positions: dict[str, dict[str, Any]] = {}
        decisions = reviewed_thesis["decisions"] if reviewed_thesis else {}
        if set(decisions) - set(candidate_ids):
            raise ValueError(
                f"Revisão contém candidatura fora do retrato ativo: {suffix}"
            )
        for candidate_id in candidate_ids:
            row = positions.get((source_id, candidate_id))
            decision = (
                full_review[candidate_id]["decisions"][suffix]
                if complete_review or (full_review and approved)
                else decisions.get(candidate_id)
            )
            if decision and row is None and not full_review:
                raise ValueError(
                    f"Decisão sem origem analisada: {source_id} / {candidate_id}"
                )
            thesis_positions[candidate_id] = _position_payload(
                row, decision, documents, effective_review_id, approved, candidate_id
            )
            if complete_review or (full_review and approved):
                if decision is None:
                    raise ValueError(
                        f"Revisão documental ausente: {suffix}/{candidate_id}"
                    )
                thesis_positions[candidate_id]["review"].update(
                    {
                        "status": "full_document_reviewed_automated",
                        "search_terms": decision["search_terms"],
                        "absence_reason": decision.get("absence_reason"),
                        "document_id": full_review[candidate_id]["document_id"],
                        "pages_total": full_review[candidate_id]["pages_total"],
                        "pages_reviewed": full_review[candidate_id]["pages_reviewed"],
                        "sha256": full_review[candidate_id]["sha256"],
                    }
                )
            thesis_positions[candidate_id]["review"]["previous_published_position"] = (
                review["previous_export"]["categorical_positions"]
                .get(suffix, {})
                .get(candidate_id, "sem_posicao")
            )
        if complete_review:
            if selection_item is None:
                raise ValueError(f"Seleção editorial ausente: {suffix}")
            category_counts = Counter(
                item["analytical_position"] for item in thesis_positions.values()
            )
            categorical_count = (
                category_counts["CONCORDA"] + category_counts["DISCORDA"]
            )
            has_both_poles = bool(
                category_counts["CONCORDA"] and category_counts["DISCORDA"]
            )
            valid_selection = {
                "nucleus": has_both_poles and categorical_count >= 3,
                "complementary": has_both_poles and categorical_count == 2,
                "rejected": not has_both_poles,
            }[selection_class]
            if not valid_selection:
                raise ValueError(
                    "Seleção editorial incompatível com o contraste documental: "
                    f"{suffix}/{selection_class}"
                )
            expected_metrics = {
                "agree": category_counts["CONCORDA"],
                "disagree": category_counts["DISCORDA"],
                "conditional": category_counts["CONDICIONAL_OU_MISTA"],
                "not_found": category_counts["NAO_ENCONTRADA"],
            }
            if selection_item.get("metrics", expected_metrics) != expected_metrics:
                raise ValueError(f"Métricas da seleção editorial divergentes: {suffix}")
        if approved and not {"concordo", "discordo"}.issubset(
            {item["position"] for item in thesis_positions.values()}
        ):
            raise ValueError(f"Tese ativa perdeu contraste documentado: {suffix}")
        version = reviewed_thesis["version"] if reviewed_thesis else 2
        supersedes = reviewed_thesis.get("supersedes") if reviewed_thesis else None
        if full_review and suffix == "034A":
            supersedes = {
                "version": version,
                "text": text,
                "text_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
                "reason": "Esclarece continuidade institucional, sem implicar preservação da composição ou das regras atuais.",
            }
            text = CONTINUITY_THESIS_TEXT
            version = 3
        theses.append(
            {
                "id": f"BR26-T{suffix}",
                "version": version,
                "text": text,
                "text_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
                "topic": TOPICS[suffix],
                "status": "approved" if approved else "draft",
                "selection": selection_class,
                "source_thesis_id": source_id,
                "supersedes": supersedes,
                "editorial_note": (
                    selection_item["reason"]
                    if selection_item
                    else "Nove formulações com revisão documental integral automatizada de todas as candidaturas ativas; há contraste documentado. Não constitui revisão humana."
                    if approved and full_review
                    else "Há contraste documentado nas passagens revisadas. Aprovação apenas técnica para seleção; validação humana e revisão das células pendentes não concluídas."
                    if approved
                    else DRAFT_REASONS[suffix]
                ),
                "positions": thesis_positions,
            }
        )

    for proposal_key, proposal in expansion_review.items():
        approved = proposal["recommendation"] in {"nucleus", "complementary"}
        proposal_positions = {}
        for candidate_id in candidate_ids:
            decision = proposal["decisions"][candidate_id]
            proposal_positions[candidate_id] = _position_payload(
                None,
                decision,
                documents,
                effective_review_id,
                approved,
                candidate_id,
            )
            proposal_positions[candidate_id]["review"].update(
                {
                    "status": "full_document_reviewed_automated",
                    "search_terms": decision["search_terms"],
                    "absence_reason": decision.get("absence_reason"),
                    "document_id": full_review[candidate_id]["document_id"],
                    "pages_total": full_review[candidate_id]["pages_total"],
                    "pages_reviewed": full_review[candidate_id]["pages_reviewed"],
                    "sha256": full_review[candidate_id]["sha256"],
                    "expansion_key": proposal_key,
                    "previous_published_position": "sem_posicao",
                }
            )
        theses.append(
            {
                "id": proposal["id"],
                "version": proposal["version"],
                "text": proposal["text"],
                "text_sha256": hashlib.sha256(
                    proposal["text"].encode("utf-8")
                ).hexdigest(),
                "topic": proposal["topic"],
                "status": "approved" if approved else "draft",
                "selection": proposal["recommendation"],
                "source_thesis_id": None,
                "source_bank_ids": proposal["bank_ids"],
                "supersedes": None,
                "introduced_in": effective_review_id,
                "editorial_note": proposal["reason"],
                "editorial_problems": proposal["problems"],
                "positions": proposal_positions,
            }
        )

    payload = {
        "metadata": {
            "election": ELECTION_YEAR,
            "office": OFFICE,
            "country": "BR",
            "version": 6
            if expansion_review
            else 5
            if complete_review
            else 4
            if full_review
            else 3,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "reviewed_at": expansion_meta["reviewed_at"]
            if expansion_meta
            else selection["reviewed_at"]
            if selection
            else review["reviewed_at"],
            "review_id": effective_review_id,
            "review_scope": (
                f"Leitura integral automatizada dos 13 programas oficiais; classificação das 494 células das 38 formulações originais e de {len(expansion_review) * len(candidate_ids)} células de {len(expansion_review)} propostas adicionais auditadas."
                if expansion_review
                else "Leitura integral automatizada dos 13 programas oficiais e classificação das 494 células das 38 formulações; a seleção editorial separa núcleo, perguntas complementares e itens rejeitados."
                if complete_review
                else "Leitura integral automatizada dos 13 programas oficiais e classificação das 117 células das nove teses ativas; as demais teses continuam fora do núcleo revisado."
                if full_review
                else review["scope"]
            ),
            "editorial_state": (
                "matriz documental ampliada e seleção editorial concluída; sem revisão humana"
                if expansion_review
                else "matriz documental automatizada completa e seleção editorial concluída; sem revisão humana"
                if complete_review
                else "revisão documental integral automatizada concluída; sem revisão humana"
                if full_review
                else "rascunho editorial auditado por IA, pendente de revisão humana"
            ),
            "documentary_review_status": "complete_automated"
            if full_review
            else "partial_automated",
            "human_reviewed": False,
            "methodology": (
                "Leitura de todas as páginas, busca complementar por termos e equivalentes e verificação visual quando necessária. PDFs e contagens físicas conferidos contra o ZIP oficial; categorias integrais preservadas, condições e diferenças de escopo explícitas. Ausência não é discordância; decisões condicionais não recebem pontuação binária. A análise V1 permanece apenas como histórico. "
                + selection["method"]
                + " "
                + expansion_meta["method"]
                if expansion_meta and selection
                else "Leitura de todas as páginas, busca complementar por termos e equivalentes e verificação visual quando necessária. PDFs e contagens físicas conferidos contra o ZIP oficial; categorias integrais preservadas, condições e diferenças de escopo explícitas. Ausência não é discordância; decisões condicionais não recebem pontuação binária. A análise V1 permanece apenas como histórico. "
                + selection["method"]
                if complete_review and selection
                else "Leitura de todas as páginas, busca complementar por termos e equivalentes e verificação visual quando necessária. PDFs e contagens físicas conferidos contra o ZIP oficial; categorias integrais preservadas, condições e diferenças de escopo explícitas. Ausência não é discordância; decisões condicionais não recebem pontuação binária. A análise V1 permanece apenas como histórico."
                if full_review
                else review["method"]
            ),
            "editorial_inputs": editorial_inputs,
            "analysed_documents": {
                key: {
                    "sha256": item["sha256"],
                    "archive_member": item["arquivo_zip_membro"],
                    "collected_at": item.get("coletado_em"),
                    **(
                        {
                            "pages_total": item["paginas"],
                            "pages_reviewed": item["pages_reviewed"],
                            "reading_notes": item["reading_notes"],
                        }
                        if full_review
                        else {}
                    ),
                }
                for key, item in documents.items()
            },
            "source_theses": 36,
            "reviewed_formulations": (
                len(THESIS_TEXTS) + len(expansion_review)
                if complete_review
                else len(review["theses"])
            ),
            "reviewed_cells": (
                (len(THESIS_TEXTS) + len(expansion_review)) * len(candidate_ids)
                if complete_review
                else len(review["theses"]) * len(candidate_ids)
            ),
            "published_theses": sum(item["status"] == "approved" for item in theses),
            "resources": {
                "candidates": {
                    "url": OFFICIAL_DATA_URL,
                    "sha256": resource_hashes["candidates"],
                },
                "candidate_status": {
                    "url": OFFICIAL_COMPLEMENT_URL,
                    "sha256": resource_hashes["complement"],
                },
                "plans": {
                    "url": OFFICIAL_PLANS_URL,
                    "sha256": resource_hashes["plans"],
                },
                "photos": {
                    "url": OFFICIAL_PHOTOS_URL,
                    "sha256": resource_hashes["photos"],
                },
            },
        },
        "theses": theses,
    }
    if full_review:
        _validate_literal_evidence(payload, plans_zip)
    return payload


def _read_photos(
    photos_zip: Path, candidates: list[dict[str, Any]]
) -> dict[str, bytes]:
    photos: dict[str, bytes] = {}
    with ZipFile(photos_zip) as zipped:
        for candidate in candidates:
            candidate_id = candidate["id"]
            member = f"FBR{candidate_id}_div.jpg"
            try:
                content = zipped.read(member)
            except KeyError as error:
                raise ValueError(f"Foto oficial ausente no pacote: {member}") from error
            if not content.startswith(b"\xff\xd8\xff"):
                raise ValueError(f"Arquivo não é JPEG: {member}")
            photos[f"{candidate_id}.jpg"] = content
    return photos


def _write_photos(photos: dict[str, bytes], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for existing_photo in output_dir.glob("*.jpg"):
        existing_photo.unlink()
    for filename, content in photos.items():
        (output_dir / filename).write_bytes(content)


def _extract_photos(
    photos_zip: Path, candidates: list[dict[str, Any]], output_dir: Path
) -> None:
    _write_photos(_read_photos(photos_zip, candidates), output_dir)


def _audit_summary(
    payload: dict[str, Any], candidates: list[dict[str, Any]]
) -> dict[str, Any]:
    active = [item for item in payload["theses"] if item["status"] == "approved"]
    pairs = []
    for index, first in enumerate(candidates):
        for second in candidates[index + 1 :]:
            comparable = [
                item
                for item in active
                if all(
                    item["positions"][candidate["id"]]["analytical_position"]
                    in {"CONCORDA", "DISCORDA"}
                    for candidate in (first, second)
                )
            ]
            pairs.append(
                {
                    "candidate_ids": [first["id"], second["id"]],
                    "categorically_comparable": len(comparable),
                    "opposed": sum(
                        item["positions"][first["id"]]["position"]
                        != item["positions"][second["id"]]["position"]
                        for item in comparable
                    ),
                    "denominator_active_theses": len(active),
                }
            )
    return {
        "review_id": payload["metadata"]["review_id"],
        "documentary_review_status": payload["metadata"].get(
            "documentary_review_status", "partial_automated"
        ),
        "human_reviewed": False,
        "pages_reviewed_total": sum(
            len(document.get("pages_reviewed", []))
            for document in payload["metadata"]["analysed_documents"].values()
        ),
        "review_inputs": payload["metadata"]["editorial_inputs"],
        "scope": payload["metadata"]["review_scope"],
        "active_cells": len(active) * len(candidates),
        "categories": dict(
            Counter(
                position["analytical_position"]
                for item in active
                for position in item["positions"].values()
            )
        ),
        "all_reviewed_cells": sum(len(item["positions"]) for item in payload["theses"]),
        "all_reviewed_categories": dict(
            Counter(
                position["analytical_position"]
                for item in payload["theses"]
                for position in item["positions"].values()
            )
        ),
        "selection": dict(Counter(item["selection"] for item in payload["theses"])),
        "by_candidate": {
            candidate["id"]: {
                "name": candidate["name"],
                "denominator": len(active),
                "categories": dict(
                    Counter(
                        item["positions"][candidate["id"]]["analytical_position"]
                        for item in active
                    )
                ),
            }
            for candidate in candidates
        },
        "by_thesis": {
            item["id"]: {
                "version": item["version"],
                "denominator": len(candidates),
                "categories": dict(
                    Counter(
                        position["analytical_position"]
                        for position in item["positions"].values()
                    )
                ),
            }
            for item in active
        },
        "pairs": pairs,
        "changed_publication_cells": [
            {
                "thesis_id": item["id"],
                "version": item["version"],
                "candidate_id": candidate_id,
                "previous_position": position["review"]["previous_published_position"],
                "position": position["position"],
                "analytical_position": position["analytical_position"],
                "change_type": "new_thesis"
                if item.get("introduced_in")
                else "reformulated_thesis"
                if item["supersedes"]
                else "same_thesis_correction",
                "reason": position["review"]["reason"],
                "evidence": position["evidence"],
            }
            for item in active
            for candidate_id, position in item["positions"].items()
            if item["supersedes"]
            or position["review"]["previous_published_position"] != position["position"]
        ],
        "excluded_theses": [
            {
                "id": item["id"],
                "selection": item["selection"],
                "reason": item["editorial_note"],
            }
            for item in payload["theses"]
            if item["status"] != "approved"
        ],
    }


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates-zip", type=Path, required=True)
    parser.add_argument("--complement-zip", type=Path, required=True)
    parser.add_argument("--plans-zip", type=Path, required=True)
    parser.add_argument("--photos-zip", type=Path, required=True)
    parser.add_argument("--experiment-dir", type=Path, required=True)
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument("--full-review-dir", type=Path)
    parser.add_argument("--extension-review-dir", type=Path)
    parser.add_argument("--selection-file", type=Path)
    parser.add_argument("--expansion-review-dir", type=Path)
    parser.add_argument("--source-bank-manifest", type=Path)
    parser.add_argument(
        "--review-file",
        type=Path,
        default=Path(__file__).resolve().parents[1]
        / "data"
        / "theses"
        / "2026"
        / REVIEW_FILE,
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    archives = {
        "candidates": args.candidates_zip,
        "complement": args.complement_zip,
        "plans": args.plans_zip,
        "photos": args.photos_zip,
    }
    for path in archives.values():
        with ZipFile(path) as zipped:
            broken = zipped.testzip()
            if broken:
                raise ValueError(f"Falha de integridade em {path}: {broken}")

    candidates = _build_candidates(args.candidates_zip, args.complement_zip)
    dispute_dir = args.experiment_dir / "disputas" / "BR_PRESIDENTE_2026"
    theses = _build_theses(
        [candidate["id"] for candidate in candidates],
        dispute_dir / "posicoes.jsonl",
        dispute_dir / "teses_selecionadas.json",
        {key: _sha256(path) for key, path in archives.items()},
        args.review_file,
        args.experiment_dir / "fontes" / "documentos.jsonl",
        args.plans_zip,
        full_review_paths=[
            (args.full_review_dir or args.review_file.parent / "full-review")
            / f"group-{group}.json"
            for group in "abcd"
        ],
        extension_review_paths=[
            (args.extension_review_dir or args.review_file.parent / "full-review-v2")
            / f"group-{group}.json"
            for group in "abcd"
        ],
        selection_path=(
            args.selection_file
            or args.review_file.parent / "question-selection-v2.json"
        ),
        expansion_review_paths=[
            (
                args.expansion_review_dir
                or args.review_file.parent / "expansion-review-v3"
            )
            / f"group-{group}.json"
            for group in "abc"
        ],
        source_bank_path=(
            args.source_bank_manifest
            or args.review_file.parent / "source-bank-manifest-v3.json"
        ),
        require_full_review=True,
    )
    theses["metadata"]["candidate_snapshot"] = sorted(
        {candidate["source_snapshot"] for candidate in candidates}
    )
    # Validate every photo before replacing any published output.
    photos = _read_photos(args.photos_zip, candidates)

    candidates_path = args.data_dir / "propostas" / "2026" / "candidates.json"
    theses_path = args.data_dir / "theses" / "2026" / "theses.json"
    candidates_path.parent.mkdir(parents=True, exist_ok=True)
    theses_path.parent.mkdir(parents=True, exist_ok=True)
    candidates_path.write_text(
        json.dumps(candidates, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    theses_path.write_text(
        json.dumps(theses, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (theses_path.parent / "review-audit.json").write_text(
        json.dumps(_audit_summary(theses, candidates), ensure_ascii=False, indent=2)
        + "\n",
        encoding="utf-8",
    )
    _write_photos(photos, args.data_dir / "fotos" / "2026" / "BR")
    print(
        f"Gerados {len(candidates)} candidatos, {len(theses['theses'])} teses "
        f"({theses['metadata']['published_theses']} ativas, "
        f"{theses['metadata']['reviewed_cells']} células revisadas) e "
        f"{len(candidates)} fotos oficiais."
    )


if __name__ == "__main__":
    main()
