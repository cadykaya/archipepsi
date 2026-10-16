# Cut, tune and tidy the machinery recordings into one-shots and zones for SigmAudio.
# Every edit is listed here so the manifest can say exactly what was done to each source.
import numpy as np,soundfile as sf,json
from scipy.signal import resample_poly, butter, sosfiltfilt
SR=44100
def load(n): x,sr=sf.read(f'wav/{n}.wav'); assert sr==SR; return x
def onset(x,t0,t1,band=None):
    s=x[int(t0*SR):int(t1*SR)]
    if band: s=sosfiltfilt(butter(4,band,'bandpass' if isinstance(band,list) else 'lowpass',fs=SR,output='sos'),s)
    e=np.convolve(s**2,np.ones(64)/64,'same'); pk=np.argmax(e)
    # walk back to where energy first rises above 10% of the peak
    j=pk
    while j>0 and e[j]>0.1*e[pk]: j-=1
    return t0+j/SR
def cut(x,t,d,fin=0.003,fout=0.05,curve=None):
    s=x[int(t*SR):int((t+d)*SR)].copy(); n=len(s)
    a=int(fin*SR); s[:a]*=np.linspace(0,1,a)
    b=int(fout*SR); s[-b:]*=np.linspace(1,0,b)**2
    if curve: s*=np.exp(-np.arange(n)/SR/curve)
    return s
def tune(s,cents):
    # resample so the recording plays `cents` higher (shorter) — pitch and speed move together, like tape
    r=2**(cents/1200); up=10000; down=int(round(up*r))
    return resample_poly(s,up,down)
def norm(s,peak=-1.0): return s/np.max(np.abs(s))*10**(peak/20)
log=[]
def save(path,s,src,what):
    s=norm(s); sf.write('cut/'+path,s,SR,subtype='PCM_24'); log.append({'file':path,'source':src,'edit':what,'seconds':round(len(s)/SR,3)})
# ---- machine kit (bayMachine): the room's working rhythm
x=load('press-highspeed-1'); t=onset(x,49.85,50.2,200); save('kick-press-stroke.wav',cut(x,t-0.005,0.30,fout=0.08),'press-highspeed-1',f'one press stroke from {t-0.005:.3f} s, 0.30 s, 80 ms fade-out')
x=load('press-highspeed-3'); t=onset(x,4.60,4.75,[1000,6000]); save('closed-hat-press-clank.wav',cut(x,t-0.002,0.14,fout=0.06),'press-highspeed-3',f'one die clank from {t-0.002:.3f} s, 0.14 s')
x=load('hydraulic-cutter-crunch'); t=onset(x,2.33,2.45); save('snare-cutter-crunch.wav',cut(x,t-0.003,0.32,fout=0.1),'hydraulic-cutter-crunch',f'one crunch from {t-0.003:.3f} s, 0.32 s')
x=load('air-release-slips'); t=onset(x,0.35,0.5); save('clap-air-puff.wav',cut(x,t-0.002,0.30,fout=0.12,curve=0.12),'air-release-slips',f'first 0.30 s of the release from {t-0.002:.3f} s, shortened with a 0.12 s decay')
x=load('valve-air-release'); t=onset(x,0.2,0.32); save('open-hat-valve-hiss.wav',cut(x,t-0.002,0.6,fout=0.25),'valve-air-release',f'0.6 s of valve hiss from {t-0.002:.3f} s')
x=load('metal-impact-hard'); t=onset(x,0.05,0.2); save('ride-metal-ping.wav',cut(x,t-0.002,1.2,fout=0.3),'metal-impact-hard',f'the impact from {t-0.002:.3f} s, 1.2 s')
# ---- heavy kit (bayHeavy): impacts for accents and escalation
x=load('metal-impact-heavy-2'); save('kick-heavy-boom.wav',cut(x,0,1.4,fin=0.001,fout=0.3),'metal-impact-heavy-2','whole impact, 1.4 s')
x=load('metal-impact-heavy-1'); save('snare-heavy-clang.wav',cut(x,0,1.3,fin=0.001,fout=0.3),'metal-impact-heavy-1','whole impact, first 1.3 s')
x=load('pneumatic-hammer-forging'); save('clap-hammer-rattle.wav',cut(x,0,0.74,fin=0.002,fout=0.05),'pneumatic-hammer-forging','the hammer burst, 0.74 s')
x=load('air-release'); save('open-hat-pressure-release.wav',cut(x,0,3.6,fin=0.002,fout=0.6),'air-release','whole release, 3.6 s')
x=load('press-highspeed-3'); t=onset(x,2.0,2.1,[1000,6000]); save('ride-press-clank-2.wav',cut(x,t-0.002,0.2,fout=0.08),'press-highspeed-3',f'a second clank from {t-0.002:.3f} s')
# ---- pitched: the air horn, split to one tone, tuned to D#4
x=load('horn-industrial-air'); s=cut(x,0.33,1.95,fin=0.03,fout=0.25)
from scipy.signal import stft,istft
f,tt,Z=stft(s,SR,nperseg=8192,noverlap=8192-512)
keep=np.zeros_like(f)
for k in range(1,40):
    keep=np.maximum(keep,np.exp(-0.5*((f-k*317.29)/9)**2))
