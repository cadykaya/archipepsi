"""Cadence/overlap checks and the two audition reels, assembled from the delivered WAVs.
Placement and fixed gains only: no processing, no limiter. usage: context.py <wavDir> <outDir>"""
import sys, os, json, wave, numpy as np
D, OUT = sys.argv[1], sys.argv[2]; os.makedirs(OUT, exist_ok=True); SR = 48000
def load(n):
    with wave.open(os.path.join(D, n + '.wav'), 'rb') as w: return np.frombuffer(w.readframes(w.getnframes()), '<i2').reshape(-1, 2) / 32768.0
def place(buf, x, t, db=0.0):
    i = int(round(t * SR)); end = i + len(x)
    if end > len(buf): buf.resize((end, 2), refcheck=False)
    buf[i:end] += x * 10 ** (db / 20); return buf
def save(name, y):
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(np.clip(np.round(y * 32767), -32768, 32767).astype('<i2').tobytes())
db = lambda v: round(float(20 * np.log10(v + 1e-12)), 1)
# 1) cadence: six shots at the brief's candidate interval, overlap-added
report = {}
for name, interval, extra in [('foundry_fire', .72, None), ('sightline_fire', .35, None), ('bulkhead_fire', 1.0, ('bulkhead_pump', .35)),
                              ('massdriver_release_full', 2.0, None), ('switchback_fire_a', 1/7.5, None)]:
    x = load(name); buf = np.zeros((1, 2))
    for k in range(6):
        place(buf, x, k * interval)
        if extra: place(buf, load(extra[0]), k * interval + extra[1])
    single = np.abs(x).max(); series = np.abs(buf).max()
    env = np.sqrt(np.convolve(x.mean(1) ** 2, np.ones(480) / 480, 'same'))
    j = int(interval * SR); resid = env[j] if j < len(env) else 0.0
    report[name] = {'interval_s': round(interval, 3), 'single_peak_dbfs': db(single), 'six_shot_peak_dbfs': db(series),
                    'buildup_db': round(db(series) - db(single), 1), 'tail_at_next_shot_db_below_peak': round(db(resid) - db(env.max()), 1)}
json.dump(report, open(os.path.join(OUT, 'cadence-overlap.json'), 'w'), indent=1)
for k, v in report.items(): print(k, v)
# 2) level-matched comparison: each weapon's primary fire event, one second apart
cmp = np.zeros((1, 2)); t = .3
for name in ['foundry_fire', 'sightline_fire', 'switchback_series_demo', 'bulkhead_fire', 'massdriver_release_full']:
    x = load(name); place(cmp, x, t); t += len(x) / SR + .6
save('five-weapons-level-matched.wav', np.vstack([cmp, np.zeros((SR // 2, 2))]))
# 3) in-context demo: shots with impacts on metal, stone and organic (impacts 4 dB down, 30 ms later)
I = {m: load('impact_' + m) for m in ['metal', 'stone', 'organic']}
I.update({'driver_' + m: load('massdriver_impact_' + m) for m in ['metal', 'stone', 'organic']})
demo = np.zeros((1, 2)); t = .5; cues = []
def shot(name, at, mat=None, idb=-4.0, mark=True):
    place(demo, load(name), at)
    if mat: place(demo, I[mat], at + .03, idb)
    if mark: cues.append([round(at, 3), name, mat])
for k, m in enumerate(['metal', 'stone', 'organic']): shot('foundry_fire', t + k * .72, m)
t += 3 * .72 + 1.4
for k, m in enumerate(['metal', 'metal', 'stone', 'stone', 'organic', 'organic']): shot('sightline_fire', t + k * .35, m)
t += 6 * .35 + 1.2
for k in range(15):
    shot('switchback_fire_' + 'ab'[k % 2], t + k / 7.5, ['stone', 'metal'][k % 2], -9.0, mark=(k == 0))
place(demo, load('switchback_release_tail'), t + 15 / 7.5 - .04); cues.append([round(t + 15 / 7.5 - .04, 3), 'switchback_release_tail', None])
t += 2 + 1.6
for k in range(2):
    shot('bulkhead_fire', t + k * 1.0, 'stone', -3.0)
    for j, d in enumerate([.004, .009, .013]): place(demo, I['stone'], t + k * 1.0 + .03 + d, -12.0 - 2 * j)
    shot('bulkhead_pump', t + k * 1.0 + .35)
t += 2 + 1.4
shot('massdriver_charge', t); t += 1.25
hold = load('massdriver_charge_hold_loop'); place(demo, hold, t); cues.append([round(t, 3), 'massdriver_charge_hold_loop', None]); t += len(hold) / SR
shot('massdriver_release_full', t, 'driver_metal', -2.0); shot('massdriver_powerdown', t + .55); t += 2.4
early = load('massdriver_charge')[:int(.5 * SR)].copy(); early[-480:] *= np.linspace(1, 0, 480)[:, None]
place(demo, early, t); cues.append([round(t, 3), 'massdriver_charge (released at 0.5 s)', None]); t += .5
shot('massdriver_release_early', t, 'driver_stone', -4.0); shot('massdriver_powerdown', t + .45)
demo = np.vstack([demo, np.zeros((SR, 2))])
pk = np.abs(demo).max(); print('demo peak dBFS', db(pk), 'length s', round(len(demo) / SR, 1))
save('five-weapons-in-context-demo.wav', demo)
json.dump({'peak_dbfs': db(pk), 'events': cues}, open(os.path.join(OUT, 'five-weapons-in-context-demo.cues.json'), 'w'), indent=1)
