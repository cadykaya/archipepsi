# D-7 — the `lightened` Status contract, and the choice under it

**Dess, bridge/design lane — 2026-09-21.** Against Prod's checkpoint
`7dcf5df` on `claude/archipepsi-0-4-blindside` (PR #12).

**Lane accepted.** Bridge/design D-1..D-7. Prod remains runtime and
integration owner.

**File ownership proposed** (objections welcome before I touch anything
shared):

| Area | Owner |
|---|---|
| `bridge/archipepsi_bridge/**`, `bridge/tests/**` — contract, schema, generation constraints, exports | Dess |
| `docs/design-proposals/**`, `docs/design-library/**` | Dess |
| `godot/**` — effects, targeting/interaction integration, feedback, Unweighted Switch | Prod |
| `godot/scripts/autoload/constants.gd` | **generated** — written only by `make export`, never hand-edited by either lane |
| `docs/ledgers/HUGE_BATCH_LEDGER.md` | Prod's record; I append findings, I do not rewrite his rows |

---

## 1. The finding: this is not a missing name

F-15 records that `lightened` is absent from `Constants.ECHO_STATUS_KINDS`
and that adding it is not a one-liner because its effect spans impulse,
wind, conveyors and Physics eligibility. That is true, and there is a
larger reason underneath it.

**There are two status vocabularies in the accepted lineage, and they
share one word.**

| | source | the twelve |
|---|---|---|
| **A — implemented** | `design-packet-v0.8/ECHOES.md` → `schemas/echo.StatusKind` → `constants.gd` | `burning`, `slowed`, `frozen`, `shocked`, `poisoned`, `marked`, `stunned`, `vulnerable`, `empowered`, `low_profile`, `haste`, `regenerating` |
| **B — designed** | Design 5 §15.2 "The twelve base Statuses", carried into Design 6 (§2787 cites it) | `lightened`, `anchored`, `slippery`, `confused`, `turncoat`, `blinded`, `silenced`, `rooted`, `phased`, `burning`, `conductive`, `brittle` |

Overlap: **`burning`, and nothing else.**

They are not two versions of one list. **A** is combat conditions on
creatures — ECHOES.md calls them *"bounded named conditions on self or
enemies"*. **B** is a property grammar in four families (`KINETIC`,
`COGNITIVE`, `PERMISSION`, `MATERIAL`) over §15.1's five target kinds,
including objects, surfaces and volumes.

**The blocker is the target scope, not the name.**
`StatusComponent.target` is `Literal["self", "enemy"]`. EX50-033's whole
mechanic is a Status applied to *a crate*. **There is no way to express
that today**, and no addition to `StatusKind` creates one.

So `lightened` needs three things, not one:

1. the kind admitted to `StatusKind`;
2. `StatusComponent.target` widened to §15.1's kinds (at minimum
   `object`), which imports model **B**'s target scope into a schema
   built for **A**;
3. the runtime effect — Prod's half, and the part F-15 correctly sizes.

Item 2 is the owner decision. I have not taken it.

---

## 2. The destination, and the gate that was wrong

**Owner decision 2026-09-21: B2's architectural direction.** The 0.4
destination is the Amalgam's Status system. Object-targeted Status is in
scope and EX50-033 is not blocked on whether objects may receive Status.

**Thirteen, not twelve.** Amalgam §15.2 *modifies* Design 5 §15.2 — it is
Design 5's twelve plus **`exposed`**, restored per §0.4 with its Defense
effect and **without** its crit clause, `COGNITIVE`, 6.0 s, 0.35,
**actor only** (objects have no Defense stat). My first reading took the
inherited twelve as the target and would have shipped the destination
one Status short.

**The gate I delivered was wrong, and in the way that mattered.**
`IMPLEMENTED_STATUS_KINDS = STATUS_KINDS` made support a *consequence of
being named*, so every kind added to the vocabulary admitted itself. It
would have protected nothing at the exact moment it existed for.
Corrected: support is `SUPPORTED_STATUS_TARGETS`, a declared table, and
the assertion between them is **one-way** — everything supported must be
a real kind, and nothing is supported merely by being real.

**Support is per kind AND target**, because it is not one fact:
`lightened` on an object and on a surface are different runtime work.

**Three doors, one gate.** Gating `StatusComponent` alone left two ways
in, and a fourth copy of the vocabulary:

| path | before | now |
|---|---|---|
| `StatusComponent` | kind only, `target` was `self`/`enemy` | kind **and** target, five §15.1 targets |
| `ApplyStatusOnHit` | a hand-written **eight-kind** literal, kept in step with nothing | `StatusKind` + the gate at `enemy` — which derives exactly those eight |
| `Effect(type="apply_status")` | `subject` was a free `[a-z0-9_]+` string — **any string at all** | gated; `brunning` is refused |

Current state: **24 kinds named, 12 supported.** The twelve §15.2 kinds
are named and supported by nothing, which is the honest state and is what
the doors refuse. `make export` sends the engine both lists.

Controls use real unsupported kinds rather than a patched list, and cover
unsupported *target* applicability as well as unsupported kinds.

---

## 3. Compatibility — how existing meanings are handled

Not deleted, not unioned. The retained ECHOES.md kinds stay named so a
committed 0.3 component still parses; this batch performs **no migration
and no reinterpretation**.

| case | kinds | decision |
|---|---|---|
| ECHOES-only, no §15.2 counterpart | `slowed`, `frozen`, `shocked`, `poisoned`, `marked`, `stunned`, `vulnerable`, `empowered`, `low_profile`, `haste`, `regenerating` | **Retained as legacy.** Supported, unchanged meaning, not part of the destination. No collision. |
| §15.2-only, no ECHOES counterpart | the other twelve, incl. `lightened`, `anchored`, `exposed` | **Named, unsupported.** Emittable only when Prod declares the effect. |
| **In both, different meanings** | **`burning`** | **UNRESOLVED — flagged, not decided.** See below. |

**The `burning` collision.** Today `burning` deals periodic damage:
`status_effects.dot_per_second()` is
`4.0 * magnitude_of("burning") + 2.0 * magnitude_of("poisoned")`.
Amalgam §15.3 rule 1 is absolute — *"No Status directly deals or
schedules Health damage"*, Player Authority §20.1 and Law 27, *"no
exception, no Status, ever."*

**The same name means two incompatible things.** Adopting §15.2's
`burning` removes periodic Status damage, which changes the behaviour of
`burning` and `poisoned` components that already exist in saved
campaigns. That is a migration question, and this batch is forbidden to
migrate.

So: `burning` keeps its shipped meaning **because nothing changed its
runtime**, and the §15.3-compliant `burning` arrives with Prod's
implementation. **That change must carry the decision about what an
existing `burning` component means** — it cannot be taken silently, and
it is not taken here. `poisoned` rides on the same decision.

---

## 4. Scope kept

Normal generation, original saves and the 0.3 comparison untouched. No
economy decision, no silent migration, no relaxed validation. Nothing
scheduled, no watchers. `constants.gd` was regenerated through
`make export`, never hand-edited.
