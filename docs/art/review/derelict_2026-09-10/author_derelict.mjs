// Archipepsi x ECMS Glyph -- deep_space_derelict, four repeating fields.
//
//   GLYPH_ROOT=/path/to/ecms-glyph node author_derelict.mjs [outdir]
//
// A VISUAL PROOF, NOT A THEME PACK. Nothing here ships, nothing is bound
// into runtime, no approved asset or manifest is touched, and
// Constants.THEME_MATERIALS is not changed.
//
// THE POINT IS THAT IT IS NOT A DARKENED CONCRETE.
//
// Two things carry the difference, and neither is brightness.
//
// STRUCTURE IS TRANSPOSED. concrete_facility is a poured wall: horizontal
// courses every 1.0 m, vertical joints every 2.0 m, bolts ON the horizontal
// seams. This is a fabricated hull: VERTICAL stringers every 1.0 m,
// HORIZONTAL weld seams every 2.0 m, rivets ON the stringers. The same two
// pitches, swapped axes, and a wall you cannot mistake for the other one
// even in grayscale.
//
// VALUE HIERARCHY IS INVERTED AT THE EDGES. concrete's trim is a mid-dark
// band under a bright field. Here the structural frame goes to near-black
// (L 9-26) and the wall field stays the PALEST large surface in the room
// (L 58) -- dark secondary structure establishes the place, the pale field
// keeps it navigable. The floor sits between them so the ground plane is
// never the brightest thing in view.
//
// Colours come from derelict_palette.json, solved in CIE LCh at a fixed hue
// and chroma per role. Every one is measured against the protected
// gameplay families by tools/content/check_decal_colours.py.

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
mkdirSync(OUT, { recursive: true });
const OWNER = "act_owner_skyiah";
const ARTIST = "act_agent_arty";

const PAL = JSON.parse(readFileSync(join(HERE, "derelict_palette.json"), "utf8"));
const DENSITY = PAL.texels_per_metre;                  // 32
const t = (m) => Math.max(1, Math.round(m * DENSITY));
const hex = (role, i) => PAL.roles[role].ramp[i];
const rgb = (h) => {
  const s = h.replace("#", "");
  return [0, 2, 4].map((i) => parseInt(s.slice(i, i + 2), 16));
};
const GRIME = ["#241f1c", "#4e433c", "#7b6a60"];

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
  hash32(`archipepsi/derelict/${seed}/${what}/${x}/${y}`) / 4294967295;

const grid = (w, h, fill) =>
  Array.from({ length: h }, () => Array(w).fill(fill));
const rows = (g) => g.map((r) => r.join(""));

