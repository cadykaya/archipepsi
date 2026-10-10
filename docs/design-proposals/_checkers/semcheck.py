import re,sys
s=open("06_THE_AMALGAM.md").read()
def live(pat):
    """Occurrences NOT inside a narrated historical correction."""
    out=[]
    for m in re.finditer(pat,s):
        w=s[max(0,m.start()-400):m.start()]
        if re.search(r'(A previous revision|An earlier revision|a previous revision|an earlier revision|was withdrawn|A prior revision)[^.]{0,400}$',w,re.S):
            continue
        out.append(m.group(0)[:70])
    return out
FAIL=0
NCHK=0
def chk(name, bad, why):
    global FAIL, NCHK
    NCHK += 1
    hits=live(bad)
    if hits: print(f"  CONTRADICTION  {name}: {len(hits)} live — {why}\n      {hits[:2]}"); FAIL+=1
    else: print(f"  ok             {name}")

chk("floor withdrawn vs provider floor",
    r'the numeric envelope is withdrawn|floor.{0,30}was withdrawn.{0,80}capability model structurally cannot hold',
    "29.3.2 requires the envelope for provider qualification")
chk("no actor Status modifies damage",
    r'No Status applied to an actor modifies a damage number\.|may one modify damage on an actor\? \| Thirteen\. None',
    "exposed zeroes Defense, which the resolver reads")
chk("composition replaces profile everywhere",
    r'composition replaces it everywhere',
    "Mobility is the profile-backed exception (12.8)")
chk("qualifies_manipulate as a stored field",
    r'stamps `qualifies_manipulate: bool` on the `HostDefinition`',
    "4.2 states it is derived, never serialized")
chk("fallback keyed on degree",
    r'CERTIFIED_FALLBACK\[purpose\]\[degree\]',
    "the key is a normalized connector signature")
chk("PLACED not room-indexed",
    r'`PLACED` is deliberately not room-indexed',
    "a legally dropped object stays where it was dropped")
chk("shell answers composition-equivalent",
    r'legal answers are all equivalent to the composer',
    "shell choice narrows later package availability")
chk("offered_shells needs selected packages",
    r'exposing every offer the room.s already-selected packages require',
    "packages are selected six steps later")
chk("PURPOSE_ROTATION truncated",
    r'truncated to the first twelve entries',
    "vertical_ascent and boss_arena would be ungeneratable")
chk("ellipsis in a generated-record schema",
    r'ChamberType\s+#[^\n]*\.\.\.',
    "an implementer would have to guess the enum")
chk("PASS asserted alongside open owner forks",
    r'\*\*Zero-Guesswork verdict: PASS\.\*\*',
    "three owner decisions remain open")
chk("15 orthogonal asserted before the table",
    r'enumerates \*\*fifteen\*\* pairs as genuinely orthogonal',
    "the totals must be derived from the generated table")

chk("invented connector kinds live anywhere",
    r'(?<!proposed `\{ DOORWAY, DROP, )RAIL_MOUTH|rail mouth, vertical shaft',
    "the live vocabulary is DOORWAY/CORRIDOR_END from connector_grammar.gd")

# ---- pass-4 classes: contradictions that survived pass 3's checker ----
chk("Law 47 seed-determinism vs Epsilon choice",
    r'All 48 laws unchanged|Every one of the 48 inherited laws holds|Deterministic given `\(zone_seed, progression_state, ap_catalog\)`\.',
    "1.4 narrows Law 47; fresh generation is not seed-deterministic")
chk("two live CERTIFIED_FALLBACK schemas",
    r'\*\*`CERTIFIED_FALLBACK\[purpose\]`\*\* names, for every purpose',
    "the live key is [purpose][ConnectorSignature]")
chk("every profile composed vs Mobility not composed",
    r'Every profile in Designs 1, 2, 3, and 5 is a fixed composition',
    "12.8 exempts Mobility entirely")
