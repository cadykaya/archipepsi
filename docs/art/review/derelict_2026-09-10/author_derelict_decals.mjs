// Archipepsi x ECMS Glyph -- the Derelict decal extension.
//
//   GLYPH_ROOT=/path/to/ecms-glyph node author_derelict_decals.mjs [outdir]
//
// FOUR NEW MARKS, AND FOUR REUSED. The brief asks for marks that strengthen
// this theme, not six near-duplicates to fill a list, so the neutral kit
// from Batch 041 is reused wherever it already serves:
//
//   REUSED  decal_grime     accumulated grime -- dirt is dirt in any theme
//   REUSED  decal_scorch    restrained impact/scorch damage
//   REUSED  decal_scuff     wear where things pass
//   REUSED  decal_stencil   the non-gameplay compartment stencil
//   NEW     decal_coolant       a COLD condensation trail, which is a
//                               different event from the warm grime run
//                               `decal_drip` records
//   NEW     decal_corroded_seam corrosion following a weld, which only
//                               exists because this theme HAS welds
//   NEW     decal_panel_removed a bay whose cover is gone: the one mark
//                               that says "maintained, intermittently"
//   NEW     decal_inspection    a small dated inspection mark
//
// `decal_drip` and `decal_splatter` are deliberately NOT carried over. A
// warm brown run and a splatter belong to a wet, dirty building; this one
// is cold and dry, and reusing them would be filling a list.
//
// NON-GAMEPLAY, NON-SEMANTIC. Nothing here is interactive, nothing marks an
// affordance, and every colour is measured against the protected families
// by tools/content/check_decal_colours.py.

import { mkdirSync, writeFileSync, readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { execFileSync } from "node:child_process";

const t0 = performance.now();
const HERE = dirname(fileURLToPath(import.meta.url));
const GLYPH_ROOT = process.env.GLYPH_ROOT ?? "/home/user/ecms-glyph";
const GLYPH_SHA = (() => {
  try {
    return execFileSync("git", ["-C", GLYPH_ROOT, "rev-parse", "HEAD"],
                        { encoding: "utf8" }).trim();
  } catch { return "unknown"; }
})();
const { newEasel } = await import(
  pathToFileURL(join(GLYPH_ROOT, "tools", "easel.mjs")).href);

const OUT = process.argv[2] ?? ".";
const DIR = join(OUT, "decals");
mkdirSync(DIR, { recursive: true });
const OWNER = "act_owner_skyiah";
const ARTIST = "act_agent_arty";
const DENSITY = 32;

const PAL = JSON.parse(readFileSync(join(HERE, "derelict_palette.json"), "utf8"));
const rgb = (h) => {
  const s = h.replace("#", "");
  return [0, 2, 4].map((i) => parseInt(s.slice(i, i + 2), 16));
};
const ramp = (role, i) => rgb(PAL.roles[role].ramp[i]);

function hash32(str) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0;
  }
  h ^= h >>> 16; h = Math.imul(h, 2246822507) >>> 0;
  h ^= h >>> 13; h = Math.imul(h, 3266489909) >>> 0;
  return (h ^ (h >>> 16)) >>> 0;
}
const mk = (seed) => (w, x, y) =>
  hash32(`archipepsi/derelict-decal/${seed}/${w}/${x}/${y}`) / 4294967295;
const grid = (w, h) => Array.from({ length: h }, () => Array(w).fill("."));
const rows = (g) => g.map((r) => r.join(""));

// The house 3x5 stencil alphabet, from tools/blender/paintkit.py.
const GLYPHS = {
  A: ["###", "# #", "###", "# #", "# #"], C: ["###", "#  ", "#  ", "#  ", "###"],
  E: ["###", "#  ", "## ", "#  ", "###"], H: ["# #", "# #", "###", "# #", "# #"],
  K: ["# #", "# #", "## ", "# #", "# #"], P: ["###", "# #", "###", "#  ", "#  "],
};

