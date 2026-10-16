import numpy as np, subprocess, sys
SR=48000
def load(path, sr=SR):
    raw=subprocess.run(['ffmpeg','-v','error','-i',path,'-f','f32le','-ac','2','-ar',str(sr),'-'],capture_output=True,check=True).stdout
    return np.frombuffer(raw,np.float32).reshape(-1,2).astype(np.float64)
def env(x,win=0.1,sr=SR):
    m=x.mean(1); n=int(win*sr); k=len(m)//n
    seg=m[:k*n].reshape(k,n); rms=np.sqrt((seg**2).mean(1))
    F=np.abs(np.fft.rfft(seg*np.hanning(n),axis=1)); f=np.fft.rfftfreq(n,1/sr)
    cen=(F*f).sum(1)/(F.sum(1)+1e-12)
    return rms,cen
if __name__=='__main__':
    for p in sys.argv[2:]:
        x=load(p); rms,cen=env(x,float(sys.argv[1]))
        print('==',p.split('/')[-1],len(x)/SR)
        print(' '.join(f"{i*float(sys.argv[1]):.1f}:{20*np.log10(r+1e-9):.0f}/{c/1000:.1f}k" for i,(r,c) in enumerate(zip(rms,cen))))
