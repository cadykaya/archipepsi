"""The six theme families as they actually REPEAT.

Every wall, floor and trim texture is world-projected at a texel density,
so each one tiles across large surfaces -- and no sheet in this repository
has ever shown one repeating. Eighteen tiles, each 3x3, with the verdict
`x-glyph.check_tiling` gave it, so the numbers and the picture sit together.

Nothing is modified. This reads the shipped PNGs and writes one sheet.
"""
import zlib, struct, json, os

def load(path):
    raw = open(path, "rb").read(); pos = 8; idat = b""; pal = None
    while pos < len(raw):
        ln = struct.unpack(">I", raw[pos:pos+4])[0]; typ = raw[pos+4:pos+8]
        d = raw[pos+8:pos+8+ln]
        if typ == b"IHDR": w, h, bd, ct = struct.unpack(">IIBB", d[:10])
        elif typ == b"PLTE": pal = d
        elif typ == b"IDAT": idat += d
        pos += 12 + ln
    ch = {0:1, 2:3, 3:1, 4:2, 6:4}[ct]
    buf = zlib.decompress(idat); stride = w * ch
    rows = []; prev = bytearray(stride); p = 0
    for _ in range(h):
        f = buf[p]; line = bytearray(buf[p+1:p+1+stride]); p += 1 + stride
        for i in range(stride):
            a = line[i-ch] if i >= ch else 0
            b = prev[i]; c = prev[i-ch] if i >= ch else 0
            if f == 1: line[i] = (line[i] + a) & 255
            elif f == 2: line[i] = (line[i] + b) & 255
            elif f == 3: line[i] = (line[i] + (a + b)//2) & 255
            elif f == 4:
                pp = a + b - c
                pa, pb, pc = abs(pp-a), abs(pp-b), abs(pp-c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        rows.append(bytes(line)); prev = line
    px = [[(lambda s: tuple(pal[s[0]*3:s[0]*3+3]) if ct == 3 else tuple(s[:3]))(
        rows[y][x*ch:(x+1)*ch]) for x in range(w)] for y in range(h)]
    return w, h, px

def write(path, w, h, px):
    raw = b"".join(b"\x00" + b"".join(bytes(px[y][x]) for x in range(w))
                   for y in range(h))
    def ck(t, d):
        return (struct.pack(">I", len(d)) + t + d
                + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff))
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n"
        + ck(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
        + ck(b"IDAT", zlib.compress(raw, 9)) + ck(b"IEND", b""))

# 5x7 pixel digits and letters, enough for the labels.
FONT = {}
for chn, rowsp in {
 "A":"01110 10001 10001 11111 10001 10001 10001","B":"11110 10001 11110 10001 10001 10001 11110",
 "C":"01111 10000 10000 10000 10000 10000 01111","D":"11110 10001 10001 10001 10001 10001 11110",
 "E":"11111 10000 11110 10000 10000 10000 11111","F":"11111 10000 11110 10000 10000 10000 10000",
 "G":"01111 10000 10000 10111 10001 10001 01111","H":"10001 10001 11111 10001 10001 10001 10001",
 "I":"11111 00100 00100 00100 00100 00100 11111","L":"10000 10000 10000 10000 10000 10000 11111",
 "M":"10001 11011 10101 10001 10001 10001 10001","N":"10001 11001 10101 10011 10001 10001 10001",
 "O":"01110 10001 10001 10001 10001 10001 01110","R":"11110 10001 11110 10100 10010 10001 10001",
 "S":"01111 10000 01110 00001 00001 10001 01110","T":"11111 00100 00100 00100 00100 00100 00100",
 "U":"10001 10001 10001 10001 10001 10001 01110","V":"10001 10001 10001 10001 10001 01010 00100",
 "W":"10001 10001 10001 10101 10101 11011 10001","Y":"10001 10001 01010 00100 00100 00100 00100",
 "_":"00000 00000 00000 00000 00000 00000 11111"," ":"00000 00000 00000 00000 00000 00000 00000",
 "-":"00000 00000 00000 11111 00000 00000 00000",":":"00000 00100 00000 00000 00100 00000 00000",
 "P":"11110 10001 10001 11110 10000 10000 10000","K":"10001 10010 10100 11000 10100 10010 10001",
 "X":"10001 10001 01010 00100 01010 10001 10001","Z":"11111 00001 00010 00100 01000 10000 11111",
 "J":"00111 00010 00010 00010 00010 10010 01100","Q":"01110 10001 10001 10001 10101 10010 01101",
}.items():
    FONT[chn] = [r for r in rowsp.split(" ")]

def text(img, W, H, s, x0, y0, col):
    for i, chn in enumerate(s.upper()):
        g = FONT.get(chn)
        if not g: continue
        for dy, row in enumerate(g):
            for dx, bit in enumerate(row):
                if bit == "1":
                    x, y = x0 + i*6 + dx, y0 + dy
                    if 0 <= x < W and 0 <= y < H: img[y][x] = col

THEMES = ["concrete_facility", "gothic_stone", "neon_transit",
          "rusted_industrial", "temple_ruin", "void_glitch"]
ROLES = ["wall", "floor", "trim"]
verdicts = {}
for r in json.load(open("/tmp/claude-0/glyphtrial/tiling.json")):
    if r["depth"] == 1:
        verdicts[r["tex"]] = r["tiles"]

TILE, T, PAD, LBL = 128, 3, 14, 12
CW, CH = TILE*T, TILE*T + LBL + 4
W = PAD + len(ROLES)*(CW + PAD)
H = PAD + 18 + len(THEMES)*(CH + PAD)
img = [[(18, 20, 24) for _ in range(W)] for _ in range(H)]
text(img, W, H, "THE SIX THEME FAMILIES AS THEY REPEAT - 3X3, NATIVE", PAD, 6,
     (235, 238, 242))
for ti, th in enumerate(THEMES):
    for ri, role in enumerate(ROLES):
        name = "%s_%s" % (th, role)
        p = "godot/content/theme/%s.png" % name
        if not os.path.exists(p): continue
        w, h, px = load(p)
        ox = PAD + ri*(CW + PAD)
        oy = PAD + 18 + ti*(CH + PAD) + LBL + 4
        for y in range(h*T):
            for x in range(w*T):
                img[oy+y][ox+x] = px[y % h][x % w]
        ok = verdicts.get(name)
        col = (140, 220, 160) if ok else (240, 180, 90)
        text(img, W, H, "%s  %s" % (name, "TILES" if ok else "FLAGGED"),
             ox, oy - LBL - 1, col)
write("/tmp/claude-0/THEME_TILING.png", W, H, img)
print("wrote", W, "x", H)
