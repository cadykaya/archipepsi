"""Painting textures in code, structure-first.

Archipepsi's textures are painted pixel by pixel from `art_palette.json`,
the same way its geometry is built from `brushkit`. No image files are
sourced, no procedural noise library is used, and no texture is "made
retro" by downsampling something smoother -- that produces an
anti-aliased edge at low resolution, which reads as a compression artefact
rather than as a painted surface.

## The rule this module exists to enforce

> **A hash on a broad surface is digital camouflage.**

mario-3's most expensive paint lesson, and it applies here exactly. Every
cluster placed by a random number sits where a random number put it, so no
cluster means anything, and the result reads as *generated* rather than as
painted -- which for a game whose entire premise is "a local AI was handed a
1998 level editor" is the single worst thing the art could accidentally say.
Runtime Epsilon must never manufacture a texture; development-time art must
never look like it did.

So a painter here never gets only a coordinate. It gets a `Surface`: what
kind of surface this is, where its panel seams fall, where its bolts are,
where the floor is, which way is up. Every mark is then placed against that
structure -- streaks run DOWN from a fixture, wear sits AT an edge, soot
gathers ABOVE a vent -- and randomness survives only as a *breaker* inside a
zone structure already chose.

## Snap before colour

Density alone does not make a pixel look. A smooth rule sampled at any
resolution still reads as an anti-aliased edge. Every decision here is made
in whole texels: the shape is drawn IN pixels, never downsampled TO pixels.
"""

from __future__ import annotations

import hashlib
import math

import bpy
import numpy as np

import palette as pal


# ----------------------------------------------------------------------
# deterministic noise -- a breaker, never a placer
# ----------------------------------------------------------------------

class Hash:
    """Seeded, reproducible, and deliberately awkward to use as a placer.

    It takes a `zone` label as its first argument, so the call site has to
    name the structural region the randomness is breaking up. There is no
    way to ask this class "give me a random position", which is the API
    shape that made mario-3's Walker read as digital camouflage.
    """

    def __init__(self, seed):
        self._seed = str(seed)

    def breaker(self, zone, x, y, salt=""):
        """0.0-1.0, stable for (zone, x, y). Use to BREAK a chosen zone."""
        key = "%s|%s|%d|%d|%s" % (self._seed, zone, x, y, salt)
        digest = hashlib.sha256(key.encode("utf-8")).digest()
        return int.from_bytes(digest[:4], "big") / 0xFFFFFFFF


# ----------------------------------------------------------------------
# the canvas
# ----------------------------------------------------------------------

class Canvas:
    """An RGB texel grid, addressed in whole texels, top-left origin.

    Kept as float RGB in a numpy array because Blender wants floats back,
    but every drawing method takes integer texel coordinates. There is no
    sub-texel API on purpose.
    """

    def __init__(self, size, fill_hex):
        self.size = size
        self.px = np.zeros((size, size, 3), dtype=np.float32)
        self.px[:, :] = pal.rgb(fill_hex)

    # -- primitives ----------------------------------------------------
    def set(self, x, y, hex_or_rgb):
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[y, x] = _rgb(hex_or_rgb)

    def get(self, x, y):
        x = max(0, min(self.size - 1, x))
        y = max(0, min(self.size - 1, y))
        return tuple(self.px[y, x])

    def rect(self, x, y, w, h, hex_or_rgb):
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.size, x + w), min(self.size, y + h)
        if x1 > x0 and y1 > y0:
            self.px[y0:y1, x0:x1] = _rgb(hex_or_rgb)

    def hline(self, y, x0, x1, hex_or_rgb):
        self.rect(min(x0, x1), y, abs(x1 - x0) + 1, 1, hex_or_rgb)

    def vline(self, x, y0, y1, hex_or_rgb):
        self.rect(x, min(y0, y1), 1, abs(y1 - y0) + 1, hex_or_rgb)

    def outline(self, x, y, w, h, hex_or_rgb):
        self.rect(x, y, w, 1, hex_or_rgb)
        self.rect(x, y + h - 1, w, 1, hex_or_rgb)
        self.rect(x, y, 1, h, hex_or_rgb)
        self.rect(x + w - 1, y, 1, h, hex_or_rgb)

    def darken(self, x, y, amount):
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[y, x] *= max(0.0, 1.0 - amount)

    def lighten(self, x, y, amount):
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[y, x] = 1.0 - (1.0 - self.px[y, x]) * max(0.0, 1.0 - amount)

    def mix(self, x, y, hex_or_rgb, t):
        if 0 <= x < self.size and 0 <= y < self.size:
            target = np.array(_rgb(hex_or_rgb), dtype=np.float32)
            self.px[y, x] = self.px[y, x] * (1.0 - t) + target * t

    # -- families used -------------------------------------------------
    def to_blender(self, name):
        image = bpy.data.images.new(name, self.size, self.size, alpha=False)
        # Blender's pixel buffer is bottom-up RGBA.
        rgba = np.ones((self.size, self.size, 4), dtype=np.float32)
        rgba[:, :, :3] = np.flipud(self.px)
        image.pixels.foreach_set(rgba.ravel())
        image.pack()
        return image


