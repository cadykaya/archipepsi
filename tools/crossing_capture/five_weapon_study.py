"""The five weapons, photographed in Prod's hand-cannon range. REVIEW ONLY.
(Arty, 2026-10-10.)

    python3 tools/crossing_capture/five_weapon_study.py OUT_DIR

Writes one `dcap.gd` spec per moment for a read-only checkout of
`review/hand-cannon` (host `weapon_feel.gd`, flag `--weapon-feel`), using
Batch 068's sheets (`assets/fx/weapons`) and viewmodels
(`assets/models/weapons_five`). The player's own Static Pulse device is
hidden and the candidate gun is placed where a Viewmodel child sits.

THE MOMENTS ARE FROZEN, NOT PLAYED. Each one is a time after the trigger,
and everything in it is computed for that time from the source data:
  * the gun's pose from its recoil springs, integrated exactly as Prod's
    `hand_cannon.gd` does (60 fps, two half steps a frame);
  * each flipbook's frame from its `durations_ms` in `fx.json`;
  * the round's position at Prod's 320 m/s streak speed;
  * the muzzle light decaying from Prod's 7.0.
So a sequence of moments is a time-lapse of one shot, not a playtest: the
runtime that plays it is Prod's.

SETS
  foundry_tNNN   one Foundry shot at the steel plate, t = 0 .. 550 ms:
                 FP (the player's eye, 90 deg + the FOV spring), SIDE
                 (beside the line of fire), CU (the plate, 38 deg lens)
  mat_hit, mat_after   every material hit at once, then only the marks
  <weapon>_rest / _fire / _m050   the five guns: rest, the shot's own
                 frame (spring jump + first flash frame), 50 ms later; FP
                 and an inspection view from beside the head
  massdriver_cNNN   charge 0 / 50 / 100 %: rings, bolts, accumulator light
"""

import json
import math
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
FX = os.path.join(REPO, "assets", "fx", "weapons")
MODELS = os.path.join(REPO, "assets", "models", "weapons_five")
SHEETS = json.load(open(os.path.join(FX, "fx.json")))
GUNS = json.load(open(os.path.join(MODELS, "manifest.json")))

STREAK_SPEED = 320.0                     # Prod's, m/s
FLASH = (7.0, 0.03)                      # energy, e-folding time (s)
# Prod's range (weapon_feel.gd on review/hand-cannon).
PLATE_HIT = [-3.6, 1.35, -8.97]          # steel plate face, +Z normal
GEL_HIT = [-2.2, 0.62, -6.27]            # gel block face, +Z
CRATE_HIT = [-3.25, 0.6, -13.49]         # timber crate face, +Z
FLOOR_HIT = [1.0, 0.0, -7.0]             # stone floor, +Y
WALL_HIT = [-5.99, 1.5, -11.0]           # stone west wall, +X
NORMALS = {"metal": [0, 0, 1], "flesh": [0, 0, 1], "wood": [0, 0, 1],
           "stone": [0, 1, 0], "wall": [1, 0, 0]}


# ------------------------------------------------------------------ maths

def rot_yxz(deg):
    """Godot's Basis.from_euler (YXZ) as a 3x3 row-major matrix."""
    x, y, z = (math.radians(a) for a in deg)
    cx, sx, cy, sy, cz, sz = (math.cos(x), math.sin(x), math.cos(y),
                              math.sin(y), math.cos(z), math.sin(z))
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return _mul(_mul(ry, rx), rz)


def _mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)]
            for i in range(3)]


