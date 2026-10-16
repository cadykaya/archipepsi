# How clearly a warning sound reads over the music: in the time-frequency cells where the horn has its energy
# (within 25 dB of its loudest cell), how far does the horn sit above the music in the same cell?
# usage: clarity.py music.wav sfx.wav t0 t1   (both WAVs aligned, same rate)
import sys, numpy as np
from scipy.io import wavfile
from scipy.signal import stft
def rd(f):
    sr, x = wavfile.read(f); x = x.astype(np.float64)
    return sr, (x.mean(1) if x.ndim == 2 else x)
sr, m = rd(sys.argv[1]); _, s = rd(sys.argv[2]); t0, t1 = float(sys.argv[3]), float(sys.argv[4])
m = m[int(t0 * sr):int(t1 * sr)]; s = s[int(t0 * sr):int(t1 * sr)]
f, t, M = stft(m, sr, nperseg=4096, noverlap=3072); _, _, Sx = stft(s, sr, nperseg=4096, noverlap=3072)
Pm, Ps = np.abs(M) ** 2 + 1e-20, np.abs(Sx) ** 2 + 1e-20
band = (f > 150) & (f < 6000)
cells = band[:, None] & (10 * np.log10(Ps) > 10 * np.log10(Ps[band].max()) - 25)
snr = 10 * np.log10(Ps[cells] / Pm[cells])
w = Ps[cells] / Ps[cells].sum()
above = float(w[snr > 0].sum() * 100)
print(f"horn cells {cells.sum()}: horn above music in {above:.0f}% of its energy; median margin {np.median(snr):+.1f} dB; energy-weighted margin {10*np.log10(np.sum(w*10**(snr/10))):+.1f} dB")
# the loudness gap, for context
def ms(x): return 10 * np.log10(np.mean(x ** 2) + 1e-20)
print(f"plain RMS: horn {ms(s):.1f} dB, music {ms(m):.1f} dB over {t1-t0:.1f} s")
