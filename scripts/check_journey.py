"""Checks the journey files in assets/data/journey before they ship.

    python scripts/check_journey.py

    python scripts/check_journey.py cafe     # one stage

Every lesson needs 6-8 words and a conversation of at least 8 lines with 4
learner turns; every week ends on a checkpoint conversation (`cp`) of at
least 10 lines with 5 turns. Choice and listening questions need four
different options; a learner's turn needs three. A word is taught once per
stage. Prints each problem and exits non-zero if there is any.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'data' / 'journey'
ORDER = ['depart', 'premiers', 'cafe', 'ville', 'conversations', 'debats', 'parisien']


def conversation(where, lines, min_lines, min_turns, problems):
    turns = [l for l in lines if l[0] == '']
    if len(lines) < min_lines or len(turns) < min_turns:
        problems.append(f'{where}: conversation of {len(lines)} lines, '
                        f'{len(turns)} turns (needs {min_lines}/{min_turns})')
    for l in lines:
        if l[0] == '' and (len(l[1]) != 3 or len(set(l[1])) != 3):
            problems.append(f'{where}: turn options {l[1]}')
        elif l[0] != '' and (len(l) < 2 or not l[1]):
            problems.append(f'{where}: empty line {l}')


def check(path):
    problems = []
    seen = {}
    data = json.loads(path.read_text(encoding='utf-8'))
    lessons = 0
    for w, week in enumerate(data['weeks'], 1):
        if len(week['lessons']) != 5:
            problems.append(f'week {w}: {len(week["lessons"])} lessons, not 5')
        for lesson in week['lessons']:
            lessons += 1
            where = f'week {w} «{lesson["t"]}»'
            items = lesson['i']
            if not 6 <= len(items) <= 8:
                problems.append(f'{where}: {len(items)} words, needs 6-8')
            for item in items:
                if len(item) < 5 or not (item[0] and item[2] and item[3] and item[4]):
                    problems.append(f'{where}: incomplete word {item}')
                    continue
                key = item[0].lower()
                if key in seen:
                    problems.append(f'{where}: «{item[0]}» already taught in '
                                    f'«{seen[key]}»')
                seen[key] = lesson['t']
            kinds = [x[0] for x in lesson.get('x', [])]
            if 'd' not in kinds:
                problems.append(f'{where}: no conversation')
            for x in lesson.get('x', []):
                if x[0] in ('c', 'l'):
                    opts = x[2]
                    if len(opts) != 4 or len(set(opts)) != 4:
                        problems.append(f'{where}: options {opts}')
                elif x[0] == 'd':
                    conversation(where, x[1], 8, 4, problems)
                elif x[0] == 'o':
                    if len(x[1].split()) < 3:
                        problems.append(f'{where}: order too short «{x[1]}»')
        conversation(f'week {w} checkpoint', week.get('cp', []), 10, 5,
                     problems)
    return lessons, len(data['weeks']), problems


def main():
    total = 0
    bad = False
    for key in sys.argv[1:] or ORDER:
        path = ROOT / f'{key}.json'
        if not path.exists():
            print(f'{key}: MISSING')
            bad = True
            continue
        lessons, weeks, problems = check(path)
        total += lessons
        print(f'{key}: {weeks} weeks, {lessons} lessons')
        for p in problems:
            print(f'   {p}')
        bad = bad or bool(problems)
    print(f'total: {total} lessons')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
