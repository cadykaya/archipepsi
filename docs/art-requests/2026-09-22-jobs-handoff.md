# Batch 050 — A11: enemy jobs and the spaces that host them

**Arty**

**To:** Prod (integration) and Dess (job/placement decisions)
**Art head:** this commit, branch `claude/archipepsi-art`
**Fitted against:** Production `claude/archipepsi-0-4-blindside` @ `f404410`

**Every asset here is a CANDIDATE.** Imported and fit-checked; **not**
runtime-bound and **not** owner-approved. **No encounter placement is
changed by anything in this batch.**

---

## 1 · A11 was not blocked, and the inventory said so

A11.6 offers an escape — "if no runtime job contract exists yet, mark
clips as candidates and continue other roles" — and it does not apply.
`Constants.ENEMY_JOBS` declares four jobs with their parameters, and
`enemy.gd` implements all four:

```
ENEMY_JOBS            melee/charger/scuttler  patrol
                      ranged/brute/bulwark/artillery  watch
                      drifter/diver  drift
                      beacon  tend
ENEMY_JOB_SPEED       0.45
ENEMY_PATROL_PAUSE    1.2       seconds at each beat end
ENEMY_PATROL_RADIUS   4.5       the beat is a point on this circle
ENEMY_POST_TOLERANCE  1.5       how close to the post counts as back
ENEMY_SWEEP_RATE      0.7 rad/s (halved for `tend`)
```

So this batch is fitted to real numbers rather than proposed against a
hypothetical.

---

## 2 · Four jobs, four working areas — and a prop's first duty is to be
out of the way

Read out of `enemy.gd`, not guessed:

| job | what the code does | the space it needs |
|---|---|---|
| `patrol` | `_patrol` walks to a **random** point on a 4.5 m circle round the post, pauses 1.2 s, picks another | a **disc 9 m across**, walked over |
| `drift` | `_drift` orbits the post at **2.5 m** at 0.4 rad/s and never descends | a **ring** at the role's hover height |
| `watch` | holds the post, sweeps `rotation.y` at 0.7 rad/s | a **cylinder** the role's own width |
| `tend` | the same, at half rate | the same |

`assert_clear_of_job` checks every prop against the served role's
**published envelope** rather than against a comment:

* a `watch`/`tend` prop must stay outside a circle the widest served
  role needs to turn in — for `job_watch_post` that is the brute at
  1.80, so 1.95 m;
* a `drift` perch must be narrower than the 2.5 m orbit minus the
  flyer's own body — 1.675 m for the drifter.

`assert_flat` keeps floor cues under the measured 0.12 m walk-up,
because **A11.4 says a decorative mark is not a promise of reachable
geometry** and anything a player can step onto is making one.

**Sabotage-tested, three ways.** A column moved inside the turning
circle: refused at 0.416 m against 1.050. A beat cue raised to 0.31 m:
refused against the walk-up. A perch widened to 4.2 m: refused at
2.103 m against a 1.675 m limit.

### A11.2's warning, taken seriously

> "Avoid one oversized docking station for every enemy regardless of
> role."

So there is no universal dock here. `job_watch_post` is sized to the
roles that stand at it. `job_drift_perch` hangs, because `_drift`'s own
comment says a flyer that came down to the floor between fights would
stop owning the ceiling. And `job_charge_socket` is a **0.5 m wall
socket that claims no role-specific fit at all** — which is the honest
alternative to pretending one shape serves a scuttler and a brute.

### A11.4, and why there is no patrol path

`_patrol` picks a **random** point on the circle every beat. There is
no fixed path, so a painted line between two points would be Art
inventing a route the runtime does not walk. `job_beat_cue` is a single
scuff at the beat radius: something comes here, and it does not claim
which way it came.

---

## 3 · A11.5 — the idle-to-alert comparison, in the only truthful form

The ten role bodies are **single joined meshes**. There is no pose to
change and no articulation to change it with, so an idle-versus-alert
*pose* comparison is not something this lane can deliver today.

What the six frames compare instead is the **post**: one ground role
(`melee`, patrol), one planted role (`ranged`, watch) and one flyer
(`drifter`, drift), at their stations, idle and alerted — through the
anchors Batch 030 now carries.

That is less than a rigged roster would give you and the frames say so
on every one. It is not nothing: *can a player tell an alerted sentry
from an incurious one at gameplay distance* is a question these frames
can answer, and the answer does not depend on a rig that does not
exist.

### A finding that belongs to A10 as much as to A11

**An anchor is an attachment POINT, not a display surface.**

The first cut of these frames lit `anchor_warn` itself, and nothing
appeared. That is correct: Batch 030's anchors are 40 mm markers
**embedded inside the body**, and `enemy_readiness.gd` refuses one that
stands proud — a bump on an enemy that has none is a modelling error.

So the frames now do what a runtime would: read the anchor's transform
and attach a marker there. Worth stating explicitly in case anyone
reads the A10 handoff and expects `anchor_warn` to glow by itself: it
cannot, and it should not.

*(And a second-order one: the builder writes anchor geometry at world
coordinates and leaves the object at the origin, so every anchor's
NODE sits at (0,0,0) under the body. A marker placed at
`global_position` lands on the floor between the role's feet. Read the
mesh's centre.)*

---

## 4 · What is NOT delivered

**A11.1's motion clips**, and the blocker is A10.4's rather than
A11's. There is no authored-visual path into `Enemy.visual`, no
animation owner, and gameplay already scales that node for the flinch
and the windup swell. A11.1 forbids inventing a behavioural controller
to stage an animation **in the same sentence** it asks for clips, so
there is nothing here that could honestly be built first.

**A11.3's entry/exit blends** depend on the same thing.

What A11.3 *can* be held to without a rig is clearance, and that is
what `assert_clear_of_job` is: a role that has room to turn at its post
cannot leave a hand through a panel, because the panel is not inside
its turning circle.

---

## 5 · What I am NOT claiming

- **Not runtime-bound.** Nothing places these.
- **Not owner-approved.**
- **No encounter placement is changed**, which A11's completion
  boundary asks for explicitly. These are props for posts Production
  and Dess choose; Art has chosen none.
- **The room is not inhabited because objects are in it.** A11.6 says
  so and I agree: what these give you is somewhere for a job to happen,
  not evidence that one does.
- **`job_charge_socket`, `job_inspect_panel` and `job_tool_rack` serve
  no declared role.** They are service dressing that suits any post. If
  a job wants a specific one — a `tend` beacon that recharges, say —
  that is a fit I have not made and would rather be told about.
