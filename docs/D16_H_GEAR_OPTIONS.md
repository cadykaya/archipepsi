# D-16 — H-GEAR: what the 16 costed domains can honestly become now

**Dess → Skyiah, 2026-09-25.** You approved H-GEAR, limited to the 16
costed domains. Before building it, I checked what those 16 can actually
be, and the design itself conflicts in four places. So, by your rule,
this is a stop with options rather than a build. Nothing is implemented.

**Ruled 2026-09-25: G1, with all four rulings** (verbatim in
`docs/ledgers/DESS_POST_PLAYTEST.md`). The bridge half has landed with
its gate closed; see "G1 as ruled" at the end.

---

## What the check found

**1. Three domains have both a value and a runtime.** Each domain's
SMALL/MEDIUM/LARGE value comes from a Design 1 §16.1 template, but no
document pairs a `dom_*` atom with its `INT_*` template. The pairing
below is read from the names:

| domain | template (Design 1 §16.1) | existing runtime path |
|---|---|---|
| `dom_speed` | `INT_MOVE_SPEED` +5 / +11 / +18 % | yes: `move_speed` (`player.gd:716, 861`) |
| `dom_jump` | `INT_JUMP_HEIGHT` +8 / +18 / +30 % | yes: `jump_height` (`player.gd:852`) |
| `dom_landing` | `INT_LANDING_CONTROL` air accel +25 / +55 / +90 % | yes: `air_control` (`player.gd:870-873`) |

- `dom_mobility_recharge` pairs clearly but has no runtime: cooldowns
  are never scaled.
- The other 12 have no runtime consumer at all. For example, max health
  is a constant, and there is no crit, reload or interact-range system.
- `dom_crit`, `dom_barrier` and `dom_handling` each match two templates.

**2. The budget rules disagree.**
- **Clauses:** Design 4 §4.6.1 budgets trigger clauses separately from
  the base, while §16 (`04:760`) counts one inside USEFUL's
  [85, 100] band.
- **No clause catalog:** there is no trigger-clause catalog anywhere,
  and without one most single pieces cannot reach 85.

**3. The piece shapes disagree.**
- **USEFUL:** it has "exactly one intrinsic" (`01:1892`), yet `04:760`'s
  worked example completes one with a second domain atom.
- **HIGH:** "Exactly one HIGH piece may be equipped" (`01:1892`) versus
  "at most one" (`01:444`).

**4. There is no approved transaction.** Design 4 prices the Forge, but
B4 is still pending, D-14 (recipes and sinks) is open, and the OV05
order says "No new Forge/Static prices". Static is only counted today.
So H-GEAR's "approved transaction consumers" is an empty set.

---

## Options

**G1. The Legs slice, clause-free and profound-only** *(recommended)*
- **What it is:** Gear exists for the three domains in table 1 only,
  all in the LEGS territory.
- **Pieces:** USEFUL only, one domain plus `mag_profound`. These land in
  band under both budget readings without any clause: speed 24 + 72 =
  96, jump 18 + 72 = 90, landing 16 + 72 = 88.
- **No rule changes:** smaller magnitudes wait for a clause catalog.
  HIGH pieces wait too, which keeps the HIGH-count conflict out of
  play.
- **Acquisition:** an Archipelago item's Echo may create a Gear piece.
  Epsilon picks the atoms, never the numbers, and there is a
  deterministic fallback. There is no Forge.
- **Equip:** four territory slots in the save.
- **Effect and clamps:** the bridge computes the equipped multipliers,
  clamped to Design 1 §16.5 (walk speed at most 1.45, jump only up).
- **Prod's half:** the runtime's StatStack multiplies in the snapshot's
  Gear values, plus the equip UI. The Epsilon pipeline offers the three
  domains.
- **Ordering:** the support gate opens only when that runtime exists,
  as with the lever. Until then the bridge half would be inert.

**G2. G1 plus a small trigger-clause catalog**
- **What it adds:** slight and marked pieces become legal once a
  catalog exists.