drop=np.zeros_like(f)
for k in range(1,40): drop=np.maximum(drop,np.exp(-0.5*((f-k*385.53)/9)**2))
mask=np.clip(keep*1.0-0.9*drop,0,1)[:,None]
_,y=istft(Z*mask,SR,nperseg=8192,noverlap=8192-512); y=y[:len(s)]
y=tune(y,1200*np.log2(311.127/317.29)); y[:int(0.02*SR)]*=np.linspace(0,1,int(0.02*SR))
save('horn-D#4.wav',y,'horn-industrial-air','steady part and release, 0.33-2.28 s; the 385.5 Hz second horn removed with a harmonic mask so one tone remains; tuned -34 cents to exactly D#4 (311.1 Hz)')
# ---- pitched: the electric motor, tuned to B2
x=load('motor-electric-whir'); s=cut(x,14.5,7.6,fin=0.12,fout=0.6); s=tune(s,1200*np.log2(123.471/119.8))
save('motor-B2.wav',s,'motor-electric-whir','steady whir 14.5-22.1 s; tuned +52 cents to exactly B2 (123.5 Hz)')
# ---- pitched: the hydraulic lift's hum, tuned to F4
x=load('hydraulic-scissor-lift-2'); s=cut(x,28.5,7.5,fin=0.25,fout=0.8); f0=345.0; s=tune(s,1200*np.log2(349.228/f0))
save('hydraulic-F4.wav',s,'hydraulic-scissor-lift-2',f'hydraulic hum 28.5-36.0 s; tuned +{1200*np.log2(349.228/f0):.0f} cents to F4')
# ---- atmosphere: the conveyor, made into a seamless loop with a 1 s crossfade
x=load('conveyor-industrial'); a=x[int(60*SR):int(77*SR)]; xf=SR
loop=a[:-xf].copy(); loop[:xf]=a[-xf:]*np.linspace(1,0,xf)**0.5+a[:xf]*np.linspace(0,1,xf)**0.5
save('conveyor-loop.wav',loop,'conveyor-industrial','60-77 s, with the last second crossfaded into the first so it loops without a seam (16 s loop)')
# ---- SFX reference (not imported into SigmAudio): the Shunter's horn
x=load('horn-freight-train'); save('../sfx-shunter-horn.wav',cut(x,0,2.45,fin=0.01,fout=0.3),'horn-freight-train','first 2.45 s (the horn chord, before the train passes); 10 ms fade-in, 0.3 s fade-out. Not imported: the game would play it as a sound effect')
json.dump(log,open('cut/edits.json','w'),indent=1)
for l in log: print(l['file'].ljust(32),l['seconds'],l['edit'][:70])
