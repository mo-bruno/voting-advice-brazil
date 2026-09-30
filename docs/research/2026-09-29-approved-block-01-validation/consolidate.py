#!/usr/bin/env python3
"""Consolidate mechanically valid and individually adjudicated original reviews."""
import collections
import hashlib
import json
from pathlib import Path
P=Path(__file__).resolve().parent
LABELS={'CONCORDA':'Concorda','DISCORDA':'Discorda','CONDICIONAL_OU_MISTA':'Condicional/mista','NAO_ENCONTRADA':'Sem posição suficiente'}
def read(p): return json.loads(p.read_text())
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d): p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def main():
 s=read(P/'STATE.json'); v=read(P/'validation.json'); editorial=read(P/'EDITORIAL_REVIEW.json'); adjustments=read(P/'ADJUDICATIONS.json'); qs=read(P/'questions.json')
 assert v['valid'] and v['valid_reviews']==13 and v['answers']==52
 assert editorial['status']=='complete' and editorial['reviewer']=='/root'
 reviewed={r['candidate_id']:r for r in editorial['reviewed_candidates']}
 valid={r['candidate_id']:r for r in v['results']}
 overrides={(a['candidate_id'],a['question_id']):a for a in adjustments['entries']}
 answers=[]
 for c in s['candidates']:
  f=P/c['review_file']; h=digest(f)
  assert h==reviewed[c['id']]['review_sha256']==valid[c['id']]['review_sha256']
  r=read(f)
  for a in r['answers']:
   adjustment=overrides.get((c['id'],a['question_id']))
   final=adjustment['final_classification'] if adjustment else a['classification']
   assert final in LABELS
   if adjustment: assert adjustment['original_classification']==a['classification'] and adjustment['reason']
   answers.append({'candidate_id':c['id'],'candidate_name':c['name'],'question_id':a['question_id'],'question_version':a['question_version'],'wording_sha256':a['wording_sha256'],'agent_classification':a['classification'],'final_classification':final,'original_review':c['review_file'],'rationale':adjustment['reason'] if adjustment else a['rationale'],'conditions':a['conditions'],'evidence':a['evidence'],'adjudication':adjustment})
 coverage=[]
 for q in qs['items']:
  counts=collections.Counter(a['final_classification'] for a in answers if a['question_id']==q['id'])
  coverage.append({'question_id':q['id'],'counts':{k:counts[k] for k in LABELS},'categorical_positions':counts['CONCORDA']+counts['DISCORDA'],'has_documented_opposing_categories':bool(counts['CONCORDA'] and counts['DISCORDA']),'conditions_are_not_categorical':True})
 write(P/'CONSOLIDATION.json',{'schema_version':1,'questions_sha256':digest(P/'questions.json'),'candidate_count':13,'answer_count':len(answers),'coverage':coverage,'answers':answers,'meaning_changes_applied':False,'production_changes':False})
 lines=['# Matriz final — B01 v1','','Posições atribuídas exclusivamente aos planos. Ausência documental não significa neutralidade nem rejeição.','', '| Plano | Q01: grandes fortunas | Q02: crédito industrial | Q03: extração/estrangeiras | Q04: dívida/auditoria |','|---|---|---|---|---|']
 for c in s['candidates']:
  row=[c['name']]+[LABELS[next(a for a in answers if a['candidate_id']==c['id'] and a['question_id']==q['id'])['final_classification']] for q in qs['items']]
  lines.append('| '+' | '.join(row)+' |')
 lines+=['','## Cobertura documental','','| Tese | Concorda | Discorda | Condicional/mista | Sem posição suficiente |','|---|---:|---:|---:|---:|']
 for q in coverage: lines.append('| '+q['question_id']+' | '+' | '.join(str(q['counts'][k]) for k in LABELS)+' |')
 lines+=['','As contagens não são pontuações de afinidade. Um item sem oposição explícita ainda pode conter propostas distintas, mas esta rodada não o demonstrou como contraste binário. Condições e trechos estão em [CONSOLIDATION.json](CONSOLIDATION.json) e nos relatórios individuais.','']
 (P/'MATRIX.md').write_text('\n'.join(lines))
 print(json.dumps(coverage,ensure_ascii=False,indent=2))
if __name__=='__main__': main()
