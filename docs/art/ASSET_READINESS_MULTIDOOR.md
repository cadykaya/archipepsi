# Asset readiness — multi-door, closures, plugs, warp stations

**Arty** · art lane · 2026-09-11 · against the Zone 1 playtest of the same day

---

## OWNER RULINGS, 2026-09-11 — read these before the note below

The note was written as questions. Four of them are now answered, and the
answers bind.

1. **Return devices, Zone exits, sealed doors and secrets each get their own
   visual identity.** The two conflicts flagged in §2 and §3 are settled the
   way they were flagged: a plug does **not** borrow the portal, and a
   closure does **not** borrow the batch029 secret language.
2. **A closure is a placement, not baked shell geometry** — §5 item 2,
   decided as recommended, so doorway usage stays selectable per decision 3.
3. **The pending checkpoint assets are candidates for ADAPTATION, not
   approved.** Nothing in this note or the discussion around it promotes
   batch026, and it must not be cited as approval.
4. **HOLD on authoring.** No junction shell, plug or warp station is
   authored until **Dess returns the doorway contract**. The Span shell
   stays untouched until **Production supplies the precise route/collider
   finding**.

**The continuous-groove deck tread is accepted and that revision is
closed** (Art `3cf824b`).

---

A readiness note, not a batch. **Nothing is authored here**, no approved
asset, manifest or review state is touched, and the twelve shells are not
rebuilt. Written after reading `03-decisions-and-open-questions.md` so the
art lane can say what already exists before anyone commissions new work.

**The relevant hard numbers, measured from the source rather than
remembered:** the doorway every shell cuts is **`DOOR_W` 2.40 × `DOOR_H`
3.20 m**, centred in its wall (`build_rooms.py`). Everything below is sized
against that.

---

## 1 · Multi-door rooms and junctions

**Existing: the builder kit, not the rooms.** A junction shell would be
authored from the same `roomkit` / `brushkit` / `roomcollision` modules the
twelve approved shells already use, so the pipeline — collision derivation,
socket and surface declaration, the offer gate, the export path — needs
nothing new. `arch_wall_variant_a`/`_b`, `arch_column`, `arch_beam_span`,
`arch_ceiling_plain`, `arch_trim_ceiling` (batch020, **PASS**) and
`arch_catwalk`, `arch_tunnel_bore` (batch021, **PASS**) are the module
vocabulary a T-junction would be dressed from.

**Needs new art: the shells themselves.** Every one of the twelve declares
exactly two doorway sockets named `entry` and `exit`; none can be adapted,
because a third doorway is a hole in a wall that is currently solid. This is
new geometry, and it is the largest item on this list.

**Not blocked by art.** Decision 1 names four places the *system* assumes
two doors. I can author a five-door shell the moment the socket contract
exists; until then I would be guessing at names, count and ordering.

---

## 2 · Reusable closures for unused doorways

**This is the cheapest of the four, and most of it exists.**

| what | asset | status | fits a 2.40 × 3.20 doorway? |
| --- | --- | --- | --- |
| capability-locked closure | `gate_launch`, `gate_grapple`, `gate_break`, `gate_blink_proposal` (batch034) | **PASS** | **no** — 8.00 × 5.00 × 5.50, these are wall-scale barriers, not door plugs |
| key-locked closure | `zkey_receiver_ch1/2/3` (batch031) | **PASS** | the receiver is 0.42 × 0.30 × 1.48 and mounts *beside* a door, not in it |
| the door leaf itself | `door_standard` (batch006) | **PASS** | **yes** — 2.72 × 0.62 × 3.38, built for exactly this gap |

**Needs new art: a plain sealed plate** — the "this doorway is walled off"
case from decision 3. One asset, door-aperture sized, per theme treatment.
It is genuinely small work.

**A conflict worth deciding before I author it.** `batch029/secrets`
(`secret_displaced_panel`, `secret_construction_seam`,
`secret_service_access`) is a deliberate visual language meaning *this
opening can be got through*. A sealed doorway must **not** borrow it, or
every walled-off branch reads as a secret the player should be working at.
The closure needs to say "finished wall, nothing here" — which is the
opposite of everything batch029 does. Note that batch029 is in the
**023–030 PENDING** band and unreviewed.

---

## 3 · Dead-end return devices (the plugs)

