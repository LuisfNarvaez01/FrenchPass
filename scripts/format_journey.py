"""Rewrites journey files in their hand-written layout: one word, exercise
or conversation line per row, so diffs stay readable.

    python scripts/format_journey.py            # every stage
    python scripts/format_journey.py cafe       # one stage

Edit a stage with json.load / json.dump if you like, then run this.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'data' / 'journey'
ORDER = ['depart', 'premiers', 'cafe', 'ville', 'conversations', 'debats', 'parisien']


def j(value):
    return json.dumps(value, ensure_ascii=False)


def lines_block(lines, indent):
    pad = ' ' * indent
    return ',\n'.join(pad + j(l) for l in lines)


def exercise(x, indent):
    pad = ' ' * indent
    if x[0] == 'd':
        return (f'{pad}["d", [\n{lines_block(x[1], indent + 2)}\n{pad}]]')
    return pad + j(x)


def lesson(l, indent):
    pad = ' ' * indent
    inner = ' ' * (indent + 2)
    parts = [f'{inner}"t": {j(l["t"])}']
    if 'g' in l:
        parts.append(f'{inner}"g": {j(l["g"])}')
    parts.append(f'{inner}"i": [\n{lines_block(l["i"], indent + 4)}\n{inner}]')
    if l.get('x'):
        xs = ',\n'.join(exercise(x, indent + 4) for x in l['x'])
        parts.append(f'{inner}"x": [\n{xs}\n{inner}]')
    for k, v in l.items():
        if k not in ('t', 'g', 'i', 'x'):
            parts.append(f'{inner}{j(k)}: {j(v)}')
    return pad + '{\n' + ',\n'.join(parts) + '\n' + pad + '}'


def week(w):
    pad = ' ' * 6
    parts = []
    for k in ('theme', 'goal', 'tutor'):
        if k in w:
            parts.append(f'{pad}{j(k)}: {j(w[k])}')
    ls = ',\n'.join(lesson(l, 8) for l in w['lessons'])
    parts.append(f'{pad}"lessons": [\n{ls}\n{pad}]')
    if w.get('cp'):
        parts.append(f'{pad}"cp": [\n{lines_block(w["cp"], 8)}\n{pad}]')
    for k, v in w.items():
        if k not in ('theme', 'goal', 'tutor', 'lessons', 'cp'):
            parts.append(f'{pad}{j(k)}: {j(v)}')
    return '    {\n' + ',\n'.join(parts) + '\n    }'


def render(data):
    weeks = ',\n'.join(week(w) for w in data['weeks'])
    return ('{\n'
            f'  "stage": {j(data["stage"])},\n'
            f'  "weeks": [\n{weeks}\n  ]\n'
            '}\n')


def main():
    for key in sys.argv[1:] or ORDER:
        path = ROOT / f'{key}.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        out = render(data)
        assert json.loads(out) == data, key
        path.write_text(out, encoding='utf-8', newline='\n')
        print(f'{key}: formatted')


if __name__ == '__main__':
    main()
