import sys, numpy as np
from au import load, SR
for p in sys.argv[1:]:
    x = load(p); m = x.mean(1)
    onset = np.argmax(np.abs(m) > 10 ** (-40 / 20)) / SR
    dc = 20 * np.log10(abs(m.mean()) + 1e-12)
    d = np.abs(np.diff(x, axis=0)).max()
    end = 20 * np.log10(np.abs(x[-int(0.01 * SR):]).max() + 1e-12)
    # spectral centroid slope over the loud part
    n = int(0.05 * SR); k = len(m) // n
    seg = m[:k * n].reshape(k, n); r = np.sqrt((seg ** 2).mean(1))
    F = np.abs(np.fft.rfft(seg * np.hanning(n), axis=1)); f = np.fft.rfftfreq(n, 1 / SR)
    c = (F * f).sum(1) / (F.sum(1) + 1e-12); loud = r > r.max() * 10 ** (-20 / 20)
    t = np.arange(k)[loud] * 0.05
    slope = np.polyfit(t, c[loud], 1)[0] if loud.sum() > 2 else 0
    print(f"{p.split('/')[-1]:28s} onset {onset*1000:5.1f} ms  DC {dc:6.1f} dB  max step {d:.3f}  last10ms {end:6.1f} dBFS  centroid {np.median(c[loud]):5.0f} Hz, trend {slope:+6.0f} Hz/s")