chk("13.6 s as actual first-attempt cost",
    r'`13\.6 s` is what a Zone that composes first time actually costs',
    "first-attempt total is 13.6 s + Epsilon latency")
chk("audit PASS header vs conditional verdict",
    r'\*\*Verdict:\*\* \*\*PASS\.\*\* See §7\.',
    "the header must match the final verdict")
# A "meets the standard" claim is legitimate only when the verdict line agrees.
_claims = bool(re.search(r'meets the Zero-Guesswork Standard v1\.1 in every area', s))
_passes = bool(re.search(r'Zero-Guesswork verdict: PASS', s))
_cond   = bool(re.search(r'Zero-Guesswork verdict: CONDITIONAL', s))
if _claims and (_cond or not _passes):
    print("  CONTRADICTION  meets-standard claim vs verdict: claim present, verdict not PASS"); FAIL+=1
else:
    print(f"  ok             meets-standard claim vs verdict (claim={_claims}, PASS={_passes})")
chk("committed field absent from a schema",
    r'`carry_legal`[^.]{0,80}committed in the manifest',
    "carry_legal is derived from crossing; 4.9a declares the field")
chk("connector kind absent from the edge schema",
    r'each carrying its direction \(`A_TO_B`, `B_TO_A`, or bidirectional\)',
    "4.9a gives TopologyEdge connector_kind and the three-value direction")
chk("open owner decisions in the final verdict",
    r'OWNER DECISION REQUIRED|Zero-Guesswork verdict: CONDITIONAL',
    "all four owner rulings are applied")
chk("nonexistent section reference 30.9a",
    r'§?30\.9a',
    "no such section; the authority is 35.4.1 / check 31")

# structural: duplicate package-check ids
seg=s[s.index('| 1–18 | *Pinned: identical to Design 1 §23.5.* | D1 |'):s.index('### 23.5.1')]
ids=re.findall(r'^\|\s*\*{0,2}(\d+[a-z]?)\*{0,2}\s*\|',seg,re.M)
dup={i for i in ids if ids.count(i)>1}
print(f"  {'CONTRADICTION  duplicate package-check ids: '+str(dup) if dup else 'ok             package-check ids unique'}")
FAIL += 1 if dup else 0

# structural: 66-pair map self-consistency
blk=s[s.index("| Pair | Class | Section or reason |"):]
blk=blk[:blk.index("\n\nTwo naming corrections")]
rows=re.findall(r'^\| (.+?) \| (INTERACTS|ORTHOGONAL) \|',blk,re.M)
ni=sum(1 for _,c in rows if c=="INTERACTS"); no=len(rows)-ni
claim=re.search(r'\*\*`(\d+)` INTERACTS, `(\d+)` ORTHOGONAL, `(\d+)` total',s)
okmap = (len(rows)==66 and ni==int(claim.group(1)) and no==int(claim.group(2)))
print(f"  {'ok' if okmap else 'CONTRADICTION '}             system map: {len(rows)} rows, {ni} INTERACTS, {no} ORTHOGONAL vs claim {claim.groups()}")
FAIL += 0 if okmap else 1
# ---- pass 5 structural classes ----------------------------------------------
# Added because pass 4's 23 classes reported clean while an enum-size
# contradiction, an orphan identifier family, an orphan table row and a missing
# pin-ledger entry were all live. Each class below catches exactly one of them.
NCLASS = 0
def sct(name, ok, detail=""):
    global FAIL, NCLASS
    NCLASS += 1
    print(f"  {'ok            ' if ok else 'CONTRADICTION '} {name}{': '+detail if detail and not ok else ''}")
    if not ok: FAIL += 1

FENCES = re.findall(r'```(.*?)```', s, re.S)
CODE = "\n".join(FENCES)

# declared enum members, per enum
ENUMS = {}
for m in re.finditer(r'(\w+)\s*=\s*enum\s*\{(.*?)\}', CODE, re.S):
    ENUMS[m.group(1)] = [t for t in re.findall(r'\b[A-Z][A-Z0-9_]{2,}\b',
                         re.sub(r'#[^\n]*', '', m.group(2)))]
