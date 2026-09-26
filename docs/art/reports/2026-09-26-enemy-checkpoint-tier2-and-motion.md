# The enemy checkpoint: Tier 1 landed, Tier 2 re-cut, motion reviewed

*Arty*

> **RULED and CORRECTED 2026-09-26.** The checkpoint is accepted:
> * **Tier 2:** both re-cuts are accepted.
> * **The eye:** Production keeps its existing eye.
>
> **One suggestion below was wrong.** §1 offered to retire the
> `void_glitch` floor exception because it "now clears". Only the
> AGGREGATE clears (0.100). Per role, five of the ten are below 0.10,
> the diver at 0.088, so the exception is **not** retired. Aggregate and
> per-role numbers are now labelled separately everywhere. The tables
> below are aggregates. The four evidence scopes are kept apart in
> `review/DECISIONS_FOR_OWNER.md`; none of this report is
> integrated-gameplay evidence.

**Branch `claude/archipepsi-art`, PR #5.** Everything you asked for on
2026-09-26 is done, and the lane now holds:
* **Tier 1** landed, as art. It is not active in the shipping game.
* **The tintable symbols** ship in pure-white ink.
* **Tier 2** is built and measured, and waits on your review.
* **The motion review** is done. It raises one new decision: the eye.

In this archive:
* `review/` is `docs/art/review/enemies_2026-09-25/`.
* `readiness/` is `docs/art/review/enemy_readiness_2026-09-22/`, and
  `jobs/` is `docs/art/review/jobs_2026-09-22/`. Both are regenerated;
  see §2.
* `interface/` is `docs/art/review/interface_2026-09-24/`.

---

## 1. Tier 1 — landed as art

The ten roles ship as **two sets of the same enemies**. Geometry,
anchors and markings are identical in both, and so is every material's
structure. Only the body's value differs.

| band | body L\* | models | rooms |
| --- | --- | --- | --- |
| standard | 0.40 × the skin's | `assets/models/batch030/enemies/` | `concrete_facility`, `gothic_stone`, `neon_transit`, `temple_ruin` |
| deep | 0.10 × the skin's | `assets/models/batch030/enemies_deep/` | `rusted_industrial`, `void_glitch` |

The map is data: `assets/models/batch030/enemy_value_bands.json`. It
holds the bands, the room-to-band map, and your acceptance as data: the
threshold, the cases, the two exceptions and the openings limitation.
Its status line reads "NOT active in the shipping game".
`check_enemy_bands.py` holds the ruling in the suite:
* The two sets are the same geometry and markings, byte for byte.
* The deep set is darker.
* The committed measurement is tied to the **sha256 of every shipped
  model**, so a repainted enemy cannot ship on old evidence.
* The measurement uses your distance and threshold.

Measured under each room's own light, ambient and fog, with the Tier-2
models (✗ means below 0.10):

| room | wall | floor | dim | opening |
| --- | --- | --- | --- | --- |
| `concrete_facility` | 0.234 | 0.171 | 0.158 | 0.059 ✗ |
| `gothic_stone` | 0.156 | 0.147 | 0.100 | 0.070 ✗ |
| `neon_transit` | 0.244 | 0.121 | 0.163 | 0.033 ✗ |
| `rusted_industrial` | 0.147 | 0.127 | 0.094 ✗ | 0.103 |
| `temple_ruin` | 0.233 | 0.228 | 0.153 | 0.117 |
| `void_glitch` | 0.159 | 0.100 | 0.119 | 0.224 |

* **`rusted_industrial` dim** is your accepted exception.
* **`void_glitch` floor** was your other exception, at 0.0999. It now
  clears on the unrounded flag, at 0.100, so it could be retired. That
  is your call; the ruling stands as written.
* **`gothic_stone` dim** also sits on the line, at 0.100, and clears.
* **The openings** below 0.10 are the documented limitation.

**For Production** (`docs/art-requests/2026-09-26-enemy-value-bands-and-L08.md`):
the shipping enemy builders in `enemy.gd` paint with the room's own
accent and trim, which breaks L-08 independently of this art pass.
Nothing in Production loads the art models.