def _rgb(value):
    if isinstance(value, str):
        return pal.rgb(value)
    return tuple(value)


# ----------------------------------------------------------------------
# structure -- what the painter is painting ON
# ----------------------------------------------------------------------

class Surface:
    """What this texture is a surface OF.

    Every field here answers a question a painter must be able to ask
    before it may place a mark. A painter handed only (x, y) has one tool
    left, and that tool is a hash.
    """

    def __init__(self, size, metres, kind, seams=(), bolt_pitch=0,
                 floor_edge=None, seed="archipepsi"):
        #: texels along one edge
        self.size = size
        #: how many world metres this texture covers
        self.metres = metres
        #: "wall" | "floor" | "ceiling" | "trim" | "panel" | "prop"
        self.kind = kind
        #: horizontal texel rows where a structural seam falls
        self.seams = tuple(seams)
        #: texels between bolts along a seam, 0 for none
        self.bolt_pitch = bolt_pitch
        #: which edge of the texture meets the ground: "bottom" | None
        self.floor_edge = floor_edge
        self.hash = Hash(seed)

    @property
    def texels_per_metre(self):
        return self.size / float(self.metres)

    def texels(self, metres):
        """Convert a real-world size to whole texels. Rounds UP to 1.

        Know the texel size before designing a detail: below ~2 texels a
        feature does not survive the render, and the honest response is to
        make it bigger or leave it out -- never to draw it at 0.6 texels
        and hope.
        """
        return max(1, int(round(metres * self.texels_per_metre)))

    def nearest_seam(self, y):
        if not self.seams:
            return self.size * 2
        return min(abs(y - seam) for seam in self.seams)

    def height_above_floor(self, y):
        """Texels above the ground edge, or None when there is no ground."""
        if self.floor_edge != "bottom":
            return None
        return self.size - 1 - y


# ----------------------------------------------------------------------
# the structural paint verbs
# ----------------------------------------------------------------------

def panel_seams(canvas, surface, dark, light):
    """Draw the seams the surface says it has. Two texels: shadow, then lip.

    A seam is one texel of shadow and one of highlight, in that order top to
    bottom, because a panel laps over the one below it and that is the only
    thing that tells the eye which way the wall was assembled.
    """
    for seam in surface.seams:
        canvas.hline(seam, 0, surface.size - 1, dark)
        if seam + 1 < surface.size:
            canvas.hline(seam + 1, 0, surface.size - 1, light)


def bolts(canvas, surface, dark, light, inset=2):
    """Bolts ON the seams, at the surface's own pitch. Never scattered.

    A bolt that is not on a seam is not a bolt, it is a speck. This is the
    smallest example of the whole module's thesis and the easiest to get
    wrong.
    """
    if not surface.bolt_pitch or not surface.seams:
        return
    for seam in surface.seams:
        y = seam - inset
        if y < 1:
            continue
        for x in range(surface.bolt_pitch // 2, surface.size,
                       surface.bolt_pitch):
            canvas.set(x, y, dark)
            canvas.set(x, y - 1, light)


