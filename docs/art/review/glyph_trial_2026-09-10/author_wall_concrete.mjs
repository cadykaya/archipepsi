// Archipepsi x ECMS Glyph -- one ordinary concrete_facility wall texture.
//
//   GLYPH_ROOT=/path/to/ecms-glyph node author_wall_concrete.mjs [outdir]
//
// WHAT THIS IS. The first Archipepsi texture authored through Glyph rather
// than through `tools/blender/materials.py`. It is a TRIAL: nothing here
// ships, no approved asset is touched, and the result is not a promotion.
//
// WHOSE WORK IT IS. Skyiah is the Lead Owner and authorises every
// transaction; Arty is the agent artist and dispatches every command.
// MAKING_ART_WITH_GLYPH.md is explicit that these are two identities and
// that collapsing them has already gone wrong once in Glyph's own history,
// so `on_behalf_of` carries the owner and the artist is never the owner.
//
// WHERE THE NUMBERS COME FROM. Not from taste. `assets/art_palette.json`
// gives concrete_facility's solved ramps, and `tools/blender/materials.py`
// gives the structure: a 128 px tile at 32 texels/m is 4.00 m of wall,
// panel courses every 1.2 m, vertical joints every 2.0 m, bolts at 0.5 m on
// the seams, and a dark base course over the bottom 0.85 m. Every constant
// below is that arithmetic, not a number that looked right.
//
// NO HAZARD MARKINGS. This is an ordinary corridor wall. Danger markings
// stay reserved for danger.

import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const GLYPH_ROOT = process.env.GLYPH_ROOT ?? "/home/user/ecms-glyph";
const { newEasel } = await import(
  pathToFileURL(join(GLYPH_ROOT, "tools", "easel.mjs")).href);

const t0 = performance.now();
const OUT = process.argv[2] ?? ".";
mkdirSync(OUT, { recursive: true });

const OWNER = "act_owner_skyiah";
const ARTIST = "act_agent_arty";

// -- the surface, in metres before texels ---------------------------------
const SIZE = 128;                       // texels along one edge
const DENSITY = 32;                     // texels per metre (architecture budget)
const METRES = SIZE / DENSITY;          // 4.00 m
const t = (m) => Math.max(1, Math.round(m * DENSITY));

const COURSE_PITCH = t(1.2);            // 38 -- horizontal panel courses
const JOINT_PITCH = t(2.0);             // 64 -- vertical panel joints
const BOLT_PITCH = t(0.5);              // 16
const BASE_COURSE = t(0.85);            // 27 -- the dark bottom band
const BASE_TOP = SIZE - BASE_COURSE;    // 101
const SEAMS = [];
for (let y = 0; y < SIZE; y += COURSE_PITCH) SEAMS.push(y);   // 0 38 76 114

// -- the palette, derived from the shipped ramps ---------------------------
// concrete_facility base #626360 #8c8e8a #b9bcb6 #e8ece4, accent #6f9cc8,
// trim #2e3338, and the shared `grime` family every theme uses so six
// material families look like one world. The field is the mid base step
// tinted 10% toward the accent, because the owner's facility language is
// "cold gray concrete, white / pale blue" and neutral grey is not it.
const PALETTE = [
  { name: "field", value: [178, 185, 184, 255] },
  { name: "field_dark", value: [168, 174, 172, 255] },
  { name: "field_light", value: [192, 198, 195, 255] },
  { name: "seam_shadow", value: [98, 99, 96, 255] },
  { name: "seam_lip", value: [232, 236, 228, 255] },
  { name: "course", value: [114, 116, 114, 255] },
  { name: "course_lip", value: [125, 126, 122, 255] },
  { name: "course_under", value: [46, 51, 56, 255] },
  { name: "course_grit", value: [106, 108, 105, 255] },
  { name: "grime", value: [78, 67, 60, 255] },
  { name: "grime_soft", value: [156, 159, 157, 255] },
  { name: "speck", value: [142, 146, 144, 255] },
];

// One symbol per entry, for the dense patches below.
const SYM = {
  ".": null, f: "field", d: "field_dark", l: "field_light",
  s: "seam_shadow", L: "seam_lip", c: "course", C: "course_lip",
  u: "course_under", g: "grime", G: "grime_soft", k: "speck",
  p: "course_grit",
};
const symbols = Object.fromEntries(
  Object.entries(SYM).filter(([, v]) => v).map(([k, v]) => [k, v]));

