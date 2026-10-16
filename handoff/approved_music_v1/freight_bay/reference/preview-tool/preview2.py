# Offline preview of a SigmAudio adaptive cue, built from its own exported stems and stinger WAVs.
# It does what the exported runtime does: every layer stem plays phase-locked on one looping clock, a state is a
# set of audible layers, a state change waits for the authored quantize point (beat, bar or phrase) and fades
# layers linearly over the authored fadeBeats, and "always" transitions fire after their dwell.
# Events (script 'events') take the authored event transition out of the current state and start every stinger
# authored on that event and allowed in that state, at the stinger's own quantize point, from the exported pack.
# Sound effects (script 'sfx') are mixed in unquantized, the way the game would play them.
# usage: preview2.py project.json stems_dir stinger_pack_dir script.json out.wav [log.json]
import sys, json, re, os, glob, numpy as np
from scipy.io import wavfile
proj, stems_dir, pack, script_path, out = sys.argv[1:6]
P = json.load(open(proj)); cue = P['cues'][0]; A = cue['adaptive']; T = cue['transport']
beat = 60 / T['bpm']; bar = beat * T['meter']['beatsPerBar']; phrase = bar * T.get('phraseLengthBars', 4)
q = {'immediate': 0, 'beat': beat, 'bar': bar, 'phrase': phrase}
L = {l['id']: l for l in A['layers']}; S = {s['name']: s for s in A['states']}; Sid = {s['id']: s for s in A['states']}
EV = {e['name']: e['id'] for e in A['events']}
slug = lambda s: re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')
def readwav(f):
    sr, x = wavfile.read(f)
    x = x.astype(np.float64) / (float(np.iinfo(x.dtype).max) + 1 if x.dtype.kind == 'i' else 1.0)
    return sr, (x if x.ndim == 2 else np.stack([x, x], 1))
files = glob.glob(os.path.join(stems_dir, '*.wav')); stems = {}
for lid, l in L.items():
    m = [f for f in files if slug(os.path.basename(f)[:-4]).endswith('-' + slug(l['name']))]
    if len(m) != 1:
        if not any(lid in st['activeLayerIds'] for st in A['states']): continue   # e.g. a layer that only holds stinger tracks
        raise SystemExit(f"stem for layer {l['name']}: {m}")
    sr, stems[lid] = readwav(m[0])
n_loop = min(len(v) for v in stems.values())
man = json.load(open(os.path.join(pack, 'manifest.json'))); stw = {}
for a in man['assets']:
    s2, x = readwav(os.path.join(pack, a['file']))
    if s2 != sr: raise SystemExit(f'stinger at {s2} Hz, stems at {sr} Hz')
    stw[a['stingerId']] = x
script = json.load(open(script_path)); total = script['lengthSeconds']; N = int(total * sr)
quant = lambda t, qn: (np.ceil(t / q[qn] - 1e-9) * q[qn]) if q[qn] else t
now_state = script.get('startState', Sid[A['baseStateId']]['name']); active_since = 0.0
timeline, stingers = [], []
pending = sorted(script.get('events', []), key=lambda r: r['at'])
while True:
    nxt = pending[0] if pending else None
    auto = [t for t in A['transitions'] if t['fromStateId'] == S[now_state]['id'] and t['when']['kind'] == 'always']
    auto_t = quant(active_since + auto[0]['dwellMs'] / 1000, auto[0]['quantize']) if auto else None
    if nxt and (auto_t is None or nxt['at'] < auto_t):
        pending.pop(0); eid = EV[nxt['event']]
        for s in A['stingers']:
            if s['eventId'] == eid and (s['allowedStateIds'] is None or S[now_state]['id'] in s['allowedStateIds']):
                stingers.append((quant(nxt['at'], s['quantize']), s, nxt['at']))
        c = [t for t in A['transitions'] if t['fromStateId'] in (S[now_state]['id'], '*') and t['when']['kind'] == 'event' and t['when']['eventId'] == eid]
        if not c: continue
        tr = sorted(c, key=lambda t: -t['priority'])[0]; to = Sid[tr['toStateId']]['name']
        sw = quant(max(nxt['at'], active_since + tr['dwellMs'] / 1000), tr['quantize'])
        timeline.append((sw, now_state, to, tr['fadeBeats'], tr['quantize'], nxt['at'], nxt.get('why', '')))
        now_state = to; active_since = sw
    elif auto_t is not None and auto_t < total:
        to = Sid[auto[0]['toStateId']]['name']
        timeline.append((auto_t, now_state, to, auto[0]['fadeBeats'], auto[0]['quantize'], auto_t, 'automatic after its dwell'))
        now_state = to; active_since = auto_t
    else: break
