# Wave 1 — technical repair under the authored-entry ruling

**Art lane · branch `claude/archipepsi-art` · 2026-09-03**

| | |
| --- | --- |
| Art head before | `0ed2292` |
| Art head after | **`26a2914`** (repair itself is `4441ea5`) |
| Production reference | `fc2cc41` |
| Rooms touched | `shell_plenum_helix`, `shell_yard_gantry`, `shell_span_basin` |
| Rooms deliberately not touched | `shell_hall_transit` (frozen), all eight P2 shells |
| Review states | all four rooms remain `review: "pending"` |

---

## What this was

Production reported measured findings on the three Wave 1 rooms —
**plenum 2, yard 5, span 4** — before starting its own parallel
correction pass. Those counts included findings produced under a
superseded convention, so they were diagnostic evidence rather than a
repair list.

The owner's ruling that governs the work:

> An authored room's local origin is not its entrance. The entry
> doorway is the room-to-room attachment transform; `player_entry` is
> the safe interior arrival region; **(0,0,0) has no universal
> semantic meaning.**

So the task was to reproduce all eleven findings, separate the ones that
exist only because the audit assumes entry-at-origin (Production's, leave
alone) from the ones that are genuinely Art's, and repair only the
second group — without normalising any room to its origin.

## How the findings were reproduced

Production's **unmodified** `RoomAudit` was run against this branch's
content pack in a **detached read-only git worktree** at `fc2cc41`.
Nothing of Production's was copied into the art lane or modified.

The Wave 1 entries in that worktree were verified byte-identical to this
branch's before measuring, so the reproduction is exactly the state
Production's diagnostics came from.

One runner detail: `room_contract_driver.gd` touches the `BridgeClient`
autoload on its first line, and autoloads are not registered for a script
run with `-s`. A four-line scene making the probe the main scene fixes
it. Patching Production's driver instead would have meant measuring
against something Production does not run.

**Result — all eleven reproduced verbatim:**

```
CENSUS shell_plenum_helix structural=0 measured=2
CENSUS shell_yard_gantry  structural=0 measured=5
CENSUS shell_span_basin   structural=0 measured=4
```

---

## The split

### Three are the entry-at-origin assumption — excluded

| room | finding | why it is superseded |
| --- | --- | --- |
| plenum | `the entry at (0,0,0) is sealed` | entry doorway is at **y = 68** — the top of a 72 m shaft you descend |
| yard | `the entry at (0,0,0) is sealed` | entry doorway is at **x = −43** — the west end of an 84 m field |
| span | `the entry at (0,0,0) is sealed` | entry doorway is at **y = 14** — on the deck, not in the basin |

None of these rooms claims an entrance at its origin. "Fixing" the
plenum's would mean moving its entrance to the bottom of the shaft —
which is the one thing its approved form exists to do differently.
**Production's. Nothing moved, added or translated for them.**

### Eight are Art's — all one mistake

**A declared point carrying the *centre* of the thing it names.**

| room | finding | was | now |
| --- | --- | --- | --- |
| yard | `cover_0` inside solid geometry | `−26.0, 0.3, 16.0` | `−26.0, 0.3, 13.4` |
| yard | `cover_1` inside solid geometry | `−9.0, 0.3, 34.0` | `−9.0, 0.3, 37.1` |
| yard | `cover_2` inside solid geometry | `11.0, 0.3, 15.0` | `11.0, 0.3, 12.4` |
| yard | `cover_3` inside solid geometry | `27.0, 0.3, 33.0` | `27.0, 0.3, 36.6` |
| span | `cover_0` inside solid geometry | `−9.0, 0.3, 22.0` | `−12.1, 0.3, 22.0` |
| span | `cover_1` inside solid geometry | `8.0, 0.3, 44.0` | `10.6, 0.3, 44.0` |
| span | `cover_2` inside solid geometry | `−7.0, 0.3, 66.0` | `−10.6, 0.3, 66.0` |
| plenum | `reward` inside solid geometry | `0.0, 29.333, 10.0` | `5.25, 29.333, 10.0` |

Seven `cover` sockets were declared at the centre of their own 1.9 m
cover block — buried in concrete. A cover socket is an **offer of
somewhere to be**, and the middle of a crate is not somewhere to be.
They now sit beside the block, on the far side from the room's centre
line, so the block is between the player and the open middle. That is
what cover is for.