## 2. Two defects found on the way, and fixed

* **Every art-lane enemy faced +Z.** Their anchors, and `enemy.gd`'s
  enemies, face −Z, so the bulwark's weak-point anchor sat on its shield.
  The models are now turned at build time, with a per-role check that
  the front part is in front. The readiness gate refuses a front anchor
  that is not in front, and a weak anchor that is not behind. Both
  directions were sabotaged to prove the gate fires. The A10 handoff
  carries a dated correction.
* **"Embedded" anchors could stand proud.** "Embedded" had meant inside
  the body's box, and the box includes air. Each anchor is now walked
  into a real part. The silhouette harness renders every view twice,
  with the anchors shown and hidden, and requires identical pixels. No
  anchor pixel shows at any view.

The A10 and A11 review frames had gone **stale**: they still showed the
pre-band skin, the anchor bumps and the pre-`236acf8` props. Both are
regenerated, and in the gate's own output only the two re-cut roles'
sizes changed. I record the cause as a lesson: evidence goes stale when
a *shared* input changes.

## 3. Track A — pure-white ink for the tintable symbols

The symbols (circuit, control, exit, blocked, and the arrows) are
authored in `#ffffff`, so ordinary runtime modulation gives the exact
palette colour. The table of tints is in `icons.json`, and the gate
renders each tint and reads it back to within 1/255. The text face keeps
its off-white ink, and nothing asks Production to compensate for it.
Details are in `interface/README.md`.

## 4. Tier 2 — for your review

