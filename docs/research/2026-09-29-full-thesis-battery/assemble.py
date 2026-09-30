#!/usr/bin/env python3
"""Assemble the whole human-review battery from the independent editorial drafts."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
COVERAGE = ROOT / "drafts" / "coverage-review.json"
ANCHORS = ROOT.parent / "2026-09-29-question-editorial-review" / "BLOCK_01.json"
APPROVAL = ROOT / "APPROVAL.json"

BUTTONS = ["Concordo", "Discordo", "Neutro", "Pular"]

SELECTED = [
    "B01-Q01", "B01-Q02", "B01-Q03", "B01-Q04",
    "CR-Q05", "CR-Q06", "CR-Q07", "CR-Q08",
    "CR-Q11", "CR-Q12", "CR-Q14", "CR-Q15", "CR-Q16",
    "CR-Q17", "CR-Q19", "CR-Q21", "CR-Q22",
    "CR-Q23", "CR-Q25", "CR-Q26",
]

ID_BY_SOURCE = {
    "CR-Q05": "FB-Q05",
    "CR-Q06": "FB-Q06",
    "CR-Q07": "FB-Q07",
    "CR-Q08": "FB-Q08",
    "CR-Q11": "FB-Q10",
    "CR-Q12": "FB-Q11",
    "CR-Q14": "FB-Q12",
    "CR-Q15": "FB-Q13",
    "CR-Q16": "FB-Q14",
    "CR-Q17": "FB-Q15",
    "CR-Q19": "FB-Q16",
    "CR-Q21": "FB-Q17",
    "CR-Q22": "FB-Q18",
    "CR-Q23": "FB-Q19",
    "CR-Q25": "FB-Q21",
    "CR-Q26": "FB-Q22",
}

VERSION_BY_SOURCE = {
    "CR-Q07": 2,
    "CR-Q08": 2,
    "CR-Q21": 2,
}

REVISION_HISTORY = {
    "CR-Q07": {
        "previous_version": 1,
        "previous_wording_sha256": "4fea5e6441d0e4ba9cffb4969e56a62c7d06f2060f7a13062523090963656a02",
        "reason": "Substitui a construção 'deve poder' por uma ação legal direta e preserva avaliação, prova e defesa.",
    },
    "CR-Q08": {
        "previous_version": 1,
        "previous_wording_sha256": "e3c81d6427738af6c3639abf761c6eac28e4a5b7902574dfe8a8815ea44742f9",
        "reason": "Recorta o instrumento de competência federal: repasse de recursos para a tarifa zero municipal.",
    },
    "CR-Q21": {
        "previous_version": 1,
        "previous_wording_sha256": "ee2bff21023ff7e0fe973f7305ee3ddb2df134f621a620696f1fbaafd024858b",
        "reason": "Usa o termo comum 'aborto' para reduzir custo de interpretação sem incorporar justificativa moral.",
    },
}

OVERRIDES = {
    "CR-Q05": {
        "statement": "O governo federal deve ter uma regra que limite o crescimento das despesas públicas.",
        "explanation": "A afirmação pergunta se esse limite deve existir. Ela não escolhe uma lei, um índice de correção, uma meta de resultado nem um limite para a dívida.",
    },
    "CR-Q06": {
        "statement": "A Petrobras deve permanecer sob controle do governo federal.",
        "explanation": "A afirmação trata de manter o governo federal como acionista controlador. Ela não exige propriedade integral, monopólio no setor, integração de refinarias ou reestatização de outras empresas.",
        "decision_object": "Manutenção do controle acionário federal da Petrobras.",
    },
    "CR-Q07": {
        "statement": "A lei deve permitir a demissão de um servidor público estável por baixo desempenho comprovado em avaliações periódicas, com direito de defesa.",
        "explanation": "A afirmação pergunta se o baixo desempenho pode ser motivo legal para demissão. Ela não torna a demissão automática e não abrange cargos temporários, remuneração por mérito nem demissão sem processo.",
        "decision_object": "Permissão legal para demitir servidor estável por baixo desempenho comprovado, com direito de defesa.",
    },
    "CR-Q08": {
        "statement": "O governo federal deve repassar recursos para que os municípios ofereçam transporte coletivo urbano gratuito a todos os passageiros.",
        "explanation": "A afirmação trata do financiamento federal da tarifa zero universal. A organização e a prestação do serviço permanecem locais; a pergunta não define a fonte dos recursos, os critérios de distribuição nem o operador.",
        "decision_object": "Financiamento federal da gratuidade universal no transporte coletivo urbano municipal.",
    },
    "CR-Q11": {
        "explanation": "Mercado regulado de carbono é um sistema obrigatório para os setores abrangidos: cada emissor deve cumprir regras sobre suas emissões e pode negociar créditos conforme normas públicas. A afirmação não define os setores, os limites nem a distribuição inicial dos créditos.",
    },
    "CR-Q12": {
        "statement": "Sistemas de inteligência artificial classificados como de alto risco devem cumprir obrigações preventivas antes de serem usados.",
        "explanation": "Alto risco se refere a usos capazes de afetar segurança, direitos ou acesso a serviços relevantes. As obrigações podem incluir avaliação de risco, registro e supervisão; a afirmação não exige autorização prévia para toda inteligência artificial.",
    },
    "CR-Q14": {
        "statement": "O SUS deve contratar atendimento de clínicas e hospitais privados quando a rede pública não tiver capacidade suficiente para atender a demanda.",
        "explanation": "A afirmação prevê a compra complementar de consultas, exames, leitos ou procedimentos. Ela não transfere a gestão de unidades públicas nem exige contratação permanente.",
    },
    "CR-Q15": {
        "statement": "Quem recebe benefício de transferência de renda e consegue emprego formal deve poder manter parte do benefício por um período de transição.",
        "explanation": "A afirmação permite reduzir o benefício gradualmente depois da entrada no emprego formal, em vez de encerrá-lo de uma vez. Ela não fixa o programa, o valor nem a duração.",
    },
    "CR-Q21": {
        "statement": "O aborto voluntário deve deixar de ser crime até determinado período da gestação.",
        "explanation": "A afirmação pergunta se deve existir um prazo gestacional em que o aborto voluntário não tenha punição criminal. Ela não define esse prazo, a forma de atendimento nem as regras clínicas.",
        "decision_object": "Descriminalização do aborto voluntário até determinado período da gestação.",
    },
    "CR-Q22": {
        "statement": "A partir dos 16 anos, adolescentes devem responder pelo regime penal adulto por qualquer crime.",
        "explanation": "A afirmação propõe aplicar o regime penal adulto a adolescentes de 16 e 17 anos em todos os crimes. Ela não altera as medidas socioeducativas para menores de 16 anos.",
        "decision_object": "Aplicação geral do regime penal adulto a partir dos 16 anos.",
    },
    "CR-Q26": {
        "statement": "O Brasil deve ratificar o texto final do acordo comercial entre Mercosul e União Europeia.",
        "explanation": "Ratificar é concluir a aprovação interna necessária para que o acordo produza efeitos para o Brasil. A afirmação não implica apoiar outros acordos nem impede relações comerciais com outros parceiros.",
        "decision_object": "Ratificação do texto final do acordo Mercosul-União Europeia.",
    },
}


def read(path):
    return json.loads(path.read_text())


def digest(item):
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


def main():
    if APPROVAL.exists():
        raise SystemExit("A bateria já foi aprovada; assemble.py não pode sobrescrever decisões humanas.")
    coverage = read(COVERAGE)
    anchors = read(ANCHORS)
    coverage_items = {item["id"]: item for item in coverage["proposed_battery"]}
    anchor_items = {item["id"]: item for item in anchors["items"]}
    assert SELECTED[:4] == list(anchor_items)
    assert len(SELECTED) == len(set(SELECTED)) == 20

    items = []
    for number, source_id in enumerate(SELECTED, 1):
        if source_id in anchor_items:
            source = anchor_items[source_id]
            item = {
                "id": source_id,
                "display_number": number,
                "version": source["version"],
                "status": "approved_anchor",
                "anchor_approved": True,
                "statement": source["statement"],
                "explanation": source["explanation"],
                "decision_object": source["decision"],
                "category_id": coverage_items[source_id]["category_id"],
                "family_ids": source["decision_family_ids"],
                "measurement_risks": source["limits"],
                "reach_hypothesis": coverage_items[source_id]["reach_hypothesis"],
                "source_drafts": ["BLOCK_01.json", "coverage-review.json"],
            }
            assert item["statement"] == coverage_items[source_id]["statement"]
            assert source["wording_sha256"] == digest(item)
        else:
            source = coverage_items[source_id]
            item = {
                "id": ID_BY_SOURCE[source_id],
                "source_draft_id": source_id,
                "display_number": number,
                "version": VERSION_BY_SOURCE.get(source_id, 1),
                "status": "pending_user_review",
                "anchor_approved": False,
                "statement": source["statement"],
                "explanation": source["explanation"],
                "decision_object": source["decision_object"],
                "category_id": source["category_id"],
                "family_ids": source["family_ids"],
                "measurement_risks": source["measurement_risks"],
                "reach_hypothesis": source["reach_hypothesis"],
                "terms_to_explain": source["terms_to_explain"],
                "source_drafts": [
                    "coverage-review.json",
                    "whole-battery.json",
                    "semantic-review.json",
                    "red-team.json",
                ],
            }
            item.update(OVERRIDES.get(source_id, {}))
            if source_id in REVISION_HISTORY:
                item["revision_history"] = REVISION_HISTORY[source_id]
                item["source_drafts"].append("HUMAN_REVIEW_01.md")
        item["wording_sha256"] = digest(item)
        items.append(item)

    result = {
        "schema_version": 1,
        "battery_id": "full-battery-human-review-v2",
        "battery_version": 2,
        "status": "pending_user_review",
        "item_count": len(items),
        "approved_anchor_count": 4,
        "pending_item_count": 16,
        "response_buttons": BUTTONS,
        "published_theses_used": False,
        "candidate_validation_dispatched": False,
        "selection_note": "O conjunto foi derivado dos 636 registros e 118 famílias. O tamanho resulta da revisão editorial, sem cota rígida por categoria. Contagens do mapa são apenas pistas de busca, não respostas de candidatos.",
        "removed_after_human_review": [
            {
                "id": "FB-Q09",
                "previous_version": 1,
                "previous_wording_sha256": "dfc23818f258a734242d5c3397d7521d977365081bce3ad4eace4c103fb2a723",
                "statement": "Os serviços de água e esgoto devem poder ser concedidos a empresas privadas.",
                "reason": "A redação mede uma decisão do titular local ou interfederativo do serviço, sem recortar uma ação própria do governo federal.",
            },
            {
                "id": "FB-Q20",
                "previous_version": 1,
                "previous_wording_sha256": "45ed9c0f7011fe7e7c81dbea2308097b94888bc1f577bf3a662197e46c08c3c2",
                "statement": "Lideranças de facções criminosas devem cumprir pena separadamente dos demais presos, em unidades de segurança máxima.",
                "reason": "A redação descreve em grande parte uma regra jurídica e uma prática já existentes, reduzindo sua utilidade como escolha política discriminante.",
            },
        ],
        "items": items,
    }
    (ROOT / "BATTERY.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    )

    lines = [
        "# Bateria completa para validação humana",
        "",
        "São 20 afirmações apresentadas numa única rodada. As quatro primeiras já foram aprovadas; as outras 16 aguardam decisão. Afirmação e explicação formam uma única versão.",
        "",
        "Botões previstos: **Concordo · Discordo · Neutro · Pular**. Nenhuma destas versões foi enviada à nova rodada dos treze planos.",
        "",
    ]
    for item in items:
        marker = "âncora já aprovada" if item["anchor_approved"] else "aguarda aprovação"
        lines.extend([
            f"## {item['display_number']}. {item['statement']}",
            "",
            item["explanation"],
            "",
            f"*Estado: {marker}. Objeto: {item['decision_object']}*",
            "",
        ])
    lines.extend([
        "## Limites desta proposta",
        "",
        "Cobertura potencial, oposição e redundância só poderão ser medidas depois da aprovação destas versões e da aplicação uniforme aos treze planos. Silêncio documental não será convertido em neutralidade. Alterações de significado retornam ao usuário antes de qualquer validação.",
        "",
    ])
    (ROOT / "BATTERY.md").write_text("\n".join(lines))

    categories = {}
    for item in items:
        categories[item["category_id"]] = categories.get(item["category_id"], 0) + 1
    print(json.dumps({"items": len(items), "categories": categories}, ensure_ascii=False))


if __name__ == "__main__":
    main()
