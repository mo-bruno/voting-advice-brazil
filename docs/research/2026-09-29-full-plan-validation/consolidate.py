#!/usr/bin/env python3
"""Build a traceable matrix from independent reports and explicit adjudications.

Never edits the frozen questions, source reviews or production dataset.
"""
import collections,itertools,json
from pathlib import Path
P=Path(__file__).resolve().parent
CAT={'CONCORDA','DISCORDA'}
def read(p):return json.loads(p.read_text())
def main():
 state=read(P/'STATE.json');questions=read(P/'questions.json')['questions'];cs=state['candidates'];adjudications=read(P/'ADJUDICATIONS.json') if (P/'ADJUDICATIONS.json').exists() else {'decisions':[]};ds={(d['candidate_id'],d['question_id']):d for d in adjudications['decisions']};validation=read(P/'validation.json') if (P/'validation.json').exists() else {};valids={r['candidate_id']:r['valid'] for r in validation.get('reviews',[])}
 matrix=[];pending=[];unresolved=[]
 for c in cs:
  file=P/'reviews'/(c['id']+'.json')
  if not file.exists():pending.append(c['id']);continue
  r=read(file)
  for row in r['positions']:
   decision=ds.get((c['id'],row['question_id']));divergent=row['comparison']=='divergent';resolved=decision is not None and decision.get('status')=='resolved'
   if divergent and not resolved:unresolved.append({'candidate_id':c['id'],'question_id':row['question_id']})
   category=decision['final_category'] if resolved else row['category']
   matrix.append({'candidate_id':c['id'],'name':c['name'],'question_id':row['question_id'],'question_text_sha256':row['question_text_sha256'],'prior_category':row['prior_category'],'reviewer_category':row['category'],'final_category':category,'decision_status':'adjudicated' if resolved else 'pending_adjudication' if divergent else 'confirmed_by_reviewer' if row['comparison']=='confirmed' else 'new_document_review','source_review':str(file.relative_to(P)),'evidence':decision.get('evidence',row['evidence']) if resolved else row['evidence'],'reason':decision.get('reason',row['reason']) if resolved else row['reason'],'in_prior_product_roster':c['in_prior_product_roster']})
 bycandidate=[]
 for c in cs:
  rows=[r for r in matrix if r['candidate_id']==c['id']];bycandidate.append({'id':c['id'],'name':c['name'],'in_prior_product_roster':c['in_prior_product_roster'],'review_present':bool(rows),'literal_validation_passed':valids.get(c['id'],False),'prior_categorical':sum(r['prior_category'] in CAT for r in rows) if c['in_prior_product_roster'] else None,'reviewer_categorical':sum(r['reviewer_category'] in CAT for r in rows),'final_categorical':sum(r['final_category'] in CAT for r in rows),'confirmed':sum(r['prior_category']==r['reviewer_category'] for r in rows),'divergent':sum(r['prior_category'] is not None and r['prior_category']!=r['reviewer_category'] for r in rows)})
 byquestion=[]
 for q in questions:
  rows=[r for r in matrix if r['question_id']==q['id'] and r['in_prior_product_roster']];counts=collections.Counter(r['final_category'] for r in rows);byquestion.append({'id':q['id'],'text':q['text'],'reviewed_current_plans':len(rows),'prior_categorical':sum(r['prior_category'] in CAT for r in rows),'final_categorical':sum(r['final_category'] in CAT for r in rows),'counts':dict(counts),'both_poles':counts['CONCORDA']>0 and counts['DISCORDA']>0})
 current=[c['id'] for c in cs if c['in_prior_product_roster']];lookup={(r['candidate_id'],r['question_id']):r['final_category'] for r in matrix};pairs=[]
 for a,b in itertools.combinations(current,2):
  common=[q['id'] for q in questions if lookup.get((a,q['id'])) in CAT and lookup.get((b,q['id'])) in CAT];pairs.append({'candidate_ids':[a,b],'comparable_questions':common,'opposing_questions':[tid for tid in common if lookup[a,tid]!=lookup[b,tid]]})
 complete=not pending and not unresolved and all(valids.get(c['id']) and c['status']=='validated' for c in cs)
 output={'schema_version':1,'complete':complete,'pending_plans':pending,'unresolved_divergences':unresolved,'matrix':matrix,'by_candidate':bycandidate,'by_question':byquestion,'current_candidate_pairs':pairs,'scope':'Frozen16 draft questions. Historical extra plan excluded from current13 aggregate counts. No production changes.','method_note':'Final category is provisional until all deliveries, validations and adjudications are complete.'}
 (P/'CONSOLIDATION.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'complete':complete,'received_plans':len(cs)-len(pending),'matrix_cells':len(matrix),'unresolved_divergences':len(unresolved)},ensure_ascii=False))
if __name__=='__main__':main()
