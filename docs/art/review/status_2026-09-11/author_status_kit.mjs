// Archipepsi x ECMS Glyph -- Batch 043, the complete status graphic kit.
//
//   GLYPH_ROOT=/path/to/ecms-glyph node author_status_kit.mjs [outdir]
//
// PROPOSAL ART. Nothing here ships, nothing is bound into runtime, no
// approved asset, manifest or registry state is touched, and no status
// mechanic is implemented by any of it. These are pictures of the thirteen
// Statuses and eight compounds Design 6 §15 defines.
//
// WHAT IS AUTHORED AND WHAT IS DERIVED
//
// Authored by hand, in `status_bodies.mjs`: the 21 silhouettes. Those are
// drawings and they are where the judgement is.
// Authored procedurally, in `status_frames.mjs`: the 5 frames. Those are
// regular figures that must be identical under every glyph.
// Derived here: the dark outline (one-pixel eight-way dilation of the body),
// every composition, and the depletion track.
//
// NATIVE SIZES, AND WHY
//
//   glyph   16 x 16   the reduced treatment of §33.10 rule 2 -- what a
//                     distant or crowded target gets, alone, with no ring
//                     and no sentence. It has to work at this size with
//                     nothing helping it.
//   marker  32 x 32   frame + glyph. The frame leaves a 12 px clear radius;
//                     a 16 x 16 glyph needs 11.3 at its corners. At 24 the
//                     frame stroke cut the corners off, which is the whole
//                     reason the marker is 32.
//   tick     8 x 8    the player-applied mark, seated at (21,21).
//
// COLOUR, AND THE CONFLICT THIS KIT REFUSED TO INVENT AROUND
//
// The kit is NEUTRAL: one near-black ink, one near-white face, one mid grey
// for dimmed hints. Design 5 §33.7 requires family to be carried by "shape,
// never colour alone" and Design 1 §19.5's sibling rule for conduits says
// the same thing about hue. A neutral kit satisfies both absolutely.
//
// It is also the honest answer to a real conflict. The palette's six
// universal colours already carry fixed meanings -- `signal` "you can use
// this", `hazard`, `identity` Epsilon, `dead`, `send`, `glitch` -- and their
// hues are 45 degrees apart by rule (palette.MUST_NOT_CONFUSE). There is no
// room left for four more saturated status families that would not read as
// one of those six. Inventing a fifth, sixth, seventh and eighth saturated
// family here would have been a palette decision taken by the art lane on
// its own initiative, in the one place the palette explicitly guards.
//
// So: shape studies proceed, and the colour question goes to the owner. It
// is written up in DECISIONS_FOR_OWNER.md.
//
// ONE reserved colour IS used, and it is proposed rather than assumed: the
// player-applied tick is `send` #ffd45c, because `send` already means "this
// one came from you". If the owner would rather the tick were neutral too,
// it is one palette entry.

import { mkdirSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { execFileSync } from "node:child_process";
import { STATUSES, COMPOUNDS } from "./status_bodies.mjs";
import { FRAMES, TICK, TICK_AT, MARKER, GLYPH, INSET, track }
  from "./status_frames.mjs";

const t0 = performance.now();
const HERE = dirname(fileURLToPath(import.meta.url));
const GLYPH_ROOT = process.env.GLYPH_ROOT ?? "/home/user/ecms-glyph";
const sha = (root) => {
  try {
    return execFileSync("git", ["-C", root, "rev-parse", "HEAD"],
                        { encoding: "utf8" }).trim();
  } catch { return "unknown"; }
};
const GLYPH_SHA = sha(GLYPH_ROOT);
const ART_SHA = sha(join(HERE, "..", "..", "..", ".."));
const { newEasel } = await import(
  pathToFileURL(join(GLYPH_ROOT, "tools", "easel.mjs")).href);

const OUT = process.argv[2] ?? HERE;
const SRC = join(OUT, "glyph");          // editable Glyph projects
const PNG = join(OUT, "png");            // individual transparent exports
const BIG = join(OUT, "png8x");          // the same, 8x, for looking at
for (const d of [OUT, SRC, PNG, BIG]) mkdirSync(d, { recursive: true });

const OWNER = "act_owner_skyiah";
const ARTIST = "act_agent_arty";

// -- the three values ------------------------------------------------------
const PALETTE = [
  { name: "ink", value: [20, 23, 28, 255] },     // L* 8.6
  { name: "lit", value: [238, 241, 244, 255] },  // L* 94.6
  { name: "dim", value: [122, 130, 140, 255] },  // L* 53.4  -- dimmed hint
  { name: "spent", value: [74, 80, 88, 255] },   // L* 33.3  -- used duration
  { name: "tick", value: [255, 212, 92, 255] },  // `send`, proposed
];
// `dim` and `spent` are two values, not one, because they answer different
// questions. A dimmed compound hint must still be READ as a glyph -- it is
// telling the player what to apply next -- so it stays well above the ink.
// A spent arc must only hold the frame's silhouette open, so it goes as far
// down as it can without vanishing. One shared grey made the depletion
// unreadable at a glance, which is the one thing it exists for.
const SYM = { i: "ink", l: "lit", d: "dim", s: "spent", t: "tick" };

// -- grids -----------------------------------------------------------------
const blank = (w, h) => Array.from({ length: h }, () => new Array(w).fill("."));
const fromAscii = (rows) => rows.map((r) => r.split("").map((c) => c === "X" ? 1 : 0));

/** The outline: one pixel of ink in all eight directions around a body. */
function outline(mask) {
  const h = mask.length, w = mask[0].length;
  const out = Array.from({ length: h }, () => new Array(w).fill(0));
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (mask[y][x]) continue;
      for (let dy = -1; dy <= 1 && !out[y][x]; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          const ny = y + dy, nx = x + dx;
          if (ny < 0 || nx < 0 || ny >= h || nx >= w) continue;
          if (mask[ny][nx]) { out[y][x] = 1; break; }
        }
      }
    }
  }
  return out;
}