gain = {lid: np.zeros(N) for lid in stems}
def setspan(lid, t0, t1, a0, a1):
    i0, i1 = int(t0 * sr), min(N, int(t1 * sr))
    if i1 > i0: gain[lid][i0:i1] = np.linspace(a0, a1, i1 - i0, endpoint=False)
start = S[script.get('startState', Sid[A['baseStateId']]['name'])]['activeLayerIds']
for lid in stems: gain[lid][:] = 1.0 if lid in start else 0.0
for (sw, frm, to, fb, qn, req, why) in timeline:
    on = set(S[to]['activeLayerIds']); fd = fb * beat
    for lid in stems:
        a0 = gain[lid][min(N - 1, int(sw * sr))]; a1 = 1.0 if lid in on else 0.0
        if fd > 0: setspan(lid, sw, sw + fd, a0, a1)
        setspan(lid, sw + fd, total, a1, a1)
mix = np.zeros((N, 2)); idx = np.arange(N) % n_loop
for lid, x in stems.items(): mix += x[idx] * gain[lid][:, None]
music = mix.copy()
for (t0, s, req) in stingers:
    x = stw[s['id']]; i0 = int(t0 * sr); i1 = min(N, i0 + len(x)); mix[i0:i1] += x[:i1 - i0]; music[i0:i1] += x[:i1 - i0]
sfx = np.zeros((N, 2))
for e in script.get('sfx', []):
    s2, x = readwav(e['file'] if os.path.isabs(e['file']) else os.path.join(os.path.dirname(script_path), e['file']))
    if s2 != sr:
        from scipy.signal import resample_poly
        x = resample_poly(x, sr, s2, axis=0)
    x = x * 10 ** (e.get('gainDb', 0) / 20); i0 = int(e['at'] * sr); i1 = min(N, i0 + len(x)); sfx[i0:i1] += x[:i1 - i0]
mix += sfx
fo = script.get('fadeOutSeconds', 0)
if fo:
    k = np.linspace(1, 0, int(fo * sr))[:, None]; mix[-len(k):] *= k; music[-len(k):] *= k
wavfile.write(out, sr, mix.astype(np.float32))
base = out[:-4]; wavfile.write(base + '.music-only.wav', sr, music.astype(np.float32)); wavfile.write(base + '.sfx-only.wav', sr, sfx.astype(np.float32))
log = {'peak': float(np.abs(mix).max()), 'loopSeconds': n_loop / sr,
       'transitions': [{'requested': round(r, 3), 'switch': round(sw, 3), 'from': f, 'to': t, 'quantize': qn, 'fadeBeats': fb, 'loopBar': round((sw % (n_loop / sr)) / bar + 1, 2), 'why': w} for (sw, f, t, fb, qn, r, w) in timeline],
       'stingers': [{'event_at': round(r, 3), 'starts': round(t0, 3), 'name': s['name']} for (t0, s, r) in stingers],
       'sfx': script.get('sfx', [])}
if len(sys.argv) > 6: json.dump(log, open(sys.argv[6], 'w'), indent=1)
print(json.dumps(log['transitions'], indent=0)); print('stingers start at', sorted(set(x['starts'] for x in log['stingers']))); print('peak', round(20 * np.log10(log['peak']), 2), 'dBFS')
