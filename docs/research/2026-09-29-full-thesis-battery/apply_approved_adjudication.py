#!/usr/bin/env python3
"""Apply the four user-approved editorial adjudications as battery version 3."""

import datetime
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VALIDATION = ROOT.parent / "2026-09-29-approved-full-battery-validation"
BUTTONS = ["Concordo", "Discordo", "Neutro", "Pular"]
USER_MESSAGE = "sim"

REPLACEMENTS = {
    8: {
        "id": "FB-Q23",
        "version": 1,
        "statement": "O governo federal deve usar concessões e parcerias público-privadas para ampliar a infraestrutura de transportes.",
        "explanation": "Concessões e parcerias público-privadas permitem que empresas participem do financiamento, da construção ou da operação de projetos. A afirmação não exige esse modelo em toda obra nem implica privatizar empresas públicas.",
        "decision_object": "Uso federal de concessões e parcerias público-privadas na ampliação da infraestrutura de transportes.",
        "category_id": "infraestrutura_territorio",
        "family_ids": ["T01", "T04"],
        "measurement_risks": [
            "Concessão, parceria público-privada, autorização e privatização de empresa são instrumentos diferentes.",
            "Apoio a capital privado em um projeto não prova adesão a esse modelo em toda a infraestrutura.",
            "Estatização ou reversão de concessões só constitui oposição quando alcança a infraestrutura de transportes perguntada.",
        ],
        "reach_hypothesis": "Sete planos documentam concessões ou parcerias na infraestrutura; planos que defendem estatização ou reversão podem fornecer oposição, sujeita a reclassificação.",
    },
    10: {
        "id": "FB-Q24",
        "version": 1,
        "statement": "O governo federal deve investir no desenvolvimento de capacidade nacional de inteligência artificial.",
        "explanation": "Capacidade nacional inclui pesquisa, infraestrutura e desenvolvimento de modelos de inteligência artificial no Brasil. A afirmação não define se a execução será pública, privada ou cooperativa nem exige excluir tecnologias estrangeiras.",
        "decision_object": "Investimento federal no desenvolvimento de capacidade nacional de inteligência artificial.",
        "category_id": "ciencia_tecnologia_inovacao",
        "family_ids": ["I05"],
        "measurement_risks": [
            "Capacidade nacional não significa propriedade estatal, uso obrigatório ou proibição de modelos estrangeiros.",
            "Difusão de sistemas existentes sem desenvolvimento nacional não responde integralmente à tese.",
            "Laboratório, infraestrutura computacional, pesquisa e modelos nacionais são instrumentos distintos que podem sustentar a mesma direção geral.",
        ],
        "reach_hypothesis": "Cinco planos documentam alguma forma de capacidade nacional de inteligência artificial, sujeita a reclassificação no escopo exato.",
    },
    12: {
        "id": "FB-Q25",
        "version": 1,
        "statement": "Concursos públicos federais devem reservar vagas com base em critérios raciais.",
        "explanation": "A reserva separa parte das vagas de concursos federais para grupos raciais definidos pela política pública. A afirmação não fixa percentual, procedimento de verificação nem duração da medida.",
        "decision_object": "Reserva de vagas por critério racial em concursos públicos federais.",
        "category_id": "cidadania_direitos",
        "family_ids": ["C05"],
        "measurement_risks": [
            "Cotas em universidades, empresas privadas e eleições não respondem automaticamente a concursos públicos federais.",
            "Cotas para pessoas com deficiência ou por identidade de gênero não substituem uma posição sobre critério racial.",
            "Abolição geral das cotas pode constituir oposição quando seu alcance inclui o serviço público.",
        ],
        "reach_hypothesis": "Quatro planos apresentam apoio potencial no serviço público e um plano rejeita cotas em geral; o contraste requer reclassificação uniforme.",
    },
    18: {
        "id": "FB-Q19",
        "version": 2,
        "statement": "O poder público deve usar reconhecimento facial em espaços públicos para fins de segurança.",
        "explanation": "A afirmação admite comparar imagens captadas em espaços públicos com bases de identificação para ações de segurança. Ela não dispensa regras de finalidade, privacidade, auditoria, precisão, armazenamento ou supervisão.",
        "decision_object": "Uso de reconhecimento facial em espaços públicos para finalidades de segurança.",
        "category_id": "seguranca_publica",
        "family_ids": ["S08"],
        "measurement_risks": [
            "Câmeras corporais, integração de bases e drones não equivalem a reconhecimento facial.",
            "Uma proposta restrita a finalidade ou local específico pode exigir classificação condicional.",
            "Ausência de salvaguardas no plano não autoriza afirmar que a candidatura as rejeita.",
        ],
        "reach_hypothesis": "Cinco planos documentam reconhecimento facial ou identificação por inteligência artificial na segurança, sujeita ao escopo exato.",
    },
}


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def wording_digest(item):
    payload = {
        "id": item["id"],
        "version": item["version"],
        "statement": item["statement"],
        "explanation": item["explanation"],
        "response_buttons": BUTTONS,
    }
    return hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True).encode()
    ).hexdigest()


