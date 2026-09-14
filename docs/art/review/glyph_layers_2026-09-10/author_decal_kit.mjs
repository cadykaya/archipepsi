// Archipepsi x ECMS Glyph -- a reusable decal kit, six transparent studies.
//
//   GLYPH_ROOT=/path/to/ecms-glyph node author_decal_kit.mjs [outdir]
//
// WHAT A DECAL IS FOR HERE. The wall field carries only what can bear being
// seen a hundred times. Everything specific -- a leak under one joint, the
// scuff by one doorway, one scorch -- is a decal, placed once. The wall
// layers batch exists because the trial baked both into one texture and the
// 3x3 sheet showed what that costs: five identical drips per tile, on a
// grid, and the eye goes to them before it reads a single panel.
//
// SIX MARKS, NOT SIX VERSIONS OF EVERY ROOM. Each is authored once at a
// declared physical size, with the surfaces it suits and the orientations it
// may take. A drip stays upright because gravity is structure; a floor scuff
// rotates freely because a floor has no up.
//
// ORDINARY DECORATION MAY NOT IMPERSONATE A SIGNAL. `art_palette.json`
// reserves six universal colours -- signal, hazard, identity, dead, send,
// glitch -- and AUTHORED_CONTENT.md's rule is that "can I use this?" is
// never a guess. Nothing in this kit comes near them, and the check is not a
// promise: `check_decal_colours.py` measures every emitted pixel against all
// six and fails on a near miss.

import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { execFileSync } from "node:child_process";

const t0 = performance.now();
const GLYPH_ROOT = process.env.GLYPH_ROOT ?? "/home/user/ecms-glyph";
const { newEasel } = await import(
  pathToFileURL(join(GLYPH_ROOT, "tools", "easel.mjs")).href);

const GLYPH_SHA = (() => {
  // The brief requires the exact Glyph commit for every delivered trial, so
  // it is read from the installation rather than typed in beside it.
  try {
    return execFileSync("git", ["-C", GLYPH_ROOT, "rev-parse", "HEAD"],
                        { encoding: "utf8" }).trim();
  } catch { return "unknown"; }
})();

const OUT = process.argv[2] ?? ".";
const DIR = join(OUT, "decals");
mkdirSync(DIR, { recursive: true });
const OWNER = "act_owner_skyiah";
const ARTIST = "act_agent_arty";
const DENSITY = 32;                       // texels/m, the house convention

function hash32(str) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0;
  }
  h ^= h >>> 16; h = Math.imul(h, 2246822507) >>> 0;
  h ^= h >>> 13; h = Math.imul(h, 3266489909) >>> 0;
  return (h ^ (h >>> 16)) >>> 0;
}
const mk = (seed) => (what, x, y) =>
  hash32(`archipepsi/decal/${seed}/${what}/${x}/${y}`) / 4294967295;

// The house stencil alphabet, 3x5, from tools/blender/paintkit.py. Reused
// rather than redrawn: a second alphabet is a second thing to keep in step.
const GLYPHS = {
  S: ["###", "#  ", "###", "  #", "###"],
  U: ["# #", "# #", "# #", "# #", "###"],
  B: ["## ", "# #", "## ", "# #", "## "],
};

const grid = (w, h) => Array.from({ length: h }, () => Array(w).fill("."));
const rows = (g) => g.map((r) => r.join(""));

// =========================================================================
// THE SIX
// =========================================================================
// Every palette below is drawn from `art_palette.json`: the shared `grime`
// family that every theme uses so six material families look like one world,
// the concrete base ramp where a mark EXPOSES substrate rather than adding
// to it, and concrete's own accent for paint.

