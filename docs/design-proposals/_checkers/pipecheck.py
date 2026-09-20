import re, sys
path = sys.argv[1]
bad = []
for i, line in enumerate(open(path), 1):
    s = line.rstrip("\n")
    if not (s.startswith("|") and s.count("|") >= 2):
        continue
    # find code spans; a pipe inside a code span breaks the cell in GFM
    for m in re.finditer(r'`+[^`]*`+', s):
        if re.search(r"(?<!\\)\|", m.group(0)):
            bad.append((i, m.group(0), s[:100]))
for i, span, ctx in bad:
    print(f"{i}: {span!r}\n    {ctx}")
print(f"TOTAL {len(bad)}")