def _apply(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


def spring_at(spring, t):
    """Prod's integrator: displacement `t` seconds after the shot."""
    x, v = spring["jump"], spring["kick"]
    w = 2 * math.pi * spring["freq"]
    for _ in range(int(round(t * 60))):
        for _h in range(2):
            dt = 1.0 / 120.0
            a = -w * w * x - 2 * spring["zeta"] * w * v
            v += a * dt
            x += v * dt
    return x


def pose(weapon, t, fired=True):
    """(position, rotation_deg, fov) of the viewmodel at time t."""
    gun = GUNS[weapon]
    pos = list(gun["rest"]["position"])
    rot = list(gun["rest"]["rotation_deg"])
    fov = 90.0
    if fired:
        s = {k: spring_at(v["spring"], t) for k, v in gun["recoil"].items()}
        pos[1] += s["lift"]
        pos[2] += s["back"]
        rot[0] += s["pitch"]
        rot[2] -= s["roll"]          # Prod's first shot rolls one way
        fov += s["fov"]
    return pos, rot, fov


def to_eye(pos, rot, p):
    """A Viewmodel-space point in the camera's frame."""
    r = _apply(rot_yxz(rot), p)
    return [round(pos[i] + r[i], 4) for i in range(3)]


def frame(name, t, start=0.0):
    """The flipbook frame showing at t (ms after `start`), or None."""
    d = SHEETS[name]["durations_ms"]
    k = t - start
    if k < 0:
        return None
    for i, ms in enumerate(d):
        if k < ms:
            return i
        k -= ms
    return len(d) - 1 if SHEETS[name]["loop"] == "hold_last" else None


def sprite(name, fr, size=None, **place):
    sheet = SHEETS[name]
    item = {"png": os.path.join(FX, sheet["file"]), "hframes": sheet["frames"],
            "frame": fr, "size_m": size or sheet["size_m"],
            "blend": sheet["blend"]}
    item.update(place)
    return item


def glb(weapon, pos, rot, poses=None):
    item = {"path": os.path.join(MODELS, weapon + ".glb"), "eye": pos,
            "eye_rot_deg": rot}
    if poses:
        item["pose"] = poses
    return item


# ------------------------------------------------------------------ layers

def muzzle_layers(weapon, t, pos, rot):
    """The muzzle's 2D layers at time t, following the gun."""
    nodes = GUNS[weapon]["nodes"]
    m = to_eye(pos, rot, nodes["muzzle"])
    out = []
    lay = {"foundry": [("foundry_flash_flare", 0), ("foundry_flash_core", 0),
                       ("foundry_afterglow", 34)],
           "sightline": [("sightline_flash", 0)],
           "switchback": [("switchback_flash_a", 0)],
           "bulkhead": [("bulkhead_flash", 0)],
           "massdriver": [("massdriver_release", 0)]}[weapon]
    for name, start in lay:
        fr = frame(name, t, start)
        if fr is not None:
            out.append(sprite(name, fr, at_eye=m))
    if weapon == "foundry":
        fr = frame("foundry_brake_tongue", t)
        if fr is not None:
            for port, side in (("brake_port_l", -1), ("brake_port_r", 1)):
                p = nodes[port]
                tip = [p[0] + side * 0.36, p[1] + 0.02, p[2] - 0.05]
                out.append(sprite("foundry_brake_tongue", fr, 0.12,
                                  at_eye=to_eye(pos, rot, p),
                                  beam_to_eye=to_eye(pos, rot, tip),
                                  face_eye=True))
    return m, out


def smoke_layers(weapon, t, m0):
    name = {"foundry": "foundry_smoke", "bulkhead": "bulkhead_smoke"}.get(
        weapon)
    if not name:
        return []
    fr = frame(name, t, 17)
    if fr is None:
        return []
    # The gas leaves forward: the puff sits 0.25 m ahead of the muzzle,
    # so it hangs in front of the barrel instead of ghosting the gun.
    rise = 0.3 * min(1.0, t / 800.0)
    return [sprite(name, fr, at_eye=[m0[0], m0[1] + rise, m0[2] - 0.25])]


def round_layers(weapon, t, m0, hit, dist):
    """The round in flight (a stretch of the muzzle -> hit path)."""
    travel = STREAK_SPEED * t / 1000.0
    if travel >= dist:
        return []
    head = travel / dist
    names = {"foundry": ("foundry_slug", "foundry_trail"),
             "sightline": (None, "sightline_tracer"),
             "switchback": (None, "switchback_tracer"),
             "bulkhead": (None, "bulkhead_pellet"),
             "massdriver": ("massdriver_slug", "massdriver_trail")}[weapon]
    # A round at 320 m/s covers ~5 m a frame, so the runtime STRETCHES
    # its sheet along the travel (Prod caps his streak at 1.2 m): the
    # slug to 0.9 m, the trail behind it to 3 m; widths stay authored.
    out = []
    slug, trail = names
    if trail:
        cell = SHEETS[trail]["cell"]
        width = max(0.03, SHEETS[trail]["size_m"] * cell[1] / cell[0])
        out.append(sprite(trail, 0, width, at_eye=m0, beam_to=hit,
                          face_eye=True,
                          along=[max(0.0, head - 3.0 / dist), head]))
    if slug:
        cell = SHEETS[slug]["cell"]
        width = SHEETS[slug]["size_m"] * cell[1] / cell[0]
        out.append(sprite(slug, frame(slug, t) or 0, width, at_eye=m0,
                          beam_to=hit, face_eye=True,
                          along=[max(0.0, head - 0.9 / dist), head]))
    return out


def impact_layers(weapon, material, t, hit, t_hit, marks=True):
    """What a hit draws on `material` at t (ms), the hit landing at t_hit."""
    n = NORMALS[material]
    off = lambda d: [hit[i] + n[i] * d for i in range(3)]  # noqa: E731
    out = []
    kind = {"wall": "stone"}.get(material, material)
    if weapon == "massdriver":
        fr = frame("massdriver_impact", t, t_hit)
        if fr is not None:
            out.append(sprite("massdriver_impact", fr, at=off(0.1)))
        if marks and t >= t_hit:
            out.append(sprite("massdriver_mark", 0, at=off(0.004), normal=n))
        return out
    if weapon == "bulkhead":
        fr = frame("bulkhead_blast", t, t_hit)
        if fr is not None:
            out.append(sprite("bulkhead_blast", fr, at=off(0.08)))
        if marks and t >= t_hit:
            out.append(sprite("bulkhead_mark", 0, at=off(0.004), normal=n))
        return out
    if weapon == "sightline":
        fr = frame("sightline_pop", t, t_hit)
        if fr is not None:
            out.append(sprite("sightline_pop", fr, at=off(0.03)))
    scale = {"foundry": 1.0, "sightline": 0.6, "switchback": 0.45}[weapon]
    if kind == "metal":
        for name, d in (("impact_metal_flash", 0.03),
                        ("impact_metal_smoke", 0.06)):
            if weapon == "sightline" and name == "impact_metal_flash":
                continue
            fr = frame(name, t, t_hit + (34 if "smoke" in name else 0))
            if fr is not None:
                out.append(sprite(name, fr, SHEETS[name]["size_m"] * scale,
                                  at=off(d)))
        fr = frame("impact_metal_heat", t, t_hit)
        if marks and fr is not None and weapon == "foundry":
            out.append(sprite("impact_metal_heat", fr, at=off(0.006),
                              normal=n))
        mark = {"foundry": "decal_metal_hole", "sightline": "sightline_mark",
                "switchback": "switchback_pock"}[weapon]
    elif kind == "stone":
        fr = frame("impact_stone_dust", t, t_hit)
        if fr is not None:
            out.append(sprite("impact_stone_dust", fr,
                              SHEETS["impact_stone_dust"]["size_m"] * scale,
                              at=off(0.05 + 0.3 * scale)))
        mark = {"foundry": "decal_stone_crater",
                "sightline": "sightline_mark",
                "switchback": "switchback_pock"}[weapon]
    elif kind == "flesh":
        fr = frame("impact_flesh_splash", t, t_hit)
        if fr is not None:
            out.append(sprite("impact_flesh_splash", fr,
                              SHEETS["impact_flesh_splash"]["size_m"] * scale,
                              at=off(0.04)))
        mark = "decal_flesh_mark"
    else:
        fr = frame("impact_stone_dust", t, t_hit)
        if fr is not None:
            out.append(sprite("impact_stone_dust", fr, 0.5 * scale,
                              at=off(0.2), modulate="#d8c8a8ff"))
        mark = "decal_wood_mark"
    if marks and t >= t_hit:
        out.append(sprite(mark, 0, at=off(0.004), normal=n))
    return out


def base(aim, sprites, glbs, lights, shots):
    return {"host": "res://scripts/content/weapon_feel.gd",
            "room_var": "_range", "show_player": True,
            "hide_viewmodel": True, "settle_frames": 60, "aim": aim,
            "glbs": glbs, "sprites": sprites, "lights": lights,
            "shots": shots}


def _dist(a, b):
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))


