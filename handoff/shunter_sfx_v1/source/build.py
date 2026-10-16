"""Builds the Shunter's seven sound effects from CC0 Freesound recordings.

Every layer below is a cut of a recording listed in ../SOURCES.md, resampled,
filtered and enveloped. Nothing is synthesised except fades. Run from this
folder:  python3 -I build.py RAW_DIR OUT_DIR
"""
import json, subprocess, sys
import numpy as np
from scipy.ndimage import minimum_filter1d, uniform_filter1d
from scipy.signal import butter, sosfilt

SR = 48000
RAW, OUT = sys.argv[1], sys.argv[2]
_cache = {}


def load(name):
    if name not in _cache:
        raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', f'{RAW}/{name}.mp3',
                              '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'],
                             capture_output=True, check=True).stdout
        _cache[name] = np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)
    return _cache[name]


def cut(name, start, dur):
    x = load(name)
    a = int(start * SR)
    return x[a:a + int(dur * SR)].copy()


def speed(x, rate):
    """Varispeed (tape-style: pitch and tempo together). `rate` is a constant
    or a function of output time in seconds returning the playback rate."""
    if callable(rate):
        pos, out, t = 0.0, [], 0
        n = len(x) - 2
        while pos < n:
            out.append(pos)
            pos += rate(t / SR)
            t += 1
        idx = np.array(out)
    else:
        idx = np.arange(0, len(x) - 1, rate)
    i = idx.astype(int)
    f = (idx - i)[:, None]
    return x[i] * (1 - f) + x[i + 1] * f


def filt(x, kind, freq, order=2):
    sos = butter(order, freq, btype=kind, fs=SR, output='sos')
    return sosfilt(sos, x, axis=0)


def fade(x, fin=0.005, fout=0.01):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)[:, None]
    if b:
        x[-b:] *= np.linspace(1, 0, b)[:, None] ** 2
    return x


def shape(x, points):
    """Gain envelope through (time s, dB) points, linear in dB."""
    t = np.arange(len(x)) / SR
    ts, ds = zip(*points)
    g = 10 ** (np.interp(t, ts, ds) / 20)
    return x * g[:, None]


def db(x, gain):
    return x * 10 ** (gain / 20)


def tame(x, above_db, ratio, win=0.015):
    """Compressor on the layer's own level: above `above_db` under its
    loudest 15 ms, level grows 1/ratio as fast. Evens out a choppy grind."""
    e = np.sqrt(filt(x.mean(1) ** 2, 'lowpass', 1 / win, 1).clip(1e-12))
    e_db = 20 * np.log10(e / e.max())
    over = np.maximum(e_db - above_db, 0)
    return x * (10 ** (-over * (1 - 1 / ratio) / 20))[:, None]


def limit(x, ceiling_db=-1.0, look=0.006):
    """Brick-wall peak limiter with a 6 ms look-ahead. Returns the limited
    signal and the deepest gain reduction in dB."""
    ceil = 10 ** (ceiling_db / 20)
    need = np.minimum(1.0, ceil / (np.abs(x).max(1) + 1e-12))
    n = int(look * SR)
    g = uniform_filter1d(minimum_filter1d(need, 2 * n + 1), n)
    g = np.minimum(g, need)
    return x * g[:, None], round(max(0.0, float(-20 * np.log10(g.min()))), 2)


def sweep_lowpass(x, f0, f1, block=0.02):
    """A lowpass whose cutoff glides from f0 to f1 (log), block by block
    with crossfaded blocks so the glide has no zipper."""
    n = int(block * SR); out = np.zeros_like(x); win = np.hanning(2 * n)[:, None]
    steps = range(0, len(x), n)
    for k, a in enumerate(steps):
        f = f0 * (f1 / f0) ** (k / max(len(steps) - 1, 1))
        s0 = max(a - n, 0); seg = x[s0:a + n]
        y = filt(seg, 'lowpass', f, 2)
        w = win[n - (a - s0):n - (a - s0) + len(seg)] if a else win[n:n + len(seg)]
        out[s0:s0 + len(seg)] += y * (w if a else 1.0)
    return out