// -- determinism ----------------------------------------------------------
// `paintkit` breaks its own ties with a seeded hash so a rebuild is the same
// wall. Same idea, self-contained, so this script reproduces without
// importing the Blender lane.
//
// PASS 1 FAILED HERE, and the failure is kept because it is instructive.
// The first version was FNV-1a alone and read out as `h / 2**32`. `y` is the
// last thing hashed, one `imul` does not carry the low bits up into the high
// bits that division reads, and so the tie-breaker was very nearly CONSTANT
// IN Y: measured, 83.2% of vertical neighbours agreed to within 0.02 against
// 3.3% of horizontal ones. Every patch came out a column, the wall read as
// vertical streaking, and `passes/pass1_vertical_striping_8x.png` is what
// that looks like. The fix is a murmur3 `fmix32` avalanche after the loop, so
// the last byte reaches the top bits. Verified the same way it was found.
function hash32(str) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0;
  }
  h ^= h >>> 16; h = Math.imul(h, 2246822507) >>> 0;
  h ^= h >>> 13; h = Math.imul(h, 3266489909) >>> 0;
  return (h ^ (h >>> 16)) >>> 0;
}
const breaker = (what, x, y) =>
  hash32(`archipepsi/concrete_facility/wall/${what}/${x}/${y}`) / 4294967295;

// A blank grid of "leave this alone".
const blank = () =>
  Array.from({ length: SIZE }, () => Array(SIZE).fill("."));
const rowsOf = (grid) => grid.map((r) => r.join(""));

// =========================================================================
// PASS 1 -- the pour
// A flat fill is not a surface. Broad patches at a 0.55 m cell are big
// enough to read AS marks on a wall; at 2 texels they would be noise, which
// is the mistake paintkit's own docstring records making twice.
// =========================================================================
function pour() {
  const g = blank();
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) g[y][x] = "f";
  const cell = t(0.55);                                     // 18
  for (let row = 0, cy = -cell; cy < SIZE + cell; cy += cell, row++) {
    const shift = Math.floor(breaker("row", row, 0) * cell);
    for (let cx = -cell; cx < SIZE + cell; cx += cell) {
      const r = breaker("patch", cx + shift, cy);
      if (r > 0.22) continue;                               // density
      const step = breaker("step", cx, cy) < 0.5 ? "d" : "l";
      const w = cell + Math.floor(breaker("w", cx, cy) * cell);
      const h = cell + Math.floor(breaker("h", cx, cy) * cell);
      const rim = Math.max(2, Math.round(cell * 0.35));
      for (let y = cy; y < cy + h; y++) {
        for (let x = cx + shift; x < cx + shift + w; x++) {
          if (x < 0 || y < 0 || x >= SIZE || y >= SIZE) continue;
          // Ragged EDGE, not ragged everywhere: a pour mark has no straight
          // side, but it is solid in the middle. Dropout rises toward the
          // rim and is zero deeper in, so the patch reads as one mark.
          const din = Math.min(y - cy, cy + h - 1 - y,
                               x - (cx + shift), cx + shift + w - 1 - x);
          const edginess = din >= rim ? 0 : 1 - din / rim;
          if (breaker("edge", x, y) < 0.55 * edginess) continue;
          g[y][x] = step;
        }
      }
    }
  }
  return g;
}

// =========================================================================
// PASS 2 -- the panels
// A 4 m span of unbroken surface is not a panel, it is a wall with lines on
// it, so the tile is divided in BOTH axes. Bolts sit ON the seams at the
// surface's own pitch: a bolt that is not on a seam is a speck.
// =========================================================================
function panels(g) {
  for (const y of SEAMS) {
    for (let x = 0; x < SIZE; x++) {
      g[y][x] = "s";
      if (y + 1 < SIZE) g[y + 1][x] = "L";
    }
  }
  for (let x = 0; x < SIZE; x += JOINT_PITCH) {
    for (let y = 0; y < SIZE; y++) {
      g[y][x] = "s";
      if (x + 1 < SIZE) g[y][x + 1] = "L";
    }
  }
  for (const seam of SEAMS) {
    const y = seam - 2;
    if (y < 1) continue;
    for (let x = BOLT_PITCH >> 1; x < SIZE; x += BOLT_PITCH) {
      g[y][x] = "s";
      g[y - 1][x] = "L";
    }
  }
  return g;
}

// =========================================================================
// PASS 3 -- the base course
// Real institutional buildings have one. It grounds a pale wall and it puts
// a hard value break exactly where the eye meets the floor, viewed from
// 1.6 m -- which is most of what "separate the floor from the walls" means.
// The 114 course survives inside it as its own shadow, one step darker,
// because the band darkens the field and not the seam.
// =========================================================================
function baseCourse(g) {
  for (let y = BASE_TOP; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      g[y][x] = g[y][x] === "s" ? "s" : g[y][x] === "L" ? "C" : "c";
    }
  }
  for (let x = 0; x < SIZE; x++) {
    g[BASE_TOP][x] = "L";
    g[BASE_TOP + 1][x] = "u";
  }
  return g;
}