const KIT = [
  {
    id: "decal_coolant", title: "condensation / coolant trail",
    size: [16, 40], metres: [0.5, 1.25],
    surfaces: ["wall"], orientation: "upright only",
    why: "it runs down. And it is COLD and pale where `decal_drip` is warm "
       + "and brown, so it reads as a line that froze rather than as dirt.",
    palette: [
      { name: "wet", value: [...ramp("base", 3), 175] },
      { name: "film", value: [...ramp("base", 3), 95] },
      { name: "haze", value: [...ramp("base", 2), 55] },
      { name: "shade", value: [...ramp("floor", 0), 70] },
    ],
    draw(g, r) {
      const W = 16, H = 40;
      // A wet head at the top, then a run that thins and beads.
      for (let y = 0; y < 3; y++) {
        for (let x = 6; x < 11; x++) {
          if (r("head", x, y) < 0.2) continue;
          g[y][x] = "wet";
        }
      }
      let cx = 8;
      for (let y = 2; y < H; y++) {
        const f = 1 - (y - 2) / (H - 2);
        if (r("wander", cx, y) < 0.14) cx += r("dir", cx, y) < 0.5 ? -1 : 1;
        cx = Math.max(1, Math.min(W - 3, cx));
        // Beads: a cold trail is not continuous, it hangs and drops.
        const bead = r("bead", cx, y) < 0.30 + 0.35 * f;
        if (bead) {
          g[y][cx] = f > 0.45 ? "wet" : "film";
          if (r("wide", cx, y) < 0.35 * f) g[y][cx + 1] = "film";
        }
        // A shadow on one side only, so it sits on the surface.
        if (g[y][cx] !== "." && r("sh", cx, y) < 0.5) {
          g[y][Math.max(0, cx - 1)] = "shade";
        }
        if (g[y][cx] === "." && r("haze", cx, y) < 0.22 * f) g[y][cx] = "haze";
      }
      return g;
    },
  },
  {
    id: "decal_corroded_seam", title: "corroded seam",
    size: [32, 8], metres: [1.0, 0.25],
    surfaces: ["wall"],
    orientation: "aligned to a seam: horizontal on a weld, rotated 90 deg "
               + "on a stringer. Never free-floating.",
    why: "corrosion follows the joint it started in. Placed off a seam it "
       + "is a stain, and this theme already has one of those.",
    palette: [
      { name: "bloom", value: [123, 106, 96, 165] },
      { name: "oxide", value: [78, 67, 60, 195] },
      { name: "pit", value: [36, 31, 28, 205] },
      { name: "creep", value: [123, 106, 96, 80] },
    ],
    draw(g, r) {
      const W = 32, H = 8;
      // The seam line sits at mid-height; corrosion grows out of it.
      const mid = 3;
      for (let x = 0; x < W; x++) {
        // How far the bloom has crept here, 0..1, varying slowly along.
        const reach = 0.35 + 0.65 * r("reach", x - (x % 4), 0);
        for (let dy = -3; dy <= 4; dy++) {
          const y = mid + dy;
          if (y < 0 || y >= H) continue;
          const d = Math.abs(dy) / 3.5;
          if (d > reach) continue;
          if (r("edge", x, y) > 1.05 - d) continue;
          g[y][x] = d < 0.25 ? "pit" : d < 0.6 ? "oxide" : "bloom";
        }
        if (g[mid][x] === ".") g[mid][x] = "oxide";
      }
      // A faint creep beyond the bloom, so the mark has no hard boundary.
      for (let x = 0; x < W; x++) {
        for (let y = 0; y < H; y++) {
          if (g[y][x] !== "." || r("creep", x, y) > 0.16) continue;
          g[y][x] = "creep";
        }
      }
      return g;
    },
  },
  {
    id: "decal_panel_removed", title: "removed-panel outline",
    size: [24, 24], metres: [0.75, 0.75],
    surfaces: ["wall"], orientation: "upright only",
    why: "a bay is square to the structure it sits in. Rotated off axis it "
       + "stops reading as a missing cover and starts reading as damage.",
    palette: [
      // The substrate a cover has been protecting is CLEANER than the wall
      // around it, which is the whole tell. Taken from the base ramp's
      // light step rather than from the grime family for that reason.
      { name: "clean", value: [...ramp("base", 3), 120] },
      { name: "rim", value: [...ramp("trim", 0), 190] },
      { name: "hole", value: [...ramp("trim", 0), 225] },
      { name: "lip", value: [...ramp("base", 3), 150] },
      { name: "dirt", value: [78, 67, 60, 90] },
    ],
    draw(g, r) {
      const N = 24;
      // The protected square, paler than the wall it is cut into.
      for (let y = 2; y < N - 2; y++) {
        for (let x = 2; x < N - 2; x++) {
          if (r("clean", x, y) < 0.12) continue;
          g[y][x] = "clean";
        }
      }
      // A recessed rim: shadow on the top and left, a lit lip below right.
      for (let i = 2; i < N - 2; i++) {
        g[2][i] = "rim"; g[i][2] = "rim";
        g[N - 3][i] = "lip"; g[i][N - 3] = "lip";
      }
      // Four fastener holes, which is what tells you it was BOLTED on.
      for (const [x, y] of [[5, 5], [N - 6, 5], [5, N - 6], [N - 6, N - 6]]) {
        g[y][x] = "hole"; g[y][x + 1] = "hole";
        g[y + 1][x] = "hole"; g[y + 1][x + 1] = "hole";
      }
      // Dirt banked against the outside of the rim, where the cover met it.
      for (let y = 0; y < N; y++) {
        for (let x = 0; x < N; x++) {
          if (g[y][x] !== ".") continue;
          const near = Math.min(Math.abs(y - 1), Math.abs(y - (N - 2)),
                                Math.abs(x - 1), Math.abs(x - (N - 2)));
          if (near > 1 || r("dirt", x, y) > 0.5) continue;
          g[y][x] = "dirt";
        }
      }
      return g;
    },
  },
  {
    id: "decal_inspection", title: "maintenance inspection mark",
    size: [16, 8], metres: [0.5, 0.25],
    surfaces: ["wall"], orientation: "upright only",
    why: "it is lettering, and it is small on purpose: an inspection mark "
       + "is for whoever is standing at the panel, not for the room.",
    palette: [
      { name: "ink", value: [...ramp("accent", 0), 200] },
      { name: "faded", value: [...ramp("accent", 1), 120] },
      { name: "box", value: [...ramp("base", 3), 90] },
    ],
    draw(g, r) {
      // A stencilled box with two letters in it: CHK. Three at 3x5 with
      // one-texel gaps is 11 wide, which fits 16 with a box round it.
      for (let x = 1; x < 15; x++) { g[0][x] = "box"; g[7][x] = "box"; }
      for (let y = 0; y < 8; y++) { g[y][1] = "box"; g[y][14] = "box"; }
      let ox = 3;
      for (const ch of "CHK") {
        const rowsG = GLYPHS[ch];
        for (let gy = 0; gy < 5; gy++) {
          for (let gx = 0; gx < 3; gx++) {
            if (rowsG[gy][gx] !== "#") continue;
            if (r("chip", ox + gx, gy) < 0.10) continue;
            g[gy + 1][ox + gx] = r("wear", ox + gx, gy) < 0.25 ? "faded" : "ink";
          }
        }
        ox += 4;
      }
      return g;
    },
  },
];

