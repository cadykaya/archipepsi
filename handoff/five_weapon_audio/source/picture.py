"""Waveform + log-frequency spectrogram picture of WAVs, stacked, for reviewing by eye.
usage: python3 -I picture.py out.png a.wav [b.wav ...]"""
import sys, subprocess, numpy as np
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
from scipy.signal import spectrogram
out, files = sys.argv[1], sys.argv[2:]
fig, axes = plt.subplots(len(files), 2, figsize=(14, 2.3*len(files)), squeeze=False, gridspec_kw={'width_ratios':[1,1.4]})
for row, path in zip(axes, files):
    raw = subprocess.run(['ffmpeg','-v','error','-i',path,'-f','f32le','-ac','1','-ar','48000','-'],capture_output=True).stdout
    x = np.frombuffer(raw, dtype=np.float32); t = np.arange(len(x))/48000
    row[0].plot(t, x, lw=.4, color='k'); row[0].set_ylim(-1,1); row[0].set_title(path.split('/')[-1], fontsize=8, loc='left'); row[0].tick_params(labelsize=7)
    f, tt, S = spectrogram(x, 48000, nperseg=1024, noverlap=896)
    row[1].pcolormesh(tt, f, 10*np.log10(S+1e-12), shading='auto', vmin=-130, vmax=-40, cmap='magma')
    row[1].set_yscale('symlog', linthresh=100); row[1].set_ylim(20, 24000); row[1].tick_params(labelsize=7)
plt.tight_layout(); plt.savefig(out, dpi=80)