EYE = [0.0, 0.05 + 1.6, 0.0]      # SPAWN + the player's eye height (approx.)


# ------------------------------------------------------------------ sets

def foundry_moment(t):
    pos, rot, fov = pose("foundry", t / 1000.0)
    pos0, rot0, _ = pose("foundry", 0.0)
    m0 = to_eye(pos0, rot0, GUNS["foundry"]["nodes"]["muzzle"])
    m, sprites = muzzle_layers("foundry", t, pos, rot)
    dist = _dist(EYE, PLATE_HIT)
    t_hit = 1000.0 * dist / STREAK_SPEED
    sprites += smoke_layers("foundry", t, m0)
    sprites += round_layers("foundry", t, m0, PLATE_HIT, dist)
    sprites += impact_layers("foundry", "metal", t, PLATE_HIT, t_hit)
    ease = min(1.0, t / 90.0)
    poses = {"cylinder": {"rotation_deg": [0, 0, -60 * ease]},
             "hammer": {"rotation_deg": [38, 0, 0]}}
    lights = []
    e = FLASH[0] * math.exp(-(t / 1000.0) / FLASH[1])
    if e > 0.05:
        lights.append({"at_eye": m, "color": "#ffb86b", "energy": round(e, 3),
                       "range": 14.0, "shadows": True})
    if t >= t_hit:
        e2 = 1.4 * math.exp(-((t - t_hit) / 1000.0) / 0.04)
        if e2 > 0.05:
            lights.append({"at": [PLATE_HIT[0], PLATE_HIT[1],
                                  PLATE_HIT[2] + 0.45],
                           "color": "#ffc890", "energy": round(e2, 3),
                           "range": 4.0})
    shots = [{"name": "FP", "player_eye": True, "fov": round(fov, 2),
              "gray": True},
             {"name": "SIDE", "eye": [2.6, 2.0, -5.2],
              "look": [-1.2, 1.45, -3.6]},
             {"name": "CU", "eye": [-2.4, 1.5, -6.2], "fov": 38,
              "look": PLATE_HIT}]
    return base(PLATE_HIT, sprites, [glb("foundry", pos, rot, poses)],
                lights, shots)


