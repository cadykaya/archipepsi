"""Measure rendered weapon/impact WAVs: sample peak, true peak, loudness, crest, spectrum, decay.
usage: python3 -I measure.py out.json file.wav ...  (needs ffmpeg, numpy)"""
import sys, json, subprocess, re, numpy as np
from scipy.signal.windows import tukey
SR = 48000
def load(path, ch=2):
    raw = subprocess.run(['ffmpeg','-v','error','-i',path,'-f','f32le','-ac',str(ch),'-ar',str(SR),'-'],capture_output=True,check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, ch)
def ebur(path, pad_s):
    # pad short files with silence so the 400 ms momentary window sees the whole event
    cmd = ['ffmpeg','-nostats','-v','verbose','-i',path,'-af',f'apad=pad_dur={pad_s},ebur128=peak=true:framelog=verbose','-f','null','-']
    err = subprocess.run(cmd, capture_output=True, text=True).stderr
    M = [float(m) for m in re.findall(r' M:\s*(-?[\d.]+)', err)]
    S = [float(m) for m in re.findall(r' S:\s*(-?[\d.]+)', err)]
    tp = re.findall(r'True peak:\s+Peak:\s+(-?[\d.]+|-inf)', err)
    I = re.findall(r'I:\s+(-?[\d.]+) LUFS', err)
    return max(M), max(S), float(tp[-1]) if tp and tp[-1] != '-inf' else None, float(I[-1]) if I else None
def measure(path):
    x = load(path); m = x.mean(axis=1); a = np.abs(x).max(axis=1)
    pk = float(np.abs(x).max()); n = len(x)
    clipped = int((np.abs(x) >= 0.9999).sum())
    env = np.sqrt(np.convolve(m*m, np.ones(240)/240, 'same'))  # 5 ms RMS
    ipk = int(np.argmax(env)); first = int(np.argmax(a > 10**(-60/20)))
    def until(db):
        idx = np.where(env[ipk:] > env[ipk]*10**(db/20))[0]
        return (ipk + idx[-1])/SR if len(idx) else ipk/SR
    # A flat (Tukey) window from just before onset: a Hann window would hide the attack.
    s0 = max(0, first - SR//200); seg = m[s0:s0+SR//2]; w = tukey(len(seg), .1); X = np.abs(np.fft.rfft(seg*w))**2; f = np.fft.rfftfreq(len(seg), 1/SR)
    band = lambda lo, hi: float(10*np.log10(X[(f>=lo)&(f<hi)].sum()/X.sum()+1e-12))
    Mmax, Smax, tp, I = ebur(path, 1.0)
    rms_body = float(20*np.log10(np.sqrt((m[first:first+int(.1*SR)]**2).mean())+1e-12))
    end = float(20*np.log10(np.abs(x[-int(.02*SR):]).max()+1e-12))
    side = x[:,0]-x[:,1]; width = float(20*np.log10(np.sqrt((side**2).mean())/ (np.sqrt((m**2).mean())+1e-12)+1e-12))
    return dict(file=path.split('/')[-1], seconds=round(n/SR,3), lead_ms=round(first/SR*1000,1),
        peak_dbfs=round(20*np.log10(pk+1e-12),2), true_peak_dbtp=tp, clipped_samples=clipped,
        momentary_max_lufs=Mmax, short_term_max_lufs=Smax,
        crest_db=round(20*np.log10(pk+1e-12)-rms_body,1),
        centroid_hz=int((X*f).sum()/X.sum()),
        band_db=dict(sub_20_80=round(band(20,80),1), low_80_300=round(band(80,300),1), mid_300_2k=round(band(300,2000),1), high_2k_8k=round(band(2000,8000),1), air_8k_up=round(band(8000,24000),1)),
        decay_to_minus20_s=round(until(-20)-ipk/SR,3), decay_to_minus40_s=round(until(-40)-ipk/SR,3), decay_to_minus60_s=round(until(-60)-ipk/SR,3),
        last_20ms_peak_dbfs=round(end,1), side_vs_mid_db=round(width,1))
out = sys.argv[1]; rows = [measure(p) for p in sys.argv[2:]]
json.dump(rows, open(out,'w'), indent=1)
for r in rows: print(json.dumps(r))