# inline field enums too, e.g.  direction : enum { A, B }
for m in re.finditer(r'enum\s*\{(.*?)\}', CODE, re.S):
    for t in re.findall(r'\b[A-Z][A-Z0-9_]{2,}\b', re.sub(r'#[^\n]*', '', m.group(1))):
        ENUMS.setdefault('_inline', []).append(t)
DECLARED = {t for v in ENUMS.values() for t in v}
DECLARED |= set(re.findall(r'\b[A-Z][A-Z0-9_]{2,}\b', CODE))

PROSE = re.sub(r'```.*?```', '', s, flags=re.S)

# A. enum members agree with the carry-legal table that follows them
tbl = re.search(r'\| `CrossingMethod` \| The crossing \| Carry-legal\? \|\n\|[-: |]+\|\n((?:\|.*\n)+)', s)
rows = re.findall(r'^\| `([A-Z_]+)` \|.*?\| \*\*(yes|no)\*\*', tbl.group(1), re.M) if tbl else []
cm = ENUMS.get('CrossingMethod', [])
sct("CrossingMethod enum members == carry-legal table rows",
    bool(cm) and bool(rows) and set(cm) == {r for r, _ in rows} and len(cm) == len(rows),
    f"enum {sorted(cm)} vs table {sorted(r for r,_ in rows)}")

# B. the derivation set == exactly the rows marked no
deriv = re.search(r'carry_legal\(e\) = e\.crossing ∉ \{([^}]*)\}', s)
dset = set(re.findall(r'\b[A-Z][A-Z0-9_]{2,}\b', deriv.group(1))) if deriv else set()
nos  = {r for r, v in rows if v == "no"}
sct("carry_legal derivation set == the table's non-carry-legal rows",
    bool(dset) and dset == nos, f"rule {sorted(dset)} vs table {sorted(nos)}")

# C. no orphan `PREFIX_*` family reference — a family named in prose must have members
orphans = []
for fam in set(re.findall(r'`([A-Z][A-Z0-9]*_)\*`', PROSE)):
    if not any(t.startswith(fam) for t in DECLARED):
        orphans.append(fam + "*")
sct("no prose reference to an undeclared identifier family", not orphans, str(orphans))

# D. no orphan table row — a `|` line with no table header above it
orphan_rows = []
lines = s.split("\n"); intable = False
for i, ln in enumerate(lines):
    if re.match(r'^\|[-: |]+\|\s*$', ln): intable = True; continue
    if ln.startswith("|"):
        if not intable and not (i + 1 < len(lines) and re.match(r'^\|[-: |]+\|\s*$', lines[i+1])):
            orphan_rows.append(f"L{i+1}: {ln[:60]}")
    elif not ln.strip(): intable = False
sct("no table row outside a table", not orphan_rows, str(orphan_rows[:3]))

# E. the pin ledger has no duplicate row
led = s[s.index("| Pinned | Modified by | What changes |"):]
led = led[:led.index("\n\n**This table is complete")]
lrows = [r.strip() for r in led.split("\n")[2:] if r.startswith("|")]
ldup = {r for r in lrows if lrows.count(r) > 1}
sct("pin ledger has no duplicate row", not ldup, str(ldup))

# F. every "— modifies Design N §X" section appears in the pin ledger
missing = []
for m in re.finditer(r'^#+ (\d+(?:\.\d+)*[a-z]?) [^\n]*— modifies Design \d+ §[\d.]+', s, re.M):
    if f"§{m.group(1)}" not in led: missing.append(m.group(1))
sct("every modifying section has a pin-ledger row", not missing, str(missing))

# G. every prose count of CrossingMethod agrees with the table
W = {"one":1,"two":2,"three":3,"four":4,"five":5,"six":6,"seven":7,"eight":8,
     "nine":9,"ten":10,"eleven":11,"twelve":12,"thirteen":13}