def materials(after):
    t = 400 if after else 60
    sprites = []
    for material, hit in (("metal", PLATE_HIT), ("flesh", GEL_HIT),
                          ("wood", CRATE_HIT), ("stone", FLOOR_HIT),
                          ("wall", WALL_HIT)):
        if after:
            sprites += [s for s in impact_layers("foundry", material, 5000,
                                                 hit, 0)]
        else:
            sprites += impact_layers("foundry", material, t, hit, 30)
    pos, rot, _ = pose("foundry", 0, fired=False)
    shots = [{"name": "FP", "player_eye": True, "gray": True},
             {"name": "CU_METAL", "eye": [-2.4, 1.5, -6.2], "fov": 38,
              "look": PLATE_HIT, "gray": True},
             {"name": "CU_FLESH", "eye": [-1.2, 1.3, -4.3], "fov": 38,
              "look": GEL_HIT, "gray": True},
             {"name": "CU_WOOD", "eye": [-2.0, 1.4, -11.0], "fov": 38,
              "look": CRATE_HIT, "gray": True},
             {"name": "CU_STONE", "eye": [2.0, 1.4, -4.8], "fov": 38,
              "look": FLOOR_HIT, "gray": True},
             {"name": "CU_WALL", "eye": [-3.6, 1.6, -9.6], "fov": 38,
              "look": WALL_HIT, "gray": True}]
    return base([-2.6, 1.0, -9.0], sprites, [glb("foundry", pos, rot)], [],
                shots)


def weapon_moment(weapon, t, fired=True):
    pos, rot, fov = pose(weapon, t / 1000.0, fired)
    pos0, rot0, _ = pose(weapon, 0.0, fired)
    m0 = to_eye(pos0, rot0, GUNS[weapon]["nodes"]["muzzle"])
    sprites = []
    lights = []
    if fired:
        m, sprites = muzzle_layers(weapon, t, pos, rot)
        dist = _dist(EYE, PLATE_HIT)
        t_hit = 1000.0 * dist / STREAK_SPEED
        sprites += smoke_layers(weapon, t, m0)
        sprites += round_layers(weapon, t, m0, PLATE_HIT, dist)
        sprites += impact_layers(weapon, "metal", t, PLATE_HIT, t_hit)
        # Proposed muzzle lights (the handoff's table). Mass Driver's is a
        # pale cold white: a strong violet washed the room toward the
        # blue "movement" signal in the first pass.
        energy = {"foundry": 7.0, "sightline": 3.0, "switchback": 2.5,
                  "bulkhead": 8.0, "massdriver": 3.0}[weapon]
        colour = {"massdriver": "#e4e0ff", "sightline": "#dfe8ff"}.get(
            weapon, "#ffb86b")
        e = energy * math.exp(-(t / 1000.0) / FLASH[1])
        if e > 0.05:
            lights.append({"at_eye": m, "color": colour,
                           "energy": round(e, 3), "range": 12.0,
                           "shadows": True})
    shots = [{"name": "FP", "player_eye": True, "fov": round(fov, 2),
              "gray": True},
             {"name": "INSPECT", "eye_local": [0.95, -0.12, -0.55],
              "look_local": [0.3, -0.29, -0.78], "fov": 50}]
    return base(PLATE_HIT, sprites, [glb(weapon, pos, rot)], lights, shots)


