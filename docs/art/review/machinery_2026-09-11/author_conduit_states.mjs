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
// blocked vs inactive, AND THE RULE THIS PAIR NEARLY BROKE.
//
// §19.5's own table gives `inactive` "dim, static, no audio" and `blocked`
// "dim with a broken-segment pattern, no audio". Read literally those two
// differ in PATTERN ALONE -- and the same section requires every state to
// differ in at least two of brightness, pattern, motion and audio. The
// section's table does not satisfy the section's rule for this one pair.
//
// A first pass of this kit reproduced that, and then reached for `hazard`
// orange on the break mark to make up the difference. That was wrong twice:
// it leaned on hue, which §50 forbids, and `hazard` means THIS WILL HURT
// YOU. A blocked conduit is inert. It is a signal that is not arriving, not
// a thing that burns you, and teaching a player otherwise costs more than a
// dull-looking conduit ever would.
//
// So the second channel is BRIGHTNESS, and it is MEASURED rather than
// asserted -- see `assertTwoChannels()` at the foot of this file, which
// reduces each composited state to CIE L* and fails the build if the pair
// this comment claims to separate does not actually separate.
//
// A first attempt at that separation made `blocked` dimmer than `inactive`
// and measured 25.0 against 23.9 -- one L* apart, which is nothing. It also
// had the semantics backwards. `inactive` is scenery: a conduit with no
// signal in it, and the player has nothing to do about it. `blocked` is a
// PUZZLE STATE: something is trying to get through and cannot, and the
// player is meant to notice it from across the room. So:
//
//   inactive   a thin continuous hairline at a low value. Whole, calm,
//              and almost not there.
//   blocked    tall segments at a much higher value, each capped by a
//              bright cut end, with one wide severance in the run. Brighter
//              overall AND broken, against dim and whole.
//
// Two channels, no hue, no hazard, and both states still still.
//
// AUDIO IS NOT DELIVERED AND IS NOT PRETENDED. §19.5 names a low hum, a
// click on arrival and a rising pitch. None of them exists, and each is an
// integration requirement.
//
// A CORRECTION TO THIS FILE'S OWN EARLIER CLAIM. It said the rising pitch
// was the only channel that tells the player HOW LONG. That is not what
// §19.5 says. Its row for `delayed` reads "filling-band animation showing
// remaining time, rising pitch" -- the FILLING BAND carries the remaining
// time and is required to, and the pitch is the second channel beside it.
//
// So the visual half is not a consolation for missing audio; it is the
// primary timing display, and this kit owes it a real one. `band_delayed`
// is a fill behind a hard leading edge with a marked END STOP, so a player
// can read how far the edge has come and how far it has left to go from a
// single frame. The room preview shows a labelled, known-duration delay
// with both endpoints marked.

import { mkdirSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

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
// Glyph's own PNG codec, resolved out of the checkout the easel came from,
// so the measurement below reads the same bytes the renderer wrote rather
// than a second decoder's opinion of them.
const { decodePng } = await import(
  pathToFileURL(join(GLYPH_ROOT, "packages", "io", "dist", "index.js")).href);

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
  { name: "dim", value: [104, 112, 122, 255] },   // L* 46, the neutral dim
  { name: "idle", value: [86, 93, 102, 255] },    // L* 38, inactive's line
  { name: "stuck", value: [139, 147, 157, 255] }, // L* 60, blocked's blocks
  { name: "cut", value: [195, 202, 210, 255] },   // L* 81, a severed end
];
const SYM = { s: "struct", h: "shadow", r: "rail", l: "lit", d: "dim",
              i: "idle", k: "stuck", c: "cut" };

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
    why: "A thin unbroken hairline, low value, end to end. A whole conduit "
       + "with nothing in it -- scenery rather than a problem. Still, "
       + "continuous, and the dimmest state in the kit.",
    draw(g) {
      for (const y of [7, 8]) hline(g, y, 0, W - 1, "i");
    },
    motion: "none", brightness: "lowest in the kit (L* 38 line)",
    pattern: "unbroken hairline", audio_required: "none",
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
    why: "Segments at a LOWER value than inactive's line, each capped by a "
       + "short bright cut-end, and one wide gap where the run is severed. "
       + "Dimmer AND severed, against inactive's dim and whole -- two "
       + "channels, and neither of them hue.",
    draw(g) {
      // Tall blocks -- they fill the trough -- so the state has real area
      // and a mean brightness well above inactive's hairline.
      for (let x = 0; x < W; x += 10) {
        for (let y = 5; y <= 10; y++) hline(g, y, x, x + 6, "k");
        // Both cut ends, brighter still: the flow stops HERE.
        for (let y = 5; y <= 10; y++) { g[y][x % W] = "c"; g[y][(x + 6) % W] = "c"; }
      }
      // The severance: a gap wider than any between segments, with taller
      // cut ends either side, so ONE break reads as THE break.
      for (let x = 27; x <= 36; x++) {
        for (let y = 4; y <= 11; y++) g[y][x] = ".";
      }
      for (let y = 3; y <= 12; y++) { g[y][26] = "c"; g[y][37] = "c"; }
    },
    motion: "none",
    brightness: "well above inactive (L* 60 blocks against a L* 38 line)",
    pattern: "tall broken blocks, bright cut ends, one wide severance",
    audio_required: "none",
  },
  delayed: {
    why: "THE TRACK, NOT THE FILL. A marked START STOP at the source, a "
       + "marked END STOP at arrival, a dim hairline between them and "
       + "quarter marks along it. Both endpoints and every graduation are "
       + "STATIC and full length, in every frame of the delay.\n\n"
       + "The fill is separate GEOMETRY -- the `fill_band` node -- which "
       + "grows from the source stop across this track. That split is the "
       + "whole point. A first version drew the fill into this texture and "
       + "scaled the band to grow it, which squashed the track's own end "
       + "stops along with it: at 0% the arrival stop sat 12% of the way "
       + "along the run, so the span the fill is a fraction OF moved with "
       + "the fill, and the player could not read a fraction at all. "
       + "Endpoints that move are not endpoints.",
    draw(g) {
      for (const y of [7, 8]) hline(g, y, 2, W - 3, "i");
      // The two end stops: full-height, static, and always both present.
      for (let y = 2; y <= 13; y++) { g[y][0] = "c"; g[y][1] = "c"; }
      for (let y = 2; y <= 13; y++) { g[y][W - 2] = "c"; g[y][W - 1] = "c"; }
      // Quarter marks: the graduations that turn "a bar" into "how far".
      for (let x = 16; x < W - 3; x += 16) {
        for (let y = 4; y <= 11; y++) g[y][x] = "d";
      }
    },
    motion: "the `fill_band` node grows from the source stop; the track "
          + "and both its endpoints never move",
    brightness: "a bright fill over a dim track",
    pattern: "a static graduated track between two fixed end stops, with a "
           + "growing fill across it",
    fill_is: "GEOMETRY, not texture: the `fill_band` node on "
           + "mach_conduit_run. This texture is the track only.",
    audio_required: "rising pitch (§19.5), as the SECOND timing channel -- "
                  + "the filling band is the first and §19.5 requires it",
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
       + "here demonstrates them. It is an integration requirement and NOT "
       + "the only timing information: §19.5 requires the filling band to "
       + "show remaining time, and `band_delayed` does.",
  two_channel_rule: "§19.5 requires every state to differ from every other "
       + "in at least two of brightness, pattern, motion and audio. NOTE "
       + "that §19.5's own table separates `inactive` and `blocked` by "
       + "pattern alone; this kit adds a brightness difference so the pair "
       + "satisfies the rule the section states.",
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
// -- the two-channel rule, MEASURED --------------------------------------
//
// A comment claiming two states differ in brightness is worth nothing; the
// first version of this file carried exactly that comment while the two
// states measured 1.1 L* apart. So the claim is computed from the actual
// composited pixels and the build fails if it is false.
function srgbToL(r, g, b) {
  const lin = (c) => {
    const v = c / 255;
    return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  };
  const y = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
  return y > 0.008856 ? 116 * Math.cbrt(y) - 16 : 903.3 * y;
}

function troughStats(id) {
  const chan = decodePng(readFileSync(join(PNG, "conduit_channel.png")));
  const band = decodePng(readFileSync(join(PNG, `band_${id}.png`)));
  let sum = 0, n = 0, peak = 0;
  for (let y = 4; y <= 11; y++) {
    for (let x = 0; x < W; x++) {
      const i = y * W + x;
      const bp = band.pixels[i], cp = chan.pixels[i];
      const a = bp & 0xff;
      const px = a === 255 ? bp : cp;           // source-over, opaque bands
      const L = srgbToL((px >>> 24) & 0xff, (px >>> 16) & 0xff,
                        (px >>> 8) & 0xff);
      sum += L; n += 1; peak = Math.max(peak, L);
    }
  }
  return { mean: sum / n, peak };
}

const MIN_BRIGHTNESS_GAP = 8.0;   // L*, comfortably outside display noise
const stats = {};
for (const id of Object.keys(BANDS)) stats[id] = troughStats(id);
const gap = Math.abs(stats.inactive.mean - stats.blocked.mean);
if (gap < MIN_BRIGHTNESS_GAP) {
  throw new Error(
    `inactive and blocked differ by ${gap.toFixed(1)} L* in the trough, `
    + `under the ${MIN_BRIGHTNESS_GAP} L* floor. §19.5 requires two of `
    + `brightness, pattern, motion and audio, and this pair has no motion `
    + `and no audio -- so brightness has to do real work or the pair is `
    + `separated by pattern alone.`);
}
for (const [id, st] of Object.entries(stats)) {
  meta.states[id].measured_trough_L = {
    mean: Number(st.mean.toFixed(1)), peak: Number(st.peak.toFixed(1)),
  };
}
meta.two_channel_measurement = {
  rule: `|mean L*(inactive) - mean L*(blocked)| >= ${MIN_BRIGHTNESS_GAP}`,
  inactive_mean: Number(stats.inactive.mean.toFixed(1)),
  blocked_mean: Number(stats.blocked.mean.toFixed(1)),
  gap: Number(gap.toFixed(1)),
  asserted_by: "author_conduit_states.mjs, at authoring time",
};

writeFileSync(join(OUT, "conduit_states.json"), JSON.stringify(meta, null, 2));
console.log(`channel + ${Object.keys(BANDS).length} states`);
for (const [id, st] of Object.entries(stats)) {
  console.log(`  ${id.padEnd(18)} trough L* mean ${st.mean.toFixed(1)
    .padStart(5)}  peak ${st.peak.toFixed(1).padStart(5)}`);
}
console.log(`  inactive/blocked brightness gap ${gap.toFixed(1)} L* `
          + `(floor ${MIN_BRIGHTNESS_GAP.toFixed(1)})`);