def w(t): return W.get(t.lower(), None)
n_all, n_yes, n_no = len(rows), sum(1 for _,v in rows if v=="yes"), len(nos)
claims, bad = [], []
m1 = re.search(r'\*\*(\w+) values, (\w+) carry-legal and (\w+) not\.\*\*', s)
if m1: claims += [(m1.group(1), n_all), (m1.group(2), n_yes), (m1.group(3), n_no)]
m2 = re.search(r'enumerates all (\w+) crossing methods and which (\w+) are carry-legal', s)
if m2: claims += [(m2.group(1), n_all), (m2.group(2), n_yes)]
m3 = re.search(r'The (\w+) that are not are `RAIL`', s)
if m3: claims += [(m3.group(1), n_no)]
for word, truth in claims:
    if w(word) != truth: bad.append(f"{word}!={truth}")
sct("every prose count of CrossingMethod matches the table",
    len(claims) == 6 and not bad, f"{len(claims)} claims found, mismatches {bad}")

# H. the audit's own verdict may not assert zero open decisions and then list some
AUD = open("06_THE_AMALGAM_AUDIT.md", encoding="utf-8").read()
zero = bool(re.search(r'\*\*Zero owner decisions remain open\.\*\*', AUD))
open_claims = re.findall(
    r'(?:owner-level forks remain|forks remain, and neither|remains an? (?:open|unresolved) owner|'
    r'explicit unresolved owner gate|must be decided before)', AUD)
# a claim inside a paragraph that names it as superseded does not count
live_claims = [c for c in open_claims
               if not re.search(r'(previously listed|was fork|pass 5 removed|were closed)',
                                AUD[max(0, AUD.index(c)-500):AUD.index(c)+500])]
sct("audit: zero-open-decisions claim vs live open-fork prose",
    not (zero and live_claims), f"zero={zero}, live open-fork claims={live_claims}")

# I. no heading is a repetition of itself, in any of the nine files
import glob
rep = []
for f in sorted(glob.glob("*.md")):
    for i, ln in enumerate(open(f, encoding="utf-8"), 1):
        ln = ln.rstrip("\n")
        if ln.startswith("#") and re.match(r'^(#{1,6} .+?)\1+$', ln):
            rep.append(f"{f}:{i}")
sct("no heading repeats itself, across all files", not rep, str(rep))

# J. every word count the README states matches the file it names
RD = open("README.md", encoding="utf-8").read()
wrong = []
NAMES = {"00": "00_ZERO_GUESSWORK_STANDARD.md", "01": "01_RELIABLE_CORE.md",
         "02": "02_PHYSICS_IS_THE_GAME.md", "03": "03_THE_DUNGEON_IS_ONE_MACHINE.md",
         "04": "04_EPSILON_IS_THE_CONTENT.md", "05": "05_STATUS_AS_GRAMMAR.md",
         "06 — The Amalgam": "06_THE_AMALGAM.md", "06 — Repair audit": "06_THE_AMALGAM_AUDIT.md",
         "07": "07_ENGINE_RECONCILIATION.md"}
for line in RD.split("\n"):
    if not line.startswith("| "): continue
    m = re.search(r'~\s*([\d.]+)k words', line)
    if not m: continue
    key = next((k for k in NAMES if line.startswith("| " + k)), None)
    if not key: continue
    actual = len(open(NAMES[key], encoding="utf-8").read().split())
    stated = float(m.group(1)) * 1000
    # figures are stated to 0.1k, so half a bucket is the tolerance
    if abs(actual - stated) > 50:
        wrong.append(f"{NAMES[key]}: says {m.group(1)}k, is {actual/1000:.1f}k")
sct("README word counts match the files", not wrong, str(wrong))

print(f"\nSTRUCTURAL CLASSES: {NCLASS}")

print(f"\nTOTAL CLASSES: {NCHK} pattern + 2 structural + {NCLASS} pass-5 = {NCHK + 2 + NCLASS}")
print(f"SEMANTIC CONTRADICTIONS: {FAIL}")
sys.exit(1 if FAIL else 0)
