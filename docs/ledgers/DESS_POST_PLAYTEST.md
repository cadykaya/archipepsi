# Dess — post-playtest execution (Wave 0 → Wave 1 → Wave 2, then D-01)

The governing packet is `post_playtest_v1.0/` (Prod's CP0 copy).
Dess's brief is `post_playtest_v1.0/dispatch/DESS_START.md`. Task IDs
are the packet's.

## Resumption

- **Resumed:** 2026-09-24, at `76b0952` (Prod's CP1 head, fast-forwarded,
  clean tree).
- **Approval:** the owner approved the Dess lane plan — Wave 0 → Wave 1
  → Wave 2, then D-01 as ready work. D-02, D-03 and D-04 stay owner
  decisions: Dess brings concrete options before implementing those
  branches.

## The owner's rulings on the plan's decisions (2026-09-24, verbatim)

**M-1 — legacy step-once plate routes.** "Existing saved Zones
containing the old step-once route retain their saved behavior until
the player leaves or the Zone is regenerated. New composition must not
produce that route. Do not reinterpret an existing Zone as a held plate
and do not auto-open it by inventing state."

**M-2 — legacy encounters.** "If an older save contains no evidence
that an encounter member died, the current encounter is unknown:
reconstruct it and resume the player from its safe arrival point rather
than amid respawned enemies. However, replaying an unknown encounter
must not duplicate any already-authorized one-shot AP Check, unique
reward, key, or other monotone progression state."

**M-3 — map room names.** "Use the authored room name when one exists,
otherwise type + number. This is presentation only; it must not become
persistent room identity."

## W0.1 — the Prod → Dess file handback (REQUESTED; Dess edits no shared file until it is recorded)

Prod's ledger (`PROD_POST_PLAYTEST.md`, "Ownership, recorded before any
shared edit") took a temporary single-writer exception because Dess had
not resumed, with the rule *"if Dess or Arty resumes, the file in
question passes back to them."* **Dess has resumed.**

The owner has made this handback **mandatory before Dess edits any
shared file, with no two-writer interval.** There is no live channel
between the sessions, so the handback is requested here. Until Prod
records it, **Dess edits none of the files below.**

### Files requested back (the 09 §5 split: Dess owns schema, protocol, progression source and generated exports)

- `bridge/archipepsi_bridge/schemas/**`: protocol, transitions, zone,
  signal_graph, physics, constants, graph, minors, gear, export,
  mechanics, echo, content, migration, and `generated/*`.
- Progression and composition in `bridge/archipepsi_bridge/`: topology,
  cross_room, latched_route, transport_route, candidate, minor_hosting,
  theme_packs, content_value, layout, store.
- In `campaign.py` and `server.py`: **only** the progress-intent seams —
  the handlers, the routing and `_about`.
- Generated from those: `godot/scripts/autoload/constants.gd`, the
  apworld constants copy, `docs/design-packet-v0.8/schemas/*`, and the
  Zone fixtures the make targets regenerate.
- Bridge tests follow the file they exercise.

**Prod keeps** everything else under `godot/`, the runtime integration
and the final combined tests.

### What the handback needs from Prod (one ledger entry)

1. Commit, or name, any in-flight edit to the files above.
2. Record *"handback to Dess at `<sha>`"* with the released files, and
   any file he must keep and until which checkpoint.
3. After that, request any shared change through a Dess note or a
   recorded temporary transfer — never by editing directly.

### Sequencing, so CP2 is not held up

After the handback, Dess delivers the bridge halves of H-PRESSURE-C and
H-RELEASE-C first. Those are what H-PRESSURE-R and the three room
repairs consume, so Prod does not need to take the exception for them.

## Working without shared edits until the handback lands

These touch no shared file:

- **H-SEAMS review.** Verdicts are recorded here; any repair waits for
  the handback.
- **Boundary tests of existing behaviour, in new test files.**
- **The H-KEYS audit.** A new read-only tool.
- **Contract texts** for H-PRESSURE-C and H-RELEASE-C.

Anything that needs a shared edit is queued below with its file named.
