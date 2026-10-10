"""Cut the deliberate one-second pre-roll from rendered WAVs, keeping every audible sample.
The cut point is 1 ms before the first sample above -90 dBFS; everything removed is
checked to be below -90 dBFS. PCM16 samples are copied unchanged (no resampling, no gain).
usage: python3 -I trim.py <outDir> in.wav ..."""
import sys, wave, os, numpy as np
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
for path in sys.argv[2:]:
    with wave.open(path, 'rb') as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        assert sw == 2, 'expected PCM16'
        x = np.frombuffer(w.readframes(n), dtype='<i2').reshape(-1, ch)
    thr = 32768 * 10**(-90/20)
    loud = np.where(np.abs(x).max(axis=1) > thr)[0]
    cut = max(0, int(loud[0]) - sr // 1000)
    assert np.abs(x[:cut]).max(initial=0) <= thr, f'{path}: audible material before cut'
    y = x[cut:]
    with wave.open(os.path.join(out, os.path.basename(path)), 'wb') as w:
        w.setnchannels(ch); w.setsampwidth(2); w.setframerate(sr); w.writeframes(y.astype('<i2').tobytes())
    print(f'{os.path.basename(path)} cut {cut} frames ({cut/sr*1000:.1f} ms), {len(y)} frames remain')
