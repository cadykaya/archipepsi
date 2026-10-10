// The four family frames, the compound frame, and the player-applied tick.
//
// Design 5 §33.7 names the four treatments and nothing else: KINETIC
// angular, COGNITIVE rounded, PERMISSION barred, MATERIAL irregular. What
// each one actually looks like is an art decision, and these are it.
//
// THEY ARE BUILT PROCEDURALLY AND THE GLYPHS ARE NOT, on purpose. A frame is
// a regular geometric figure whose job is to be recognised at a glance and to
// be IDENTICAL under every glyph it wraps; hand-placing 32x32 of those four
// times would only introduce drift. A glyph is a drawing.
//
// SIZES. Frame 32x32, glyph 16x16 seated at (8,8). The 12 px clear radius the
// frame leaves is just over the 11.3 px a 16x16 square needs at its corners,
// so no glyph in the kit can ever touch its frame. That one number is why the
// marker is 32 and not 24: at 24 the frame stroke cut the glyph's corners.

export const MARKER = 32;
export const GLYPH = 16;
export const INSET = (MARKER - GLYPH) / 2;      // 8
const C = (MARKER - 1) / 2;                     // 15.5

const blank = (n) => Array.from({ length: n }, () => new Array(n).fill(0));

function thick(mask, ax, ay, bx, by, w) {
  const n = Math.max(Math.abs(bx - ax), Math.abs(by - ay)) * 4 + 1;
  const r = (w - 1) / 2;
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    const x = ax + (bx - ax) * t, y = ay + (by - ay) * t;
    for (let dy = -Math.ceil(r); dy <= Math.ceil(r); dy++) {
      for (let dx = -Math.ceil(r); dx <= Math.ceil(r); dx++) {
        const px = Math.round(x) + dx, py = Math.round(y) + dy;
        if (px < 0 || py < 0 || px >= MARKER || py >= MARKER) continue;
        if (Math.hypot(dx, dy) <= r + 0.35) mask[py][px] = 1;
      }
    }
  }
}

/** An annulus: every pixel whose centre distance falls in [r0, r1]. */
function ring(mask, r0, r1, keep = () => true) {
  for (let y = 0; y < MARKER; y++) {
    for (let x = 0; x < MARKER; x++) {
      const dx = x - C, dy = y - C;
      const d = Math.hypot(dx, dy);
      if (d < r0 || d > r1) continue;
      // Screen angle, 0 at 12 o'clock, growing clockwise -- the same
      // convention the depletion track uses, so `keep` can speak in it.
      let a = (Math.atan2(dx, -dy) * 180) / Math.PI;
      if (a < 0) a += 360;
      if (keep(a, d)) mask[y][x] = 1;
    }
  }
}

function regularPolygon(sides, radius, phaseDeg) {
  return Array.from({ length: sides }, (_, i) => {
    const a = ((phaseDeg + (360 / sides) * i) * Math.PI) / 180;
    return [C + radius * Math.sin(a), C - radius * Math.cos(a)];
  });
}

function closedPath(mask, pts, w) {
  for (let i = 0; i < pts.length; i++) {
    const [ax, ay] = pts[i], [bx, by] = pts[(i + 1) % pts.length];
    thick(mask, ax, ay, bx, by, w);
  }
}

