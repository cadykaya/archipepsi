"""How much of each Shunter sound's energy sits above the Freight Bay combat
music, with the music as loud as the horn (the floor the music handoff set),
measured as the music handoff measured the horn: the share of the sound's
STFT energy in bins where it is louder than the music. The worst of eight
start points through the loop is reported.
Usage: python3 -I clarity.py WAV_DIR COMBAT_LOOP"""
import subprocess, sys
import numpy as np
from scipy.signal import stft
SR = 48000


def load(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-ac', '1',
                          '-ar', str(SR), '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def ffm(path, af):
    return subprocess.run(['ffmpeg', '-nostats', '-i', path, '-af', af, '-f', 'null', '-'],
                          capture_output=True, text=True).stderr


wav, music_path = sys.argv[1:3]
horn = max(float(l.split('=')[1]) for l in ffm(f'{wav}/shunter_horn.wav',
           'ebur128=metadata=1,ametadata=print:key=lavfi.r128.M').splitlines() if 'r128.M=' in l)
music_lufs = float(ffm(music_path, 'ebur128').rsplit('I:', 1)[1].split('LUFS')[0])
music = load(music_path) * 10 ** ((horn - music_lufs) / 20)
for name in ['horn', 'plough_scrape', 'rush', 'crumple_clang', 'skid', 'vent_gust', 'plume_hiss', 'power_down']:
    x = load(f'{wav}/shunter_{name}.wav')
    worst = 1.0
    for k in range(8):
        a = int(k * len(music) / 8)
        m = np.take(music, np.arange(a, a + len(x)), mode='wrap')
        _, _, X = stft(x, SR, nperseg=2048); _, _, M = stft(m, SR, nperseg=2048)
        ex, em = np.abs(X) ** 2, np.abs(M) ** 2
        worst = min(worst, ex[ex > em].sum() / ex.sum())
    print(f'{name:14s} {100 * worst:5.1f} % of its energy above the combat music (worst of 8 starts)')