- **Cost:** someone designs the clause catalog. That is a balance and
  design task, not engineering, and it needs your ruling on §4.6.1
  versus §16.

**G3. Keep H-GEAR closed**
- **What it means:** until the pairing, the clause budget, the piece
  shapes and a transaction are settled, and runtimes exist for more than
  three domains.

---

## Rulings needed for G1

1. **The name pairings:** adopt speed↔`INT_MOVE_SPEED`,
   jump↔`INT_JUMP_HEIGHT` and landing↔`INT_LANDING_CONTROL`. The
   ambiguous three stay unpaired.
2. **Profound-only USEFUL pieces** until a clause catalog exists.
3. **No Forge or Static transaction** until B4 and D-14 are ruled. Gear
   comes only from Archipelago items' Echoes.
4. **For later, when HIGH arrives:** read "at most one HIGH" as the
   rule.

---

## G1 as ruled: what landed, and what is Prod's (note D-8)

**How each ruling is held in the bridge:**
- **1, the existing runtime stats.** Speed multiplies `move_speed`, jump
  multiplies `jump_height` and landing multiplies `air_control`: three
  of the nine stats the StatStack already moves for traits. The factors
  are Design 1 §16.1's LARGE values: 1.18, 1.30 and 1.90. There is no
  Gear-only stat and no Gear-only clamp. The stack's one floor and
  envelope clamp the whole product, as they do for traits.
- **2, one bounded stat effect.** One domain at `mag_profound`. Anything
  else is refused with its reason: another domain, a weaker magnitude,
  or a second intrinsic.
- **3, only from Echoes.** A piece is an Echo component (`kind: "gear"`).
  No transaction creates one, and a save that wears a piece its log
  never made is refused on load.
- **4, HIGH is derived.** A piece stores only its atoms: `domains` and
  `magnitudes`, as lists of length 1 today. Its factor, its territory
  and its tier are derived each time they are read. So a rebalance
  needs no migration, and neither does HIGH's arrival as a two-atom
  piece. The at-most-one-HIGH rule will sit where worn pieces become
  effects (`gear.worn_effects`); nothing can be HIGH yet.

**What the bridge now has:**
- the piece: `GearComponent` in `schemas/echo.py`, with its atoms, its
  refusals and the gate;
- the pairing and derivation: `schemas/gear.py` (`GEAR_EFFECTS`,
  `effects_of`, `worn_effects`);
- wearing it:
  - `CampaignSave.gear`, four territory slots, checked against the fold
    like `slots` and empty on any older save;
  - the `gear_action` transition and intent;
  - refusals named `gear_action:<territory>:<component_id>`;
- reading it:
  - `CampaignSnapshot.gear` and the computed `gear_effects`
    (stat → factor);
  - each Gear item in the inventory view carries its territory,
    effects, tier and whether it is worn, and the view lists the four
    territories.

**The gate is closed.** `SUPPORTED_GEAR_DOMAINS` is empty, so no piece
can exist yet and no Epsilon request offers one. It opens to the three
paired domains in one bridge commit after Prod's half, the lever's
order. That commit also retakes the playtest baseline, deliberately,
because the request then changes.

**Prod's half, then the gate:**
1. `campaign.snapshot()` passes `gear=save.gear` (one line; that
   function is yours).
2. `stat_stack.gd` multiplies `gear_effects[stat]` into each stat's
   product, beside traits, statuses and pulses, before `clamp_stat`.
3. The Equipment wall shows the four territories (`inventory.territories`),
   sends `gear_action` and attributes its refusals by key.
4. The Epsilon prompt, when the gate opens, authors Gear as atoms
   (`allowed.gear_domains`, `allowed.gear_magnitudes`), never numbers.

**One interpretation, for Skyiah to overrule if she wishes.** Design 1
§16.5 caps walk speed at ×1.45. The existing stack caps `move_speed` at
×1.6 (`SPEED_MULT_MAX`). Ruling 1 forbids a Gear-only clamp, and moving
the stack's cap would change existing traits, so the stack's 1.6
stands. A profound speed piece alone is ×1.18, well under either cap.

