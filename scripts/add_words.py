"""Adds word batches to the bundled corpus, checking every entry first.

usage: python scripts/add_words.py <batch.txt> [<batch.txt> ...]

A batch is plain text. A line `# category: <key>` sets the category for
the lines below it; every other non-empty line is one word:

    french | ipa | español | english | example in French | ejemplo | level | type

level is a1..c2; type is noun, verb, adjective, adverb, phrase or
expression. The IPA goes without brackets; they are added.

Nothing is written unless every line of every batch is valid, and a word
already in the corpus (same French, ignoring case, spacing and
final punctuation) is reported and skipped, never duplicated.
"""
import json
import os
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORPUS = os.path.join(ROOT, 'assets', 'data', 'words_seed.json')

CATEGORIES = {
    'daily_life', 'food', 'travel', 'business', 'emotions', 'technology',
    'nature', 'culture', 'health', 'home', 'conversation',
    'people', 'time', 'shopping', 'education', 'leisure',
}
LEVELS = {'a1', 'a2', 'b1', 'b2', 'c1', 'c2'}
TYPES = {'noun', 'verb', 'adjective', 'adverb', 'phrase', 'expression'}
IPA_FORBIDDEN = set('[]/')


def key(french):
    # Accents stay: in French they tell words apart (sucre / sucré).
    text = unicodedata.normalize('NFC', french.lower().replace('’', "'"))
    return ' '.join(text.replace('?', '').replace('!', '').split())


def parse(path, errors):
    category = None
    entries = []
    with open(path, encoding='utf-8') as f:
        for n, raw in enumerate(f, 1):
            line = raw.strip()
            if not line:
                continue
            if line.startswith('#'):
                if line.lower().startswith('# category:'):
                    category = line.split(':', 1)[1].strip()
                    if category not in CATEGORIES:
                        errors.append(f'{path}:{n}: unknown category {category}')
                continue
            parts = [p.strip() for p in line.split('|')]
            where = f'{path}:{n}'
            if len(parts) != 8:
                errors.append(f'{where}: expected 8 fields, got {len(parts)}')
                continue
            french, ipa, es, en, ex_fr, ex_es, level, kind = parts
            if category is None:
                errors.append(f'{where}: no category set above this line')
            if not all(parts):
                errors.append(f'{where}: empty field')
            if level not in LEVELS:
                errors.append(f'{where}: bad level {level}')
            if kind not in TYPES:
                errors.append(f'{where}: bad type {kind}')
            if IPA_FORBIDDEN & set(ipa):
                errors.append(f'{where}: write the IPA without brackets')
            entries.append({
                'french': french,
                'ipa': f'[{ipa}]',
                'translation_es': es,
                'translation_en': en,
                'example_fr': ex_fr,
                'example_es': ex_es,
                'category': category,
                'level': level,
                'word_type': kind,
                'audio_asset': None,
            })
    return entries


def main(paths):
    with open(CORPUS, encoding='utf-8') as f:
        corpus = json.load(f)
    words = corpus['words']
    seen = {key(w['french']) for w in words}

    errors = []
    batch = []
    for path in paths:
        batch.extend(parse(path, errors))
    if errors:
        print('\n'.join(errors))
        sys.exit(1)

    next_id = 1 + max(
        (int(w['id'].split('-')[1]) for w in words if w['id'].startswith('w-')),
        default=0)
    added, skipped = 0, []
    for entry in batch:
        k = key(entry['french'])
        if k in seen:
            skipped.append(entry['french'])
            continue
        seen.add(k)
        words.append({'id': f'w-{next_id:04d}', **entry})
        next_id += 1
        added += 1

    corpus['words'] = words
    corpus['total'] = len(words)
    corpus['version'] = '4.0.0'
    with open(CORPUS, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(corpus, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'added {added}, skipped {len(skipped)} duplicates, total {len(words)}')
    if skipped:
        print('skipped:', ', '.join(skipped))


if __name__ == '__main__':
    main(sys.argv[1:])
