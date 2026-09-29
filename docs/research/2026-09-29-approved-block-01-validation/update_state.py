#!/usr/bin/env python3
"""Persist dispatch and receipt; semantic completion is set only by the orchestrator."""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
P=Path(__file__).resolve().parent

def read(p): return json.loads(p.read_text())
def write(p,d): p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--started',nargs='*',default=[]); ap.add_argument('--received',nargs='*',default=[]); args=ap.parse_args()
 s=read(P/'STATE.json'); now=datetime.now(timezone.utc).isoformat()
 for c in s['candidates']:
  if c['id'] in args.started: c.update(status='running',dispatched_at=now)
  if c['id'] in args.received:
   assert (P/c['review_file']).exists(); c.update(status='received',received_at=now)
 s['updated_at']=now; s['phase']='candidate_validation_in_progress'
 completed=sum(c['status'] in {'received','adjudicated'} for c in s['candidates']); s['metrics']['completed_reviews']=completed
 v=read(P/'validation.json') if (P/'validation.json').exists() else {'valid_reviews':0}
 s['metrics']['validated_answers']=4*v['valid_reviews']
 write(P/'STATE.json',s)
 rows=['# Documento central — validação do bloco aprovado B01','',f'Quatro teses v1 aprovadas; {completed}/13 entregas recebidas. Cada responsável conserva seu plano e contexto originais. Pablo Marçal excluído.','', '[Aprovação](APPROVAL.json) · [Perguntas imutáveis](questions.json) · [Protocolo](PROTOCOL.md) · [Estado](STATE.json) · [Conferência mecânica](validation.json).','','| Plano | Agente original | Estado |','|---|---|---|']
 for c in s['candidates']: rows.append(f"| {c['name']} | `{c['agent_id']}` | {c['status']} |")
 rows+=['','A conferência mecânica de citações não substitui a adjudicação semântica. Alterações de significado exigem nova aprovação do usuário. Nenhuma alteração de ranking ou produção.','']
 (P/'ORCHESTRATION.md').write_text('\n'.join(rows))
 old=P.parent/'2026-09-29-question-editorial-review'; editorial=read(old/'STATE.json'); editorial['phase']='block_01_candidate_validation_in_progress'; editorial['updated_at']=now; editorial['approval_gate']['candidate_validation_dispatched']=True; editorial['first_block']['status']='approved_in_documentary_validation'; editorial['metrics']['candidate_answers_created']=completed*4; write(old/'STATE.json',editorial)
 block=read(old/'BLOCK_01.json'); block['candidate_validation_dispatched']=True; write(old/'BLOCK_01.json',block)
 print(f'{completed}/13 received; {v["valid_reviews"]}/13 mechanically valid')
if __name__=='__main__': main()
