# The Shunter's horn: split the three horn tones apart with harmonic masks, tune each to the piece's dominant (B major: D#4, F#4, B4), and sum them again.
import numpy as np,soundfile as sf
from scipy.signal import stft,istft,resample_poly
SR=44100
x,_=sf.read('wav/horn-freight-train.wav'); s=x[:int(2.45*SR)].copy()
s[:441]*=np.linspace(0,1,441); s[-int(0.3*SR):]*=np.linspace(1,0,int(0.3*SR))**2
f,t,Z=stft(s,SR,nperseg=8192,noverlap=8192-512)
tones={'D#4':(309.54,311.127),'F#4':(377.55,369.994),'B4':(492.48,493.883)}
masks={k:np.zeros_like(f) for k in tones}
for k,(f0,_) in tones.items():
    for h in range(1,45): masks[k]=np.maximum(masks[k],np.exp(-0.5*((f-h*f0)/8)**2))
tot=sum(masks.values())+1e-9
resid=np.clip(1-np.maximum.reduce(list(masks.values())),0,1)
out=np.zeros(len(s)+SR)
for k,(f0,ft) in tones.items():
    _,y=istft(Z*(masks[k]/np.maximum(tot,1))[:,None],SR,nperseg=8192,noverlap=8192-512)
    up=10000; dn=int(round(up*ft/f0)); y=resample_poly(y[:len(s)],up,dn)
    out[:len(y)]+=y
_,r=istft(Z*resid[:,None],SR,nperseg=8192,noverlap=8192-512)   # the breath and rattle of the horn, untuned
out[:len(s)]+=r[:len(s)]
out=out[:int(2.5*SR)]; out[-int(0.3*SR):]*=np.linspace(1,0,int(0.3*SR))**2
out=out/np.max(np.abs(out))*10**(-1/20)
sf.write('sfx-shunter-horn-tuned.wav',out,SR,subtype='PCM_24')