def edge_wear(canvas, surface, hex_color, reach_texels, strength=0.7):
    """Wear at the texture's own edges -- where a module meets a module.

    A rim is a FIXED WIDTH IN THE WORLD, never a fraction of the surface.
    mario-3's version expressed it as a fraction and every texel on a small
    plate became an "edge", which is how an asset ends up uniformly noisy.
    """
    size = surface.size
    for y in range(size):
        for x in range(size):
            edge = min(x, y, size - 1 - x, size - 1 - y)
            if edge >= reach_texels:
                continue
            fade = 1.0 - edge / float(reach_texels)
            # A breaker, INSIDE a zone the structure already chose.
            if surface.hash.breaker("edge", x, y) > fade * strength:
                continue
            canvas.mix(x, y, hex_color, 0.35 + 0.45 * fade)


def streak(canvas, surface, from_x, from_y, length, hex_color, width=1,
           strength=0.55):
    """A stain running DOWN from a specific thing. Gravity is structure.

    The caller must say what it is running from. There is no "add some
    streaks" call, because streaks that come from nothing are the exact
    failure this module is built to prevent -- and a wall covered in them
    is a wall with a story nobody wrote.
    """
    for i in range(length):
        y = from_y + i
        if y >= surface.size:
            break
        fade = (1.0 - i / float(length)) * strength
        for w in range(width):
            x = from_x + w
            jitter = surface.hash.breaker("streak", x, y)
            if jitter > 0.25 + 0.6 * fade:
                continue
            canvas.mix(x, y, hex_color, fade)


def grime_pool(canvas, surface, hex_color, strength=0.5):
    """Dirt gathers where dirt gathers: the floor line and the seams.

    Not "blotches at random points". The two places a real surface gets
    dirty are the bottom, where everything settles, and every horizontal
    ledge a seam creates.
    """
    size = surface.size
    for y in range(size):
        near_floor = 0.0
        if surface.floor_edge == "bottom":
            depth = size - 1 - y
            near_floor = max(0.0, 1.0 - depth / (size * 0.22))
        near_seam = max(0.0, 1.0 - surface.nearest_seam(y) / (size * 0.06))
        weight = max(near_floor, near_seam * 0.7)
        if weight <= 0.02:
            continue
        for x in range(size):
            if surface.hash.breaker("grime", x, y) > weight:
                continue
            canvas.mix(x, y, hex_color, strength * weight)


