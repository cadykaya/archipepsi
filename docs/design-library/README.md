# Design library — the EX50 setpiece entries

**These are PAPER DESIGN PROPOSALS. They are not runtime acceptance
reports, and nothing in them is evidence that the engine does what they
describe.** Verified runtime behaviour for this programme lives in
`docs/ledgers/HUGE_BATCH_LEDGER.md`, which states for every task whether
it is planned, implemented, verified, blocked or unrun, and by what
measurement. Keeping the two apart is the point of this directory
existing separately.

## What is here

| File | What it is |
|---|---|
| `EX50_entries/EX50-011.md` | Passing Platforms |
| `EX50_entries/EX50-021.md` | Counterfire Arcade |
| `EX50_entries/EX50-033.md` | Unweighted Switch |
| `EX50_REFERENCE_NOTES.md` | The entries' source abbreviations and evidence labels |
| `RECOVERY_SHA256SUMS.txt` | The recovery bundle's own manifest, copied unchanged |

The three entries are the minor setpieces selected in the approved
huge-batch plan (§4 E / decision 4), chosen for parts-sharing with the
Blindside major rather than for variety.

## Provenance, and how it was checked

The files arrived on 2026-09-21 in
`ARCHIPEPSI_FIRST_MINOR_SPECS_RECOVERED.zip`. That bundle states the
entries were extracted byte-for-byte from `design_library/EX50_entries/`
inside `ARCHIPEPSI_HUGE_BATCH_PLAN_PACKAGE.zip`
(SHA-256 `dfd6dec4efac005ab3b603a31f73ed73270bfe321821b4ab9e2d87d990838e99`),
and independently compared against the copies in
`ARCHIPEPSI_EX50_CHECKPOINT_45.zip`.

**Checked twice on this line, and the second check is the one that
matters here:** the bundle's own manifest verified on arrival, and the
same digests were recomputed **after** the files were copied into this
repository. All four match.

| File | SHA-256 |
|---|---|
| `EX50_entries/EX50-011.md` | `bd27368a631b4cf551884267f6d330a5c8de246e56d6417019578016ad3b1fff` |
| `EX50_entries/EX50-021.md` | `a6306df1bb4c3aa9e57e61b2788a8e87232cfdc8fc64667bcc812df24e451708` |
| `EX50_entries/EX50-033.md` | `910b532a3040a9c6ef742ae0f40cc5a6c535d558b1becea8fe6e78378426ec8c` |
| `EX50_REFERENCE_NOTES.md` | `67185a0a1fdbf0547e20950f13ccbab98b4369ab25e39e679571b1a0c9d8ce51` |

**Nothing in `EX50_entries/` has been edited, reflowed, reconciled or
annotated, and nothing in it should be.** A correction, an amendment or
an implementation note goes in the ledger or in a file beside this one,
never into an original — the digests above are how anyone confirms that
what the engine was built against is what was written.

## How to read them against the rest of the project

- **Their status label is REVISED_ON_PAPER.** Proposed dimensions,
  timings and dependencies are claims to be checked against the
  implementation, not facts about it.
- **Their source-baseline notes are historical.** They do not establish
  what this engine can currently do, in either direction.
- **Later owner decisions supersede conflicting historical design text.**
  The approved 0.4 plan and its 2026-09-21 addendum are the current
  authority; in particular, old source notes must not be used to narrow
  Epsilon's subsequently approved objective-authoring role.
- **Recovering the documents removed a document-access blocker and
  nothing else.** It does not mean the engineering dependencies exist.
  EX50-033 in particular describes a *semantic mass-class sensor* and a
  LIGHTENED interaction, which is a different thing from a summed-kilogram
  plate or a numeric mass adjustment; the ledger records which of those
  the engine actually has.

## This is not a competing authority

`docs/design-proposals/` holds the six complete player/dungeon authority
proposals, of which exactly one is promoted. This directory holds
setpiece entries and is not one of them, does not rank against them, and
does not restate them.
