import re,sys,json
D={1:"01_RELIABLE_CORE",2:"02_PHYSICS_IS_THE_GAME",3:"03_THE_DUNGEON_IS_ONE_MACHINE",
   4:"04_EPSILON_IS_THE_CONTENT",5:"05_STATUS_AS_GRAMMAR",6:"06_THE_AMALGAM"}
def secs(n):
    o=set()
    for l in open(f"{D[n]}.md"):
        m=re.match(r'^#+\s+(\d+(?:\.\d+)*)[\.\s]',l)
        if m:o.add(m.group(1).rstrip('.'))
    return o
def vecs(n):
    t=open(f"{D[n]}.md").read()
    try: b=t[t.index("# 38. TEST VECTORS"):t.index("# 39. TRACEABILITY")]
    except ValueError: return set()
    return set(int(re.match(r'\d+',x).group()) for x in re.findall(r'^(\d+[a-z]?)\.\s',b,re.M))
S={n:secs(n) for n in D}; V={n:vecs(n) for n in D}
t=open("06_THE_AMALGAM.md").read()
bad_sec=[]; bad_vec=[]
for m in re.finditer(r'Design (\d)[^.\n]{0,70}?§([\d]+(?:\.\d+)*)',t):
    d,r=int(m.group(1)),m.group(2).rstrip('.')
    if r not in S[d] and r.split('.')[0] not in S[d]: bad_sec.append(f"D{d} §{r}")
for m in re.finditer(r'D(\d) V ?(\d+)',t):
    d,v=int(m.group(1)),int(m.group(2))
    if v not in V[d]: bad_vec.append(f"D{d} V{v}")
internal=set()
for m in re.finditer(r'§(\d+(?:\.\d+)*)',t):
    pre=t[max(0,m.start()-75):m.start()]
    if re.search(r'Design \d[^.\n]{0,70}$',pre) or re.search(r'Authority[^.\n]{0,30}$',pre): continue
    internal.add(m.group(1).rstrip('.'))
bad_int=sorted([r for r in internal if r not in S[6] and r.split('.')[0] not in S[6]])
print(f"D1 vectors available: {min(V[1])}-{max(V[1])} ({len(V[1])})")
print(f"broken cross-doc section refs : {len(bad_sec)} {sorted(set(bad_sec)) if bad_sec else ''}")
print(f"broken source vector refs     : {len(bad_vec)} {sorted(set(bad_vec)) if bad_vec else ''}")
print(f"broken internal refs          : {len(bad_int)} {bad_int if bad_int else ''}")
tot=sum(1 for _ in re.finditer(r'D\d V ?\d+',t))
print(f"total source-vector citations : {tot}")
