import re,sys
s=open("06_THE_AMALGAM.md").read()
WORDS={'thirty-five':'35','thirty-four':'34','nineteen':'19','thirteen':'13',
       'twenty-four':'24','thirty-one':'31'}
def norm(t):
    t=t.replace('`','').replace('*','').lower()
    for w,d in WORDS.items(): t=t.replace(w,d)
    return re.sub(r'\s+',' ',t)
def sect(a,b):
    i=s.index(a); j=s.index(b,i+len(a)); return norm(s[i:j])
CH=[("Composition worst case","103.0 s", sect("### 35.4.3","\n## ")),
    ("Composition first pass","16.6 s",   sect("### 35.4.3","\n## ")),
    ("Placement solve","3.0 s",           sect("### 35.4.3","\n## ")),
    ("Replay wall clock","10.8 s",        sect("### 35.4.1","### 35.4.2")),
    ("Replay duration bound","12.0 s",    sect("### 35.4.1","### 35.4.2")),
    ("Epsilon worst case","20.0 s",       sect("### 35.4.2","### 35.4.3")),
    ("Implementation waves","35 waves",   sect("## 40.2","| Wave |")),
    ("Composable Weapons","179,326,745",  sect("## 11.9","## 11.9.1")),
    ("Composable Abilities","16,586,524", sect("## 12.7","## 12.8")),
    ("Atom catalog","121",                sect("### 11.7.1","### 11.7.2")),
    ("Puzzle families","34 puzzle",       sect("# 24. THE","| # | Family")),
    ("System pairs","66",                 sect("## 31.3","Rows 5, 6, 10")),
    ("Statuses","13 statuses",            sect("## 15.2","| Status |")),
    ("Configurations","49,152",           sect("### Cost","### On failure")),
    ("Union fixtures","19 fixtures",      sect("## 37.3","| # | Fixture")),
    ("Manipulate envelope","700 n",       sect("### 29.3.2","### ")),
    ("Package range","8–16",              sect("### 24.1.1","**What thirty-four")),
]
bad=[l for l,n,b in CH if norm(n) not in b]
for l,n,b in CH: print(f"  {'ok  ' if norm(n) in b else 'FAIL'} {l:26s} {n}")
print(f"\nCLOSURE FIGURES MISMATCHED: {len(bad)}")
sys.exit(1 if bad else 0)