![Before and after, on the metric's own canvas](review/tier2/SHEET_tier2_before_after.png)

* **`ranged` — a braced gunner.** It carries a LONG emitter diagonally
  across the body, from behind one hip to past the opposite shoulder,
  with its muzzle as the figure's highest point. It stands with daylight
  between its feet, where the `melee` stands on one block. Neither tell
  is a width.
* **`bulwark` — a mantlet.** Head-on it is drawn as the brute's
  negative. Where the brute has its small head, the bulwark has a
  sighting notch between two ears. Where the brute stands on one block
  of legs, it stands on two runners at its edges, with the floor showing
  between them. The face is still one uninterrupted plate, as 037-R
  approved it.

Scaled outline overlap (the bar is 0.80), before → after:

| pair | yaw 0 | yaw 45 | yaw 90 |
| --- | --- | --- | --- |
| `melee` / `ranged` | 0.788 → **0.496** | 0.856 → **0.605** | 0.825 → **0.563** |
| `brute` / `bulwark` | 0.825 → **0.677** | 0.710 → **0.701** | 0.523 → **0.553** |

Track B reported only each pair's worst angle, and that hid a second
failure: melee/ranged also failed at 90°.

What held through the re-cut:
* **The envelopes.** The build asserts that each model fits its
  envelope.
* **The readiness gate:** fit, facing, and every anchor inside a part.
* **No anchor pixel** at any view.
* **The value picture.** Re-measured, no Tier-1 cell moved more than
  0.001 and no flag flipped.

Three anchors moved with the shapes; their names did not:
* `ranged` `anchor_muzzle` is now 1.29 m up, at the emitter's tip.
* `ranged` `anchor_warn` is 1.22 m up.
* `bulwark` `anchor_warn` is 1.71 m up, centred under the notch.

**Production's shot starts 0.32 m from the muzzle the player sees.**
`Enemy.muzzle()` fires from 1.2 m up on the centreline. Before the
re-cut the gap was 0.39 m.

## 5. The motion review

The art lane's enemies are rigid. Every motion they get is a transform
that Production gives them, so the review covers exactly those
transforms, read from Production's own source at `27363fe`.

![The full turn: every pair at every 15 degrees](review/motion/CHART_turn_overlap.png)

1. **The turn.** Production snaps every role but the bulwark to face
   the player, and a patrolling enemy faces the way it walks, so a
   player sees every yaw.
   Re-measured every 15° (`review/motion/SHEET_turn.png`):
   * Tier 2 holds all the way round. The worst yaw is 0.669 for
     melee/ranged and 0.734 for brute/bulwark.
   * Only floor-role-against-flyer pairs reach 0.80.
     `charger`/`drifter` reaches 0.803 at 15°; that is 3A, which you
     deferred. Across yaws, `charger`/`diver` reaches 0.847 and
     `charger`/`drifter` 0.828.
   * The outline metric crops each body to itself, so it cannot see
     that these never share a row of the frame. The charger stands
     0–1.05 m tall; the flyers hang at 1.65 m and above.
2. **What moves.** Motion separates melee from ranged completely: one
   closes at 4 m/s and the other has speed 0. It separates brute from
   bulwark only weakly. The bulwark lags at 90°/s, but that shows only
   when the player moves round it, and the brute swells before it hits.
3. **The windup swell** (1 + 0.12 sin) moves the outline 8.9 px on the
   brute but 3 px or less on the charger, drifter and diver at 18 m
   (`review/motion/SHEET_telegraph_swell.png`).
4. **Openings.** A moving body changes each pixel by exactly its static
   separation, so motion adds no value contrast. An approach from 18 m
   grows the outline by at most 0.17 px per frame. `neon_transit`, at
   0.033, is the cell to test first in integrated play.

![The windup swell on the art models, at 18 m](review/motion/SHEET_telegraph_swell.png)

**The finding that needs you — the eye.** Today's code-built enemies
carry an emissive `Eye`, in hard-coded red and orange. It is the only
emissive part of their bodies. Production dims it at idle, brightens it
once the enemy has noticed you, and **flares it at every windup**.

The art models have none. Even if they had one, `_set_eye` reaches only
a `material_override`, which a glTF import does not set; this is the
damage-tint gap again. So integrating the art models as they stand
drops the one windup cue made of light rather than shape. It also drops
the only emissive part of the body, which matters at the openings,
where value runs out. I did not measure the eye against an opening.

An eye needs a colour, and you have put new enemy colours on hold, so
**nothing is built.**

## 6. Decisions that are yours

1. **Tier 2:** accept both re-cuts, either one, or neither. A rejected
   re-cut goes back to its `fa16cfe` shape.
2. **The eye:** choose one.
   * Production builds today's eye onto the art models, in today's
     colours. The art lane would add at most an anchor, on your word.
   * The art lane authors an eye in a colour you approve.
   * Drop the eye.
3. *(Optional)* **Retire the `void_glitch` floor exception**, which now
   clears.

Unchanged: 3A stays deferred, 3B stays with Production, Track C is
blocked, Track E is in reserve, and item and state art wait on
Production's slot vocabulary.

## 7. Scope of the evidence, exactly

* **What was measured:** the art lane's models, in the art lane's
  harnesses, against Production's environment, lights, motion rules and
  eye at `27363fe`. Production was read only, through `git show`, and
  nothing was integrated.
* **Numbers from Production's source:** the motion numbers are parsed
  from Production's source by `enemy_motion_review.py`, and a missing
  one fails it. The eye is read from that code, not rendered. The swell
  is drawn from outlines, and 60 fps is assumed.
* **Viewing conditions:** everything is at 18 m, FOV 90, 1920 × 1080,
  which gives 30 px per metre. Value is measured in six rooms × four
  cases. Outlines use three yaws in Track B and 24 in the motion review.
* **Build determinism:** a rebuild of both bands was byte-identical
  across all 23 model and manifest files, so the evidence stays bound
  to the right hashes.
* **The full suite** (`tools/check_art_current.sh`) **passes** on the
  committed state, including `check_enemy_bands.py`, the readiness gate
  and the docs-metrics check. Every generated asset rebuilds identical
  to its source, and the run left no drift in the tree. The font-gate
  transient did not recur.
* **Not measured:** a player, or an integrated build.
* **Placeability:** at `27363fe` all ten roles are in
  `ENEMY_ARCHETYPES`. The art lane's own frames still print "not
  spawnable", because they read the art branch's older constants.

## 8. Next — hold

The checkpoint you set is reached. **The lane holds.** Track C and
Track E stay closed unless their blockers clear or you decide something
new. No heartbeat, watchers, subscriptions or scheduled check-ins are
running.
