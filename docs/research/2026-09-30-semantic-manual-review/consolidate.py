#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RESEARCH = ROOT.parent
MATRIX_PATH = RESEARCH / "2026-09-30-v3-delta-validation" / "FINAL_MATRIX.json"
LENSES_PATH = ROOT / "question-lenses.json"
CANDIDATE_DIR = ROOT / "candidates"
OUTPUT_PATH = ROOT / "CADERNO_REVISAO_SEMANTICA.md"
STATE_PATH = ROOT / "STATE.json"

CLASSIFICATION = {
    "CONCORDA": "Concorda",
    "DISCORDA": "Discorda",
    "CONDICIONAL_OU_MISTA": "Condicional ou mista",
    "NAO_ENCONTRADA": "Sem posição documental suficiente",
}
RECOMMENDATION = {
    "MANTER": "Manter a classificação atual",
    "RECLASSIFICAR_CONCORDA": "Reconsiderar como concordância",
    "RECLASSIFICAR_DISCORDA": "Reconsiderar como discordância",
    "RECLASSIFICAR_CONDICIONAL": "Reconsiderar como condicional ou mista",
}
CATEGORY = {
    "economia_desenvolvimento": "Economia e Desenvolvimento",
    "estado_gestao": "Estado e Gestão Pública",
    "infraestrutura_territorio": "Infraestrutura e Território",
    "meio_ambiente_clima": "Meio Ambiente e Clima",
    "ciencia_tecnologia_inovacao": "Ciência, Tecnologia e Inovação",
    "bem_estar_social": "Bem-Estar Social",
    "educacao_cultura_sociedade": "Educação, Cultura e Sociedade",
    "cidadania_direitos": "Cidadania e Direitos",
    "seguranca_publica": "Segurança Pública",
    "soberania_relacoes_internacionais": "Soberania e Relações Internacionais",
}
RELATION = {
    "support": "apoio direto",
    "opposition": "oposição direta",
    "context": "contexto direto",
    "APOIA": "apoia",
    "CONTRADIZ": "contradiz",
    "QUALIFICA": "qualifica",
    "CONTEXTO": "contextualiza",
}
CONFIDENCE = {"alta": "alta", "media": "média", "baixa": "baixa"}