/** Paint a mask into a grid at an offset. Later calls win. */
function paint(grid, mask, ch, ox = 0, oy = 0) {
  for (let y = 0; y < mask.length; y++) {
    for (let x = 0; x < mask[y].length; x++) {
      if (!mask[y][x]) continue;
      const gy = y + oy, gx = x + ox;
      if (gy < 0 || gx < 0 || gy >= grid.length || gx >= grid[0].length) continue;
      grid[gy][gx] = ch;
    }
  }
}

/** body -> a grid with its ink outline under a lit face. */
function figure(w, h, mask, face = "l") {
  const g = blank(w, h);
  paint(g, outline(mask), "i");
  paint(g, mask, face);
  return g;
}

const rows = (g) => g.map((r) => r.join(""));

async function publish(id, w, h, grid, message) {
  const lens = new Set(grid.map((r) => r.length));
  if (grid.length !== h || lens.size !== 1 || !lens.has(w)) {
    throw new Error(`${id}: grid is ${grid.length} rows of ${[...lens]} `
                    + `but ${w}x${h} was declared`);
  }
  const easel = await newEasel({
    path: join(SRC, `${id}.glyph`), owner: OWNER, artist: ARTIST,
    name: id, width: w, height: h, palette: PALETTE, partialAlpha: true,
  });
  await easel.draw(message,
    (b) => b.patch({ origin: [0, 0], rows: rows(grid), symbols: SYM }));
  const native = await easel.view({ scale: 1, into: join(PNG, `${id}.png`) });
  const big = await easel.view({ scale: 8, into: join(BIG, `${id}_8x.png`) });
  // A transparent mark on a transparent ground is invisible. The checker is
  // what makes the exported alpha something a person can actually judge.
  await easel.study({ from: big, over: "checker",
                      into: join(BIG, `${id}_8x_checker.png`) });
  easel.close();
  return { id, native: native.nativeSize, png: `png/${id}.png` };
}

// -- 1. the frames ---------------------------------------------------------
const frameMask = {};
const frameTrack = {};
const made = { frames: [], glyphs: [], markers: [], hints: [], extras: [] };

for (const f of FRAMES) {
  const m = f.build();
  frameMask[f.id] = m;
  frameTrack[f.id] = track(m);
  made.frames.push({
    ...await publish(f.id, MARKER, MARKER, figure(MARKER, MARKER, m),
      `${f.family} frame (${f.treatment}). ${f.why}`),
    family: f.family, treatment: f.treatment, why: f.why,
    track_pixels: frameTrack[f.id].length,
  });
}

// The tick, on its own, so a runtime can stamp it onto any marker.
made.extras.push(await publish("marker_tick", 8, 8,
  figure(8, 8, fromAscii(TICK), "t"),
  "The player-applied tick (§33.7). Statuses the player did not cause lack "
  + "it, so its absence has to be as readable as its presence -- which is "
  + "why it sits proud in a corner rather than inside the frame."));

// -- 2. the glyphs, alone --------------------------------------------------
const ALL = [
  ...STATUSES.map((s) => ({ ...s, kind: "status" })),
  ...COMPOUNDS.map((c) => ({ ...c, kind: "compound", family: "COMPOUND" })),
];
const bodyMask = {};

