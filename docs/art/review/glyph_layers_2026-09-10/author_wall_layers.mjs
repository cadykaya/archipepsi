// Archipepsi x ECMS Glyph -- the concrete_facility wall, in separated layers.
//
//   GLYPH_ROOT=/path/to/ecms-glyph node author_wall_layers.mjs [outdir]
//
// WHAT CHANGED FROM THE TRIAL, AND WHY.
//
// The trial baked the base course INTO the wall texture, which is what
// `materials.py` does today. That is correct for a wall exactly one tile
// tall and wrong for anything else: tiled vertically it puts a dark
// skirting band every 4 m up the wall. So the field and the structural trim
// are two textures here, and the trim is placed ONCE at the floor junction
// rather than repeating.
//
// AND REMOVING THE BAND EXPOSED A SEAM THE BAND WAS HIDING. The shipped
// panel course pitch is 1.2 m = 38 texels, and 128 / 38 = 3.37 -- so the
// courses do NOT line up across a vertical repeat, and the mismatch landed
// inside the dark band where nobody could see it. The pitch here is
// 1.0 m = 32 texels, which divides 128 exactly four times. A tiling
// texture's structural pitch has to divide its own tile or the repeat shows.
// The texel density convention (32 texels/m) is unchanged.
//
// TWO TEXTURES OUT:
//   wall_field.png    128 x 128 = 4.00 x 4.00 m. Tiles in BOTH axes.
//   wall_skirt.png    128 x  32 = 4.00 x 1.00 m. Tiles horizontally ONLY,
//                     and belongs at the floor junction, once.

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
mkdirSync(OUT, { recursive: true });
const OWNER = "act_owner_skyiah";
const ARTIST = "act_agent_arty";

const DENSITY = 32;                       // texels/m -- the house convention
const W = 128;                            // 4.00 m along the wall
const H = 128;                            // 4.00 m up the wall
const SKIRT_H = 32;                       // 1.00 m of skirting
const t = (m) => Math.max(1, Math.round(m * DENSITY));

const COURSE = t(1.0);                    // 32 -- and 128 / 32 = 4, exactly
const JOINT = t(2.0);                     // 64 -- and 128 / 64 = 2, exactly
const BOLT = t(0.5);                      // 16
const SEAMS = [];
for (let y = 0; y < H; y += COURSE) SEAMS.push(y);       // 0 32 64 96

// -- determinism, with the avalanche the trial's first pass needed --------
// FNV-1a alone is very nearly constant in whatever it hashes LAST, because
// one imul does not carry the low bits up into the high bits a `/ 2**32`
// read looks at. Measured on the trial: 83.2% of vertical neighbours agreed
// against 3.3% of horizontal. murmur3's fmix32 finalizer fixes it.
function hash32(str) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0;
  }
  h ^= h >>> 16; h = Math.imul(h, 2246822507) >>> 0;
  h ^= h >>> 13; h = Math.imul(h, 3266489909) >>> 0;
  return (h ^ (h >>> 16)) >>> 0;
}
const br = (what, x, y) =>
  hash32(`archipepsi/concrete_facility/${what}/${x}/${y}`) / 4294967295;

const FIELD_PALETTE = [
  { name: "field", value: [178, 185, 184, 255] },
  // TWO steps out from the field in each direction, not one. The trial had
  // one, every patch was a hard edge against the ground, and the wall came
  // out cleaner than the shipped painter's -- which builds its surface from
  // many low-strength continuous mixes. Indexed colour cannot do continuous,
  // but it can afford a second step, and a second step is most of the way.
  { name: "field_d1", value: [173, 179, 178, 255] },
  { name: "field_d2", value: [168, 174, 172, 255] },
  { name: "field_l1", value: [185, 191, 190, 255] },
  { name: "field_l2", value: [192, 198, 195, 255] },
  { name: "seam_shadow", value: [98, 99, 96, 255] },
  { name: "seam_lip", value: [232, 236, 228, 255] },
  { name: "speck", value: [142, 146, 144, 255] },
  { name: "speck_soft", value: [160, 166, 164, 255] },
];

const SKIRT_PALETTE = [
  { name: "course", value: [114, 116, 114, 255] },
  { name: "course_grit", value: [106, 108, 105, 255] },
  { name: "course_scuff", value: [143, 146, 142, 255] },
  { name: "course_shadow", value: [100, 102, 99, 255] },
  { name: "course_lip", value: [232, 236, 228, 255] },
  { name: "course_under", value: [46, 51, 56, 255] },
  { name: "skirt_grime", value: [78, 67, 60, 255] },
  { name: "skirt_grime_soft", value: [103, 101, 97, 255] },
];

const grid = (w, h, fill) =>
  Array.from({ length: h }, () => Array(w).fill(fill));
const rows = (g) => g.map((r) => r.join(""));
const symOf = (pal) => Object.fromEntries(
  pal.map((e, i) => [String.fromCharCode(97 + i), e.name]));
