from itertools import product, combinations
W={'frame':{'light':8,'standard':10,'heavy':14,'exotic*':22},
 'delivery':{'arc':14,'projectile':18,'hitscan':20,'spread':22,'burst':24,'beam':26,'dual*':34},
 'cadence':{'deliberate':20,'standard':25,'heavy':28,'rapid':30,'precise':34,'adaptive*':42},
 'payload':{'mark':22,'status':26,'direct':30,'drain':32,'pierce':34,'charge':36,'area':38,'chain':40,'compound*':52},
 'feed':{'mag_small':12,'mag_standard':15,'heat':18,'none':22,'selfloading*':28},
 'secondary':{'none':0,'zoom':8,'detonate':12,'tether':14,'guard':16,'altfire':24,'dualmode*':32}}
def wmask(f,d,c,p,fe,s):
    if d=='beam' and fe in ('mag_small','mag_standard'): return False
    if d=='beam' and p in ('charge','chain'): return False
    if d=='arc' and (s=='zoom' or p=='area'): return False
    if d=='spread' and p in ('pierce','chain'): return False
    if p=='charge' and (c=='rapid' or fe=='heat'): return False
    if s=='detonate' and p!='area': return False
    if s=='altfire' and fe=='none': return False
    if d=='dual*' and p=='compound*': return False
    return True
A={'form':{'press':10,'cast':12,'hold':16,'charge':18,'channel':20,'sustained*':30},
 'effect':{'mark':14,'status':22,'barrier':26,'damage':28,'physics':28,'field':32,'heal':34,'deployable':38,'transform*':62},
 'targeting':{'self':6,'point':12,'actor':14,'cone':16,'area':18,'chained*':32},
 'recharge':{'action':14,'resource':18,'cd_long':20,'cd_multi':24,'cd_short':26,'dual*':40},
 'scaling':{'flat':10,'proximity':14,'charge':16,'stacks':18,'escalating*':34}}
def amask(fo,e,t,r,s):
    if s=='charge' and fo!='charge': return False
    if e=='heal' and (fo not in ('channel','sustained*') or t in ('actor','cone')): return False
    if e=='deployable' and (t!='point' or fo in ('hold','channel')): return False
    if e=='physics' and (r=='action' or t in ('area','cone','chained*')): return False
    if e=='barrier' and t!='self': return False
    if e=='field' and t not in ('point','area'): return False
    if fo=='hold' and e in ('damage','deployable','status'): return False
    return True
ev={'ON_HIT':8,'ON_CRIT':6,'ON_OVERCRIT':4,'ON_KILL':6,'ON_AIRBORNE_KILL':3,'ON_RELOAD':5,'ON_WEAPON_SWAP':5,
 'ON_DAMAGE_TAKEN':6,'ON_BARRIER_BREAK':2,'ON_STATUS_APPLIED':4,'ON_ABILITY_USED':6,'ON_MOBILITY_USED':5,
 'ON_INTERACT':3,'ON_LOW_HEALTH':2}
ef={'GRANT_BARRIER':8,'HEAL':8,'RESTORE_RESOURCE':7,'ADVANCE_COOLDOWN':9,'ADVANCE_ACTION':6,'ADD_CRIT':11,
 'ADD_DAMAGE':10,'ADD_SPEED':5,'ADD_DEFENSE':6,'APPLY_STATUS':9,'REFILL_MAGAZINE':7,'VENT_HEAT':4,
 'GRANT_INVULN':14,'SPAWN_FIRE':8,'PUSH_NEARBY':5,'MARK_NEARBY':4}
mult={'SMALL':1.0,'MEDIUM':1.8,'LARGE':3.0}
clauses=[(e,int(round(ev[e]+ef[x]*mult[m]))) for e in ev for x in ef for m in mult]
def sets_within(allow,maxn):
    ok=[c for c in clauses if c[1]<=allow]; n=1+len(ok)
    if maxn>=2: n+=sum(1 for a,b in combinations(ok,2) if a[0]!=b[0] and a[1]+b[1]<=allow)
    if maxn>=3: n+=sum(1 for a,b,c in combinations(ok,3) if len({a[0],b[0],c[0]})==3 and a[1]+b[1]+c[1]<=allow)
    return n
def bases(cat,mask,tier):
    dims=list(cat); tot=mk=0; out=[]
    for combo in product(*[cat[d].items() for d in dims]):
        names=[n for n,_ in combo]
        if tier=='USEFUL' and any(n.endswith('*') for n in names): continue
        tot+=1
        if not mask(*names): continue
        mk+=1; out.append(sum(v for _,v in combo))
    return tot,mk,out