for (const g of ALL) {
  const m = fromAscii(g.body);
  bodyMask[g.id] = m;
  made.glyphs.push({
    ...await publish(`glyph_${g.id}`, GLYPH, GLYPH, figure(GLYPH, GLYPH, m),
      `${g.id}: "${g.sentence}" -- the reduced treatment of §33.10 rule 2, `
      + `which is this glyph with no frame and no ring.`),
    kind: g.kind, family: g.family, sentence: g.sentence,
    targets: g.targets, duration_s: g.duration,
    ...(g.chance !== undefined ? { chance: g.chance } : {}),
    ...(g.components !== undefined ? { components: g.components } : {}),
    ...(g.requires_trait !== undefined
        ? { requires_trait: g.requires_trait } : {}),
  });
}

// -- 3. the composed markers ----------------------------------------------
const frameFor = (family) => ({
  KINETIC: "frame_kinetic", COGNITIVE: "frame_cognitive",
  PERMISSION: "frame_permission", MATERIAL: "frame_material",
  COMPOUND: "frame_compound",
}[family]);

function compose(frameId, glyphId, { tick = false, face = "l" } = {}) {
  const g = blank(MARKER, MARKER);
  const fm = frameMask[frameId], bm = bodyMask[glyphId];
  paint(g, outline(fm), "i");
  paint(g, outline(bm), "i", INSET, INSET);
  paint(g, fm, face);
  paint(g, bm, face, INSET, INSET);
  if (tick) {
    const tm = fromAscii(TICK);
    paint(g, outline(tm), "i", TICK_AT[0], TICK_AT[1]);
    paint(g, tm, "t", TICK_AT[0], TICK_AT[1]);
  }
  return g;
}

for (const g of ALL) {
  const fid = frameFor(g.family);
  made.markers.push({
    ...await publish(`marker_${g.id}`, MARKER, MARKER, compose(fid, g.id),
      `${g.id} in its ${g.family} frame. Family is the frame's shape; the `
      + `glyph is the verb. Both are separately usable and both are `
      + `exported on their own.`),
    frame: fid, family: g.family,
  });
}

// One marker with the tick, and one with a part-spent track, as the reusable
// examples §33.7 asks for. They are examples of a rule, not 21 more assets.
const spentExample = (() => {
  const g = compose("frame_kinetic", "slippery", { tick: true });
  const t = frameTrack.frame_kinetic;
  // 38% remaining: everything past that point on the track goes to `dim`.
  const keep = Math.round(t.length * 0.38);
  for (let i = keep; i < t.length; i++) {
    const [x, y] = t[i];
    if (g[y][x] === "l") g[y][x] = "s";
  }
  return g;
})();
made.extras.push(await publish("example_slippery_38pct_player", MARKER, MARKER,
  spentExample,
  "slippery at 38% remaining, applied by the player. The depletion runs "
  + "clockwise from 12 o'clock along the frame's OWN outer edge -- there is "
  + "no second ring to align, and the spent part goes to the dim value "
  + "rather than disappearing, so the marker keeps its silhouette."));

// -- 4. the compound hints (§33.8) ----------------------------------------
// "the other component's glyph, dimmed, alongside the compound's glyph."
// Read literally: a 48x32 pair. The dimmed component is what the player is
// one step away from applying; the compound glyph is what they would get.
for (const c of COMPOUNDS) {
  for (const missing of c.components) {
    const present = c.components.find((x) => x !== missing);
    const g = blank(48, MARKER);
    const mm = bodyMask[missing];
    paint(g, outline(mm), "i", 0, INSET);
    paint(g, mm, "d", 0, INSET);            // dimmed: not applied yet
    const composed = compose("frame_compound", c.id);
    for (let y = 0; y < MARKER; y++) {
      for (let x = 0; x < MARKER; x++) {
        if (composed[y][x] !== ".") g[y][x + 16] = composed[y][x];
      }
    }
    made.hints.push({
      ...await publish(`hint_${c.id}_needs_${missing}`, 48, MARKER, g,
        `${c.id} hint: the target already carries ${present}. The dimmed `
        + `${missing} on the left is the missing half; the framed glyph on `
        + `the right is what it would become. §33.8 -- the combination table `
        + `printed on the target, only for the pair the player is one step `
        + `away from.`),
      compound: c.id, missing, present,
    });
  }
}