def load(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def quote_block(page: int, relation: str, quote: str, relevance: str) -> list[str]:
    quote_lines = [line.rstrip() for line in quote.strip().splitlines()] or [quote.strip()]
    relation_label = RELATION.get(relation, relation)
    lines = [f"> **Página {page} · {relation_label}:** {quote_lines[0]}"]
    lines.extend(">" if not line else f"> {line}" for line in quote_lines[1:])
    lines += [">", f"> **Relevância semântica:** {relevance}", ""]
    return lines


def main() -> int:
    matrix = load(MATRIX_PATH)
    lenses = load(LENSES_PATH)
    lens_by_id = {item["question_id"]: item for item in lenses["items"]}
    candidate_meta = {
        item["candidate_id"]: item for item in matrix["candidates"]
    }

    reports: dict[str, dict] = {}
    missing: list[str] = []
    for candidate_id in candidate_meta:
        path = CANDIDATE_DIR / f"{candidate_id}.json"
        if not path.exists():
            missing.append(candidate_id)
            continue
        reports[candidate_id] = load(path)

    state = {
        "schema_version": 1,
        "candidate_count_expected": len(candidate_meta),
        "candidate_count_complete": len(reports),
        "review_count_complete": sum(len(item.get("reviews", [])) for item in reports.values()),
        "missing_candidate_ids": missing,
        "complete": not missing,
    }
    STATE_PATH.write_text(
        json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    if missing:
        print(json.dumps(state, ensure_ascii=False, indent=2))
        return 1

    review_by_candidate = {
        candidate_id: {
            review["question_id"]: review for review in report["reviews"]
        }
        for candidate_id, report in reports.items()
    }

    lines: list[str] = [
        "# Caderno de revisão semântica das 20 teses",
        "",
        "**Revisor(a):** ____________________________________",
        "**Data:** ____/____/________",
        "",
        "> Este documento serve à revisão humana das classificações. As posições atuais e as "
        "recomendações preliminares aparecem separadas. Nada neste caderno altera automaticamente "
        "o aplicativo ou a matriz de produção.",
        ">",
        "> A análise não usa ausência de palavra-chave como prova conclusiva. Os contextos "
        "semânticos recuperam decisões equivalentes, instrumentos próximos, princípios, tensões "
        "e condições documentadas nos perfis integrais dos planos.",
        "",
        "## Como revisar",
        "",
        "1. Leia a posição atual e sua evidência direta.",
        "2. Examine os trechos semanticamente relacionados, inclusive os que apenas qualificam o tema.",
        "3. Compare os argumentos para manter e reconsiderar.",
        "4. Marque uma classificação e registre sua justificativa.",
        "",
        "## Índice",
        "",
    ]
    for question in sorted(matrix["questions"], key=lambda item: item["display_number"]):
        lines.append(f'- **Tese {question["display_number"]}:** {question["statement"]}')
    lines += ["", "## Fila de revisão prioritária", ""]
    priority_items = []
    question_by_id = {item["question_id"]: item for item in matrix["questions"]}
    for meta in sorted(candidate_meta.values(), key=lambda item: item["candidate_name"].casefold()):
        for review in reports[meta["candidate_id"]]["reviews"]:
            if review["preliminary_recommendation"] == "MANTER":
                continue
            question = question_by_id[review["question_id"]]
            priority_items.append((question["display_number"], meta, review))
    priority_items.sort(key=lambda item: (item[0], item[1]["candidate_name"].casefold()))
    if priority_items:
        lines += [
            "Estes casos têm evidência semântica suficiente para justificar uma leitura humana antes dos demais. A indicação é provisória.",
            "",
            "| Tese | Candidatura | Posição atual | Leitura preliminar | Confiança | Questão para decisão |",
            "|---:|---|---|---|---|---|",
        ]
        for number, meta, review in priority_items:
            lines.append(
                f'| {number} | {meta["candidate_name"]} ({meta["party"]}) | '
                f'{CLASSIFICATION[review["current_classification"]]} | '
                f'{RECOMMENDATION[review["preliminary_recommendation"]]} | '
                f'{CONFIDENCE[review["confidence"]]} | {review["human_review_question"]} |'
            )
    else:
        lines.append("Nenhuma divergência preliminar foi identificada.")
    lines += ["", "---", ""]

    recommendations = Counter()
    for question in sorted(matrix["questions"], key=lambda item: item["display_number"]):
        question_id = question["question_id"]
        lens = lens_by_id[question_id]
        positions = {
            item["candidate_id"]: item for item in question["positions"]
        }
        lines += [
            f'## Tese {question["display_number"]} — {question["statement"]}',
            "",
            f'**Categoria:** {CATEGORY[question["category_id"]]}',
            f'**Decisão examinada:** {lens["decision_object"]}',
            f'**Pergunta central ao revisor:** {lens["human_review_question"]}',
            "",
            "**Dimensões semânticas consideradas:**",
            "",
        ]
        lines.extend(f'- {item}' for item in lens["semantic_axes"])
        lines += ["", "**Limites de interpretação:**", ""]
        lines.extend(f'- {item}' for item in lens["interpretation_boundaries"])
        lines += ["", "### Visão comparativa", "", "| Candidato | Posição atual | Recomendação preliminar | Confiança |", "|---|---|---|---|"]
        candidate_order = sorted(
            candidate_meta.values(), key=lambda item: item["candidate_name"].casefold()
        )
        for meta in candidate_order:
            review = review_by_candidate[meta["candidate_id"]][question_id]
            recommendations[review["preliminary_recommendation"]] += 1
            lines.append(
                f'| {meta["candidate_name"]} ({meta["party"]}) | '
                f'{CLASSIFICATION[review["current_classification"]]} | '
                f'{RECOMMENDATION[review["preliminary_recommendation"]]} | '
                f'{CONFIDENCE[review["confidence"]]} |'
            )
        lines += ["", "### Fichas por candidatura", ""]

        for meta in candidate_order:
            candidate_id = meta["candidate_id"]
            review = review_by_candidate[candidate_id][question_id]
            position = positions[candidate_id]
            lines += [
                f'#### {meta["candidate_name"]} ({meta["party"]})',
                "",
                f'**Classificação atual:** {CLASSIFICATION[review["current_classification"]]}',
                f'**Justificativa atual:** {review["current_rationale"]}',
                "",
                "**Evidência direta usada na matriz atual:**",
                "",
            ]
            direct = position.get("evidence") or []
            if direct:
                for evidence in direct:
                    lines += quote_block(
                        evidence["page"],
                        evidence.get("role", "evidência direta"),
                        evidence["quote"],
                        evidence.get("interpretation", "Trecho usado na classificação atual."),
                    )
            else:
                lines += ["- Nenhum trecho direto foi considerado suficiente na matriz atual.", ""]

            lines += [
                f'**Vizinhança semântica do plano:** {review["semantic_neighborhood_summary"]}',
                "",
                "**Trechos semanticamente relacionados:**",
                "",
            ]
            context = review["semantic_context"]
            if context:
                for entry in context:
                    lines += quote_block(
                        entry["page"], entry["relation"], entry["quote"], entry["semantic_relevance"]
                    )
            else:
                lines += [
                    f'- {review["semantic_context_absence_reason"]}',
                    "",
                ]

            lines += [
                f'**Avaliação semântica:** {review["semantic_assessment"]}',
                "",
                "**Razões para manter a classificação atual:**",
                "",
            ]
            lines.extend(f'- {item}' for item in review["reasons_to_keep"])
            lines += ["", "**Razões para reconsiderar:**", ""]
            lines.extend(f'- {item}' for item in review["reasons_to_reconsider"])
            lines += [
                "",
                f'**Recomendação preliminar do revisor documental:** {RECOMMENDATION[review["preliminary_recommendation"]]} '
                f'(confiança {CONFIDENCE[review["confidence"]]}).',
                "",
                f'**Decisão humana necessária:** {review["human_review_question"]}',
                "",
                "- [ ] Concorda",
                "- [ ] Discorda",
                "- [ ] Condicional ou mista",
                "- [ ] Sem posição documental suficiente",
                "",
                "**Justificativa do revisor humano:**",
                "",
                "________________________________________________________________________________",
                "",
                "________________________________________________________________________________",
                "",
            ]
        lines += ["---", ""]

    lines += [
        "## Totais das recomendações preliminares",
        "",
    ]
    for key in (
        "MANTER",
        "RECLASSIFICAR_CONCORDA",
        "RECLASSIFICAR_DISCORDA",
        "RECLASSIFICAR_CONDICIONAL",
    ):
        lines.append(f'- **{RECOMMENDATION[key]}:** {recommendations[key]}')
    lines.append("")

    OUTPUT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(
        json.dumps(
            {
                **state,
                "output": str(OUTPUT_PATH),
                "recommendations": dict(recommendations),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
