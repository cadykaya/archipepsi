# Batch 043 — the decisions that genuinely need you

**Arty**

Five, and no more. Everything else in this batch was a routine artistic call
and was made without asking.

---

## 1. Do the four status families get a colour, and if so, from where?

**This is the one that blocks nothing and changes everything.**

Design 5 §33.7 requires family to be carried by *"shape, never colour
alone."* That permits colour as a second channel; it does not supply one.
And the palette has no room left: `signal`, `hazard`, `identity`, `dead`,
`send` and `glitch` already own fixed meanings, `palette.MUST_NOT_CONFUSE`
holds three of them 45° apart by rule, and four more saturated families
would collide with one of the six at any hue I could pick.

So **the kit is neutral** — one ink, one face value, one dim, one spent —
and it satisfies §33.7 completely on its own. The shape studies are finished
and do not wait on this.

What I need from you is whether that is the answer or a placeholder:

- **(a) Stay neutral.** Family is shape. Simplest, safest, already done.
- **(b) Give the four families a low-chroma tint band** — chroma under 18,
  which is below the gate's own floor for a signalling family, so it can
  never be read as one. A tint, not a hue.
- **(c) Open the palette** and assign four new saturated families. This is a
  palette decision, not an art-lane one, and I have not taken it.

## 2. May the player-applied tick use `send` (#ffd45c)?

§33.7: *"A small tick on the marker; Statuses the player did not cause lack
it."* The tick in this kit is `send` yellow, because `send` already means
"this one came from you / this one is going out" and the tick means exactly
that. It is the only reserved colour the status kit touches.

If you would rather nothing reused a grammar colour, it is one palette entry
and the tick goes neutral. **The tick's job survives either way** — its
shape and its position are what carry it, and it is the only gold thing on
screen in both versions.

## 3. Do compounds get their own frame?

§15.5 gives the eight compounds no frame and §33.7 names four family
treatments. A compound built from a `KINETIC` and a `MATERIAL` component
belongs to neither, so wearing either parent's frame would be a lie about
its family.

I proposed a fifth treatment — **two concentric rings**, belonging to no
family and visibly two of something. It is in `SHEET_frames.png`.

The alternative, if you would rather not add a treatment: a compound wears
the frame of its **first-named component** in §15.5's table. That is
arbitrary, and it is arbitrary in a way the player would have to learn.

## 4. Is 32 px the right marker size?

The marker is authored at 32 × 32 and the reduced treatment at 16 × 16, and
`SHEET_native_size.png` shows both 1:1 on three grounds. The preview draws
them screen-fixed, so a marker is the same size at 3 m and at 11 m.

32 was forced by geometry, not taste: the frame has to leave a 12 px clear
radius, a 16 px glyph needs 11.3 px at its corners, and at a 24 px marker
the frame stroke cut the corners off every glyph. If 32 is too large on
screen for you, **the glyph shrinks before the frame does** — and a 12 px
glyph will not hold `shatterpoint` or `arc_path`.

## 5. `delayed` has no audio, and it is the state that needs it

Design 1 §19.5 gives `delayed` a rising pitch, and that pitch is the only
channel that tells the player **how long**. The visual half is delivered — a
fill that grows behind a hard leading edge, which separates it from a
travelling pulse in pattern and in motion — but a silent `delayed` says
"soon" and never says "two more seconds".

No audio exists in this kit and none is claimed. If `delayed` is meant to
ship before there is sound, it needs a visual duration channel it does not
currently have, and that is a design question rather than an art one.

---

*Nothing in this batch is blocked on any of the five. Each one is a
direction I would rather take from you than invent.*