// -- 5. an eight-step depletion strip, per family -------------------------
for (const f of FRAMES) {
  const steps = 8;
  const g = blank(MARKER * steps, MARKER);
  const sample = { KINETIC: "anchored", COGNITIVE: "blinded",
                   PERMISSION: "rooted", MATERIAL: "burning",
                   COMPOUND: "grounded" }[f.family];
  for (let s = 0; s < steps; s++) {
    const cell = compose(f.id, sample);
    const t = frameTrack[f.id];
    const keep = Math.round((t.length * (steps - s)) / steps);
    for (let i = keep; i < t.length; i++) {
      const [x, y] = t[i];
      if (cell[y][x] === "l") cell[y][x] = "s";
    }
    for (let y = 0; y < MARKER; y++) {
      for (let x = 0; x < MARKER; x++) {
        if (cell[y][x] !== ".") g[y][x + s * MARKER] = cell[y][x];
      }
    }
  }
  made.extras.push(await publish(`deplete_${f.family.toLowerCase()}`,
    MARKER * steps, MARKER, g,
    `${f.family} depletion, 100% to 12.5% in eight steps, on ${sample}. `
    + `The track is the frame's own edge, ${frameTrack[f.id].length} px long, `
    + `so the smallest visible change is ${(100 / frameTrack[f.id].length)
        .toFixed(1)}% of duration.`));
}

// -- 6. the atlas ----------------------------------------------------------
// A convenience, explicitly a supplement: the individual PNGs are the assets.
{
  const cols = 8;
  const rowsN = Math.ceil(ALL.length / cols);
  const g = blank(MARKER * cols, MARKER * rowsN);
  const index = [];
  ALL.forEach((s, n) => {
    const cx = (n % cols) * MARKER, cy = Math.floor(n / cols) * MARKER;
    const cell = compose(frameFor(s.family), s.id);
    for (let y = 0; y < MARKER; y++) {
      for (let x = 0; x < MARKER; x++) {
        if (cell[y][x] !== ".") g[y + cy][x + cx] = cell[y][x];
      }
    }
    index.push({ id: s.id, cell: [n % cols, Math.floor(n / cols)],
                 rect: [cx, cy, MARKER, MARKER] });
  });
  made.extras.push(await publish("atlas_markers", MARKER * cols,
    MARKER * rowsN, g,
    "All 21 markers on one sheet, 32 px cells. A SUPPLEMENT: the individual "
    + "transparent PNGs in png/ are the assets, and an atlas that disagreed "
    + "with them would be the atlas that is wrong."));
  writeFileSync(join(OUT, "atlas_markers.json"),
    JSON.stringify({ cell: MARKER, columns: cols, entries: index }, null, 2));
}

// -- 7. metadata -----------------------------------------------------------
const meta = {
  batch: "043",
  authored: "2026-09-11",
  art_revision: ART_SHA,
  glyph_revision: GLYPH_SHA,
  design_revision: "a20bf55",
  design_sections: ["06 §15.2", "05 §15.1-15.8", "05 §33.7-33.9", "06 §33.10"],
  status: "PROPOSAL -- not approved, not bound to runtime, no mechanic implemented",
  native_sizes: { glyph: [GLYPH, GLYPH], marker: [MARKER, MARKER], tick: [8, 8] },
  tick_origin: TICK_AT,
  glyph_origin_in_marker: [INSET, INSET],
  colour: {
    scheme: "neutral -- ink / lit / dim",
    ink: "#14171c", lit: "#eef1f4", dim: "#7a828c", spent: "#4a5058",
    family_hue: "NOT ASSIGNED. See DECISIONS_FOR_OWNER.md item 1.",
    tick: "#ffd45c (`send`) -- PROPOSED reuse, see item 2",
  },
  depletion: {
    rule: "the frame's own outer edge is the track; paint the first "
        + "`remaining` fraction lit and the rest dim",
    tracks: Object.fromEntries(
      Object.entries(frameTrack).map(([k, v]) => [k, v])),
  },
  ...made,
};
writeFileSync(join(OUT, "status_kit.json"), JSON.stringify(meta, null, 2));

console.log(`frames  ${made.frames.length}`);
console.log(`glyphs  ${made.glyphs.length}  (13 statuses + 8 compounds)`);
console.log(`markers ${made.markers.length}`);
console.log(`hints   ${made.hints.length}   (both directions for all 8 compounds)`);
console.log(`extras  ${made.extras.length}`);
console.log(`glyph @ ${GLYPH_SHA.slice(0, 7)}   art @ ${ART_SHA.slice(0, 7)}`);
console.log(`${((performance.now() - t0) / 1000).toFixed(1)}s`);