// =========================================================================
// THE FIELDS
// =========================================================================
const FIELDS = [
  {
    id: "derelict_wall", role: "wall", size: [128, 128],
    title: "bulkhead plating",
    palette: [
      { name: "plate", value: [...rgb(hex("base", 2)), 255] },
      { name: "plate_d1", value: [...rgb(hex("base", 1)), 255] },
      { name: "plate_d2", value: [...rgb(hex("base", 0)), 255] },
      { name: "plate_l", value: [...rgb(hex("base", 3)), 255] },
      { name: "rib", value: [...rgb(hex("base", 1)), 255] },
      { name: "rib_lit", value: [...rgb(hex("base", 3)), 255] },
      { name: "shadow", value: [...rgb(hex("trim", 1)), 255] },
      { name: "weld", value: [...rgb(hex("trim", 2)), 255] },
      { name: "corrode", value: [...rgb(GRIME[1]), 255] },
    ],
    draw(g, r, S) {
      const W = 128, H = 128;
      const RIB = t(1.0);        // 32 -- and 128 / 32 = 4
      const WELD = t(2.0);       // 64 -- and 128 / 64 = 2
      const RIVET = t(0.5);      // 16
      const RIB_W = t(0.18);     // 6

      // ROLLED PLATE, not poured concrete: the variation runs along the
      // direction the sheet came off the roll.
      //
      // FIRST PASS WAS A DITHER. It banded 30% of columns and then dropped
      // 45% of the pixels inside each, so every panel filled with vertical
      // dashes -- noisy texture across the whole material, which is what a
      // large tiling field can least afford. A rolled band is CONTINUOUS
      // and only just visible: a few of them, full height, one step off the
      // field, with soft ends.
      for (let x = 0; x < W; x++) {
        const band = r("band", x, 0);
        if (band > 0.12) continue;
        const tone = band < 0.06 ? S.plate_d1 : S.plate_l;
        const wide = 1 + Math.floor(r("bw", x, 0) * 3);
        for (let w = 0; w < wide; w++) {
          const xx = (x + w) % W;
          for (let y = 0; y < H; y++) {
            // Soft only at the very ends, so the band is a band and not
            // a run of speckle.
            const e = Math.min(y, H - 1 - y) / 10;
            if (e < 1 && r("bend", xx, y) > e) continue;
            g[y][xx] = tone;
          }
        }
      }

      // HORIZONTAL WELD SEAMS. A weld is a bead and a shadow, not a groove:
      // the bright line sits ON the joint, the dark one under it.
      for (let y = 0; y < H; y += WELD) {
        for (let x = 0; x < W; x++) {
          g[y][x] = S.weld;
          g[(y + 1) % H][x] = r("bead", x, y) < 0.7 ? S.rib_lit : S.plate_l;
          g[(y + 2) % H][x] = S.shadow;
        }
      }

      // VERTICAL STRINGERS, the theme's dominant rhythm. Lit on one side and
      // shadowed on the other, so the wall has a direction the light comes
      // from -- which is most of what makes plating read as plating.
      for (let x = 0; x < W; x += RIB) {
        for (let y = 0; y < H; y++) {
          g[y][(x - 1 + W) % W] = S.shadow;
          for (let w = 0; w < RIB_W; w++) g[y][(x + w) % W] = S.rib;
          g[y][x % W] = S.rib_lit;
          g[y][(x + RIB_W) % W] = S.plate_d2;
        }
        // RIVETS ON THE STRINGERS -- concrete puts its bolts on the seams,
        // so this is the other place they can be, and it reads as the other
        // way of holding a wall together.
        for (let y = RIVET >> 1; y < H; y += RIVET) {
          const cx = (x + 2) % W;
          g[y][cx] = S.plate_d2;
          g[(y - 1 + H) % H][cx] = S.rib_lit;
        }
      }

      // Corrosion, ONLY in the weld shadow, where water and flux collect.
      // Fine enough to read as surface rather than as an event -- a mark
      // with a shape would repeat, and this field is seen a hundred times.
      for (let y = 0; y < H; y++) {
        const d = Math.min(...[0, WELD].map((s) =>
          Math.min(Math.abs(y - s), H - Math.abs(y - s))));
        if (d > 3) continue;
        for (let x = 0; x < W; x++) {
          if (g[y][x] === S.rib_lit || g[y][x] === S.rib) continue;
          if (r("corr", x, y) > 0.10 * (1 - d / 4)) continue;
          g[y][x] = S.corrode;
        }
      }
      return g;
    },
  },
  {
    id: "derelict_floor", role: "floor", size: [128, 128],
    title: "deck plate with anti-slip tread",
    palette: [
      { name: "deck", value: [...rgb(hex("floor", 2)), 255] },
      // Two tones a HAIR either side of the field, not the ramp's own big
      // steps. See the note in draw().
      { name: "deck_a", value: [56, 70, 72, 255] },
      { name: "deck_b", value: [72, 86, 89, 255] },
      { name: "deck_d", value: [...rgb(hex("floor", 1)), 255] },
      { name: "deck_dd", value: [...rgb(hex("floor", 0)), 255] },
      { name: "tread", value: [...rgb(hex("floor", 3)), 255] },
      { name: "seam", value: [...rgb(hex("trim", 0)), 255] },
      { name: "bolt", value: [...rgb(hex("floor", 3)), 255] },
      { name: "wear", value: [...rgb(GRIME[1]), 255] },
    ],
    draw(g, r, S) {
      const N = 128, PLATE = t(1.0);   // 32, four plates each way

      // Per-plate tone: no two plates in a hull are the same age.
      //
      // FIRST PASS DITHERED THIS at 70% per pixel and the deck came out as
      // static with the tread lost inside it. A plate is one piece of
      // metal: it takes ONE tone, flat.
      //
      // SECOND PASS FLATTENED IT AND THE 3x3 CAUGHT THE REAL PROBLEM. Using
      // the ramp's own steps put 20 L* between the palest plate and the
      // darkest, the deck read as a CHECKERBOARD, and with sixteen plates
      // to a tile the arrangement itself became the thing that repeated.
      // A floor is the surface a player looks at while moving and it has to
      // be the quietest thing in the room, so the plate tones are now a
      // hair either side of the field -- L28.5 and L35.5 against a field of
      // L32 -- and the AGE difference is carried by how worn each plate's
      // tread is, below, which is what actually differs between two plates
      // of the same metal.
      const plateTone = [];
      for (let py = 0; py < N; py += PLATE) {
        for (let px = 0; px < N; px += PLATE) {
          const k = r("plate", px, py);
          const tone = k < 0.18 ? S.deck_a : k < 0.36 ? S.deck_b : null;
          plateTone.push([px, py, k]);
          if (tone === null) continue;
          for (let y = py; y < py + PLATE; y++) {
            for (let x = px; x < px + PLATE; x++) g[y][x] = tone;
          }
        }
      }
      // ANTI-SLIP TREAD. The single strongest "this is a ship" mark in the
      // theme, and a REGULAR one: a rhythm at 0.125 m, not an event.
      const P = t(0.125);              // 4
      // How worn each plate's tread is, keyed off the same draw as its tone
      // so a pale plate is a fresher plate. THIS is where the age lives.
      const wearOf = (x, y) => {
        const px = x - (x % PLATE), py = y - (y % PLATE);
        return r("plate", px, py);
      };
      for (let y = 2; y < N; y += P) {
        for (let x = 2; x < N; x += P) {
          const ox = ((y / P) | 0) % 2 ? P >> 1 : 0;   // staggered rows
          const xx = (x + ox) % N;
          // A worn plate keeps less of its tread. 0.25 of the marks gone on
          // the freshest, 0.70 on the most walked-over.
          const gone = 0.25 + 0.45 * (1 - wearOf(xx, y));
          if (r("worn", xx, y) > gone) {
            g[y][xx] = S.tread;
            g[y][(xx + 1) % N] = S.tread;
            g[(y + 1) % N][xx] = S.deck_dd;
            g[(y + 1) % N][(xx + 1) % N] = S.deck_dd;
          }
        }
      }
      // Plate seams, cut after the tread so a seam is never treaded over.
      for (let i = 0; i < N; i += PLATE) {
        for (let k = 0; k < N; k++) {
          g[i][k] = S.seam; g[(i + 1) % N][k] = S.deck_dd;
          g[k][i] = S.seam; g[k][(i + 1) % N] = S.deck_dd;
        }
      }
      // Countersunk bolts at every plate corner.
      for (let py = 0; py < N; py += PLATE) {
        for (let px = 0; px < N; px += PLATE) {
          for (const [dx, dy] of [[3, 3], [PLATE - 3, 3],
                                  [3, PLATE - 3], [PLATE - 3, PLATE - 3]]) {
            const x = (px + dx) % N, y = (py + dy) % N;
            g[y][x] = S.deck_dd;
            g[(y - 1 + N) % N][x] = S.bolt;
          }
        }
      }
      // Traffic wear along the seams, where boots catch the lip.
      for (let y = 0; y < N; y++) {
        for (let x = 0; x < N; x++) {
          if (g[y][x] !== S.deck && g[y][x] !== S.deck_d) continue;
          const d = Math.min(x % PLATE, PLATE - (x % PLATE),
                             y % PLATE, PLATE - (y % PLATE));
          if (d > 3 || r("wear", x, y) > 0.06) continue;
          g[y][x] = S.wear;
        }
      }
      return g;
    },
  },
  {
    id: "derelict_trim", role: "trim", size: [128, 32],
    title: "structural frame channel",
    palette: [
      { name: "steel", value: [...rgb(hex("trim", 1)), 255] },
      { name: "steel_d", value: [...rgb(hex("trim", 0)), 255] },
      { name: "steel_l", value: [...rgb(hex("trim", 2)), 255] },
      { name: "edge", value: [...rgb(hex("base", 1)), 255] },
      { name: "bolt", value: [...rgb(hex("base", 2)), 255] },
      { name: "grime", value: [...rgb(GRIME[0]), 255] },
    ],
    draw(g, r, S) {
      const W = 128, H = 32;
      // A chamfer that catches the light, then the channel face falling
      // away into the floor. This is the darkest thing in the room and it
      // is what tells you where the room ENDS.
      for (let x = 0; x < W; x++) {
        g[0][x] = S.edge;
        g[1][x] = S.steel_l;
        g[H - 1][x] = S.steel_d;
        g[H - 2][x] = S.steel_d;
      }
      // Web stiffeners at the wall's own 1.0 m stringer pitch, so frame and
      // plating agree about where the structure is.
      for (let x = 0; x < W; x += t(1.0)) {
        for (let y = 2; y < H - 2; y++) {
          g[y][x] = S.steel_d;
          g[y][(x + 1) % W] = S.steel_l;
        }
      }
      // Bolts at 0.5 m, on the channel face.
      for (let x = t(0.25); x < W; x += t(0.5)) {
        const y = (H >> 1) + 2;
        g[y][x] = S.bolt;
        g[y + 1][x] = S.steel_d;
      }
      for (let y = 2; y < H - 2; y++) {
        for (let x = 0; x < W; x++) {
          if (g[y][x] !== S.steel) continue;
          if (r("grit", x, y) < 0.05) g[y][x] = S.steel_d;
          else if (y > H - 8 && r("pool", x, y) < 0.10) g[y][x] = S.grime;
        }
      }
      return g;
    },
  },
  {
    id: "derelict_accent", role: "accent", size: [128, 128],
    title: "louvred machinery face with cold indicators",
    palette: [
      { name: "case", value: [...rgb(hex("trim", 1)), 255] },
      { name: "case_d", value: [...rgb(hex("trim", 0)), 255] },
      { name: "case_l", value: [...rgb(hex("trim", 2)), 255] },
      { name: "conduit", value: [...rgb(hex("base", 0)), 255] },
      { name: "conduit_l", value: [...rgb(hex("base", 1)), 255] },
      { name: "lamp", value: [...rgb(hex("accent", 2)), 255] },
      { name: "lamp_d", value: [...rgb(hex("accent", 1)), 255] },
      { name: "socket", value: [...rgb(hex("accent", 0)), 255] },
    ],
    draw(g, r, S) {
      const N = 128;
      // LOUVRES at 0.25 m: a uniform machinery face, dark, and quiet enough
      // that a wall of it does not become noise.
      const L = t(0.25);              // 8
      for (let y = 0; y < N; y += L) {
        for (let x = 0; x < N; x++) {
          g[y][x] = S.case_d;
          g[(y + 1) % N][x] = S.case_l;
          // Sparse, because a louvred face seen across a whole wall is the
          // last place that can afford grain.
          for (let k = 2; k < L; k++) {
            if (r("face", x, y + k) < 0.025) g[(y + k) % N][x] = S.case_d;
          }
        }
      }
      // TWO CONDUIT RUNS at 2.0 m, so the field divides the same way the
      // bulkhead does.
      for (let y = t(0.85); y < N; y += t(2.0)) {
        for (let x = 0; x < N; x++) {
          g[y][x] = S.conduit;
          g[(y + 1) % N][x] = S.conduit_l;
          g[(y + 2) % N][x] = S.conduit;
          g[(y + 3) % N][x] = S.case_d;
        }
        // INDICATORS at 1.0 m along each run. A RHYTHM, not an event: every
        // one is identical and evenly spaced, so it reads as a system that
        // continues rather than as a thing that keeps happening.
        for (let x = t(0.5); x < N; x += t(1.0)) {
          g[y][x] = S.socket;
          g[(y + 1) % N][x] = S.lamp;
          g[(y + 1) % N][(x + 1) % N] = S.lamp_d;
          g[(y + 2) % N][x] = S.socket;
        }
      }
      return g;
    },
  },
];