const KIT = [
  {
    id: "decal_drip", title: "leak / drip beneath a joint",
    size: [16, 48], metres: [0.5, 1.5],
    surfaces: ["wall"], orientation: "upright only",
    why: "gravity is structure. A drip on its side is not a drip, and a "
       + "drip on a floor is a stain, which is `decal_grime`.",
    palette: [
      { name: "wet", value: [36, 31, 28, 215] },      // grime dark
      { name: "run", value: [78, 67, 60, 165] },      // grime mid
      { name: "trail", value: [123, 106, 96, 105] },  // grime light
      { name: "haze", value: [123, 106, 96, 55] },
    ],
    draw(g, r) {
      const [W, H] = [16, 48];
      // The source: a blot right under the joint, wider than the run.
      for (let y = 0; y < 4; y++) {
        for (let x = 5; x < 11; x++) {
          if (r("blot", x, y) < 0.12) continue;
          g[y][x] = y < 2 ? "wet" : (r("blot2", x, y) < 0.6 ? "wet" : "run");
        }
      }
      // One main run that wanders, narrowing and fading as it falls.
      let cx = 7;
      for (let y = 3; y < H; y++) {
        const f = 1 - (y - 3) / (H - 3);
        if (r("wander", cx, y) < 0.16) cx += r("dir", cx, y) < 0.5 ? -1 : 1;
        cx = Math.max(1, Math.min(W - 3, cx));
        const wide = f > 0.55 ? 2 : 1;
        for (let w = 0; w < wide; w++) {
          const x = cx + w;
          if (r("run", x, y) > 0.35 + 0.6 * f) continue;
          g[y][x] = f > 0.6 ? "wet" : f > 0.3 ? "run" : "trail";
        }
        // A soft halo, so the run sits in the surface instead of on it.
        for (const x of [cx - 1, cx + wide]) {
          if (x < 0 || x >= W) continue;
          if (g[y][x] !== "." || r("halo", x, y) > 0.3 * f) continue;
          g[y][x] = "haze";
        }
      }
      // A secondary trail, fainter and shorter: real leaks are not tidy.
      let sx = 11;
      for (let y = 5; y < 30; y++) {
        const f = 1 - (y - 5) / 25;
        if (r("w2", sx, y) < 0.12) sx += r("d2", sx, y) < 0.5 ? -1 : 1;
        sx = Math.max(1, Math.min(W - 2, sx));
        if (r("s2", sx, y) > 0.30 + 0.4 * f) continue;
        g[y][sx] = f > 0.5 ? "run" : "haze";
      }
      return g;
    },
  },
  {
    id: "decal_grime", title: "accumulated grime patch",
    size: [32, 32], metres: [1.0, 1.0],
    surfaces: ["wall", "floor", "ceiling"], orientation: "any rotation",
    why: "an accumulation has no up. Rotating it is how one asset stops "
       + "reading as the same asset.",
    palette: [
      { name: "deep", value: [36, 31, 28, 130] },
      { name: "mid", value: [78, 67, 60, 95] },
      { name: "thin", value: [123, 106, 96, 60] },
      { name: "edge", value: [123, 106, 96, 28] },
    ],
    draw(g, r) {
      const N = 32, c = 15.5;
      for (let y = 0; y < N; y++) {
        for (let x = 0; x < N; x++) {
          const dx = (x - c) / c, dy = (y - c) / c;
          const a = Math.atan2(dy, dx);
          // A warped radius, so the patch is a shape and not a disc.
          const warp = 0.72
            + 0.22 * Math.sin(a * 3 + r("a", 0, 0) * 6.28)
            + 0.13 * Math.sin(a * 5 + r("b", 0, 0) * 6.28);
          const d = Math.hypot(dx, dy) / warp;
          if (d > 1) continue;
          const n = r("n", x, y) * 0.42;
          const v = 1 - d + n - 0.21;
          if (v > 0.62) g[y][x] = "deep";
          else if (v > 0.38) g[y][x] = "mid";
          else if (v > 0.16) g[y][x] = "thin";
          else if (v > 0.02) g[y][x] = "edge";
        }
      }
      return g;
    },
  },
  {
    id: "decal_scuff", title: "scuff / scrape",
    size: [24, 8], metres: [0.75, 0.25],
    surfaces: ["wall", "floor"],
    orientation: "wall: horizontal only, 0.3-1.1 m up; floor: any rotation",
    why: "on a wall a scrape is made by something passing at a height, so "
       + "it is level. On a floor there is no height and no level.",
    palette: [
      // A scrape EXPOSES pale substrate; it does not add dirt. Taken from
      // the concrete base ramp rather than the grime family for that reason.
      { name: "bare", value: [232, 236, 228, 140] },
      { name: "worn", value: [140, 142, 138, 105] },
      { name: "bite", value: [98, 99, 96, 120] },
    ],
    draw(g, r) {
      const W = 24, H = 8;
      // FIRST VERSION READ AS A ROW OF BLOCKS, NOT A SCRAPE. It dropped
      // pixels at a flat rate along every stroke, so each stroke came apart
      // into pieces and the mark had no direction. A scrape is CONTINUOUS
      // where the thing bore down and breaks up only as it lifts, so the
      // strokes are solid through the middle and taper at the ends -- and
      // they all taper the same way, because one object made all of them.
      const strokes = [[0, 2, 22], [2, 3, 20], [1, 5, 23], [5, 6, 16]];
      for (const [x0, y, len] of strokes) {
        for (let i = 0; i < len; i++) {
          const x = x0 + i;
          if (x >= W) break;
          // 0 at the ends, 1 through the middle two thirds.
          const solid = Math.min(1, Math.min(i, len - 1 - i) / (len * 0.22));
          // The lift is at the RIGHT end on every stroke: one direction.
          const lift = i > len * 0.72 ? (i - len * 0.72) / (len * 0.28) : 0;
          const keep = solid * (1 - lift * 0.85);
          if (r("stroke", x, y) > 0.12 + 0.88 * keep) continue;
          g[y][x] = r("tone", x, y) < 0.55 + 0.3 * keep ? "bare" : "worn";
        }
      }
      // The bitten edge, along the BOTTOM of the whole mark rather than
      // under each stroke: the material lifted once, at the lower lip.
      for (let x = 0; x < W; x++) {
        let lowest = -1;
        for (let y = 0; y < H - 1; y++) if (g[y][x] !== ".") lowest = y;
        if (lowest < 0) continue;
        if (r("bite", x, lowest) < 0.55) g[lowest + 1][x] = "bite";
      }
      return g;
    },
  },
  {
    id: "decal_stencil", title: "sprayed maintenance stencil",
    size: [24, 16], metres: [0.75, 0.5],
    surfaces: ["wall"], orientation: "upright only",
    why: "it is lettering. Rotating it makes it unreadable, and an "
       + "unreadable mark that used to be readable looks like a mistake.",
    palette: [
      // concrete_facility's OWN accent, dark step: institutional paint.
      // Deliberately far from every reserved universal colour -- this is
      // decoration and may not look like an affordance.
      { name: "paint", value: [49, 69, 89, 205] },
      { name: "faded", value: [79, 111, 143, 130] },
      { name: "mist", value: [79, 111, 143, 55] },
    ],
    draw(g, r) {
      // "SUB" from the house 3x5 alphabet at 2x: 0.31 m tall, which is a
      // real stencil at 32 texels/m and legible across a corridor.
      const word = "SUB", scale = 2;
      let ox = 2;
      for (const ch of word) {
        const rowsG = GLYPHS[ch];
        for (let gy = 0; gy < 5; gy++) {
          for (let gx = 0; gx < 3; gx++) {
            if (rowsG[gy][gx] !== "#") continue;
            for (let sy = 0; sy < scale; sy++) {
              for (let sx = 0; sx < scale; sx++) {
                const x = ox + gx * scale + sx, y = 4 + gy * scale + sy;
                if (x >= 24 || y >= 16) continue;
                // Chipping: paint on concrete does not stay whole.
                if (r("chip", x, y) < 0.14) continue;
                g[y][x] = r("wear", x, y) < 0.22 ? "faded" : "paint";
              }
            }
          }
        }
        ox += 3 * scale + 2;
      }
      // Over-spray: the halo a can leaves outside its stencil.
      for (let y = 0; y < 16; y++) {
        for (let x = 0; x < 24; x++) {
          if (g[y][x] !== ".") continue;
          let near = false;
          for (let dy = -2; dy <= 2 && !near; dy++) {
            for (let dx = -2; dx <= 2; dx++) {
              const yy = y + dy, xx = x + dx;
              if (yy < 0 || xx < 0 || yy >= 16 || xx >= 24) continue;
              if (g[yy][xx] === "paint" || g[yy][xx] === "faded") { near = true; break; }
            }
          }
          if (near && r("mist", x, y) < 0.22) g[y][x] = "mist";
        }
      }
      return g;
    },
  },
  {
    id: "decal_scorch", title: "scorch mark",
    size: [32, 32], metres: [1.0, 1.0],
    surfaces: ["wall", "floor", "ceiling"], orientation: "any rotation",
    why: "a burn radiates from a point and has no up.",
    palette: [
      { name: "char", value: [26, 21, 18, 225] },
      { name: "soot", value: [58, 50, 44, 165] },
      { name: "smoke", value: [107, 96, 88, 95] },
      { name: "ash", value: [107, 96, 88, 40] },
    ],
    draw(g, r) {
      const N = 32, c = 15.5;
      for (let y = 0; y < N; y++) {
        for (let x = 0; x < N; x++) {
          const dx = (x - c) / c, dy = (y - c) / c;
          const a = Math.atan2(dy, dx);
          // Rounder than the grime patch, and ragged at a finer angular
          // frequency: heat spreads evenly and then tears at the rim.
          const warp = 0.86 + 0.10 * Math.sin(a * 7 + r("p", 0, 0) * 6.28)
                            + 0.06 * Math.sin(a * 11);
          const d = Math.hypot(dx, dy) / warp;
          if (d > 1) continue;
          const n = r("n", x, y) * 0.3;
          if (d < 0.30 + n * 0.2) g[y][x] = "char";
          else if (d < 0.55 + n * 0.3) g[y][x] = r("s", x, y) < 0.85 ? "soot" : "char";
          else if (d < 0.80 + n * 0.3) g[y][x] = "smoke";
          else if (r("a", x, y) < 0.55) g[y][x] = "ash";
        }
      }
      // Streaks licking outward from the core, which is what separates a
      // burn from a stain.
      for (let k = 0; k < 9; k++) {
        const ang = (k / 9) * 6.28 + r("ang", k, 0) * 0.7;
        const len = 9 + Math.floor(r("len", k, 0) * 6);
        for (let i = 6; i < len + 6; i++) {
          const x = Math.round(c + Math.cos(ang) * i);
          const y = Math.round(c + Math.sin(ang) * i);
          if (x < 0 || y < 0 || x >= N || y >= N) break;
          if (r("lick", x, y) > 0.55) continue;
          g[y][x] = i < len * 0.6 ? "soot" : "smoke";
        }
      }
      return g;
    },
  },
  {
    id: "decal_splatter", title: "splatter",
    size: [24, 24], metres: [0.75, 0.75],
    surfaces: ["wall", "floor"], orientation: "any rotation",
    why: "it lands from a direction, but which direction is the placer's "
       + "to choose, so the asset does not fix one.",
    palette: [
      { name: "wet", value: [36, 31, 28, 190] },
      { name: "spot", value: [78, 67, 60, 150] },
      { name: "fleck", value: [78, 67, 60, 95] },
    ],
    draw(g, r) {
      const N = 24, c = 11.5;
      // The main mass, small and off-centre: a splatter is mostly droplets.
      for (let y = 0; y < N; y++) {
        for (let x = 0; x < N; x++) {
          const d = Math.hypot((x - c + 1) / 5.5, (y - c + 1) / 4.5);
          if (d > 1 + r("m", x, y) * 0.45) continue;
          g[y][x] = d < 0.6 ? "wet" : "spot";
        }
      }
      // Droplets, thinning outward. Size falls with distance because a
      // droplet that carries further carries less.
      //
      // A radius-1 disc on an integer grid is a PLUS SIGN, which is what the
      // first version drew: five little crosses round the mark, and at 9x
      // they read as symbols rather than as spatter. A near droplet is a
      // 2x2 block, a far one is a single pixel, and neither is a cross.
      for (let k = 0; k < 16; k++) {
        const ang = r("ang", k, 0) * 6.28;
        const dist = 4 + r("dist", k, 0) * 8;
        const px = Math.round(c + Math.cos(ang) * dist);
        const py = Math.round(c + Math.sin(ang) * dist);
        const cells = dist < 7
          ? [[0, 0], [1, 0], [0, 1], [1, 1]].filter(
              ([dx, dy]) => r("bit", px + dx, py + dy) > 0.18)
          : [[0, 0]];
        for (const [dx, dy] of cells) {
          const x = px + dx, y = py + dy;
          if (x < 0 || y < 0 || x >= N || y >= N) continue;
          g[y][x] = dist < 7 ? "spot" : "fleck";
        }
      }
      return g;
    },
  },
];