def width(x, w):
    """Stereo width: 0 mono, 1 as recorded."""
    m = x.mean(1, keepdims=True)
    return m + (x - m) * w


def mix(length, *layers):
    out = np.zeros((int(length * SR), 2))
    for at, x in layers:
        a = int(at * SR)
        n = min(len(x), len(out) - a)
        out[a:a + n] += x[:n]
    return out


# --- the seven sounds --------------------------------------------------------

def plough_scrape():
    # BRACE (0.7 s): the plough drops to the deck in the first 0.25 s, then
    # grinds there until the rush. It is the rush's warning, so it swells
    # toward 0.7 s instead of decaying, and rises slightly in pitch.
    drop = fade(filt(cut('valve-air-release', 0.6, 0.3), 'bandpass', [900, 6000]), 0.002, 0.08)
    drop = shape(drop, [(0, -2), (0.2, -8), (0.3, -30)])
    land = filt(speed(cut('metal-impact-hard', 0.09, 0.9), 0.72), 'lowpass', 5000)
    land = shape(fade(land, 0.001, 0.2), [(0, 0), (0.6, -10)])
    grind = cut('hydraulic-cutter-crunch', 17.25, 0.95)
    grind = filt(speed(grind, lambda t: 0.92 + 0.22 * t), 'bandpass', [350, 7500])
    grit = filt(speed(cut('conveyor-metal-rollers', 9.0, 1.0), lambda t: 0.8 + 0.25 * t), 'highpass', 1200)
    body = tame(mix(0.85, (0, db(grind, -6)), (0, db(grit, 12))), -14, 4)
    body = shape(fade(body, 0.02, 0.08), [(0, -9), (0.45, -4), (0.62, 0), (0.85, -3)])
    return mix(1.1, (0, db(drop, 4)), (0.2, db(land, -8)), (0.2, db(width(body, 0.7), 0)))


def rush():
    # RUSH (up to 1.1 s at 13 m/s): drive motors spooling up hard, a heavy
    # gallop on the deck, and the plough lip skimming the floor.
    whir = cut('motor-electric-whir', 6.0, 2.5)
    whir = filt(speed(whir, lambda t: 0.85 + 0.75 * min(t / 0.35, 1.0)), 'lowpass', 6000)
    drive = cut('motor-turret', 10.0, 2.5)
    drive = filt(speed(drive, lambda t: 0.7 + 0.6 * min(t / 0.3, 1.0)), 'bandpass', [80, 3500])
    rumble = filt(cut('conveyor-industrial', 20.0, 1.4), 'lowpass', 450, 4)
    thump = filt(speed(cut('metal-impact-heavy-2', 0.0, 0.6), 0.5), 'lowpass', 600, 4)
    thump = fade(shape(thump, [(0, 0), (0.12, -12), (0.25, -40)]), 0.001, 0.05)[:int(0.25 * SR)]
    feet = []
    for i, t in enumerate(np.arange(0.04, 1.1, 0.27)):   # a gallop: da-DUM
        feet += [(t, db(thump, -6)), (t + 0.09, db(thump, 0))]
    skim = filt(cut('conveyor-metal-rollers', 9.2, 1.3), 'highpass', 2500)
    motors = mix(1.3, (0, db(whir, -4)), (0, db(drive, 0)), (0, db(rumble, 4)), (0, db(skim, 2)))
    motors = shape(fade(motors, 0.01, 0.15), [(0, -14), (0.15, -2), (0.3, 0), (1.05, 0), (1.3, -12)])
    return mix(1.3, (0, motors), *[(t, x) for t, x in feet])