export const FRAMES = [
  {
    id: "frame_kinetic", family: "KINETIC", treatment: "angular",
    why: "An octagon with four spikes on the axes. Every transition is a "
       + "corner and the silhouette is pointed: nothing else in the set has "
       + "a straight run meeting another straight run.",
    build() {
      const m = blank(MARKER);
      closedPath(m, regularPolygon(8, 12.6, 22.5), 2);
      // Two spikes, on the horizontal axis only. Four spikes on the axes
      // drew a RETICLE, and §33.10 rule 1 spends a paragraph keeping these
      // markers off the crosshair -- a marker shaped like one is the same
      // mistake wearing a different hat. Two is also the better reading:
      // KINETIC is the family of things being moved, and sideways is where
      // an impulse takes them.
      for (const a of [90, 270]) {
        const r = (a * Math.PI) / 180;
        thick(m, C + 10.5 * Math.sin(r), C - 10.5 * Math.cos(r),
                 C + 14.0 * Math.sin(r), C - 14.0 * Math.cos(r), 2.2);
      }
      return m;
    },
  },
  {
    id: "frame_cognitive", family: "COGNITIVE", treatment: "rounded",
    why: "One continuous circle. No corner, no break, no protrusion -- it is "
       + "the only closed smooth curve in the set, and it is recognised by "
       + "what it does NOT have.",
    build() {
      const m = blank(MARKER);
      ring(m, 12.2, 14.1);
      return m;
    },
  },
  {
    id: "frame_permission", family: "PERMISSION", treatment: "barred",
    why: "A square clamped between a lintel and a sill that run wider than "
       + "it does. The overhang is the tell: at native size the silhouette "
       + "is wider than it is tall, and no other frame is. The first version "
       + "ran the bars to the tile edge and three PERMISSION markers side by "
       + "side fused into one continuous rail -- the overhang has to be "
       + "visible AND bounded, so it stops two pixels short.",
    build() {
      const m = blank(MARKER);
      closedPath(m, [[6, 6], [25, 6], [25, 25], [6, 25]], 2);
      thick(m, 4, 3, 27, 3, 2);        // lintel, overhanging both sides
      thick(m, 4, 28, 27, 28, 2);      // sill
      return m;
    },
  },
  {
    id: "frame_material", family: "MATERIAL", treatment: "irregular",
    why: "A loop that has been eaten: the radius wanders by a pixel and a "
       + "half and three arcs are missing entirely. Irregularity has to be "
       + "structural, not noisy -- one stray pixel reads as a mistake, a "
       + "wandering radius reads as corrosion.",
    build() {
      const m = blank(MARKER);
      // Deterministic wobble. A seeded hash rather than Math.random so the
      // same source always produces the same frame.
      const wob = (a) => {
        const s = Math.sin(a * 0.0873) * 43758.5453;
        return (s - Math.floor(s) - 0.5) * 2.6;
      };
      // Three SHORT bites. The first version took 22, 18 and 26 degrees
      // out and the loop stopped reading as a loop at all -- it read as
      // three parentheses. Corrosion eats an edge; it does not delete a
      // third of it.
      const gaps = [[42, 53], [154, 164], [266, 278]];
      ring(m, 11.6, 14.6, (a, d) => {
        if (gaps.some(([lo, hi]) => a >= lo && a <= hi)) return false;
        const mid = 13.1 + wob(a) * 0.62;
        return Math.abs(d - mid) <= 1.1;
      });
      return m;
    },
  },
  {
    id: "frame_compound", family: "COMPOUND", treatment: "doubled",
    why: "PROPOSED, NOT SPECIFIED. §15.5 gives the eight compounds no frame "
       + "of their own and §33.7 names four family treatments, so a compound "
       + "would otherwise have to borrow a parent's frame and lie about its "
       + "family. TWO concentric rings: it belongs to no family, and it is "
       + "visibly two of something, which is the true statement about it. "
       + "The first version was one ring with four diagonal spurs and it was "
       + "indistinguishable from COGNITIVE at native size -- the spurs read "
       + "as noise on the outline rather than as structure.",
    build() {
      const m = blank(MARKER);
      ring(m, 12.1, 13.1);      // inner: clears the glyph corners at 11.31
      ring(m, 14.1, 15.0);      // outer: the ink between them draws the gap
      return m;
    },
  },
];

/**
 * The player-applied tick, 8x8, seated OUTSIDE the marker's lower right.
 *
 * It used to be gold, and the gold was the only thing separating it from the
 * frame it overlapped. With the kit neutral (see `author_status_kit.mjs` on
 * why `send` was the wrong colour to borrow) the tick has to be separated by
 * geometry instead: it sits clear of the frame's outer edge, so the ink
 * outline of each draws a gap between them, and its stroke is two pixels so
 * it reads as a mark rather than as a nick in the ring.
 */
export const TICK = [
  ".....XX.",
  "....XX..",
  "...XX...",
  "X..XX...",
  "XX.XX...",
  ".XXX....",
  "..XX....",
  "........",
];
export const TICK_AT = [23, 23];

/**
 * The depletion track: the frame's own outer edge, in clockwise order from
 * 12 o'clock.
 *
 * There is no separate ring asset and there should not be. §33.7 says "the
 * marker depletes around its edge", so the edge IS the track, and a second
 * concentric ring would be a second thing to align, tint and keep in sync.
 * A runtime paints the first `remaining` fraction of this list bright and
 * the rest dim; how many pixels that is falls out of the list length.
 */
export function track(mask) {
  const pts = [];
  for (let y = 0; y < MARKER; y++) {
    for (let x = 0; x < MARKER; x++) {
      if (!mask[y][x]) continue;
      // Outer edge only: a pixel with at least one empty 4-neighbour
      // further from centre than itself.
      const d = Math.hypot(x - C, y - C);
      const outer = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= MARKER || ny >= MARKER) return true;
        return !mask[ny][nx] && Math.hypot(nx - C, ny - C) > d;
      });
      if (!outer) continue;
      let a = (Math.atan2(x - C, -(y - C)) * 180) / Math.PI;
      if (a < 0) a += 360;
      pts.push({ x, y, a, d });
    }
  }
  pts.sort((p, q) => p.a - q.a || q.d - p.d);
  return pts.map((p) => [p.x, p.y]);
}