// -- author, look, tile ----------------------------------------------------
const made = [];
for (const f of FIELDS) {
  const [W, H] = f.size;
  const letter = Object.fromEntries(
    f.palette.map((e, i) => [e.name, String.fromCharCode(97 + i)]));
  const sym = Object.fromEntries(
    f.palette.map((e, i) => [String.fromCharCode(97 + i), e.name]));
  const S = Object.fromEntries(f.palette.map((e) => [e.name, letter[e.name]]));

  const easel = await newEasel({
    path: join(OUT, `${f.id}.glyph`), owner: OWNER, artist: ARTIST,
    name: f.id, width: W, height: H, palette: f.palette,
  });
  const g = f.draw(grid(W, H, S[f.palette[0].name]), mk(f.id), S);
  await easel.draw(`${f.title}: authored to tile, with nothing in it that
happens only once`.replace(/\n/g, " "),
    (b) => b.patch({ origin: [0, 0], rows: rows(g), symbols: sym }));

  const native = await easel.view({ scale: 1, into: join(OUT, `${f.id}.png`) });
  const big = await easel.view({ scale: 4, into: join(OUT, `${f.id}_4x.png`) });
  const tiled = await easel.study({
    from: big, tile: 3, into: join(OUT, `${f.id}_3x3.png`) });
  const valued = await easel.study({
    from: big, tile: 3, value: true, into: join(OUT, `${f.id}_3x3_value.png`) });

  made.push({
    id: f.id, role: f.role, title: f.title,
    native_size: f.size,
    metres: [W / DENSITY, H / DENSITY],
    texels_per_metre: DENSITY,
    tiles: H === W ? "both axes" : "horizontally; placed once at the floor junction",
    divides: { horizontal: W % t(1.0) === 0, vertical: H % t(1.0) === 0 },
    palette_entries: f.palette.length,
    images: { native: native.image, enlarged: big.image,
              tiled: tiled.image, tiled_value: valued.image },
    render_sha256: native.record.render_created.sha256,
    verified: native.check.render_created && big.check.render_created,
    studies_are_renders: tiled.is_a_render || valued.is_a_render,
  });
  console.log(`[derelict] ${f.id.padEnd(17)} ${W}x${H} = ${W / DENSITY}x${H / DENSITY} m  ${f.palette.length} entries`);
}

const record = {
  _comment: [
    "Batch 042 deep_space_derelict field record. TRIAL ART: ships nowhere,",
    "in no manifest, bound into no runtime.",
  ],
  glyph_root: GLYPH_ROOT, glyph_sha: GLYPH_SHA,
  owner: OWNER, artist: ARTIST,
  palette: "derelict_palette.json",
  texels_per_metre: DENSITY,
  fields: made,
  elapsed_ms: Math.round(performance.now() - t0),
};
writeFileSync(join(OUT, "derelict_fields.json"),
              JSON.stringify(record, null, 2) + "\n");
console.log(`[derelict] four fields in ${record.elapsed_ms} ms -> derelict_fields.json`);
