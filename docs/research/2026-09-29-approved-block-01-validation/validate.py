#!/usr/bin/env python3
"""Check the approved wording, original agent, official PDF and literal citations."""
import argparse
import collections
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile

P = Path(__file__).resolve().parent
OLD = P.parent / '2026-09-29-full-plan-validation'

def read(p): return json.loads(p.read_text())
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def norm(s): return ' '.join(s.split())
def variants(s):
    lines=s.splitlines()
    return [norm(s), norm('\n'.join(x for i,x in enumerate(lines) if not i or x != lines[i-1]))]

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--allow-pending',action='store_true')
    ap.add_argument('--archive',type=Path)
    args=ap.parse_args()
    state=read(P/'STATE.json'); qs=read(P/'questions.json'); approval=read(P/'APPROVAL.json')
    assert len(qs['items'])==4
    assert digest(P/'questions.json')==approval['questions_sha256']
    approved={q['id']:q for q in approval['approved_question_versions']}
    for q in qs['items']:
        payload={k:q[k] for k in ['id','version','statement','explanation']}
        payload['response_buttons']=qs['response_buttons']
        h=hashlib.sha256(json.dumps(payload,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
        assert h==q['wording_sha256']==approved[q['id']]['wording_sha256'],q['id']
    candidates=state['candidates']; assert len(candidates)==13
    assert '280002553884' not in {c['id'] for c in candidates}
    original={c['id']:c for c in read(OLD/'STATE.json')['candidates']}
    temporary=tempfile.TemporaryDirectory(prefix='feixe-b01-validation-') if args.archive else None
    if args.archive:
        spec=importlib.util.spec_from_file_location('profile_validation',P.parent/'2026-09-29-thematic-profiles/validate.py')
        module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        module.extract_archive(args.archive,Path(temporary.name),candidates)
    results=[]
    for c in candidates:
        f=P/c['review_file']
        if not f.exists(): results.append({'candidate_id':c['id'],'status':'pending','errors':[]}); continue
        r=read(f); errors=[]; quotes=0; counts=collections.Counter()
        def check(ok,message):
            if not ok: errors.append(message)
        corpus=Path(temporary.name)/c['id'] if temporary else Path(c['corpus_directory'])
        check(digest(corpus/'plan.pdf')==c['sha256']==r.get('document_sha256'),'Official PDF hash')
        check(r.get('candidate_id')==c['id'] and r.get('candidate_name')==c['name'],'Candidate identity')
        check(r.get('agent_id')==c['agent_id']==original[c['id']]['agent_id'],'Same original agent')
        check(r.get('schema_version')==1,'Schema version')
        check(r.get('questions_sha256')==approval['questions_sha256'],'Questions file hash')
        prior=read(OLD/'reviews'/f"{c['id']}.json")
        check(prior['full_read_completed'] and set(prior['pages_read'])==set(range(1,c['pages']+1)),'Prior full read')
        check(r.get('full_text_search_completed') is True,'Full text search')
        check(bool(r.get('method')) and bool(r.get('prior_full_read')),'Method and prior reference')
        revisited=r.get('revisited_pages',[])
        check(all(isinstance(x,int) and 1<=x<=c['pages'] for x in revisited),'Revisited pages')
        pages={mode:read(corpus/(mode+'-pages.json')) for mode in ['layout','raw']}
        check(all(len(p)==c['pages'] for p in pages.values()),'Physical page count')
        answers=r.get('answers',[])
        check([a.get('question_id') for a in answers]==[q['id'] for q in qs['items']],'Exactly four ordered answers')
        for a,q in zip(answers,qs['items']):
            prefix=q['id']+': '
            code=a.get('classification'); counts[code]+=1
            check(code in {'CONCORDA','DISCORDA','CONDICIONAL_OU_MISTA','NAO_ENCONTRADA'},prefix+'Classification')
            check(a.get('question_version')==q['version'] and a.get('wording_sha256')==q['wording_sha256'],prefix+'Wording version')
            check(a.get('evidence_strength') in {'explicit','clear_implication','mixed','insufficient'},prefix+'Strength')
            check(bool(a.get('rationale')) and bool(a.get('search_terms')) and 'counterevidence_or_limits' in a,prefix+'Reason/search/limits')
            check(isinstance(a.get('conditions'),list),prefix+'Conditions')
            searched=set()
            for start,end in a.get('searched_page_ranges',[]):
                check(1<=start<=end<=c['pages'],prefix+'Search range')
                searched.update(range(start,end+1))
            check(searched==set(range(1,c['pages']+1)),prefix+'Full document search range')
            evidence=a.get('evidence',[])
            check(code=='NAO_ENCONTRADA' or bool(evidence),prefix+'Evidence required')
            if code=='NAO_ENCONTRADA': check(a.get('evidence_strength')=='insufficient',prefix+'Missing evidence strength')
            for e in evidence:
                page=e.get('page'); quotes+=1
                check(isinstance(page,int) and 1<=page<=c['pages'],prefix+'Evidence page')
                check(page in revisited,prefix+'Quote page revisited')
                check(e.get('role') in {'support','opposition','condition','context','counterevidence'},prefix+'Evidence role')
                check(bool(e.get('interpretation')),prefix+'Interpretation')
                if isinstance(page,int) and 1<=page<=c['pages']:
                    quote=norm(e.get('quote',''))
                    matched=bool(quote) and any(quote in v for mode in pages for v in variants(pages[mode][page-1]))
                    check(matched,prefix+f'Literal quote mismatch page {page}: '+e.get('quote','')[:90])
            suggestion=a.get('reformulation_suggestion')
            check(suggestion is None or isinstance(suggestion,dict) and suggestion.get('meaning_change') is True,prefix+'Separate meaning change')
        check(f.with_suffix('.md').exists(),'Readable report')
        results.append({'candidate_id':c['id'],'status':'valid' if not errors else 'invalid','errors':errors,'answers':len(answers),'quotes':quotes,'counts':dict(counts),'review_sha256':digest(f),'markdown_sha256':digest(f.with_suffix('.md')) if f.with_suffix('.md').exists() else None})
    report={'schema_version':1,'approved_questions':4,'questions_sha256':approval['questions_sha256'],'source_mode':'fresh_archive_extraction' if args.archive else 'cached_verified_pdf','archive_sha256':digest(args.archive) if args.archive else None,'completed_reviews':sum(r['status']!='pending' for r in results),'valid_reviews':sum(r['status']=='valid' for r in results),'answers':sum(r.get('answers',0) for r in results),'quote_occurrences':sum(r.get('quotes',0) for r in results),'valid':all(r['status']=='valid' for r in results),'results':results}
    (P/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='results'},ensure_ascii=False))
    for r in results:
        if r['errors']: print(r['candidate_id'],json.dumps(r['errors'],ensure_ascii=False))
    if any(r['status']=='invalid' for r in results) or not args.allow_pending and not report['valid']: raise SystemExit(1)

if __name__=='__main__': main()
