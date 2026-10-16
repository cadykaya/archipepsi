# usage (from handoff/approved_music_v1): python3 verify/audio_hashes.py station/sigmaudio_pack/sigmaudio-result.json freight_bay/sigmaudio_pack/sigmaudio-result.json freight_bay/stingers/per_track/manifest.json
# Read-only: hash each WAV's audio as SigmAudio wrote it (the storage-appended C2PA chunk left out
# of the hash only), and match against the hashes SigmAudio recorded at export time.
import sys, struct, hashlib, json, re, os
known = {}
for mf in sys.argv[1:]:
    for h in re.findall(r'"(?:sha256|wavSha256)":\s*"([0-9a-f]{64})"', open(mf).read()): known[h] = mf
rows = []
for root, _, files in os.walk('.'):
    for f in sorted(files):
        if not f.endswith('.wav'): continue
        p = os.path.join(root, f); b = open(p, 'rb').read(); i = 12; parts = []; c2pa = 0
        while i + 8 <= len(b):
            cid = b[i:i+4]; sz = struct.unpack('<I', b[i+4:i+8])[0]; n = 8 + sz + (sz & 1)
            if cid == b'C2PA': c2pa += n
            else: parts.append(b[i:i+n])
            i += n
        body = b''.join(parts); orig = b'RIFF' + struct.pack('<I', 4 + len(body)) + b'WAVE' + body
        h = hashlib.sha256(orig).hexdigest()
        rows.append((p, c2pa, h, 'MATCH' if h in known else 'no-recorded-hash'))
for r in rows: print(*r, sep='\t')
print('matched', sum(r[3] == 'MATCH' for r in rows), 'of', len(rows))