def crumple_clang():
    # A rush ends on a pillar, wall or closed gate (1.8 s window): the plough
    # slams flat on steel, the body jolts back, a burst of steam.
    big = filt(cut('metal-impact-heavy-1', 0.0, 1.9), 'lowpass', 9000)
    low = filt(speed(cut('metal-impact-heavy-2', 0.0, 1.4), 0.7), 'lowpass', 2500)
    crunch = filt(cut('hydraulic-cutter-crunch', 2.25, 0.55), 'bandpass', [250, 8000])
    crunch = fade(shape(crunch, [(0, 0), (0.3, -6), (0.55, -30)]), 0.002, 0.1)
    rebound = filt(speed(cut('metal-impact-hard', 0.09, 0.9), 0.85), 'lowpass', 6000)
    steam = filt(cut('air-release-slips', 0.42, 1.6), 'bandpass', [500, 9000])
    steam = shape(fade(steam, 0.01, 0.4), [(0, 0), (0.6, -6), (1.6, -24)])
    return fade(mix(2.4, (0, db(big, 0)), (0, db(low, -1)), (0.01, db(crunch, -6)),
                    (0.16, db(rebound, -9)), (0.12, db(width(steam, 0.8), -9))), 0.001, 0.3)


def skid():
    # A rush misses on open floor or bursts a crate (1.1 s window): the nose
    # digs in and the machine slews 15-20 degrees, grinding to a stop. It
    # falls in pitch where the scrape rises, so the two don't blur.
    dig = filt(speed(cut('metal-impact-heavy-2', 0.0, 0.8), 0.55), 'lowpass', 900, 4)
    dig = fade(shape(dig, [(0, 0), (0.3, -14), (0.6, -40)]), 0.001, 0.1)
    grind = cut('hydraulic-cutter-crunch', 32.5, 1.25)
    grind = filt(speed(grind, lambda t: 1.18 - 0.5 * min(t / 1.0, 1.0)), 'bandpass', [300, 8000])
    grit = filt(speed(cut('conveyor-metal-rollers', 9.0, 1.4), lambda t: 1.2 - 0.5 * min(t, 1.0)), 'highpass', 1500)
    body = sweep_lowpass(tame(mix(1.15, (0, grind), (0, db(grit, 6))), -14, 3), 10000, 1400)
    body = shape(fade(body, 0.004, 0.25), [(0, 0), (0.5, -2), (0.9, -8), (1.15, -20)])
    return mix(1.25, (0, db(dig, -3)), (0.01, db(width(body, 0.8), 0)))


def vent_gust():
    # A heavy hit during recovery: the vent flaps bang and exhaust a short,
    # forced gust. Short and punchy, unlike the steady plume.
    clack = filt(cut('press-highspeed-3', 4.671, 0.14), 'highpass', 300)
    gust = filt(cut('air-release-slips', 0.43, 0.7), 'bandpass', [400, 10000])
    gust = shape(fade(gust, 0.003, 0.15), [(0, 0), (0.12, -3), (0.7, -22)])
    puff = filt(cut('air-release', 0.0, 0.45), 'lowpass', 2500)
    puff = shape(fade(puff, 0.002, 0.1), [(0, 0), (0.45, -20)])
    return mix(0.75, (0, db(clack, -6)), (0.005, gust), (0.005, db(puff, 2)))


def plume_hiss():
    # RECOVER: the vents are open and a warm plume rises. It plays from the
    # start of the window; the game fades it over the window's last 0.2 s,
    # the same moment the plume fades, so the ear hears the window closing.
    # 2.4 s so the longest window (1.8 s) never runs out; it decays if it
    # is left to play.
    hiss = filt(cut('valve-air-release', 0.6, 2.6), 'bandpass', [250, 7000])
    warm = filt(cut('hydraulic-scissor-lift-2', 30.5, 2.6), 'lowpass', 500, 4)
    flap = filt(cut('press-highspeed-3', 4.671, 0.14), 'highpass', 400)
    body = mix(2.4, (0, hiss), (0, db(warm, -10)))
    body = shape(fade(body, 0.12, 0.5), [(0, -6), (0.2, 0), (1.8, -1), (2.4, -10)])
    return mix(2.4, (0, db(flap, -14)), (0.03, body))


