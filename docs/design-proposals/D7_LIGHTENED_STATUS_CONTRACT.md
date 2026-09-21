# D-7 — the `lightened` Status contract, and the choice under it

**Dess, bridge/design lane — 2026-09-21.** Against Prod's checkpoint
`7dcf5df` on `claude/archipepsi-0-4-blindside` (PR #12).

**Lane accepted.** Bridge/design D-1..D-7. Prod remains runtime and
integration owner.

**File ownership proposed** (objections welcome before I touch anything
shared):

| Area | Owner |
|---|---|
| `bridge/archipepsi_bridge/**`, `bridge/tests/**` | Dess |
| `docs/design-proposals/**`, `docs/design-library/**` | Dess |
| `godot/**` authored scripts and scenes | Prod |
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

## 2. Delivered now, because it needs no decision

**NO STATUS BEFORE ITS EFFECT.** Whatever is chosen in §3, the hole
F-15 warns about has to be closed first, or the first name admitted
re-opens it.

`echo.STATUS_KINDS`' own comment records the original defect: a typo
produced *"a status that was permanent and did nothing"* — inert,
because nothing read it, yet still satisfying `status_active`
conditions and `status_applied` edges, and un-`cleanse`-able because it
was not in the cleanse order. Admitting a **designed** name does the
same thing deliberately.

So the vocabulary and the guarantee are now two lists:

- `STATUS_KINDS` — what the design **names**.
- `IMPLEMENTED_STATUS_KINDS` — what the runtime can **honour**.
- `StatusComponent` refuses to emit any kind outside the second.
- `make export` sends the engine both, as `ECHO_STATUS_KINDS` and
  `ECHO_STATUS_KINDS_IMPLEMENTED`, so it can assert it can honour what
  it is given rather than trusting the vocabulary.

Today the two lists are equal and **this refuses nothing** — it is inert
on purpose. Its value is that it makes a name safe to admit *early*: a
kind can be specified, exported and reviewed while still un-emittable,
and becomes emittable in the same change that gives it an effect.

Controls: the equal case passes every kind; the split case refuses the
unimplemented one and still passes the rest; and the engine is checked
to receive both lists. Proven to bite — the refusal test fails if the
gate is removed.

---

## 3. The decision I am not taking

**Which status model does 0.4 build on?**

- **B1 — widen A toward B.** Admit `lightened`/`anchored` and widen
  `target` to include `object`. Smallest change that unblocks EX50-033.
  Cost: a schema built for creature conditions now carries a property
  grammar it was not designed around, and the other nine **B** names
  stay absent, so the vocabulary is coherent in neither model.
- **B2 — adopt B as the status vocabulary** (the acquisition work's
  preferred-direction shape, applied here). Coherent with Design 6, and
  the largest change: eleven kinds, five target types, compounds
  (`updraft` = `lightened` + `burning`) and §15.7 immunities.
- **B3 — keep A, and EX50-033 keeps its stand-in.**
  `ManipulableBody.shift_class_provisionally` already carries the
  Status's exact shape room-locally, and §10's decisive control does not
  depend on what moved the class. The room stays unbuilt.

**I have not picked one, and the gate in §2 is correct under all three.**
My reading is that **B1 is a trap** — it is the cheapest change and the
one that leaves two incoherent vocabularies — but that is a product
judgement, and it is yours.

**What I need to proceed on priority 1:** the choice above. Everything
else in the brief (RailNetwork, acquisition, objective-binding, save
representation) is independent of it and continues meanwhile.

---

## 4. Scope kept

Normal generation, original saves and the 0.3 comparison untouched. No
economy decision, no silent migration, no relaxed validation. Nothing
scheduled, no watchers. `constants.gd` was regenerated through
`make export`, never hand-edited.
