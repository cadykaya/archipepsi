// Archipepsi x ECMS Glyph -- Batch 043, the five conduit states.
//
//   GLYPH_ROOT=/path/to/ecms-glyph node author_conduit_states.mjs [outdir]
//
// PRESENTATION ONLY. Design 1 §19.5, pinned by Design 6 §19: conduits are
// presentation, never destructible, and carry no state. Nothing here is a
// signal graph, a node type, an evaluation order or a state machine, and no
// package is validated by any of it.
//
// THE RULE THAT SHAPED EVERY ONE OF THEM
//
//   "Every state differs in AT LEAST TWO of brightness, pattern, motion and
//    audio. None is distinguished by hue alone." -- Design 1 §19.5,
//    Dungeon Authority §50.
//
// So the kit is authored as a STATIC CHANNEL plus a SWAPPABLE BAND, and the
// band is where all four channels live:
//
//   state              brightness   pattern            motion        audio
//   inactive           dim          unbroken hairline  none          none
//   active             bright       chevrons           scrolls +X    low hum
//   pulse_travelling   bright       ONE short block    scrolls fast  click
//   blocked            dim          broken segments    none          none
//   delayed            bright       solid FILL         grows, no     rising
//                                   behind a hard      travel        pitch
//                                   leading edge
//
// THE TWO DISTINCTIONS THE BRIEF ASKED FOR, AND HOW EACH IS CARRIED
//
// pulse_travelling vs delayed. A pulse is a SHORT band of constant length
// that moves from one end to the other. A delay is a band of GROWING length
// whose leading edge advances and whose tail never leaves the source. They
// differ in pattern (one block versus a fill), in motion (travel versus
// growth) and in what the edge does. That is three channels, and it is the
// distinction Design 1 §19.4 says a player must be able to make.
//
// blocked vs inactive. Both are dim and both are still, so brightness and
// motion carry nothing here -- it is entirely pattern. `inactive` is an
// unbroken hairline: a whole conduit with nothing in it. `blocked` is the
// same line cut into segments with a hard break mark on it: a conduit that
// is trying and failing. Dim-and-continuous versus dim-and-severed.
//
// AUDIO IS NOT DELIVERED AND IS NOT PRETENDED. §19.5 names a low hum, a
// click on arrival and a rising pitch. None of them exists. Four of the five
// states are separable on the visual channels alone -- which is what these
// pictures show -- but `delayed` is the one whose rising pitch is doing real
// work, because it is the only state that tells the player HOW LONG. A
// silent still of `delayed` is not evidence that `delayed` is finished.

import { mkdirSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { execFileSync } from "node:child_process";

const HERE = dirname(fileURLToPath(import.meta.url));
const GLYPH_ROOT = process.env.GLYPH_ROOT ?? "/home/user/ecms-glyph";
const sha = (r) => {
  try {
    return execFileSync("git", ["-C", r, "rev-parse", "HEAD"],
                        { encoding: "utf8" }).trim();
  } catch { return "unknown"; }
};
const { newEasel } = await import(
  pathToFileURL(join(GLYPH_ROOT, "tools", "easel.mjs")).href);

const OUT = process.argv[2] ?? HERE;
const SRC = join(OUT, "glyph"), PNG = join(OUT, "png");
for (const d of [OUT, SRC, PNG]) mkdirSync(d, { recursive: true });
const OWNER = "act_owner_skyiah", ARTIST = "act_agent_arty";

// 2.00 m x 0.50 m at the 32 texels/m architecture budget.
const W = 64, H = 16, DENSITY = 32;

const PALETTE = [
  { name: "struct", value: [58, 63, 70, 255] },   // L* 26 channel body
  { name: "shadow", value: [30, 33, 38, 255] },   // L* 13 trough
  { name: "rail", value: [128, 136, 145, 255] },  // L* 56 rail highlight
  { name: "lit", value: [238, 243, 247, 255] },   // L* 95 energised
  // L* 46. The first pass put this at L* 33 and every de-energised mark in
  // the kit disappeared into the trough at L* 13 -- `inactive` looked like an
  // empty channel and `blocked`'s broken segments were invisible, which is
  // the one distinction that state has. "Dim" has to mean dimmer than lit,
  // not indistinguishable from the hole it sits in.
  { name: "dim", value: [104, 112, 122, 255] },
  { name: "warn", value: [232, 84, 31, 255] },    // `hazard`, break mark only
];
const SYM = { s: "struct", h: "shadow", r: "rail", l: "lit", d: "dim",
              w: "warn" };

const grid = (fill = ".") =>
  Array.from({ length: H }, () => new Array(W).fill(fill));
const rows = (g) => g.map((r) => r.join(""));
const hline = (g, y, x0, x1, ch) => {
  for (let x = x0; x <= x1; x++) if (x >= 0 && x < W) g[y][x] = ch;
};

/** The channel: structure, not state. Authored once, worn by every state. */
function channel() {
  const g = grid();
  for (let y = 0; y < H; y++) hline(g, y, 0, W - 1, "s");
  hline(g, 0, 0, W - 1, "r");          // top rail catches the light
  hline(g, H - 1, 0, W - 1, "h");      // bottom edge in shadow
  for (let y = 5; y <= 10; y++) hline(g, y, 0, W - 1, "h");   // the trough
  hline(g, 4, 0, W - 1, "h");
  hline(g, 11, 0, W - 1, "h");
  // Clamps every 16 px -- 0.5 m, which is the shell's own bolt pitch.
  for (let x = 2; x < W; x += 16) {
    for (let y = 1; y < H - 1; y++) { g[y][x] = "r"; g[y][x + 1] = "s"; }
  }
  return g;
}

/** The band: transparent except the trough. This is the whole of the state. */
const BANDS = {
  inactive: {
    why: "An unbroken hairline at the dim value. A whole conduit with "
       + "nothing in it. Still, and continuous.",
    draw(g) {
      for (const y of [7, 8]) hline(g, y, 0, W - 1, "d");
    },
    motion: "none", brightness: "dim", pattern: "unbroken hairline",
    audio_required: "none",
  },
  active: {
    why: "Full-height lit bar with chevrons pointing the way the signal "
       + "goes. Scrolls +X at 0.6 m/s. Bright, patterned, moving.",
    draw(g) {
      for (let y = 6; y <= 9; y++) hline(g, y, 0, W - 1, "l");
      // Chevrons cut OUT of the bar every 8 px -- 0.25 m, so a 2 m run
      // carries eight of them. Cut rather than drawn: a mark added on top
      // of a bright bar loses its own outline the moment the bar scrolls
      // under it, and a notch cannot.
      for (let x = 0; x < W; x += 8) {
        const at = (k) => (x + k) % W;
        g[6][at(0)] = "s"; g[6][at(1)] = "s";
        g[7][at(1)] = "s"; g[7][at(2)] = "s";
        g[8][at(1)] = "s"; g[8][at(2)] = "s";
        g[9][at(0)] = "s"; g[9][at(1)] = "s";
      }
    },
    motion: "scrolls +X, 0.6 m/s", brightness: "bright",
    pattern: "directional chevrons", audio_required: "low hum (§19.5)",
  },
  pulse_travelling: {
    why: "One short lit block, 12 px (0.375 m), with a solid leading edge, "
       + "on an otherwise dim line. Scrolls +X at 4.0 m/s. The block's "
       + "LENGTH never changes -- that is what separates it from a delay.",
    draw(g) {
      hline(g, 7, 0, W - 1, "d"); hline(g, 8, 0, W - 1, "d");
      for (let y = 5; y <= 10; y++) hline(g, y, 24, 35, "l");
      for (let y = 4; y <= 11; y++) hline(g, y, 34, 35, "l");  // leading edge
      for (let y = 6; y <= 9; y++) hline(g, y, 20, 23, "d");   // short tail
    },
    motion: "scrolls +X, 4.0 m/s, constant length",
    brightness: "bright block on a dim line", pattern: "one block",
    audio_required: "click on arrival (§19.5)",
  },
  blocked: {
    why: "The same dim line, cut into 6 px segments with 4 px gaps, and one "
       + "hard break mark across the trough. Dim and SEVERED, against "
       + "inactive's dim and whole.",
    draw(g) {
      for (let x = 0; x < W; x += 10) {
        hline(g, 7, x, x + 5, "d"); hline(g, 8, x, x + 5, "d");
      }
      // The break. The one place `hazard` appears in this kit, and it is
      // the engine-owned universal hazard colour used for what it means.
      for (let y = 4; y <= 11; y++) {
        g[y][31] = "w"; g[y][32] = "w";
      }
      for (let y = 5; y <= 10; y++) { g[y][30] = "h"; g[y][33] = "h"; }
    },
    motion: "none", brightness: "dim",
    pattern: "broken segments plus a break mark", audio_required: "none",
  },
  delayed: {
    why: "A solid lit FILL from the source end behind a hard leading edge, "
       + "with the rest of the run dim. The fill GROWS; nothing travels. "
       + "This frame is the 55% one -- a runtime advances the edge.",
    draw(g) {
      hline(g, 7, 0, W - 1, "d"); hline(g, 8, 0, W - 1, "d");
      const edge = Math.round(W * 0.55);
      for (let y = 6; y <= 9; y++) hline(g, y, 0, edge - 1, "l");
      for (let y = 3; y <= 12; y++) { g[y][edge] = "l"; g[y][edge + 1] = "l"; }
      // Tick marks ahead of the edge: the run it still has to cover.
      for (let x = edge + 5; x < W; x += 6) {
        g[6][x] = "d"; g[9][x] = "d";
      }
    },
    motion: "the leading edge advances; the tail never leaves the source",
    brightness: "bright fill on a dim remainder",
    pattern: "solid fill behind a hard edge, ticks ahead of it",
    audio_required: "rising pitch (§19.5) -- THE ONE THAT CARRIES DURATION",
  },
};

async function publish(id, g, message) {
  const easel = await newEasel({
    path: join(SRC, `${id}.glyph`), owner: OWNER, artist: ARTIST,
    name: id, width: W, height: H, palette: PALETTE, partialAlpha: true,
  });
  await easel.draw(message,
    (b) => b.patch({ origin: [0, 0], rows: rows(g), symbols: SYM }));
  await easel.view({ scale: 1, into: join(PNG, `${id}.png`) });
  const big = await easel.view({ scale: 6, into: join(PNG, `${id}_6x.png`) });
  await easel.study({ from: big, tile: 3,
                      into: join(PNG, `${id}_3x3.png`) });
  easel.close();
}

await publish("conduit_channel", channel(),
  "The conduit channel: rails, trough and clamps at the shell's own 0.5 m "
  + "bolt pitch. Structure, worn by all five states, and it never changes.");

const meta = { batch: "043", authored: "2026-09-11",
  glyph_revision: sha(GLYPH_ROOT), design_revision: "a20bf55",
  design_section: "Design 1 §19.5, pinned by Design 6 §19",
  status: "PROPOSAL -- presentation only, no signal graph implemented",
  tile: { pixels: [W, H], metres: [W / DENSITY, H / DENSITY],
          texels_per_metre: DENSITY },
  audio: "NOT DELIVERED. §19.5 names a low hum, a click on arrival and a "
       + "rising pitch. None of the three exists and no still or sequence "
       + "here demonstrates them.",
  states: {} };

for (const [id, b] of Object.entries(BANDS)) {
  const g = grid();
  b.draw(g);
  await publish(`band_${id}`, g, `${id}: ${b.why}`);
  meta.states[id] = {
    texture: `png/band_${id}.png`, why: b.why, motion: b.motion,
    brightness: b.brightness, pattern: b.pattern,
    audio_required: b.audio_required,
  };
}
writeFileSync(join(OUT, "conduit_states.json"), JSON.stringify(meta, null, 2));
console.log("channel + %d states", Object.keys(BANDS).length);