const made = [];
for (const d of KIT) {
  const [W, H] = d.size;
  const letter = Object.fromEntries(
    d.palette.map((e, i) => [e.name, String.fromCharCode(97 + i)]));
  const sym = Object.fromEntries(
    d.palette.map((e, i) => [String.fromCharCode(97 + i), e.name]));
  const easel = await newEasel({
    path: join(DIR, `${d.id}.glyph`), owner: OWNER, artist: ARTIST,
    name: d.id, width: W, height: H, palette: d.palette, partialAlpha: true,
  });
  const g = d.draw(grid(W, H), mk(d.id));
  const lettered = g.map((row) => row.map((c) => c === "." ? "." : letter[c]));
  await easel.draw(`${d.title}: ${d.why}`,
    (b) => b.patch({ origin: [0, 0], rows: rows(lettered), symbols: sym }));

  const native = await easel.view({ scale: 1, into: join(DIR, `${d.id}.png`) });
  const big = await easel.view({ scale: 8, into: join(DIR, `${d.id}_8x.png`) });
  const onWall = await easel.study({
    from: big, over: { image: join(OUT, "derelict_wall.png") },
    into: join(DIR, `${d.id}_on_wall.png`) });
  const onChecker = await easel.study({
    from: big, over: "checker", into: join(DIR, `${d.id}_checker.png`) });

  made.push({
    id: d.id, title: d.title, origin: "new for deep_space_derelict",
    native_size: d.size, metres: d.metres, texels_per_metre: DENSITY,
    surfaces: d.surfaces, orientation: d.orientation, why: d.why,
    palette: d.palette.map((e) => ({ name: e.name, rgba: e.value })),
    images: { native: native.image, enlarged: big.image,
              on_wall: onWall.image, on_checker: onChecker.image },
    render_sha256: native.record.render_created.sha256,
    verified: native.check.render_created && big.check.render_created,
  });
  console.log(`[decal] NEW    ${d.id.padEnd(21)} ${W}x${H} = ${d.metres[0]}x${d.metres[1]} m`);
}

