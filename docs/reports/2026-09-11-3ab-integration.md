# PROD — Playable 0.3: finishing the 3A/3B integration

**Archipepsi Production lane · 2026-09-11**

Head before: `67277aa`. Frozen authority: `docs/ROAD_TO_PLAYABLE_0_3.md`.

The joint 3A/3B milestone is closed. **A Zone the generator produced,
loaded the ordinary way, contains an authored room that carries movement
offers; a player walks into it from outside and rides its authored rail
34.3 m across ground they have none of.** Nothing here is hand-edited,
substituted from the showcase, or reached through a developer override.

**Labels.** `A1`–`A8` keep the meanings the Road froze. The checks in this
report are this stage's and are numbered `INT-1`…`INT-6` so they cannot be
mistaken for them.

---

## 1. The owner ruling, implemented

An approved shell's fixed geometry now informs the chamber being
generated. The generator **chooses a shell from the request's offered
catalog, then derives the chamber's dimensions from it** —
`shells.adoptable` answers "which offered shells could this chamber
become", `shells.adopt` writes the shell's geometry into it, and the
shared rule then holds the two to an **equality**.

This replaces a pair of one-sided clauses that could not express what was
wanted. "No bigger than the chamber" refused every arena shell outright —
they are 31 to 85 m across and the builder's arenas are 12 to 26 — and
"no smaller when the chamber carries features" was a special case standing
in for the general rule. It was also the source of the discrepancy with
the production prompt.

The schema follows the same split. `ArenaChamber`'s field bounds are now a
sanity ceiling (`MAX_AUTHORED_SPAN`, `MAX_AUTHORED_HEIGHT`); the range that
used to live on the field — 10–28 m, a 4–8 m ceiling — is enforced by
`validate_zone` on exactly the rooms it describes, the ones that name no
shell. Widening the field alone would have let a *procedural* arena be
90 m across, which no builder, audit or layout path has been asked for.

**Nothing is scaled.** `adopt` copies numbers off the manifest; no arm
stretches, retimes or reinterprets a shell.

## 2. What bounds it, after two wrong answers

`AUTHORED_AREA_BUDGET` (4000 m²) caps how much authored floor one Zone
adopts. Its justification was wrong twice and is recorded here because
both wrong answers looked convincing.

* **"The audit cannot finish."** A 900-second timeout looked like cost.
  It was `ZoneBuilder` reporting a routing failure and the audit driver
  walking off the end of the result and hanging. The audit runs in ~15 s.
* **"The chain cannot route it."** True before the placement work below,
  false after: 11 authored rooms, 20000 m² of adopted floor, no clash.

The real reason is **scale**, and it is a design question nobody has
answered. Preferring authored everywhere multiplies a Zone's floor by
roughly ten while its Checks, enemies and activities stay exactly as they
were. How long a Zone should take is the owner's call
(`CAMPAIGN_SCALE.md` 13), so the budget keeps the change bounded until
they make it. Raising it is one number and the layout carries it.

## 3. Placement: succeed, or say so

`ZoneBuilder` used to push a room forward six connectors and, if that did
not clear it, **attach it anyway**. Connectors were never overlap-checked
at all, so a long push marched a corridor through whatever was in the way.

It now **plans, then builds**. A route may take up to two corners and push
as far as the placed geometry is wide; every connector, every corner and
the exit room are checked; a direction is exhausted at the first connector
that would itself overlap. A route also clears **its own** pieces — a room
whose declared entry socket is inset extends backwards over the connectors
laid to reach it, which is why 14 large authored rooms first "routed" and
overlapped. The one exemption is the piece a room *joins* onto: rooms meet
at a shared face, and treating the join as a collision refused every large
authored room outright.

When no route exists, `build` returns `{"failed": …}` and attaches
nothing. `ZoneController` refuses the Zone and records `layout_failed`;
every other caller reports it rather than reading `root` off a failure.

Two folding sources were also removed, both found this way: a room that
turns the chain no longer collects a corner piece on **either** side of it
(only "after" was suppressed, so a corner shell could still get one in
front, giving two 90° turns with a 6 m room between them), and the
generator no longer picks the same shell twice running where it has a
choice — five `shell_corner_left` in a row is a route that spirals into
itself.

**INT-1 — an exhausted layout is refused, not overlapped.** A chain whose
corridors all carry the same corner shell closes on itself; by the sixth
room there is nowhere left. The build fails, hands back no scene, and says
which room could not be placed.
**INT-2 — no accepted Zone has pieces inside each other.** Checked over
every piece in `bounds_list` — chambers, connectors, corners, exit room —
with only consecutive pairs exempt, so a connector laid through a room
fails it.
**INT-3 — 14 of the largest approved arena route cleanly.** Measured
further: 120 of them, 465 pieces, zero clashes.

## 4. Compatibility evidence is now behavioural

`godot/tests/fixtures/shell_rule_cases.json` holds **21 cases**, executed
by Python (`shells.rule_problems`) and by Godot
(`ContentInstantiator.misfit_problem`), case for case and **clause for
clause**: accepted controls plus rejected `type`, `footprint`, `height`,
`feature`, `floors` and `elevation`, with empty declarations and
boundaries — a shell 1 cm wide of its chamber is refused, one 4 mm out is
a manifest rounding and is not.

Both sides return a clause name rather than prose, so **a comparison
changed on one side fails the cases even if every field name stays**.
That is the defect the check it replaces could not see: it compared the
field names the two files mention, and passed while Godot compared
`fits_floors` and nothing else.