def massdriver_charge(level):
    pos, rot, _ = pose("massdriver", 0, fired=False)
    pos = [pos[0], pos[1], pos[2] + 0.02 * level]     # pulled in
    acc = to_eye(pos, rot, GUNS["massdriver"]["nodes"]["accumulator"])
    poses = {}
    for i in range(3):
        slide = 0.025 * max(0.0, min(1.0, level * 3 - (2 - i)))
        rest_z = (-0.22, -0.30, -0.38)[i]
        poses["accumulator_ring_%d" % (i + 1)] = {
            "position": [0, 0.01, rest_z - slide],
            "rotation_deg": [0, 0, 240 * level * (i + 1)]}
    sprites = []
    if level > 0:
        fr = min(3, int(level * 4 - 1e-6))
        sprites.append(sprite("massdriver_charge", fr,
                              at_eye=[acc[0], acc[1] + 0.005, acc[2]]))
    lights = [{"at_eye": acc, "color": "#e4e0ff", "energy": 1.2 * level,
               "range": 2.5}] if level > 0 else []
    shots = [{"name": "FP", "player_eye": True, "gray": True},
             {"name": "INSPECT", "eye_local": [0.95, -0.12, -0.55],
              "look_local": [0.3, -0.29, -0.78], "fov": 50}]
    return base(PLATE_HIT, sprites, [glb("massdriver", pos, rot, poses)],
                lights, shots)


FOUNDRY_T = (0, 17, 33, 50, 67, 100, 150, 233, 350, 550)


def recoil_chart(path):
    """Each gun's shove (back, m) and muzzle rise (pitch, deg) over the
    first 500 ms of a shot, from the same springs: rest, peak, reset."""
    from PIL import Image, ImageDraw
    colours = {"foundry": (232, 150, 70), "sightline": (190, 210, 235),
               "switchback": (240, 200, 90), "bulkhead": (200, 120, 90),
               "massdriver": (170, 150, 255)}
    w, h, pad = 1200, 330, 60
    img = Image.new("RGB", (w, h * 2 + 40), (24, 25, 28))
    d = ImageDraw.Draw(img)
    for row, (channel, top, unit) in enumerate((("back", 0.32, "m"),
                                                ("pitch", 18.0, "deg"))):
        y0 = row * (h + 20) + 20
        lo = -top * 0.35
        sy = lambda v: y0 + h - pad - (v - lo) / (top - lo) * (h - 2 * pad)  # noqa: E731
        sx = lambda t: pad + t / 0.5 * (w - 2 * pad)  # noqa: E731
        d.line([(pad, sy(0)), (w - pad, sy(0))], fill=(80, 80, 86))
        for v in (0.0, top * 0.5, top):
            d.text((6, sy(v) - 6), ("%.2f" if unit == "m" else "%.0f") % v,
                   fill=(150, 150, 150))
        for ms in range(0, 501, 50):
            d.line([(sx(ms / 1000), sy(lo)), (sx(ms / 1000), sy(top))],
                   fill=(44, 45, 50))
            d.text((sx(ms / 1000) - 10, sy(lo) + 6), "%d" % ms,
                   fill=(150, 150, 150))
        d.text((pad, y0), "%s (%s) after the shot, ms" % (channel, unit),
               fill=(220, 220, 220))
        for k, (name, gun) in enumerate(GUNS.items()):
            spring = gun["recoil"][channel]["spring"]
            pts = [(sx(t / 1000.0), sy(spring_at(spring, t / 1000.0)))
                   for t in range(0, 501, 2)]
            d.line(pts, fill=colours[name], width=3)
            d.text((w - pad - 120, y0 + 18 + 16 * k), name,
                   fill=colours[name])
    img.save(path)


def main(out):
    os.makedirs(out, exist_ok=True)
    specs = {}
    for t in FOUNDRY_T:
        specs["foundry_t%03d" % t] = foundry_moment(t)
    specs["mat_hit"] = materials(False)
    specs["mat_after"] = materials(True)
    for w in GUNS:
        specs["%s_rest" % w] = weapon_moment(w, 0, fired=False)
        specs["%s_fire" % w] = weapon_moment(w, 0)
        specs["%s_m050" % w] = weapon_moment(w, 50)
    for level in (0.0, 0.5, 1.0):
        specs["massdriver_c%03d" % int(level * 100)] = \
            massdriver_charge(level)
    for name, spec in specs.items():
        with open(os.path.join(out, name + ".json"), "w",
                  encoding="utf-8") as handle:
            json.dump(spec, handle, indent=1)
    recoil_chart(os.path.join(out, "recoil_signatures.png"))
    print("[five] %d specs in %s" % (len(specs), out))


if __name__ == "__main__":
    main(sys.argv[1])