**Existing, and closer than I expected:** `portal_core_locked` /
`portal_core_unlocked` (batch006, **PASS**) measure **2.38 × 0.20 ×
3.31 m** — near-exactly the doorway aperture. A plug that stands in a
doorway already has a proven envelope and a locked/unlocked pair.

`checkpoint_anchor` (batch026) is a deployed canopy with one achromatic
lamp — the right vocabulary for "a place you arrive at".

**Needs new art:** the three flavours decision 2 names are three different
objects, and only one of them is nearly in hand —

* **non-euclidean door** — closest to `portal_core_*`; plausibly a
  re-dress rather than a new build;
* **disintegrate-and-rematerialise pad** — a floor pad, no existing asset;
  the checkpoint pad footprint (2.51 × 2.51) is the nearest reference;
* **tube that fades to black** — a bore interior; `arch_tunnel_bore`
  (batch021, **PASS**) is the nearest existing form.

**The conflict here is sharper than the closure one, and it is a
readability problem, not an art one.** `portal_core_*` is currently the
**Zone exit**. If a dead-end plug reuses it, the player cannot tell *this
ends the level* from *this sends me back to the start*. Those have opposite
consequences and one of them is irreversible. Either the plug gets its own
silhouette, or the exit does. **I would not reuse the portal for a plug
without that being decided first**, and I would rather give the plug a new
form than weaken the exit's.

---

## 4 · Warp / save stations

**Existing, and this is the strongest match of the four.**
`batch026/checkpoint` already ships three states:

| asset | state | size |
| --- | --- | --- |
| `checkpoint_inactive` | folded flat into the pad, dark | 2.51 × 2.51 × 0.41 |
| `checkpoint_activated` | deployed | — |
| `checkpoint_anchor` | canopy deployed, one lamp under it | 2.51 × 2.51 × 3.08 |

Decision 5's *"optionally starting broken and repaired by completing a
puzzle"* maps onto that inactive → activated pair almost directly.

**And the broken state already has a vocabulary.** `build_gates.py` states
its own rule: *"BROKEN is ragged. INSTALLED is neat"*, with every
`gate_*_ragged` variant reading as broken **with no colour at all**. A
broken warp station can borrow that language instead of inventing one, and
it will read in all six themes because it never depended on hue.

**Needs new art:** the *warp* half. A save point and a station you travel
*between* are different promises, and nothing in the kit says "there are
others like me, and you can reach them". Whether that is a directory, a
readout, or simply a distinct silhouette is a design question I would want
answered before drawing it.

**Status caveat:** batch026 sits in the **023–030 PENDING** band. My best
candidate for this role has never been reviewed, so "existing" here means
*authored and unapproved*, not *approved and idle*.

---

## 5 · What I need before authoring any of it

Ordered by how much they block:

1. **The doorway socket contract.** How many doorways may a shell declare,
   what are they named now that `entry`/`exit` no longer describes them,
   and is there an ordering a composer relies on? This blocks every
   multi-door shell.
2. **Is a closure geometry or a placement?** If the shell bakes a sealed
   doorway, capacity is fixed at export and decision 3 is untrue. If the
   composer places a closure asset into a declared doorway, I author one
   plate and it serves every shell. **I recommend the second**, and it is
   the cheaper of the two by a wide margin.
3. **Does a plug show its destination?** Decision 2 says Zone start *or*
   last large room. If the player is meant to know which before stepping
   in, that is two readable states per plug and changes what I draw.
4. **How many warp-station states**, and is "broken" distinct from
   "inactive" or the same object?
5. **Whether multi-door shells replace or supplement the twelve.** The
   brief says the two-door shells remain valid, which I read as
   *supplement* — worth confirming, since it decides whether a junction is
   a new family or a thirteenth-onward addition to the existing one.
6. **How many zone-local keys per Zone.** `zkey_ch1/2/3` and their three
   receivers exist and are **PASS**; `zkey_ch1` also already has
   `rusted_industrial` and `void_glitch` treatments, so the per-theme path
   is proven. Three is what exists; more is new art.

---

## 6 · What the art lane is deliberately not doing

* **The Span stair is untouched.** The finding is that
  `basin_south_to_deck` and `basin_north_to_deck` are `mandatory: False`,
  so nothing ever verified the 14 m climb. Production is investigating and
  I am waiting for the exact route/collider finding before altering the
  shell — changing geometry against a symptom would risk repairing the
  wrong thing.
* **No new room batch**, per the brief.
* **No manifest, schema or review-state change**, and the twelve approved
  shells are not rebuilt.
