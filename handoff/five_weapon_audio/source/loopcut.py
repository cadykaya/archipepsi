"""Cut a seamless loop from a steady SigmAudio render: N seconds starting at A, with an
F-second equal-power crossfade that blends the material just after the loop end into the
loop start, so the last sample flows into the first. usage: loopcut.py in.wav out.wav A N F"""
import sys, wave, numpy as np
src, dst, A, N, F = sys.argv[1], sys.argv[2], *map(float, sys.argv[3:])
with wave.open(src, 'rb') as w:
    sr, ch = w.getframerate(), w.getnchannels(); x = np.frombuffer(w.readframes(w.getnframes()), '<i2').reshape(-1, ch).astype(np.float64)
a, n, f = int(A*sr), int(N*sr), int(F*sr)
out = x[a:a+n].copy(); t = np.linspace(0, np.pi/2, f)[:, None]
out[:f] = x[a:a+f]*np.sin(t) + x[a+n:a+n+f]*np.cos(t)
y = np.clip(np.round(out), -32768, 32767).astype('<i2')
with wave.open(dst, 'wb') as w: w.setnchannels(ch); w.setsampwidth(2); w.setframerate(sr); w.writeframes(y.tobytes())
d = np.abs(np.diff(np.vstack([y[-1:], y[:1]]).astype(float), axis=0)).max()
print(f'loop {n} frames ({N}s) from {A}s, crossfade {F}s, wrap step {d:.0f} LSB, peak {20*np.log10(np.abs(y).max()/32768):.1f} dBFS')