// =========================================================================
// PASS 4 -- what the water and the grit have done
// A streak has to run down FROM something; streaks that come from nothing
// are a wall with a story nobody wrote. These run from the bolt line, and
// only from about three bolts in four. Grit gathers near the seams and
// along the floor, never as an even pepper over the tile.
// =========================================================================
function wear(g) {
  const length = t(0.7);                                    // 22
  for (const seam of SEAMS) {
    if (seam + 2 >= BASE_TOP) continue;
    for (let x = BOLT_PITCH >> 1; x < SIZE; x += BOLT_PITCH) {
      if (breaker("weep", x, seam) > 0.22) continue;
      for (let i = 0; i < length; i++) {
        const y = seam + 2 + i;
        if (y >= BASE_TOP) break;
        const fade = (1 - i / length);
        for (let w = 0; w < 2; w++) {
          const xx = x + w;
          if (xx >= SIZE) continue;
          if (g[y][xx] === "s" || g[y][xx] === "L") continue;
          if (breaker("streak", xx, y) > 0.25 + 0.6 * fade) continue;
          g[y][xx] = fade > 0.55 ? "g" : "G";
        }
      }
    }
  }
  // PASS 2 was too even and far too dark. Grit was scattered over half the
  // tile at a flat density, and inside the base course it was `course_under`
  // -- a 0.255 value jump per pixel, larger than the whole
  // `min_interactable_separation` of 0.18. That is not pitting, it is holes,
  // and an even pepper over half a wall is the digital camouflage paintkit's
  // own docstring records committing twice. So: grit is one small step off
  // its own ground (mix toward the concrete's dark step, as
  // `paintkit.speckle` does), the seam zone is the 0.25 m the seam actually
  // disturbs, and the density falls off across it instead of stopping dead.
  const reach = t(0.25);                                    // 8
  const nearSeam = (y) => Math.min(...SEAMS.map((s) => Math.abs(y - s)));
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      if (g[y][x] === "s" || g[y][x] === "L" || g[y][x] === "u") continue;
      const d = nearSeam(y);
      let zone = d <= reach ? 1 - d / (reach + 1) : 0;
      // And along the floor, where a corridor collects what it sweeps up.
      if (y > BASE_TOP) zone = Math.max(zone, 0.55);
      if (zone <= 0) continue;
      if (breaker("grit", x, y) > 0.045 * zone) continue;
      g[y][x] = g[y][x] === "c" || g[y][x] === "C" ? "p" : "k";
    }
  }
  return g;
}

// -- the loop -------------------------------------------------------------
const path = join(OUT, "archipepsi_concrete.glyph");
const easel = await newEasel({
  path, owner: OWNER, artist: ARTIST, name: "concrete_facility_wall",
  width: SIZE, height: SIZE, palette: PALETTE,
});

const g = pour();
await easel.draw(
  "the pour: a flat fill reads as plastic, so the field carries patch marks",
  (b) => b.patch({ origin: [0, 0], rows: rowsOf(g), symbols }));

panels(g);
await easel.draw(
  "four metres of unbroken wall is not a panel: courses at 1.2 m, joints at 2.0 m, bolts on the seams",
  (b) => b.patch({ origin: [0, 0], rows: rowsOf(g), symbols }));

baseCourse(g);
await easel.draw(
  "the pale wall did not meet the floor: a dark base course over the bottom 0.85 m",
  (b) => b.patch({ origin: [0, 0], rows: rowsOf(g), symbols }));

wear(g);
await easel.draw(
  "the wall was too clean to be used: weep from the bolt line, grit at the seams and the floor",
  (b) => b.patch({ origin: [0, 0], rows: rowsOf(g), symbols }));

const native = await easel.view({ scale: 1, into: "concrete_facility_wall.png" });
const eight = await easel.view({ scale: 8, into: "concrete_facility_wall_8x.png" });
const grid = await easel.view({ scale: 8, coordinates: 8, into: "concrete_facility_wall_8x_coords.png" });

// The three claims, kept apart the way `tools/look.mjs` keeps them apart.
// `render_created` is checked. `pixels_read` proves the bytes were accessed
// and NOT that anything perceived them. `visual_assessment` is deliberately
// absent: it is an attributed opinion, it is never verified, and the artist
// signs it in the report rather than here.
const record = {
  path, owner: OWNER, artist: ARTIST,
  surface: { metres: METRES, density: DENSITY, size: SIZE },
  structure: {
    course_pitch: COURSE_PITCH, joint_pitch: JOINT_PITCH,
    bolt_pitch: BOLT_PITCH, base_course: BASE_COURSE,
    base_top: BASE_TOP, seams: SEAMS,
  },
  views: [native, eight, grid].map((v) => ({
    image: v.image, scale: v.scale, native_size: v.nativeSize,
    render_created: v.record.render_created,
    pixels_read: v.record.pixels_read ?? null,
    visual_assessment: v.record.visual_assessment ?? null,
    check: v.check,
  })),
  elapsed_ms: Math.round(performance.now() - t0),
};
writeFileSync(join(OUT, "authoring_record.json"),
              JSON.stringify(record, null, 2) + "\n");
console.log(JSON.stringify(record, null, 2));