const codeOf = (pal) => Object.fromEntries(
  pal.map((e, i) => [e.name, String.fromCharCode(97 + i)]));

// =========================================================================
// THE FIELD
// =========================================================================
const F = codeOf(FIELD_PALETTE);

function pour(g) {
  // Two-step patches: a core of the far step inside a rim of the near one,
  // so a mark has a middle and an edge instead of one flat plateau.
  const cell = t(0.55);
  for (let row = 0, cy = -cell; cy < H + cell; cy += cell, row++) {
    const shift = Math.floor(br("row", row, 0) * cell);
    for (let cx = -cell; cx < W + cell; cx += cell) {
      if (br("patch", cx + shift, cy) > 0.26) continue;
      const dark = br("step", cx, cy) < 0.5;
      const near = dark ? F.field_d1 : F.field_l1;
      const far = dark ? F.field_d2 : F.field_l2;
      const w = cell + Math.floor(br("w", cx, cy) * cell);
      const h = cell + Math.floor(br("h", cx, cy) * cell);
      const rim = Math.max(2, Math.round(cell * 0.45));
      for (let y = cy; y < cy + h; y++) {
        for (let x = cx + shift; x < cx + shift + w; x++) {
          // WRAPPED, not clipped. A patch that runs off the right edge has
          // to arrive on the left, or every tile boundary is a line where
          // the marks stop -- which is the seam this whole batch is about.
          const px = ((x % W) + W) % W, py = ((y % H) + H) % H;
          const din = Math.min(y - cy, cy + h - 1 - y,
                               x - (cx + shift), cx + shift + w - 1 - x);
          const edge = din >= rim ? 0 : 1 - din / rim;
          if (br("edge", px, py) < 0.5 * edge) continue;
          g[py][px] = din >= rim ? far : near;
        }
      }
    }
  }
  return g;
}

function panels(g) {
  for (const y of SEAMS) {
    for (let x = 0; x < W; x++) {
      g[y][x] = F.seam_shadow;
      g[(y + 1) % H][x] = F.seam_lip;
    }
  }
  for (let x = 0; x < W; x += JOINT) {
    for (let y = 0; y < H; y++) {
      g[y][x] = F.seam_shadow;
      g[y][(x + 1) % W] = F.seam_lip;
    }
  }
  // Bolts ON the seams, at the surface's own pitch. Wrapped in y as well,
  // so the row above y=0 is the row above the seam of the tile beneath.
  for (const seam of SEAMS) {
    const y = ((seam - 2) % H + H) % H;
    const above = ((seam - 3) % H + H) % H;
    for (let x = BOLT >> 1; x < W; x += BOLT) {
      g[y][x] = F.seam_shadow;
      g[above][x] = F.seam_lip;
    }
  }
  return g;
}

// THE FIELD CARRIES NO DRIPS, AND THAT IS THE POINT OF THE BATCH.
//
// The first version of this file kept the trial's weep streaks. Tiled 3x3
// they were the only thing anyone could see: five identical dark drips per
// tile, recurring on a grid, and the eye locks onto them before it reads a
// single panel. A mark that specific cannot survive repetition -- and it
// does not have to, because a drip beneath a joint is exactly what the
// decal layer is for. It is `decal_drip` in the kit, placed once where a
// joint actually leaks.
//
// What stays in the field is only what can bear being seen a hundred times:
// the pour, the panel structure, and grit fine enough to read as surface
// rather than as an event.
function wear(g) {
  const reach = t(0.25);
  const near = (y) => Math.min(...SEAMS.map((s) =>
    Math.min(Math.abs(y - s), H - Math.abs(y - s))));
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (g[y][x] === F.seam_shadow || g[y][x] === F.seam_lip) continue;
      const d = near(y);
      if (d > reach) continue;
      const zone = 1 - d / (reach + 1);
      if (br("grit", x, y) > 0.05 * zone) continue;
      g[y][x] = br("gritstep", x, y) < 0.5 ? F.speck : F.speck_soft;
    }
  }
  return g;
}

// =========================================================================
// THE SKIRTING -- once, at the floor junction
// =========================================================================
const S = codeOf(SKIRT_PALETTE);

function skirt(g) {
  // Top edge: the lip that catches the light, then the dark line under it.
  for (let x = 0; x < W; x++) { g[0][x] = S.course_lip; g[1][x] = S.course_under; }
  // Bottom two rows darken into the floor junction -- an inside corner is
  // never as bright as the face above it.
  for (let x = 0; x < W; x++) {
    g[SKIRT_H - 1][x] = S.course_shadow;
    g[SKIRT_H - 2][x] = S.course_shadow;
  }
  // The same 2.0 m joints as the field, so trim and wall agree about where
  // the panels are. A skirting with its own rhythm reads as a different
  // building.
  for (let x = 0; x < W; x += JOINT) {
    for (let y = 2; y < SKIRT_H - 2; y++) g[y][x] = S.course_grit;
  }
  // Scuffing, which is what a skirting is FOR: it is the band that gets
  // kicked. Concentrated in the lower half, where a boot reaches.
  for (let y = 2; y < SKIRT_H - 2; y++) {
    for (let x = 0; x < W; x++) {
      const low = y / SKIRT_H;
      if (br("scuff", x, y) < 0.05 * low) g[y][x] = S.course_scuff;
      else if (br("grit2", x, y) < 0.05) g[y][x] = S.course_grit;
    }
  }
  // Grime pooling at the very bottom, where a floor meets a wall.
  for (let x = 0; x < W; x++) {
    for (let y = SKIRT_H - 6; y < SKIRT_H - 2; y++) {
      const w = (y - (SKIRT_H - 7)) / 5;
      if (br("pool", x, y) > 0.30 * w) continue;
      g[y][x] = br("poolstep", x, y) < 0.4 ? S.skirt_grime : S.skirt_grime_soft;
    }
  }
  return g;
}