// The neutral kit, reused rather than redrawn.
const REUSED = [
  ["decal_grime", "accumulated grime patch", "dirt is dirt in any theme"],
  ["decal_scorch", "scorch mark", "restrained impact damage, already neutral"],
  ["decal_scuff", "scuff / scrape", "wear where things pass"],
  ["decal_stencil", "compartment stencil", "the non-gameplay label already serves"],
];
const prior = JSON.parse(readFileSync(
  join(HERE, "..", "glyph_layers_2026-09-10", "decal_kit.json"), "utf8"));
const reused = REUSED.map(([id, title, why]) => {
  const e = prior.decals.find((x) => x.id === id);
  if (!e) throw new Error(`reused decal ${id} is not in the Batch 041 kit`);
  return {
    id, title, origin: "reused from the Batch 041 neutral kit", why,
    native_size: e.native_size, metres: e.metres,
    surfaces: e.surfaces, orientation: e.orientation,
    source: "docs/art/review/glyph_layers_2026-09-10/decals/",
    render_sha256: e.render_sha256,
  };
});
for (const e of reused) console.log(`[decal] REUSED ${e.id.padEnd(21)} ${e.metres[0]}x${e.metres[1]} m`);

const manifest = {
  _comment: [
    "The deep_space_derelict decal extension. TRIAL ART: it ships nowhere,",
    "is in no content manifest, and changes no approved asset. Physical size",
    "is authoritative -- a card is built from `metres`, never from pixels.",
    "Nothing here is interactive or semantic.",
    "",
    "decal_drip and decal_splatter from the neutral kit are deliberately NOT",
    "carried over: a warm brown run and a splatter belong to a wet, dirty",
    "building, and this one is cold and dry.",
  ],
  glyph_root: GLYPH_ROOT, glyph_sha: GLYPH_SHA,
  owner: OWNER, artist: ARTIST, texels_per_metre: DENSITY,
  decals: made, reused,
  elapsed_ms: Math.round(performance.now() - t0),
};
writeFileSync(join(OUT, "decal_kit.json"),
              JSON.stringify(manifest, null, 2) + "\n");
console.log(`[decal] ${made.length} new + ${reused.length} reused in ${manifest.elapsed_ms} ms`);