def fingerprint(items):
    payload = {
        "items": [
            {
                "id": item["id"],
                "version": item["version"],
                "wording_sha256": item["wording_sha256"],
            }
            for item in items
        ],
        "response_buttons": BUTTONS,
    }
    return hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True).encode()
    ).hexdigest()


def render_markdown(battery):
    lines = [
        "# Bateria final aprovada",
        "",
        "As 20 afirmações, suas explicações e os quatro botões foram aprovados pelo usuário. Esta é a versão editorial canônica para a continuação do trabalho.",
        "",
        "Botões: **Concordo · Discordo · Neutro · Pular**.",
        "",
    ]
    for item in battery["items"]:
        lines.extend(
            [
                f"## {item['display_number']}. {item['statement']}",
                "",
                item["explanation"],
                "",
                f"*Objeto: {item['decision_object']}*",
                "",
            ]
        )
    lines.extend(
        [
            "## Situação documental",
            "",
            "Os treze planos foram validados integralmente contra a versão 2. Dezesseis teses desta versão preservam exatamente aquele texto e podem reutilizar as classificações já validadas. As teses 8, 10 e 12 foram substituídas; a tese 18 mudou de alcance. Essas quatro redações estão aprovadas editorialmente, mas suas 52 classificações por plano não foram refeitas por decisão do usuário neste encerramento.",
            "",
            "Silêncio do plano continua significando posição não encontrada, nunca neutralidade. Pablo Marçal permanece fora do corpus.",
            "",
        ]
    )
    return "\n".join(lines)