// -- author, look, and record ---------------------------------------------
const made = [];
for (const d of KIT) {
  const [W, H] = d.size;
  const easel = await newEasel({
    path: join(DIR, `${d.id}.glyph`), owner: OWNER, artist: ARTIST,
    name: d.id, width: W, height: H, palette: d.palette, partialAlpha: true,
  });
  const g = d.draw(grid(W, H), mk(d.id));
  const symbols = Object.fromEntries(d.palette.map((e) => [e.name, e.name]));
  // Symbols are one character, so map names to letters for the patch.
  const letter = Object.fromEntries(
    d.palette.map((e, i) => [e.name, String.fromCharCode(97 + i)]));
  const lettered = g.map((row) => row.map((c) => c === "." ? "." : letter[c]));
  const sym = Object.fromEntries(
    d.palette.map((e, i) => [String.fromCharCode(97 + i), e.name]));
  void symbols;
  await easel.draw(`${d.title}: ${d.why}`,
    (b) => b.patch({ origin: [0, 0], rows: rows(lettered), symbols: sym }));

  const native = await easel.view({ scale: 1, into: join(DIR, `${d.id}.png`) });
  const big = await easel.view({ scale: 8, into: join(DIR, `${d.id}_8x.png`) });
  // A transparent mark on a transparent ground is invisible, so it is also
  // laid over the wall it is meant for -- which is the surface it will be
  // judged against in the room anyway.
  const onWall = await easel.study({
    from: big, over: { image: join(OUT, "wall_field.png") },
    into: join(DIR, `${d.id}_on_wall.png`),
  });
  const onChecker = await easel.study({
    from: big, over: "checker", into: join(DIR, `${d.id}_checker.png`),
  });

  made.push({
    id: d.id, title: d.title,
    native_size: d.size, metres: d.metres,
    texels_per_metre: DENSITY,
    surfaces: d.surfaces, orientation: d.orientation, why: d.why,
    palette: d.palette.map((e) => ({ name: e.name, rgba: e.value })),
    images: { native: native.image, enlarged: big.image,
              on_wall: onWall.image, on_checker: onChecker.image },
    render_sha256: native.record.render_created.sha256,
    verified: native.check.render_created && big.check.render_created,
  });
  console.log(`[decal] ${d.id.padEnd(16)} ${W}x${H} = ${d.metres[0]}x${d.metres[1]} m`);
}

const manifest = {
  _comment: [
    "The Archipepsi decal kit, authored in ECMS Glyph. TRIAL ART: it ships",
    "nowhere, is in no content manifest, and changes no approved asset.",
    "Physical size is authoritative -- a decal card is built from `metres`,",
    "never from the pixel size, so a texture rework cannot silently resize",
    "a mark in the world.",
  ],
  glyph_root: GLYPH_ROOT,
  glyph_sha: GLYPH_SHA,
  owner: OWNER, artist: ARTIST,
  texels_per_metre: DENSITY,
  decals: made,
  elapsed_ms: Math.round(performance.now() - t0),
};
writeFileSync(join(OUT, "decal_kit.json"),
              JSON.stringify(manifest, null, 2) + "\n");
console.log(`[decal] six marks in ${manifest.elapsed_ms} ms -> decal_kit.json`);