def broad_patches(canvas, surface, steps, cell_metres=0.35, density=0.35,
                  strength=0.35):
    """Large, low-contrast value patches: a pour mark, a damp patch, a repair.

    This is the verb that makes a flat fill look like a real surface, and it
    is deliberately COARSE. The first version of this module had one
    `value_grain` call doing both this and the speckle below at a 2-texel
    cell, and the result was a fine dither over the whole texture -- which
    is the digital camouflage this module's own docstring warns about,
    committed by the module itself on its first render.

    The fix is the same one mario-3 arrived at: a patch has to be big enough
    to read AS a patch. At 32 texels/m a 0.35 m cell is 11 texels, which is
    a mark on a wall. At 2 texels it is noise.
    """
    size = surface.size
    cell = max(3, surface.texels(cell_metres))
    # Jitter each row of cells sideways. Without it the patches line up into
    # a visible lattice -- which was the second render of this function: the
    # patches read fine individually and the WALL read as a tiled grid,
    # because every cell boundary in a column agreed with every other.
    for row, y in enumerate(range(-cell, size + cell, cell)):
        shift = int(surface.hash.breaker("row", row, 0) * cell)
        for x in range(-cell + shift, size + cell, cell):
            roll = surface.hash.breaker("patch", x // max(1, cell), row)
            if roll > density:
                continue
            index = int((roll / density) * len(steps)) % len(steps)
            # Ragged edges. A rectangular patch reads as a tile no matter
            # how well it is coloured.
            w = cell + int(surface.hash.breaker("pw", x, row) * cell * 0.6)
            h = cell + int(surface.hash.breaker("ph", x, row) * cell * 0.4)
            for yy in range(max(0, y), min(size, y + h)):
                for xx in range(max(0, x), min(size, x + w)):
                    edge = min(xx - x, yy - y, x + w - 1 - xx, y + h - 1 - yy)
                    if edge <= 1 and surface.hash.breaker(
                            "patchedge", xx, yy) > 0.35 + 0.35 * edge:
                        continue
                    # MIX, never set. The first sheet used a hard set with
                    # steps two apart on the ramp, and the patches read as
                    # pasted rectangles rather than as a surface that had
                    # been poured in more than one go. A patch is a shift in
                    # value, not a different material.
                    canvas.mix(xx, yy, steps[index], strength)


def speckle(canvas, surface, hex_color, zone, density=0.03, strength=0.5):
    """Aggregate, pitting, chipped grit -- INSIDE a zone structure chose.

    `zone(x, y) -> 0..1` is mandatory and has no default. That signature is
    the fix for this module's second self-inflicted failure: the first
    version took only a density, painted an even pepper across the whole
    tile, and every material sheet came out with the same all-over dark
    static on it. It was the exact digital camouflage the module's own
    docstring warns about, committed twice, because a function that takes
    only a density has no way to be anything else.

    So the caller must say WHERE grit gathers on this surface -- near a
    seam, along the floor, at a worn rim, inside a patch -- and the density
    is then modulated by that. A caller that genuinely wants it everywhere
    has to write `lambda x, y: 1.0`, which is at least a decision somebody
    made on purpose.
    """
    density = min(0.12, density)
    size = surface.size
    for y in range(size):
        for x in range(size):
            weight = zone(x, y)
            if weight <= 0.0:
                continue
            if surface.hash.breaker("speckle", x, y) > density * weight:
                continue
            canvas.mix(x, y, hex_color, strength)


def near_seams(surface, reach_metres=0.10):
    """A zone: strongest at a structural seam, zero away from one."""
    reach = max(1, surface.texels(reach_metres))

    def zone(x, y):
        return max(0.0, 1.0 - surface.nearest_seam(y) / float(reach))
    return zone


def near_floor(surface, reach_metres=0.6):
    """A zone: strongest at the ground edge."""
    reach = max(1, surface.texels(reach_metres))

    def zone(x, y):
        above = surface.height_above_floor(y)
        if above is None:
            return 0.0
        return max(0.0, 1.0 - above / float(reach))
    return zone


def near_edges(surface, reach_metres=0.12):
    """A zone: strongest at the texture's own boundary, where modules meet."""
    reach = max(1, surface.texels(reach_metres))
    size = surface.size

    def zone(x, y):
        edge = min(x, y, size - 1 - x, size - 1 - y)
        return max(0.0, 1.0 - edge / float(reach))
    return zone


def zone_or(*zones):
    """Combine zones by taking the strongest. Still structure, still chosen."""
    def zone(x, y):
        return max(z(x, y) for z in zones)
    return zone


def panel_grid(canvas, surface, dark, light, pitch_metres,
               vertical_pitch_metres=None):
    """Seams in BOTH axes -- a wall is panels, not horizontal courses.

    `panel_seams` draws only the horizontal courses the surface declares.
    That was enough to make the first material sheet read as *striped*
    rather than as *panelled*, because nothing ever divided the tile
    left-to-right and a 4 m span of unbroken surface is not a panel, it is a
    wall with lines on it.
    """
    step = max(2, surface.texels(pitch_metres))
    for y in range(0, surface.size, step):
        canvas.hline(y, 0, surface.size - 1, dark)
        if y + 1 < surface.size:
            canvas.hline(y + 1, 0, surface.size - 1, light)
    vstep = max(2, surface.texels(vertical_pitch_metres or pitch_metres))
    for x in range(0, surface.size, vstep):
        canvas.vline(x, 0, surface.size - 1, dark)
        if x + 1 < surface.size:
            canvas.vline(x + 1, 0, surface.size - 1, light)


def tonal_drift(canvas, surface, amount=0.05, cell_metres=0.9):
    """A very slow value gradient across the surface, stepped into bands.

    What stops a tiling texture reading as a stamp repeated across a wall.
    Stepped, never smooth: a smooth gradient at this density bands anyway
    under NEAREST filtering, and banding you did not choose looks like an
    artefact while banding you did looks like paint.
    """
    size = surface.size
    cell = max(4, surface.texels(cell_metres))
    for y in range(0, size, cell):
        for x in range(0, size, cell):
            roll = surface.hash.breaker("drift", x // cell, y // cell)
            delta = (roll - 0.5) * 2.0 * amount
            for yy in range(y, min(size, y + cell)):
                for xx in range(x, min(size, x + cell)):
                    if delta > 0:
                        canvas.lighten(xx, yy, delta)
                    else:
                        canvas.darken(xx, yy, -delta)


def hazard_stripes(canvas, x, y, w, h, dark, light, pitch=4):
    """Diagonal hazard banding. The one place a diagonal belongs.

    Snapped to whole texels: a stripe drawn as a smooth diagonal and then
    sampled is an anti-aliased line, and an anti-aliased line at 32
    texels/m is a blur, not a stripe.
    """
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            canvas.set(xx, yy, light if ((xx + yy) // pitch) % 2 else dark)


def stencil(canvas, surface, x, y, glyph_rows, hex_color):
    """Stencilled marks, drawn as literal texel rows.

    A label is worth having only if it is legible: at 32 texels/m a 5-texel
    glyph is 0.16 m tall on a wall, which is a real stencil. Anything
    smaller is a smudge and should be a smudge on purpose, not a failed
    letter.
    """
    for row, bits in enumerate(glyph_rows):
        for col, bit in enumerate(bits):
            if bit not in " .0":
                canvas.set(x + col, y + row, hex_color)


#: A tiny 3x5 stencil alphabet. Deliberately minimal -- signage in this
#: project says short words in large letters, because a long word at this
#: density is a grey bar.
GLYPHS = {
    "A": ["###", "# #", "###", "# #", "# #"],
    "B": ["## ", "# #", "## ", "# #", "## "],
    "C": ["###", "#  ", "#  ", "#  ", "###"],
    "D": ["## ", "# #", "# #", "# #", "## "],
    "E": ["###", "#  ", "## ", "#  ", "###"],
    "F": ["###", "#  ", "## ", "#  ", "#  "],
    "G": ["###", "#  ", "# #", "# #", "###"],
    "H": ["# #", "# #", "###", "# #", "# #"],
    "I": ["###", " # ", " # ", " # ", "###"],
    "K": ["# #", "# #", "## ", "# #", "# #"],
    "L": ["#  ", "#  ", "#  ", "#  ", "###"],
    "N": ["# #", "###", "###", "###", "# #"],
    "O": ["###", "# #", "# #", "# #", "###"],
    "P": ["###", "# #", "###", "#  ", "#  "],
    "R": ["###", "# #", "###", "## ", "# #"],
    "S": ["###", "#  ", "###", "  #", "###"],
    "T": ["###", " # ", " # ", " # ", " # "],
    "U": ["# #", "# #", "# #", "# #", "###"],
    "V": ["# #", "# #", "# #", "# #", " # "],
    "W": ["# #", "# #", "###", "###", "# #"],
    "X": ["# #", "# #", " # ", "# #", "# #"],
    "Y": ["# #", "# #", "###", " # ", " # "],
    "Z": ["###", "  #", " # ", "#  ", "###"],
    "0": ["###", "# #", "# #", "# #", "###"],
    "1": [" # ", "## ", " # ", " # ", "###"],
    "2": ["###", "  #", "###", "#  ", "###"],
    "3": ["###", "  #", "###", "  #", "###"],
    "4": ["# #", "# #", "###", "  #", "  #"],
    "5": ["###", "#  ", "###", "  #", "###"],
    "6": ["###", "#  ", "###", "# #", "###"],
    "7": ["###", "  #", "  #", "  #", "  #"],
    "8": ["###", "# #", "###", "# #", "###"],
    "9": ["###", "# #", "###", "  #", "###"],
    "-": ["   ", "   ", "###", "   ", "   "],
    ".": ["   ", "   ", "   ", "   ", "#  "],
    " ": ["   ", "   ", "   ", "   ", "   "],
}


def text(canvas, surface, x, y, message, hex_color, spacing=1):
    """Stencil a short word. Returns the width it consumed, in texels."""
    cursor = x
    for char in message.upper():
        glyph = GLYPHS.get(char)
        if glyph is None:
            cursor += 3 + spacing
            continue
        stencil(canvas, surface, cursor, y, glyph, hex_color)
        cursor += len(glyph[0]) + spacing
    return cursor - x


def text_width(message, spacing=1):
    return max(0, len(message) * (3 + spacing) - spacing)