**INT-4 — 21 shared cases, both languages, identical verdicts.**

The production prompt now describes the rule that is enforced: choose the
shell first, then write `width` as `size[0] - 0.8`, `depth`/`length` as
`size[2] - 0.8` and `wall_height` as `size[1]` exactly; where nothing
fits, leave `shell_id` null and size the room in the builder's own 10–28 m
range.

## 5. The normal path, end to end

**Provider: OFFLINE.** `godot/tests/fixtures/played_zone.json` is dumped
by `archipepsi_bridge.playtest` from the deterministic fallback — the
provider the game uses with no API key — through the ordinary request,
validation and storage path. No live model was called.

Zone 1 composes **7 of 23 chambers** from authored shells: `c006` is
`shell_span_basin`, and six corridors alternate `shell_corner_left` and
`shell_corner_right`. `shell_span_basin` is offer-bearing.

Loaded through the same `ZoneController` an ordinary player enters
through, with `--movement-package`:

```
mode=none   declared=6 judged=5 accepted=5 selected=0 built=0  (23 rooms judged before the first build)
mode=rail   declared=6 judged=5 accepted=5 selected=1 built=1
mode=launch declared=6 judged=5 accepted=5 selected=1 built=1
```

**INT-5 — a player walks in from outside.** Placed on the floor of the
piece *before* `c006`, walking forward under the real `_physics_process`,
the player crosses into the authored room's bounds and lands with ground
under them. Not spawned inside; not teleported to its floor.

**INT-6 — the offer changes navigation.** The rail carries the player
**34.3 m along an 83 m authored path**. From the same start, in `none`,
the same push for the same number of frames ends **14.8 m from where the
rail put them** — and the midpoint of the ride has **no ground within
`MAX_VERTICAL_STEP`**, so walking was never going to substitute.

Offers stay optional: `none` builds no movement geometry and every
mandatory route still measures clear. The 3A showcase regressions are
retained and pass.

## 6. Generation, construction, behaviour — reported separately

| | measured |
|---|---|
| **Generation** | 7 of 23 chambers name a shell, in all three baseline Zones; dimensions derived from the shell, not guessed; 6 offers declared |
| **Construction** | every named shell builds its authored scene (0 fallbacks); 1 rail node built in `rail`, 1 launch in `launch`, 0 in `none` |
| **Player behaviour** | walks in from outside and lands on the floor; rides 34.3 m; the same start without the package ends 14.8 m away |
| **Still unproved** | that a *live* provider chooses shells well — the prompt states the rule and no live run was made; that a full campaign of twelve Zones routes (one Zone measured, plus 120-room and spiral stress cases); that Zone pacing is right at this floor area (§2) |

## 7. Digests and content

| | pre-3B | 3B | now |
|---|---|---|---|
| played-zone digest | `6e8d83d0f3ec088b` | `ab57d275eea29018` | `a9e649315285bdf3` |
| baseline sha256 (16) | `5a7cfdc03da0e59b` | `c1131ac29931cc68` | `57e8baf561e38083` |
| chambers naming a shell | 0 of 23 | 6 of 23 | **7 of 23** |
| Zone 1 content value | 922 | 922 | 908 |

Byte-identity outside `shell_id` no longer holds, and should not: adopting
a shell changes a room's dimensions, and `room_value` scores space. The
Zone is **23 rooms, 15 Checks, 35 enemies** — unchanged — and its content
value moved from 922 to 908, inside the budget band, because six corridors
became 6.0 × 6.0 rooms and one arena became 30.4 × 89.2.

**Corrected 2026-09-11.** That paragraph reported the unchanged content as
a reassurance. It is the finding. A room that became 30.4 × 89.2 —
2712 m² — kept the contents budgeted for the small arena the generator
proposed: one melee enemy, two activities, one Check, and five declared `enemy_high`
stances left empty. `room_value`'s space term caps at `MAX_SPACE_VALUE` and
is then clamped by content, so the budget is structurally unable to notice
a room growing. Content staying put across a 30× area change is evidence
that nothing is watching, not evidence that nothing broke. See
`2026-09-11-playtest-zone1-findings.md` §S-7.

One consequence was worth chasing: the first attempt came out a single
point under its minimum and the retry loop covered for it. Features are
hung and shells adopted **between** the builder's two passes now, so the
top-up scores the rooms that will actually exist rather than rooms about
to change size.

The pre-3B baseline is still preserved verbatim at
`docs/baselines/playtest_2_5.pre_3b.json`.

## 8. Correction: "blocked on Art"

The 3B report said arena composition was blocked on the Art lane
shipping arena shells at generator scale. **That is superseded.** Under
the owner ruling of 2026-09-11 the chamber adopts the shell's geometry, so
the existing twelve shells compose arenas as they are —
`shell_span_basin` does so in Zone 1 today. No new Art batch was needed
and none was requested.

What remains genuinely Art-side is narrower and is not a blocker: a
chamber that declares an elevation band still takes the procedural
builder, because no approved shell declares `provides_elevation`. The
field exists and is empty; a shell declaring `("gallery",)` becomes
eligible with no code change.

## 9. Gates

* `make test` — **1144 passed**, 627 subtests, 0 failed.
* Full Godot frontier by **exit code**: 18 suites, all 0.
* `docs/design-packet-v0.8/check_packet.py` — passes.
* `godot-playtest3a` now fails on `SCRIPT ERROR`. It did not, and a test
  that crashed halfway was reported as a pass — which is how the walk-in
  proof came to be silently absent from one run.
