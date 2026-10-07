"""Sample a siox VCD into `wave` specs: vcd2wave.py FILE CELL_NS CELLS SIGNAL..."""
import sys
path, cell, cells, wanted = sys.argv[1], float(sys.argv[2]), int(sys.argv[3]), sys.argv[4:]
ids, width, changes = {}, {}, {}
scope = []
t = 0
for line in open(path):
    tok = line.split()
    if not tok: continue
    if tok[0] == '$scope': scope.append(tok[2])
    elif tok[0] == '$upscope': scope.pop()
    elif tok[0] == '$var':
        name = '.'.join(scope[1:] + [tok[4]])
        ids[tok[3]] = name; width[name] = int(tok[2]); changes[name] = []
    elif tok[0].startswith('#'): t = int(tok[0][1:])
    elif tok[0][0] in 'bB':
        changes[ids[tok[1]]].append((t, tok[0][1:]))
    elif tok[0][0] in '01xzXZ' and tok[0][1:] in ids:
        changes[ids[tok[0][1:]]].append((t, tok[0][0].lower()))
def at(name, fs):
    v = None
    for (when, val) in changes[name]:
        if when <= fs: v = val
    return v
for name in wanted:
    spec, labels, prev = '', [], None
    for i in range(cells):
        v = at(name, int(i * cell * 1e6))
        if width[name] == 1:
            c = v if v in ('0', '1', 'z', 'x') else 'x'
            spec += '.' if c == prev else c
        else:
            if v is None or any(ch in 'xz' for ch in v): c = 'x'
            else: c = str(int(v, 2))
            if c == prev: spec += '.'
            elif c == 'x': spec += 'x'
            else: spec += '='; labels.append(c)
        prev = c
    print(f'{name:16} "{spec}"', labels if labels else '')
