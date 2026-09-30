#!/usr/bin/env python3
"""Index profiles without automatically inferring cross-candidate agreement."""
import collections
import hashlib
import json
from pathlib import Path

P = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text())


def main():
    state = read(P / 'STATE.json')
    taxonomy = read(P / 'taxonomy.json')['categories']
    validation = read(P / 'validation.json') if (P / 'validation.json').exists() else {'profiles': []}
    checks = {p['candidate_id']: p for p in validation['profiles']}
    editorial = read(P / 'EDITORIAL_REVIEW.json') if (P / 'EDITORIAL_REVIEW.json').exists() else {'reviews': []}
    reviews = {r['candidate_id']: r for r in editorial['reviews']}
    profiles, positions, seeds, tensions, pending, errors = [], [], [], [], [], []
    for c in state['candidates']:
        file = P / 'profiles' / (c['id'] + '.json')
        if not file.exists():
            pending.append(c['id'])
            continue
        r = read(file)
        if r.get('status') != 'complete':
            pending.append(c['id'])
            continue
        checksum = hashlib.sha256(file.read_bytes()).hexdigest()
        checked = checks.get(c['id'], {})
        valid = checked.get('valid') and checked.get('profile_sha256') == checksum
        markdown = file.with_suffix('.md')
        valid = valid and markdown.exists() and checked.get('markdown_sha256') == hashlib.sha256(markdown.read_bytes()).hexdigest()
        if not valid:
            errors.append(c['id'] + ': current profile has not passed validation')
        if c['status'] != 'validated':
            errors.append(c['id'] + ': pending editorial review')
        review = reviews.get(c['id'], {})
        if review.get('editorial_review') != 'accepted' or review.get('profile_sha256') != checksum:
            errors.append(c['id'] + ': editorial record missing or stale')
        profiles.append({'candidate_id': c['id'], 'name': c['name'], 'agent_id': c['agent_id'],
                         'source_profile': 'profiles/' + file.name, 'profile_sha256': checksum,
                         'source_document_sha256': c['sha256'], 'overview': r['overview'],
                         'categories': r['categories'], 'positions': len(r['positions']),
                         'thesis_seeds': len(r['thesis_seeds']), 'limitations': r['limitations']})
        for position in r['positions']:
            positions.append({'candidate_id': c['id'], 'candidate_name': c['name'],
                              'position_key': c['id'] + ':' + position['id'],
                              'source_profile': 'profiles/' + file.name, **position})
        for seed in r['thesis_seeds']:
            seeds.append({'candidate_id': c['id'], 'candidate_name': c['name'],
                          'seed_key': c['id'] + ':' + seed['id'],
                          'source_profile': 'profiles/' + file.name,
                          'position_keys': [c['id'] + ':' + i for i in seed['position_ids']], **seed})
        for tension in r['tensions']:
            tensions.append({'candidate_id': c['id'], 'candidate_name': c['name'],
                             'position_keys': [c['id'] + ':' + i for i in tension['position_ids']], **tension})
    category_map = []
    for category in taxonomy:
        entries = []
        for profile in profiles:
            row = next(cat for cat in profile['categories'] if cat['id'] == category['id'])
            entries.append({'candidate_id': profile['candidate_id'], 'name': profile['name'],
                            **row, 'position_keys': [profile['candidate_id'] + ':' + i for i in row['position_ids']]})
        category_map.append({**category, 'profiles': entries,
                             'presence_counts': dict(collections.Counter(x['presence'] for x in entries)),
                             'selected_positions': sum(len(x['position_ids']) for x in entries)})
    complete = len(profiles) == 13 and not pending and not errors
    data = {'schema_version': 1, 'complete': complete, 'pending_profiles': pending, 'errors': errors,
            'profiles': profiles, 'positions': positions, 'category_map': category_map,
            'thesis_seeds': seeds, 'tensions': tensions,
            'method_note': 'Executive documentary profiles using the SAME prior reviewers. Position counts are selection counts, not importance, quality, affinity or exhaustive program inventories. Seeds are NOT a validated questionnaire; absence in a summary does not establish absence in the PDF.'}
    (P / 'DOCUMENT_INDEX.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    lines = ['# Mapa dos perfis por categoria', '',
             ('**Consolidação documental concluída.**' if complete else '**Consolidação parcial; existem entregas ou conferências pendentes.**'), '',
             'Os números descrevem o material selecionado nos perfis. Não medem qualidade do programa, afinidade, prioridade temática ou cobertura de uma pergunta específica. As escolhas e citações estão em [DOCUMENT_INDEX.json](DOCUMENT_INDEX.json); os limites de síntese, no [protocolo](PROTOCOL.md).', '',
             '| Categoria | Planos com decisões concretas | Apenas objetivos gerais | Sem posição temática selecionada | Posições selecionadas |',
             '|---|---:|---:|---:|---:|']
    for cat in category_map:
        counts = cat['presence_counts']
        lines.append(f"| {cat['name']} | {counts.get('substantive', 0)} | {counts.get('general_only', 0)} | {counts.get('not_addressed', 0)} | {cat['selected_positions']} |")
    lines += ['', '## Perfis individuais', '', '| Candidatura | Categorias com decisões concretas | Posições selecionadas | Sementes de teses |', '|---|---:|---:|---:|']
    for profile in sorted(profiles, key=lambda p: p['name'].casefold()):
        substantive = sum(c['presence'] == 'substantive' for c in profile['categories'])
        lines.append(f"| [{profile['name']}](profiles/{profile['candidate_id']}.md) | {substantive} | {profile['positions']} | {profile['thesis_seeds']} |")
    lines += ['', 'A comparação de uma tese nova deve voltar aos trechos originais e conferir os mesmos instrumentos, quantificadores e condições em todos os planos. As sementes não têm cobertura entre candidaturas presumida.', '']
    (P / 'CATEGORY_MAP.md').write_text('\n'.join(lines))
    print(json.dumps({'complete': complete, 'profiles': len(profiles), 'positions': len(positions),
                      'thesis_seeds': len(seeds), 'pending': len(pending), 'errors': len(errors)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