def main():
    battery_path = ROOT / "BATTERY.json"
    approval_path = ROOT / "APPROVAL.json"
    battery = read(battery_path)
    if battery["battery_version"] == 3:
        print(json.dumps({"status": "already_applied", "wording_fingerprint": read(approval_path)["wording_fingerprint"]}))
        return
    assert battery["battery_version"] == 2
    assert battery["status"] == "approved"
    assert len(battery["items"]) == 20
    adjudication = read(VALIDATION / "EDITORIAL_ADJUDICATION.json")
    assert adjudication["status"] in {"awaiting_human_decision", "approved_no_revalidation_requested"}
    assert len(adjudication["proposals"]) == 4

    for source, archive in [
        (battery_path, ROOT / "BATTERY_V2.json"),
        (ROOT / "BATTERY.md", ROOT / "BATTERY_V2.md"),
        (approval_path, ROOT / "APPROVAL_V2.json"),
    ]:
        assert not archive.exists()
        shutil.copyfile(source, archive)

    approved_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    prior_items = {item["display_number"]: item for item in battery["items"]}
    items = []
    replaced = []
    for number in range(1, 21):
        old = prior_items[number]
        if number not in REPLACEMENTS:
            items.append(old)
            continue
        new = {
            **REPLACEMENTS[number],
            "display_number": number,
            "status": "approved",
            "anchor_approved": False,
            "source_drafts": ["EDITORIAL_ADJUDICATION.md"],
            "revision_history": {
                "previous_id": old["id"],
                "previous_version": old["version"],
                "previous_wording_sha256": old["wording_sha256"],
                "reason": next(
                    proposal["reason"]
                    for proposal in adjudication["proposals"]
                    if proposal["display_number"] == number
                ),
            },
        }
        new["wording_sha256"] = wording_digest(new)
        new["full_battery_user_decision"] = {
            "decision": "approved",
            "version": new["version"],
            "wording_sha256": new["wording_sha256"],
            "user_message": USER_MESSAGE,
            "recorded_at": approved_at,
        }
        items.append(new)
        replaced.append(
            {
                "display_number": number,
                "previous_id": old["id"],
                "previous_version": old["version"],
                "replacement_id": new["id"],
                "replacement_version": new["version"],
            }
        )

    battery.update(
        {
            "battery_id": "full-battery-human-review-v3",
            "battery_version": 3,
            "status": "approved",
            "item_count": 20,
            "approved_item_count": 20,
            "pending_item_count": 0,
            "response_buttons": BUTTONS,
            "candidate_validation_dispatched": False,
            "candidate_validation_status": "partial_from_v2_four_items_require_reclassification",
            "validated_unchanged_item_count": 16,
            "items_requiring_reclassification": ["FB-Q23", "FB-Q24", "FB-Q25", "FB-Q19"],
            "approval_record": "APPROVAL.json",
            "prior_battery": "BATTERY_V2.json",
            "prior_approval": "APPROVAL_V2.json",
            "approved_at": approved_at,
            "replaced_after_plan_validation": replaced,
            "items": items,
        }
    )
    write(battery_path, battery)

    approval = {
        "schema_version": 1,
        "battery_id": battery["battery_id"],
        "battery_version": 3,
        "decision": "approved",
        "user_message": USER_MESSAGE,
        "approved_at": approved_at,
        "scope": "As quatro mudanças propostas na adjudicação e a bateria final de 20 afirmações com os quatro botões.",
        "item_count": 20,
        "response_buttons": BUTTONS,
        "wording_fingerprint": fingerprint(items),
        "prior_approval": "APPROVAL_V2.json",
        "adjudication": "../2026-09-29-approved-full-battery-validation/EDITORIAL_ADJUDICATION.json",
        "items": [
            {
                "id": item["id"],
                "version": item["version"],
                "wording_sha256": item["wording_sha256"],
            }
            for item in items
        ],
    }
    write(approval_path, approval)
    (ROOT / "BATTERY.md").write_text(render_markdown(battery))

    state = read(ROOT / "STATE.json")
    state["phase"] = "approved_revision_handoff"
    state["battery"].update(
        {
            "version": 3,
            "item_count": 20,
            "pending_user_review_count": 0,
            "approved_item_count": 20,
            "sha256": hashlib.sha256(battery_path.read_bytes()).hexdigest(),
        }
    )
    state["candidate_validation"].update(
        {
            "status": "partial_revalidation_not_requested",
            "previous_round_complete": True,
            "validated_unchanged_questions": 16,
            "questions_requiring_reclassification": 4,
            "answers_requiring_reclassification": 52,
            "validation_record": "../2026-09-29-approved-full-battery-validation/STATE.json",
        }
    )
    state["tasks"].append(
        {
            "id": "human_adjudication_02",
            "output": "APPROVAL.json",
            "status": "complete",
            "approval_record": "APPROVAL.json",
        }
    )
    write(ROOT / "STATE.json", state)

    adjudication["status"] = "approved_no_revalidation_requested"
    adjudication["human_decision"] = {
        "decision": "approved",
        "user_message": USER_MESSAGE,
        "recorded_at": approved_at,
        "battery_approval": "../2026-09-29-full-thesis-battery/APPROVAL.json",
    }
    write(VALIDATION / "EDITORIAL_ADJUDICATION.json", adjudication)

    historical_approval = read(VALIDATION / "APPROVAL.json")
    historical_approval["battery_approval"] = "../2026-09-29-full-thesis-battery/APPROVAL_V2.json"
    write(VALIDATION / "APPROVAL.json", historical_approval)

    print(json.dumps({"status": "approved", "battery_version": 3, "items": 20, "wording_fingerprint": approval["wording_fingerprint"]}))


if __name__ == "__main__":
    main()