// -- author ---------------------------------------------------------------
const field = await newEasel({
  path: join(OUT, "wall_field.glyph"), owner: OWNER, artist: ARTIST,
  name: "concrete_wall_field", width: W, height: H, palette: FIELD_PALETTE,
});
const gf = grid(W, H, F.field);
const symF = symOf(FIELD_PALETTE);
pour(gf);
await field.draw("the pour: patches with a core and an edge, wrapped so the "
  + "tile boundary is not where the marks stop",
  (b) => b.patch({ origin: [0, 0], rows: rows(gf), symbols: symF }));
panels(gf);
await field.draw("courses at 1.0 m so the pitch divides the tile: at 1.2 m "
  + "the repeat did not line up and the skirting was hiding it",
  (b) => b.patch({ origin: [0, 0], rows: rows(gf), symbols: symF }));
wear(gf);
await field.draw("grit at the seams only; no base "
  + "course, and no drips: a mark that specific cannot bear repeating",
  (b) => b.patch({ origin: [0, 0], rows: rows(gf), symbols: symF }));

const vField = await field.view({ scale: 1, into: join(OUT, "wall_field.png") });
const vField8 = await field.view({ scale: 8, into: join(OUT, "wall_field_8x.png") });
const vField4 = await field.view({ scale: 4, into: join(OUT, "wall_field_4x.png") });
const tiled = await field.study({
  from: vField, tile: 3, into: join(OUT, "wall_field_3x3.png") });
// The sheet a repeat is actually judged on: 3x3 at 4x is 1536 px, which is
// big enough to see a mark recur and small enough to see all nine tiles.
const tiled4 = await field.study({
  from: vField4, tile: 3, into: join(OUT, "wall_field_3x3_4x.png") });

const trim = await newEasel({
  path: join(OUT, "wall_skirt.glyph"), owner: OWNER, artist: ARTIST,
  name: "concrete_wall_skirt", width: W, height: SKIRT_H,
  palette: SKIRT_PALETTE,
});
const gs = grid(W, SKIRT_H, S.course);
skirt(gs);
await trim.draw("the skirting, once: a lit lip, the joints the wall already "
  + "has, scuffing where a boot reaches and grime in the floor junction",
  (b) => b.patch({ origin: [0, 0], rows: rows(gs), symbols: symOf(SKIRT_PALETTE) }));
const vSkirt = await trim.view({ scale: 1, into: join(OUT, "wall_skirt.png") });
const vSkirt8 = await trim.view({ scale: 8, into: join(OUT, "wall_skirt_8x.png") });
const skirtTiled = await trim.study({
  from: vSkirt, tile: 3, into: join(OUT, "wall_skirt_3x.png") });

const record = {
  glyph_root: GLYPH_ROOT,
  glyph_sha: GLYPH_SHA,
  owner: OWNER, artist: ARTIST,
  density: DENSITY,
  field: { size: [W, H], metres: [W / DENSITY, H / DENSITY],
           course_pitch: COURSE, joint_pitch: JOINT, bolt_pitch: BOLT,
           seams: SEAMS, tiles: "both axes",
           divides: { vertical: H % COURSE === 0, horizontal: W % JOINT === 0 },
           entries: FIELD_PALETTE.length },
  skirt: { size: [W, SKIRT_H], metres: [W / DENSITY, SKIRT_H / DENSITY],
           tiles: "horizontally only; placed once at the floor junction",
           entries: SKIRT_PALETTE.length },
  views: [vField, vField4, vField8, vSkirt, vSkirt8].map((v) => ({
    image: v.image, scale: v.scale, native_size: v.nativeSize,
    sha256: v.record.render_created.sha256, check: v.check })),
  studies: [tiled, tiled4, skirtTiled].map((s) => ({
    image: s.image, size: s.size, tile: s.tile, is_a_render: s.is_a_render,
    derived_from: s.derived_from.sha256, sha256: s.sha256 })),
  elapsed_ms: Math.round(performance.now() - t0),
};
writeFileSync(join(OUT, "wall_layers_record.json"),
              JSON.stringify(record, null, 2) + "\n");
console.log(JSON.stringify(record, null, 2));
