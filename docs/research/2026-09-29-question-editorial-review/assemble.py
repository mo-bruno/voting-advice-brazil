#!/usr/bin/env python3
"""Check documentary maps and prepare an explicitly unapproved review block."""
import collections
import datetime
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def item_digest(item, buttons):
    payload = {k: item[k] for k in ('id', 'version', 'statement', 'explanation')}
    payload['response_buttons'] = buttons
    return hashlib.sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def main():
    state = read(ROOT / 'STATE.json')
    if state['approval_gate']['status'] != 'pending_user_review':
        raise SystemExit('Historical pre-approval assembler: approved wording/state must not be regenerated. Use ../2026-09-29-approved-block-01-validation/validate.py.')
    inventory_path = ROOT / state['source_inventory']
    assert checksum(inventory_path) == state['source_inventory_sha256'], 'Inventory changed'
    inventory = read(inventory_path)
    positions = {x['position_key']: x for x in inventory['positions']}
    assert len(positions) == 636
    taxonomy = {x['id']: x['name'] for x in inventory['category_map']}
    families, mapped, assigned_categories, ids = [], set(), set(), set()
    for task in state['editorial_tasks']:
        source = ROOT / task['output']
        part = read(source)
        assert part['author_agent'] == task['agent_id']
        assert part['role'] == 'editorial_mapping_only'
        assert not set(part['categories']) & assigned_categories, 'Overlapping editorial scope'
        assigned_categories.update(part['categories'])
        expected = {k for k, p in positions.items() if p['category_id'] in part['categories']}
        found = set()
        assert part['unmapped'] == [], 'Unmapped entries require editorial resolution'
        for family in part['families']:
            assert family['id'] not in ids
            ids.add(family['id'])
            assert family['category_id'] in part['categories']
            for field in ('title', 'common_object', 'distinct_decisions', 'comparison_limits', 'position_keys'):
                assert family[field], (family['id'], field)
            keys = family['position_keys']
            assert len(keys) == len(set(keys)), 'Duplicate within family'
            for key in keys:
                assert key in expected, (family['id'], key)
                assert positions[key]['category_id'] == family['category_id']
            normalized_decisions = []
            for decision in family['distinct_decisions']:
                if isinstance(decision, dict):
                    if 'source_position_key' in decision:
                        key = decision['source_position_key']
                        assert key in keys
                        original = positions[key]
                        for field in ('statement', 'instrument', 'scope', 'conditions'):
                            assert decision['documented_' + field] == original[field], (family['id'], key, field)
                        assert decision['subdecisions']
                        normalized_decisions.extend({'decision': text, 'position_keys': [key]} for text in decision['subdecisions'])
                    else:
                        assert decision.get('decision')
                        assert set(decision.get('position_keys', [])) <= set(keys)
                        for variant in decision.get('source_variants', []):
                            original = positions[variant['position_key']]
                            assert variant['position_key'] in decision['position_keys']
                            for field in ('statement', 'instrument', 'scope', 'conditions'):
                                assert variant[field] == original[field], (family['id'], variant['position_key'], field)
                        normalized_decisions.append({k: v for k, v in decision.items() if k != 'source_variants'})
                else:
                    assert isinstance(decision, str)
                    normalized_decisions.append(decision)
            found.update(keys)
            families.append({**family, 'distinct_decisions': normalized_decisions, 'source_map': task['output']})
        assert found == expected, {'map': task['output'], 'missing': sorted(expected - found)}
        mapped.update(found)
        task.update(status='mapped', mapped_positions=len(found), family_count=len(part['families']), sha256=checksum(source))
    assert mapped == set(positions)
    assert assigned_categories == set(taxonomy)

    block = read(ROOT / 'BLOCK_01.json')
    assert block['status'] == 'pending_user_review'
    assert block['candidate_validation_dispatched'] is False
    assert block['response_buttons'] == ['Concordo', 'Discordo', 'Neutro', 'Pular']
    assert len({q['id'] for q in block['items']}) == len(block['items'])
    for item in block['items']:
        assert item['status'] == 'pending_user_review'
        assert item['candidate_answers'] is None and item['user_decision'] is None
        assert set(item['decision_family_ids']) <= ids
        related = {key for family in families if family['id'] in item['decision_family_ids'] for key in family['position_keys']}
        for source in item['sources']:
            original = positions[source['position_key']]
            assert source['position_key'] in related
            assert source['candidate_name'] == original['candidate_name']
            assert source['pages'] == sorted({e['page'] for e in original['evidence']})
            assert (ROOT / source['source_profile']).exists()
        for justification in item['semantic_layers']['explicit_justifications']:
            original = positions[justification['position_key']]
            assert justification['page'] in {e['page'] for e in original['evidence']}
        item['wording_sha256'] = item_digest(item, block['response_buttons'])
    write(ROOT / 'BLOCK_01.json', block)

    map_data = {'schema_version': 1, 'stage': 'editorial_mapping_only', 'mapped_positions': len(mapped),
                'family_count': len(families), 'category_count': len(taxonomy), 'families': families,
                'note': 'Links organize related decisions, not candidate answers or measured coverage of a statement.'}
    write(ROOT / 'DECISION_MAP.json', map_data)
    summary = ['# Mapa comum de decisões', '',
               f'{len(mapped)} registros do inventário organizados em {len(families)} famílias nas dez categorias. Cada registro aparece ao menos uma vez; vínculos múltiplos não são posições adicionais.', '',
               '**Este mapa não contém respostas de candidaturas às novas perguntas.** Ele localiza objetos relacionados e preserva diferenças que a futura comparação precisará examinar.', '']
    for category, name in taxonomy.items():
        summary += [f'## {name}', '', '| Família | Decisões a separar | Limites de comparação |', '|---|---|---|']
        for family in families:
            if family['category_id'] == category:
                clean = lambda values: '; '.join(v['decision'] if isinstance(v, dict) else v for v in values).replace('|', '/')
                summary.append(f"| {family['id']} — {family['title']} | {clean(family['distinct_decisions'])} | {clean(family['comparison_limits'])} |")
        summary += ['']
    summary += ['Vínculos completos por ID: [DECISION_MAP.json](DECISION_MAP.json). Evidências originais: [perfis documentais](../2026-09-29-thematic-profiles/CATEGORY_MAP.md).']
    (ROOT / 'DECISION_MAP.md').write_text('\n'.join(summary) + '\n')

    lines = ['# Bloco 1 para sua validação — Economia e Desenvolvimento', '',
             '**Quatro afirmações em revisão. Nenhuma aprovada ou enviada à rodada dos treze planos.**', '',
             'Botões previstos: **Concordo · Discordo · Neutro · Pular**. A aprovação abrange a afirmação e sua explicação. As notas de origem e limites são material editorial, não texto de resposta do eleitor.', '',
             'Você pode aprovar, editar, pedir alternativa ou excluir cada item. Aprovar este bloco não aprova os demais temas nem uma fórmula de ranking. As origens abaixo indicam contextos a investigar, sem atribuir respostas a candidaturas.', '']
    for item in block['items']:
        lines += [f"## {item['id']} · versão {item['version']}", '', f"**{item['statement']}**", '',
                  f"**Explicação na tela:** {item['explanation']}", '', f"**O que mede:** {item['decision']}", '',
                  f"**Por que entrou nesta revisão:** {item['why_selected']}", '',
                  f"**Famílias do mapa:** {', '.join(item['decision_family_ids'])}.", '', '**Origem documental:**', '']
        for source in item['sources']:
            candidate, pid = source['position_key'].split(':')
            link = '../2026-09-29-thematic-profiles/profiles/' + candidate + '.md'
            lines.append(f"- [{source['candidate_name']} — {pid}]({link}), páginas {', '.join(map(str, source['pages']))} do PDF.")
        lines += ['', '**Limites a preservar:**', ''] + ['- ' + limit for limit in item['limits']]
        layers = item['semantic_layers']
        lines += ['', '**Diagnóstico, justificativa e decisão:**', '', layers['diagnosis_in_statement']]
        for justification in layers['explicit_justifications']:
            lines += ['', f"- {justification['paraphrase']} Origem: {justification['position_key']}, p. {justification['page']}."]
        lines += ['', layers['interpretation_limit']]
        lines += ['', '**Revisão da redação:**', ''] + ['- ' + change for change in item['editorial_changes']]
        lines += ['', '**Sua decisão:** pendente.', '']
    lines += ['## Assuntos reservados para outro recorte', '']
    lines += [f"- **{x['topic']}:** {x['reason']}" for x in block['deferred_topics']]
    (ROOT / 'BLOCK_01.md').write_text('\n'.join(lines) + '\n')

    state.update(phase='awaiting_user_review_block_01', updated_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
    state['first_block'].update(status='pending_user_review', target_items=len(block['items']), file='BLOCK_01.json')
    state['remaining'] = ['Receber decisões do usuário sobre as quatro versões do bloco B01.',
                          'Ajustes de significado exigem nova validação do usuário.',
                          'Preparar outros blocos e, somente após aprovação das versões, conferir as perguntas com os treze responsáveis originais.']
    state['metrics'] = {'mapped_positions': len(mapped), 'decision_families': len(families), 'categories': len(taxonomy),
                        'questions_presented': len(block['items']), 'questions_approved': 0, 'candidate_answers_created': 0}
    write(ROOT / 'STATE.json', state)
    center = ['# Documento central — mapa, redação e validação humana', '',
              '**Etapa atual: aguardando a validação do usuário para o bloco 1.**', '',
              f"Inventário preservado: 636 registros. Mapa: {len(families)} famílias nas dez categorias. Primeiro bloco: quatro afirmações, todas pendentes de aprovação.", '',
              '1. Extração: concluída na [etapa anterior](../2026-09-29-thematic-profiles/FINAL_REPORT.md).',
              '2. Mapa comum: [organização documental](DECISION_MAP.md) e [vínculos por ID](DECISION_MAP.json).',
              '3–4. Redação e revisão: primeiro bloco preparado; demais blocos ainda serão preparados.',
              '5. Aprovação humana: [bloco para leitura](BLOCK_01.md) e [versões estruturadas](BLOCK_01.json). Nenhuma aprovação registrada.',
              '6. Confronto com treze planos: não iniciado para essas redações.',
              '7–9. Consolidação das respostas, seleção/teste da bateria e ranking: posteriores à validação documental.', '',
              'Os três agentes reutilizados nesta rodada organizaram os registros existentes em tarefas editoriais. Não receberam a bateria para atribuir respostas aos planos. A rodada dos treze revisores está condicionada à aprovação do usuário.', '',
              'Regras completas: [protocolo](PROTOCOL.md). Estado persistente: [STATE.json](STATE.json). Evidências da conferência: [validation.json](validation.json).', '',
              '## Retomada', '',
              'Ler primeiro as decisões do usuário, registrar aprovação por ID e versão junto ao texto e explicação. Nunca converter silêncio em aprovação. Versões editadas voltam à validação humana quando seu significado muda. Permanecem os quatro botões, a exclusão de Pablo Marçal e a preservação dos perfis anteriores e da produção.']
    (ROOT / 'ORCHESTRATION.md').write_text('\n'.join(center) + '\n')
    checks = {'valid': True, **state['metrics'], 'source_inventory_sha256': checksum(inventory_path),
              'block_sha256': checksum(ROOT / 'BLOCK_01.json'),
              'same_prior_agents_used_for_mapping': True, 'candidate_validation_dispatched': False,
              'note': 'Checks IDs, complete inventory mapping, source pages and the pending approval state. Does not establish semantic equivalence or validity of a ranking.'}
    write(ROOT / 'validation.json', checks)
    print(json.dumps(checks, ensure_ascii=False))


if __name__ == '__main__':
    main()
