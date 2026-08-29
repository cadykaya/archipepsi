# Batch 034 — AUDIT: hard progression gate readability

**Status: AUDIT COMPLETE. The vocabulary exists and is stronger than
expected; the gap is precise. Proposal for uncontracted families is PENDING.**

## The contract that already exists — and it is an owner ruling

`schemas/constants.py` carries the affordance signal language, decided
**2026-08-28 in art's favour**:

> **FORM tells the player WHICH affordance this is.**
> **COLOUR tells the player THIS IS A CAPABILITY OPPORTUNITY.**

`AFFORDANCE_SIGNAL_HEX = "#39d7c8"` — the art lane's own `signal` anchor,
with engineering explicitly declining a second opinion about it. The reason
recorded in the file is worth quoting because it is the whole argument:

> *"The six affordances used to carry six ad-hoc tints — the rail a violet
> that sat beside `glitch`, the breakable wall the theme HAZARD colour, and
> the bounce pad and moving platform whatever the theme's accent happened to
> be. Seven things that look different everywhere teach the player nothing."*

Two channels stay dynamic and are preserved: `breakable_wall_damage` (emission
energy ramping with damage) and `wind_ring_count`.

## The seven families with a real contract

| family | contract exists | physical cue today | can the player infer the VERB? |
|---|---|---|---|
| `grapple_anchor` | **yes** | overhead anchor, Batch 001/009 built the family | **yes** — an overhead ring at reach height reads as *attach* |
| `breakable_wall` | **yes** | a wall panel, with damage on an emission ramp | **yes** — but see the finding below |
| `rail` | **yes** | a continuous run to ride | **yes** — a rail's form is its verb |
| `bounce_pad` | **yes** | angled sprung deck (Batch 028 built the kit form) | **yes** — direction is in the geometry |
| `moving_platform` | **yes** | a deck that travels | **partly** — at rest it is a ledge |
| `wind_volume` | **yes** | stacked rings, count = strength | **yes** — rings show direction and force |
| `water_volume` | **yes** | a volume | **weakly** — a surface, not a verb |

All seven wear one colour by ruling, so **every one of them is already
readable across all six themes**: `signal` cyan does not vary by theme, which
is the property that makes the ruling correct. And none is confusable with
decoration, because decoration may never wear `signal`.

## THE GAP, stated precisely

The ruling gives the player **"you could use a capability here."** A hard
progression gate has to give them something stronger:

> **"I know what kind of thing belongs here. I don't have it yet."**

Those are different sentences, and today only the first is expressible. The
affordance colour says *opportunity*; nothing says **which capability**, and
nothing distinguishes *not yet acquired* from *available and optional*.

That matters most for the case the redesign has just created. A grapple
anchor 12 m up, with no floor route, currently reads as an ordinary optional
affordance the player happens not to be able to reach — which is one small
step from reading as **generated broken geometry**, which is the exact
failure the brief names.

**Interface requirement 34**, in two parts:

1. **There is no "you lack this" state.** No runtime signal separates *have
   the capability* from *do not have it*. `AFFORDANCE_DYNAMIC_CHANNELS` lists
   two dynamic channels and neither is acquisition.
2. **Form carries the family, but only at close range.** The ruling is right
   that form should carry it. At the distance a hard gate is *first seen* —
   across a room, through a doorway — a grapple anchor and a rail terminus
   are both "a cyan thing on a structure".

Art is not proposing the mechanic, and Production owns whether a gate is
legal.

## What art proposes instead: the DELIBERATE INCOMPLETENESS read

The gate should not be marked. It should be **built as if finished, and
missing exactly one thing** — the thing you don't have.

A route that stops with a *finished edge* reads as intentional. A route that
stops with a ragged edge reads as broken. That distinction costs no colour,
no HUD element and no new semantic channel, and it is the whole difference
between "not yet" and "bug":

| what the player sees | what it says |
|---|---|
| a landing platform, railed, lit, **with no way up to it** | somebody meant you to arrive here |
| an anchor point mounted on a proper bracket, **out of reach** | this was installed, not left behind |
| a run of rail that **starts in mid-air on a finished pylon** | the pylon is complete; the rail expects a rider who can get to it |
| a door whose frame is **intact** and whose panel is a different construction | this opens, and not by hand |

**The tell is finish quality, not signage.** Broken geometry is ragged;
infrastructure is neat. A player learns that distinction in one Zone.

## Blink / teleport, and anything without a settled mechanic

**No production asset built**, per the brief. The visual-language proposal
only:

A blink gate would be a **matched pair of finished terminals with nothing
between them** — two identical, complete, obviously-installed fixtures facing
each other across a gap that has no bridge and no debris. Symmetry is the
signal: broken things are asymmetric, and a *pair* says a relationship exists
even when the mechanism is invisible. Nothing here defines range, cost,
cooldown or legality.

## Built for this batch

Four gate demonstrations, each showing the **same route twice** — as a hard
gate, and as the ragged non-gate it must not be mistaken for:

`gate_grapple`, `gate_break`, `gate_launch`, `gate_blink_proposal`.

The last is explicitly marked as having **no mechanical contract** and is not
a production asset.

Status: **PENDING OWNER REVIEW.**
