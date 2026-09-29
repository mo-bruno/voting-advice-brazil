#!/usr/bin/env python3
"""Verify provenance, taxonomy, references and literal evidence of thematic profiles."""
import argparse
import collections
import hashlib
import json
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path

P = Path(__file__).resolve().parent
OLD = P.parent / '2026-09-29-full-plan-validation'
LEVELS = {'explicit_proposal', 'explicit_rejection', 'general_goal', 'clear_implication'}
PRESENCE = {'substantive', 'general_only', 'not_addressed'}


def read(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def norm(text):
    return ' '.join(text.split())


def variants(text):
    lines = text.splitlines()
    return [norm(text), norm('\n'.join(x for i, x in enumerate(lines) if not i or x != lines[i - 1]))]


def extract_archive(archive, directory, candidates):
    manifest = {c['id']: c for c in read(OLD / 'source-manifest.json')['candidates']}
    with zipfile.ZipFile(archive) as source:
        for candidate in candidates:
            cid = candidate['id']
            data = source.read(manifest[cid]['member'])
            if hashlib.sha256(data).hexdigest() != candidate['sha256']:
                raise ValueError('Changed official PDF snapshot: ' + cid)
            folder = directory / cid
            folder.mkdir()
            pdf = folder / 'plan.pdf'
            pdf.write_bytes(data)
            for mode in ['layout', 'raw']:
                target = folder / (mode + '.txt')
                subprocess.run(['pdftotext', '-' + mode, str(pdf), str(target)], check=True, capture_output=True)
                pages = target.read_text().split('\f')
                if not pages[-1].strip():
                    pages.pop()
                if len(pages) != candidate['pages']:
                    raise ValueError('Unexpected PDF page count: ' + cid)
                (folder / (mode + '-pages.json')).write_text(json.dumps(pages, ensure_ascii=False))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--candidate')
    ap.add_argument('--allow-pending', action='store_true')
    ap.add_argument('--archive', type=Path, help='Reextract verified PDFs from the preserved official ZIP with Poppler')
    args = ap.parse_args()
    state = read(P / 'STATE.json')
    taxonomy = read(P / 'taxonomy.json')
    category_ids = {x['id'] for x in taxonomy['categories']}
    taxonomy_hash = digest(P / 'taxonomy.json')
    original = {c['id']: c for c in read(OLD / 'STATE.json')['candidates']}
    candidates = state['candidates']
    if args.candidate:
        candidates = [c for c in candidates if c['id'] == args.candidate]
        assert candidates, 'Candidate outside the authorized cohort'
    temporary = tempfile.TemporaryDirectory(prefix='farol-thematic-validation-') if args.archive else None
    if args.archive:
        extract_archive(args.archive, Path(temporary.name), candidates)
    results = []
    for c in candidates:
        cid = c['id']
        file = P / 'profiles' / (cid + '.json')
        if not file.exists():
            results.append({'candidate_id': cid, 'name': c['name'], 'status': 'pending', 'valid': False, 'errors': []})
            continue
        errors = []
        matches = collections.Counter()

        def check(ok, message):
            if not ok:
                errors.append(message)

        try:
            r = read(file)
        except (ValueError, TypeError) as exc:
            results.append({'candidate_id': cid, 'name': c['name'], 'status': 'invalid', 'valid': False, 'errors': [str(exc)]})
            continue
        prior = read(OLD / 'reviews' / (cid + '.json'))
        expected_pages = set(range(1, c['pages'] + 1))
        check(prior['full_read_completed'] and set(prior['pages_read']) == expected_pages, 'Prior full review incomplete')
        check(c['agent_id'] == original[cid]['agent_id'] == r.get('agent_id'), 'Must use the SAME original agent')
        check(r.get('schema_version') == 1 and r.get('candidate_id') == cid, 'Schema or candidate ID')
        check(r.get('model_requested') == 'gpt-6-astra' and r.get('reasoning_effort_requested') == 'ultra', 'Model/effort')
        check(r.get('document_sha256') == c['sha256'], 'Document hash')
        check(r.get('taxonomy_sha256') == taxonomy_hash, 'Taxonomy hash')
        check(r.get('prior_full_review') == '../2026-09-29-full-plan-validation/reviews/' + cid + '.json', 'Prior review reference')
        check(r.get('status') == 'complete', 'Profile incomplete')
        check(r.get('reading_basis') == 'prior_full_read_and_contextual_reinspection', 'Reading basis')
        revisited = r.get('revisited_pages', [])
        check(set(revisited) <= expected_pages and len(set(revisited)) == len(revisited), 'Invalid revisited pages')
        corpus = Path(temporary.name) / cid if temporary else Path(c['corpus_directory'])
        check(digest(corpus / 'plan.pdf') == c['sha256'], 'Actual PDF bytes differ')
        pages = {mode: read(corpus / (mode + '-pages.json')) for mode in ['layout', 'raw']}
        check(all(len(extraction) == c['pages'] for extraction in pages.values()), 'Extraction page count')
        positions = r.get('positions', [])
        ids = {x.get('id') for x in positions}
        check(bool(positions) and len(ids) == len(positions) and all(ids), 'Positions missing or duplicate IDs')
        by_id = {x['id']: x for x in positions}
        for pos in positions:
            key = pos.get('id', '?')
            check(pos.get('category_id') in category_ids, key + ': category')
            secondary = pos.get('secondary_category_ids', [])
            check(set(secondary) <= category_ids and pos.get('category_id') not in secondary and len(set(secondary)) == len(secondary), key + ': secondary categories')
            check(pos.get('support_level') in LEVELS, key + ': support level')
            for field in ['policy_dimension', 'statement', 'instrument', 'scope']:
                check(bool(pos.get(field, '').strip()), key + ': empty ' + field)
            check(isinstance(pos.get('conditions'), list), key + ': conditions array')
            context = pos.get('context_pages', [])
            check(bool(context) and set(context) <= expected_pages, key + ': context pages')
            evidence = pos.get('evidence', [])
            check(bool(evidence), key + ': no evidence')
            for ev in evidence:
                page = ev.get('page')
                quote = norm(ev.get('quote', ''))
                check(page in context and page in revisited, key + ': evidence must be contextualized and reinspected')
                if page not in expected_pages:
                    errors.append(key + ': invalid evidence page')
                    continue
                options = [v for mode in ['layout', 'raw'] for v in variants(pages[mode][page - 1])]
                found = next((i for i, txt in enumerate(options) if quote and quote in txt), None)
                if found is None:
                    errors.append(key + f': literal not found p{page}: ' + quote)
                else:
                    matches[['layout', 'layout_dedup', 'raw', 'raw_dedup'][found]] += 1
        categories = r.get('categories', [])
        check(len(categories) == len(category_ids) and {x.get('id') for x in categories} == category_ids, 'Exactly ten categories required')
        markdown_file = file.with_suffix('.md')
        markdown = markdown_file.read_text() if markdown_file.exists() else ''
        check(bool(markdown.strip()), 'Readable Markdown profile missing')
        for category in taxonomy['categories']:
            check(markdown.splitlines().count('## ' + category['name']) == 1, 'Markdown category missing or repeated: ' + category['name'])
        names = {category['name']: category['id'] for category in taxonomy['categories']}
        active_category, markdown_positions = None, []
        for line in markdown.splitlines():
            if line.startswith('## '):
                active_category = names.get(line[3:])
            match = re.match(r'^(?:- |### )?(?:\*\*)?(P\d+)\s+[—–-]', line)
            if match:
                markdown_positions.append((match.group(1), active_category))
        check(collections.Counter(markdown_positions) == collections.Counter((pos['id'], pos['category_id']) for pos in positions),
              'Markdown positions must match the JSON primary categories exactly once')
        category_refs = []
        for cat in categories:
            key = cat['id']
            refs = cat.get('position_ids', [])
            category_refs.extend(refs)
            check(set(refs) <= ids, key + ': unknown position')
            check(all(by_id[i]['category_id'] == key for i in refs if i in ids), key + ': primary category mismatch')
            expected = 'not_addressed' if not refs else 'substantive' if any(by_id[i]['support_level'] != 'general_goal' for i in refs if i in ids) else 'general_only'
            check(cat.get('presence') in PRESENCE and cat.get('presence') == expected, key + ': presence differs from cited positions')
            check(bool(cat.get('summary', '').strip()), key + ': summary absent')
            for gap in cat.get('gaps', []):
                check(bool(gap.get('topic')) and bool(gap.get('reason')) and set(gap.get('context_pages', [])) <= expected_pages, key + ': incomplete gap')
        check(collections.Counter(category_refs) == collections.Counter(ids), 'Each position must belong to one primary category exactly once')
        overview = r.get('overview', {})
        check(bool(overview.get('text')) and bool(overview.get('position_ids')) and set(overview.get('position_ids', [])) <= ids, 'Overview needs valid position references')
        for tension in r.get('tensions', []):
            refs = tension.get('position_ids', [])
            check(bool(refs) and len(refs) == len(set(refs)) and set(refs) <= ids and bool(tension.get('description')) and bool(tension.get('interpretation_limit')), 'Incomplete tension')
        seeds = r.get('thesis_seeds', [])
        check(len(seeds) <= 8 and len({x.get('id') for x in seeds}) == len(seeds), 'Seed count/IDs')
        for seed in seeds:
            key = seed.get('id', '?')
            refs = seed.get('position_ids', [])
            check(seed.get('category_id') in category_ids, key + ': seed category')
            check(bool(refs) and set(refs) <= ids, key + ': seed references')
            check(any(by_id[i]['support_level'] != 'general_goal' for i in refs if i in ids), key + ': seed supported only by generic goals')
            check(seed.get('candidate_response') in ['CONCORDA', 'DISCORDA', 'CONDICIONAL_OU_MISTA'], key + ': response')
            for field in ['statement', 'contrast_to_investigate', 'why_useful']:
                check(bool(seed.get(field, '').strip()), key + ': empty ' + field)
            check(isinstance(seed.get('necessary_conditions'), list) and seed.get('requires_cross_plan_validation') is True, key + ': scope/validation flag')
        results.append({'candidate_id': cid, 'name': c['name'], 'status': 'submitted', 'valid': not errors, 'errors': errors,
                        'same_original_agent': r.get('agent_id') == original[cid]['agent_id'], 'category_count': len(categories),
                        'category_presence': dict(collections.Counter(x.get('presence') for x in categories)),
                        'positions': len(positions), 'support_levels': dict(collections.Counter(x.get('support_level') for x in positions)),
                        'thesis_seeds': len(seeds), 'revisited_pages': len(revisited), 'quote_matches': dict(matches), 'profile_sha256': digest(file),
                        'markdown_sha256': digest(markdown_file) if markdown_file.exists() else None})
    pending = sum(x['status'] == 'pending' for x in results)
    invalid = sum(x['status'] != 'pending' and not x['valid'] for x in results)
    summary = {'schema_version': 1, 'taxonomy_sha256': taxonomy_hash, 'candidate_count': len(results),
               'evidence_source': 'fresh_official_archive_extraction' if args.archive else 'existing_local_corpus',
               'archive_sha256': digest(args.archive) if args.archive else None,
               'pending': pending, 'invalid_submissions': invalid, 'complete_and_valid': not pending and not invalid,
               'profiles': results, 'caveat': 'Checks provenance, structure and literal evidence. Does not prove semantic interpretation, ideology or questionnaire validity.'}
    output = P / ('validation-' + args.candidate + '.json' if args.candidate else 'validation.json')
    output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'profiles': len(results), 'pending': pending, 'invalid': invalid, 'valid': sum(x['valid'] for x in results)}, ensure_ascii=False))
    for result in results:
        for error in result['errors']:
            print(result['candidate_id'] + ': ' + error)
    if temporary:
        temporary.cleanup()
    raise SystemExit(1 if invalid or (pending and not args.allow_pending) else 0)


if __name__ == '__main__':
    main()