def power_down():
    # DOWN: a relay clunk, the hydraulics sigh out, the pump and drive motor
    # spin down, and the body settles onto the deck.
    clunk = filt(speed(cut('metal-impact-hard', 0.09, 0.9), 0.6), 'lowpass', 3000)
    clunk = fade(clunk, 0.001, 0.3)
    sigh = filt(cut('air-release', 0.0, 3.6), 'lowpass', 5000)
    sigh = shape(fade(sigh, 0.03, 0.5), [(0, -2), (3.6, -6)])
    pump = cut('hydraulic-scissor-lift-2', 36.6, 2.8)
    motor = cut('motor-electric-whir', 10.0, 4.0)
    motor = filt(speed(motor, lambda t: max(1.0 - 0.85 * (t / 2.2) ** 0.7, 0.1)), 'lowpass', 5000)
    motor = shape(fade(motor, 0.005, 0.4), [(0, 0), (1.5, -6), (2.4, -24), (2.6, -60)])[:int(2.6 * SR)]
    settle = filt(speed(cut('metal-impact-heavy-2', 0.0, 1.0), 0.45), 'lowpass', 500, 4)
    settle = fade(settle, 0.001, 0.4)
    return fade(mix(3.4, (0, db(clunk, -4)), (0.04, db(sigh, -14)), (0.0, db(pump, 0)),
                    (0.0, db(motor, -6)), (2.25, db(settle, -14))), 0.002, 0.3)


SOUNDS = {
    'plough_scrape': plough_scrape, 'rush': rush, 'crumple_clang': crumple_clang,
    'skid': skid, 'vent_gust': vent_gust, 'plume_hiss': plume_hiss,
    'power_down': power_down,
}

# Loudness targets in LU relative to the approved horn's momentary maximum
# (BS.1770, 400 ms). The horn is the loudest thing the Shunter says; the
# brace scrape, the other warning, sits just under it.
TARGET_LU = {
    'plough_scrape': -2.0, 'rush': -3.0, 'crumple_clang': -1.0, 'skid': -4.0,
    'vent_gust': -7.0, 'plume_hiss': -8.0, 'power_down': -3.0,
}


def momentary_max(path):
    out = subprocess.run(['ffmpeg', '-nostats', '-i', path, '-af',
                          'ebur128=metadata=1,ametadata=print:key=lavfi.r128.M',
                          '-f', 'null', '-'], capture_output=True, text=True).stderr
    vals = [float(l.split('=')[1]) for l in out.splitlines() if 'lavfi.r128.M=' in l]
    return max(v for v in vals if v > -120)


def write(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).round().astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '2',
                    '-i', '-', '-c:a', 'pcm_s16le', '-map_metadata', '-1',
                    '-fflags', '+bitexact', '-flags:a', '+bitexact', path],
                   input=pcm, check=True)


if __name__ == '__main__':
    horn = momentary_max(f'{OUT}/shunter_horn.wav')
    report = {'horn_momentary_max_lufs': round(horn, 2), 'sounds': {}}
    for name, fn in SOUNDS.items():
        x = fn()
        path = f'{OUT}/shunter_{name}.wav'
        write(path, x / (np.abs(x).max() + 1e-12) * 0.5)
        m = momentary_max(path)
        gain = horn + TARGET_LU[name] - m
        x = x / (np.abs(x).max() + 1e-12) * 0.5 * 10 ** (gain / 20)
        x, reduction = limit(x)
        if reduction > 6.0:
            raise SystemExit(f'{name}: limiter would take {reduction} dB off its peaks')
        peak = 20 * np.log10(np.abs(x).max())
        write(path, x)
        report['sounds'][name] = {'target_lu_vs_horn': TARGET_LU[name],
                                  'momentary_max_lufs': round(momentary_max(path), 2),
                                  'sample_peak_dbfs': round(peak, 2), 'limiter_db': reduction,
                                  'seconds': round(len(x) / SR, 3)}
    json.dump(report, open(f'{OUT}/../measurements.json', 'w'), indent=1)
    print(json.dumps(report, indent=1))
