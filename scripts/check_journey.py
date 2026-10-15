"""Checks the journey files in assets/data/journey before they ship.

    python scripts/check_journey.py

Every lesson needs 3-6 words and a micro-conversation; choice and listening
questions need four different options; a learner's turn in a conversation
needs three. Prints each problem and exits non-zero if there is any.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'data' / 'journey'
ORDER = ['depart', 'premiers', 'cafe', 'ville', 'conversations', 'debats', 'parisien']


def check(path):
    problems = []
    data = json.loads(path.read_text(encoding='utf-8'))
    lessons = 0
    for w, week in enumerate(data['weeks'], 1):
        if len(week['lessons']) != 5:
            problems.append(f'week {w}: {len(week["lessons"])} lessons, not 5')
        for lesson in week['lessons']:
            lessons += 1
            where = f'week {w} «{lesson["t"]}»'
            items = lesson['i']
            if not 3 <= len(items) <= 6:
                problems.append(f'{where}: {len(items)} words')
            for item in items:
                if len(item) < 3 or not item[0] or not item[2]:
                    problems.append(f'{where}: incomplete word {item}')
            kinds = [x[0] for x in lesson.get('x', [])]
            if 'd' not in kinds:
                problems.append(f'{where}: no conversation')
            for x in lesson.get('x', []):
                if x[0] in ('c', 'l'):
                    opts = x[2]
                    if len(opts) != 4 or len(set(opts)) != 4:
                        problems.append(f'{where}: options {opts}')
                elif x[0] == 'd':
                    lines = x[1]
                    if not any(l[0] == '' for l in lines):
                        problems.append(f'{where}: conversation without a turn')
                    for l in lines:
                        if l[0] == '' and (len(l[1]) != 3 or len(set(l[1])) != 3):
                            problems.append(f'{where}: turn options {l[1]}')
                elif x[0] == 'o':
                    if len(x[1].split()) < 3:
                        problems.append(f'{where}: order too short «{x[1]}»')
    return lessons, len(data['weeks']), problems


def main():
    total = 0
    bad = False
    for key in ORDER:
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
