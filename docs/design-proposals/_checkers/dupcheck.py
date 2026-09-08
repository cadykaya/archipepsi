import re, sys
s = open("06_THE_AMALGAM.md", encoding="utf-8").read()

# Every figure that appears in more than one place must agree everywhere.
#
# `stale`  — a pattern that would be the figure's superseded value.
# `exempt` — a pattern that, found in the +/-200 characters around a stale hit,
#            proves the hit is a different quantity that happens to share the
#            number, or a narrated historical correction. Passes 3 and 4 verified
#            both exemptions below by inspection and then carried them as known
#            false positives; carrying them as checked exclusions instead means a
#            green run is green.
CANON = {
 "composition worst case": (r'88\.0 s', r'\b(28|45|50)\.0 s\b', None),
 # `10.0 s` in this document is always Epsilon's interpretation timeout
 # (Design 4 §17.4) or a Status duration (Design 5 §15.2) — never a
 # composition-pass figure, which is `13.6 s`.
 "composition first pass": (r'13\.6 s', r'\b10\.0 s\b',
                            r'([Tt]ime[sd]? out|[Tt]imeout|interpretation|expires|duration)'),
 # The single `1.8 s` is §35.4.1's narration of the replay-budget error itself.
 "replay wall clock": (r'10\.8 s', r'\b(1\.8|7\.2) s\b',
                       r'(revisions got it wrong|The first stated|previous revision|earlier revision)'),
 "replay duration bound": (r'12\.0 s', None, None),
 "implementation waves": (r'\b35\b', r'[Tt]hirty-four waves|\b34 waves\b',
                          r'(previous|earlier|prior) revision'),
 "weapons": (r'179,326,745', None, None),
 "abilities": (r'16,586,524', None, None),
 "atom catalog": (r'`121`', r'`110`-atom', r'(previous|earlier|prior) revision'),
 "configurations": (r'49,152', None, None),
 "puzzle families": (r'`34`', None, None),
 "system pairs": (r'`66`', None, None),
}

bad = 0
for name, (good, stale, exempt) in CANON.items():
    g = len(re.findall(good, s))
    if not stale:
        print(f"  ok     {name}: {g} occurrences")
        continue
    hits = list(re.finditer(stale, s))
    live = []
    for m in hits:
        window = s[max(0, m.start() - 200):m.end() + 200]
        if exempt and re.search(exempt, window):
            continue
        live.append(m.group(0))
    if live:
        print(f"  STALE  {name}: {live}"); bad += 1
    elif hits:
        print(f"  ok     {name}: {g} current, {len(hits)} exempt (checked, not ignored)")
    else:
        print(f"  ok     {name}: {g} occurrences")

print("STALE FIGURES:", bad)
sys.exit(1 if bad else 0)
