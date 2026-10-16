"""Listening preview: each sound alone, then a fight sketch over the
Freight Bay combat loop. Usage: python3 -I preview.py WAV_DIR COMBAT_LOOP OUT"""
import json, subprocess, sys
import numpy as np
SR = 48000
WAV, MUSIC, OUT = sys.argv[1:4]


def load(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-ac', '2',
                          '-ar', str(SR), '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)


def lufs(path):
    out = subprocess.run(['ffmpeg', '-nostats', '-i', path, '-af', 'ebur128', '-f', 'null', '-'],
                         capture_output=True, text=True).stderr
    return float(out.rsplit('I:', 1)[1].split('LUFS')[0])


def momentary_max(path):
    out = subprocess.run(['ffmpeg', '-nostats', '-i', path, '-af',
                          'ebur128=metadata=1,ametadata=print:key=lavfi.r128.M',
                          '-f', 'null', '-'], capture_output=True, text=True).stderr
    return max(float(l.split('=')[1]) for l in out.splitlines() if 'lavfi.r128.M=' in l)


S = {n: load(f'{WAV}/shunter_{n}.wav') for n in
     ['horn', 'plough_scrape', 'rush', 'crumple_clang', 'skid', 'vent_gust', 'plume_hiss', 'power_down']}


def play(buf, at, name, stop=None, fade=0.025):
    """Place a sound; `stop` cuts it at that many seconds with a fade, as the
    game would (the rush at its end, the plume over a window's last 0.2 s)."""
    x = S[name].copy()
    if stop is not None:
        n, f = int(stop * SR), int(fade * SR)
        x = x[:n]
        x[-f:] *= np.linspace(1, 0, f)[:, None]
    a = int(at * SR)
    buf[a:a + len(x)] += x[:len(buf) - a]


cues = []
# Part A: one at a time, dry.
order = [('horn', None, 'horn (approved, unchanged)'), ('plough_scrape', None, 'plough scrape (brace)'),
         ('rush', None, 'rush'), ('crumple_clang', None, 'crumple clang (rush hits steel)'),
         ('skid', None, 'skid (rush misses)'), ('vent_gust', None, 'vent gust (heavy hit in recovery)'),
         ('plume_hiss', 1.8, 'plume hiss (a 1.8 s window, faded over its last 0.2 s)'),
         ('power_down', None, 'power-down')]
a = np.zeros((int(26 * SR), 2)); t = 0.5
for name, stop, label in order:
    play(a, t, name, stop, 0.2 if name == 'plume_hiss' else 0.025)
    cues.append([round(t, 2), label])
    t += (stop or len(S[name]) / SR) + 0.9
a = a[:int((t + 0.3) * SR)]

# Part B: a fight sketch over the combat loop (D-20 timings).
music = load(MUSIC)
gain = momentary_max(f'{WAV}/shunter_horn.wav') - lufs(MUSIC)   # music as loud as the horn
b_len = 24.0
b = np.zeros((int(b_len * SR), 2))
B = [(0.6, 'horn', None, 0.025, 'HORN: it noticed you'),
     (3.0, 'plough_scrape', None, 0.025, 'BRACE: plough down'),
     (3.7, 'rush', 1.1, 0.025, 'RUSH'),
     (4.8, 'crumple_clang', None, 0.025, 'it hits a pillar: crumple'),
     (5.0, 'plume_hiss', 1.8, 0.2, 'RECOVER 1.8 s: plume'),
     (5.6, 'vent_gust', None, 0.025, 'a heavy hit: vent gust'),
     (9.5, 'plough_scrape', None, 0.025, 'BRACE'),
     (10.2, 'rush', 1.1, 0.025, 'RUSH'),
     (11.3, 'skid', None, 0.025, 'it misses on open floor: skid'),
     (11.5, 'plume_hiss', 1.1, 0.2, 'RECOVER 1.1 s: plume'),
     (15.0, 'plough_scrape', None, 0.025, 'BRACE'),
     (15.7, 'rush', 0.7, 0.025, 'RUSH, and it goes down mid-rush'),
     (16.4, 'skid', None, 0.025, 'skid'),
     (16.4, 'power_down', None, 0.025, 'DOWN: power-down')]
for at, name, stop, fade, label in B:
    play(b, at, name, stop, fade)
offset = len(a) / SR + 1.5
for at, name, stop, fade, label in B:
    cues.append([round(offset + at, 2), label])
m = music[:len(b)] * 10 ** (gain / 20)
m[-int(3 * SR):] *= np.linspace(1, 0, int(3 * SR))[:, None]
b += m
out = np.concatenate([a, np.zeros((int(1.5 * SR), 2)), b])
peak = np.abs(out).max()
if peak > 0.97:
    out *= 0.97 / peak
pcm = (out * 32767).round().astype('<i2').tobytes()
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '2', '-i', '-',
                '-c:a', 'aac', '-b:a', '256k', OUT], input=pcm, check=True)
json.dump({'music_gain_db': round(gain, 2), 'overall_trim_db': round(20 * np.log10(min(1, 0.97 / peak)), 2),
           'part_b_starts': round(offset, 2), 'cues': cues}, open(OUT.rsplit('.', 1)[0] + '.cues.json', 'w'), indent=1)
print(round(gain, 2), round(offset, 2), len(out) / SR)
