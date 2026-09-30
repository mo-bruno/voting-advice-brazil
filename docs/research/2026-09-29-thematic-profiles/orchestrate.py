#!/usr/bin/env python3
"""Maintain the thematic-profile phase, reusing the previous exclusive agents."""
import argparse
import datetime
import json
from pathlib import Path

P = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text())


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--status', nargs=2, action='append', default=[], metavar=('CANDIDATE_ID', 'STATUS'))
    args = ap.parse_args()
    state = read(P / 'STATE.json')
    previous = read(P.parent / '2026-09-29-full-plan-validation/STATE.json')
    original_agents = {c['id']: c['agent_id'] for c in previous['candidates']}
    updates = dict(args.status)
    assert set(updates) <= set(original_agents), 'Unknown candidate'
    assert set(updates.values()) <= {'queued', 'working', 'submitted', 'validated', 'needs_followup'}, 'Unknown status'
    for c in state['candidates']:
        assert c['agent_id'] == original_agents[c['id']], 'Do not replace the original agent'
        if c['id'] in updates:
            c['status'] = updates[c['id']]
        checkpoint = P / 'profiles' / (c['id'] + '.checkpoint.json')
        if checkpoint.exists():
            try:
                data = read(checkpoint)
                c['checkpoint_present'] = True
                c['revisited_pages'] = len(set(data.get('revisited_pages', [])))
            except (ValueError, TypeError):
                pass
        file = P / 'profiles' / (c['id'] + '.json')
        if file.exists():
            try:
                profile = read(file)
                c['profile_categories'] = len(profile.get('categories', []))
                c['positions'] = len(profile.get('positions', []))
                c['thesis_seeds'] = len(profile.get('thesis_seeds', []))
                c['profile_file'] = 'profiles/' + file.name
                if profile.get('status') == 'complete' and c['status'] not in ['validated', 'needs_followup']:
                    c['status'] = 'submitted'
            except ValueError:
                pass
    state['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    (P / 'STATE.json').write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')
    submitted = sum(c['status'] in ['submitted', 'validated'] for c in state['candidates'])
    validated = sum(c['status'] == 'validated' for c in state['candidates'])
    labels = {'queued': 'Na fila', 'working': 'Mesmo agente em atividade', 'submitted': 'Entregue; em conferência', 'validated': 'Conferido', 'needs_followup': 'Retorno ao mesmo agente'}
    lines = ['# Documento central — perfis nas dez categorias', '',
             f"Atualizado: {state['updated_at']}. **{submitted}/13 perfis entregues; {validated} conferidos.**", '',
             'Continuação da [auditoria integral](../2026-09-29-full-plan-validation/FINAL_REPORT.md). Os mesmos 13 agentes reutilizam contexto e diários das 836 páginas já lidas; esta rodada faz síntese temática e novas conferências contextuais. Não se declara outra leitura integral. Pablo permanece excluído.', '',
             'Referências: [estado persistente](STATE.json), [taxonomia do usuário](taxonomy.json), [protocolo](PROTOCOL.md). Os perfis descrevem posições documentadas; não são notas de afinidade ou rótulos ideológicos inferidos.', '',
             '| Plano | Mesmo responsável | Estado | Categorias | Posições | Sementes de teses |',
             '|---|---|---|---:|---:|---:|']
    for c in state['candidates']:
        name = f"[{c['name']}](profiles/{c['id']}.md)" if (P / 'profiles' / (c['id'] + '.md')).exists() else c['name']
        lines.append(f"| {name} | {c['agent_id']} | {labels.get(c['status'], c['status'])} | {c['profile_categories']} | {c['positions']} | {c['thesis_seeds']} |")
    lines += ['', '## Decisões', '']
    lines += [f"- **{d['id']}:** {d['decision']}" for d in state['decisions']]
    if state.get('adjudications'):
        lines += ['', '## Ajustes editoriais', '']
        lines += [f"- **{d['id']} — {d['candidate_id']} / {d['position_id']}:** {d['change']}" for d in state['adjudications']]
    lines += ['', '## Retomada', '',
              '1. Ler este arquivo e STATE.json; manter os responsáveis originais.',
              '2. Retomar com followup_task o próximo agente já existente, no máximo três simultâneos. Não criar substitutos nem recomeçar leituras integrais sem motivo.',
              '3. Conferir dez categorias, posições, literalidade, limites e sugestões; validador não substitui interpretação.',
              '4. Consolidar escolhas equivalentes entre planos, preservando divergências e lacunas.',
              '5. Sementes de tese são hipóteses; não afirmar cobertura de uma redação sem conferir a mesma decisão em todos os planos.',
              '6. Não modificar produção, a auditoria encerrada, textos de perguntas ou respostas históricas.']
    if state.get('phase') == 'profiles_complete':
        lines += ['', '## Entrega desta etapa', '',
                  'Os treze perfis foram entregues pelos responsáveis originais e conferidos. A síntese está no [relatório final](FINAL_REPORT.md); a navegação por candidatura e tema, no [mapa de categorias](CATEGORY_MAP.md).', '',
                  'A [agenda de teses](AGENDA_TESES.md) e o [método da próxima matriz](THESIS_DESIGN.md) registram o trabalho posterior. As hipóteses ainda não formam um questionário validado. Não há pendência na entrega dos perfis; a etapa seguinte tem seus próprios critérios de conclusão.', '',
                  'A continuação está no [documento central da revisão editorial](../2026-09-29-question-editorial-review/ORCHESTRATION.md). O usuário validará cada redação e explicação antes de seu envio aos treze revisores.']
    (P / 'ORCHESTRATION.md').write_text('\n'.join(lines) + '\n')
    print(json.dumps({'submitted': submitted, 'validated': validated,
                      'working': [c['name'] for c in state['candidates'] if c['status'] == 'working']}, ensure_ascii=False))


if __name__ == '__main__':
    main()