The plenum's `reward` volume was declared at the centre of the collar,
which is the centre of **eight metres of solid machine**. It now sits on
the collar band at radius 5.25, opposite the bridge, so reaching the
objective means walking the collar.

### Why it happened, and what stops it recurring

Duplication. Each room held its cover clusters **twice** — once as
`(cx, cz, sx, sz)` for the geometry, once as `(cx, cz)` for the sockets —
and the second list could only ever be right by coincidence.

There is now one list per room, and `roomkit.cover_stance` derives the
stance from the block's own centre and size. The plenum's reward comes
from `_reward_spot`, derived from the collar and the bridge. Neither
position is written out a second time.

---

## What did not change

| | plenum | yard | span |
| --- | --- | --- | --- |
| triangles | 1656 | 516 | 672 |
| collision pieces | 117 | 39 | 54 |
| surfaces / traversal / size / offers | unchanged | unchanged | unchanged |

No shell `.glb` changed. No `.tscn` changed — markers come from
traversal, and no traversal moved. The top-entry/bottom-exit shaft, the
~16 m yard, the one-way mid-span drop and every authored entry elevation
are exactly as approved.

---

## Verification

Production's own audit, re-run against the repaired pack in the same
worktree:

```
BEFORE  plenum 0/2   yard 0/5   span 0/4
AFTER   plenum 0/1   yard 0/1   span 0/1
```

The one remaining finding in each room is the entry-at-origin one. The
hall and all eight P2 shells report `structural=0 measured=0` before and
after.

| check | result |
| --- | --- |
| Mandatory routes | intact — traversal unchanged, `structural=0` everywhere |
| Scene/manifest marker parity | **PASS** — 160 markers, 12 scenes, 0 disagreements |
| Deterministic rebuild | **PASS** — every generated asset byte-identical |
| `pyverify` (Production's `ContentManifest`) | **PASS** |
| Registry | **PASS** |
| Collision | 12 shells, **0 needing attention** |
| Flight surfaces (collider triangles, 0.10 m grid) | 19 flights, **0 refused** |
| Preflight | **0 structural refusals** |
| Doc metrics | **245 / 245** |
| Zone and digest | untouched |

---

## Files changed

**Source** — `roomkit.py`, `build_yard.py`, `build_span.py`,
`build_plenum.py`, `verify_manifest.py`, plus new
`build_wave1_repair_overlay.py` and `gen_wave1_repair.py`.

**Derived** — `batch040/shells/manifest.json`, three overlay `.glb`s,
`authored_art.json`, four evidence PNGs, three documents.

## Evidence

`docs/art/review/wave1_repair/` — four views and a README.

The repair moved declared points and no geometry, so a matched
before/after render would be two identical pictures. These compose a
derived figure over the real shell: **red where the point was, green
where it is**. Both ends are computed from the same source tables rather
than typed in, so a figure cannot show a repair that did not happen.

| | |
| --- | --- |
| `W1_yard_cover` | one cluster close up — the red pin is swallowed by the block |
| `W1_yard_wide` | all four yard clusters, from the crane |
| `W1_span_cover` | the same defect and the same repair, in the span |
| `W1_plenum_reward` | the collar band, with the red pin behind the machine |

---

## One thing raised and deliberately not changed

Each plenum collar is modelled as an annulus — its collider mesh measures
radius **4.00 to 6.75**, with a real hole. Godot imports these as
`ConvexPolygonShape3D`, and **the convex hull of an annulus is a disc**,
so in the engine each collar's collision fills its own hole out to 6.75.

The three `landing_N_to_collar_K` traversal segments end on the machine's
central axis, inside that filled hull — and for two of the three, inside
the machine's own collider as well.

This was **not** among the reported findings and nothing was changed for
it. It is the same cause as the eight above, but it is failing no check
today, and it sits in exactly the area Production's parallel composition
work touches — changing traversal declarations underneath that is how two
correct repairs become one conflict. It is recorded in the evidence
README and the frontier so it cannot fall between the two lanes.

---

## Standing state

* All four rooms remain `review: "pending"`. Art does not write `pass`.
* The hall is frozen at `0ed2292` and is Production's to recertify.
* The approved P2 catalogue, the played Zone and the digest are unchanged.
* **Wave 2 has not started** and is not authorised by these verdicts.
* Lesson recorded as **L-97** in `docs/art/ART_LESSONS.md`.
