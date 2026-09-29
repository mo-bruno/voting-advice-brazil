#!/usr/bin/env python3
"""Check submitted plan reviews: provenance, page ledger, questions and literal evidence.

This verifies artifacts and declared reading coverage, not human approval or the
truth of a political interpretation. Run without --candidate for the whole set.
"""
import argparse,collections,hashlib,json,subprocess,tempfile,zipfile
from pathlib import Path
P=Path(__file__).resolve().parent
CATEGORIES={'CONCORDA','DISCORDA','CONDICIONAL_OU_MISTA','NEUTRO_EXPLICITO','NAO_ENCONTRADA'}

def read(p):return json.loads(p.read_text())
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def norm(t):return ' '.join(t.split())
def variants(t):
 lines=t.splitlines();return [norm(t),norm('\n'.join(x for i,x in enumerate(lines) if not i or x!=lines[i-1]))]
def extract_archive(archive,directory,candidates):
 # ZIP metadata can change; the frozen hashes of each actual PDF are decisive.
 with zipfile.ZipFile(archive) as z:
  for c in candidates:
   data=z.read(c['member'])
   if hashlib.sha256(data).hexdigest()!=c['sha256']:raise ValueError('Changed PDF snapshot: '+c['id'])
   folder=directory/c['id'];folder.mkdir();pdf=folder/'plan.pdf';pdf.write_bytes(data)
   for mode in ['layout','raw']:
    target=folder/(mode+'.txt');subprocess.run(['pdftotext','-'+mode,str(pdf),str(target)],check=True,capture_output=True)
    pages=target.read_text().split('\f')
    if not pages[-1].strip():pages.pop()
    if len(pages)!=c['pages']:raise ValueError('Unexpected page count: '+c['id'])
    (folder/(mode+'-pages.json')).write_text(json.dumps(pages,ensure_ascii=False))
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--candidate');ap.add_argument('--allow-pending',action='store_true');source=ap.add_mutually_exclusive_group();source.add_argument('--archive',type=Path);source.add_argument('--corpus',type=Path);args=ap.parse_args()
 manifest=read(P/'source-manifest.json');questions=read(P/'questions.json');qs={q['id']:q for q in questions['questions']};question_sha=digest(P/'questions.json');state=read(P/'STATE.json');agents={c['id']:c['agent_id'] for c in state['candidates']};cs=[c for c in manifest['candidates'] if c['id'] in agents];results=[]
 if args.candidate:cs=[c for c in cs if c['id']==args.candidate];assert cs,'Unknown candidate'
 temp=tempfile.TemporaryDirectory(prefix='farol-full-validation-') if args.archive else None
 corpus=Path(temp.name) if temp else args.corpus
 if args.archive:extract_archive(args.archive,corpus,cs)
 for c in cs:
  cid=c['id'];file=P/'reviews'/(cid+'.json');errors=[];matches=collections.Counter()
  if not file.exists():
   results.append({'candidate_id':cid,'name':c['name'],'status':'pending','valid':False,'errors':[]});continue
  try:r=read(file)
  except (ValueError,TypeError) as e:
   results.append({'candidate_id':cid,'name':c['name'],'status':'invalid_json','valid':False,'errors':[str(e)]});continue
  def check(ok,why):
   if not ok:errors.append(why)
  check(r.get('schema_version')==1,'schema_version');check(r.get('candidate_id')==cid,'candidate_id');check(r.get('document_sha256')==c['sha256'],'document_sha256');check(r.get('question_set_sha256')==question_sha,'question_set_sha256');check(r.get('model_requested')=='gpt-6-astra','model_requested');check(r.get('reasoning_effort_requested')=='ultra','reasoning_effort_requested')
  check(bool(agents.get(cid)),'No exclusive agent registered');check(r.get('status')=='complete','status not complete');check(r.get('full_read_completed') is True,'full_read_completed');check(r.get('pages_total')==c['pages'],'pages_total')
  expected=list(range(1,c['pages']+1));read_pages=r.get('pages_read',[]);check(sorted(read_pages)==expected,'pages_read must include every physical page exactly once')
  ledger=r.get('reading_log',[]);check(sorted(x.get('page',0) for x in ledger)==expected,'reading_log must cover every page exactly once')
  for entry in ledger:
   check(bool(entry.get('summary','').strip()),f"Empty page summary: {entry.get('page')}");check(set(entry.get('relevant_question_ids',[]))<=set(qs),f"Unexpected question in ledger page{entry.get('page')}")
  folder=corpus/cid if corpus else Path(c['corpus_directory']);check(digest(folder/'plan.pdf')==c['sha256'],'PDF bytes mismatch')
  pages={mode:read(folder/(mode+'-pages.json')) for mode in ['layout','raw']};check(all(len(x)==c['pages'] for x in pages.values()),'Extraction page count')
  prior={x['question_id']:x.get('category') for x in read(P/'inputs'/(cid+'.json'))['prior_positions']}
  rows=r.get('positions',[]);check(len(rows)==len(qs) and {x.get('question_id') for x in rows}==set(qs),'Exactly16 frozen questions required')
  for x in rows:
   tid=x.get('question_id');key=cid+'/'+str(tid)
   if tid not in qs:continue
   check(x.get('question_text_sha256')==qs[tid]['text_sha256'],key+': wording hash')
   check(x.get('prior_category')==prior[tid],key+': altered prior');check(x.get('category') in CATEGORIES,key+': invalid category')
   comparison='no_prior' if prior[tid] is None else 'confirmed' if prior[tid]==x.get('category') else 'divergent';check(x.get('comparison')==comparison,key+': comparison')
   check(bool(x.get('reason','').strip()),key+': empty reason');ev=x.get('evidence',[]);check(x.get('category')=='NAO_ENCONTRADA' or bool(ev),key+': substantive without evidence')
   cp=x.get('context_pages',[]);check(bool(cp),key+': no contextual pages');check(set(cp)<=set(expected),key+': invalid context page')
   for e in ev:
    n=e.get('page');quote=norm(e.get('quote',''));check(n in cp,key+': evidence page absent from context_pages')
    if n not in expected:errors.append(key+': invalid quote page');continue
    options=[v for mode in ['layout','raw'] for v in variants(pages[mode][n-1])];found=next((i for i,p in enumerate(options) if quote and quote in p),None)
    if found is None:errors.append(key+f': quotation not found p{n}: '+quote)
    else:matches[['layout','layout_dedup','raw','raw_dedup'][found]]+=1
   suggestion=x.get('reformulation_suggestion')
   if suggestion is not None:
    check(isinstance(suggestion,dict),key+': suggestion object')
    if isinstance(suggestion,dict):check(bool(suggestion.get('text')) and bool(suggestion.get('reason')) and suggestion.get('requires_cross_plan_revalidation') is True,key+': incomplete suggestion')
  for v in r.get('visual_checks',[]):check(v.get('page') in expected and bool(v.get('finding')) and bool(v.get('reason')),cid+': invalid visual check')
  results.append({'candidate_id':cid,'name':c['name'],'status':'submitted','valid':not errors,'errors':errors,'pages':c['pages'],'pages_logged':len(read_pages),'questions':len(rows),'comparisons':dict(collections.Counter(x.get('comparison') for x in rows)),'categories':dict(collections.Counter(x.get('category') for x in rows)),'quote_matches':dict(matches),'visual_check_count':len(r.get('visual_checks',[])),'review_sha256':digest(file)})
 pending=sum(x['status']=='pending' for x in results);invalid=sum(x['status']!='pending' and not x['valid'] for x in results);summary={'schema_version':1,'question_set_sha256':question_sha,'plan_count':len(results),'pending':pending,'invalid_submissions':invalid,'complete_and_valid':pending==0 and invalid==0,'reviews':results,'caveat':'Checks declared page coverage and literal evidence, not semantic correctness, human reading or approval.'}
 output=P/('validation-'+args.candidate+'.json' if args.candidate else 'validation.json');output.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'plans':len(results),'pending':pending,'invalid_submissions':invalid,'valid_submissions':sum(x['valid'] for x in results)},ensure_ascii=False))
 for x in results:
  for error in x['errors']:print(error)
 if temp:temp.cleanup()
 raise SystemExit(1 if invalid or (pending and not args.allow_pending) else 0)
if __name__=='__main__':main()
