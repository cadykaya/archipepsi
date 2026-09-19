# Replaying a committed return anchor

**Status: proposal. Nothing here is implemented, and this batch changed
no save behaviour.** The owner's original diagnostic save is untouched
and was only ever read from a disposable copy outside the repository.

## The defect this answers

`ZoneBuilder.layout_from_json` parses a manifest's `anchors` block.
`_build_once` consumes only `rooms` and `joins`. **Every anchor is
recomputed from the replayed poses**, so a save reopened on a build whose
placement rules have changed gets a device somewhere else.

Measured on the owner's own campaign: `work_manifest.json` carries
`room:c021:return = [18.99, 1.53, 42.25]` byte for byte, and this build
recomputes it to `(24.27, 1.53, 39.65)` — **5.89 m away**.

`commit_layout` says *"a committed layout is replayed, never replaced"*,
and `_the_committed_placement_is_what_was_played` holds that to 0.000 m
— **for room transforms**. It was never true of anchors and nothing
measured them, which stayed invisible only while the rule that computes
them never changed. The 0.3 return-placement repair changed it.

## What a replay has to decide, per anchor

1. **The recorded value still holds.** The common case, and the one the
   contract already promises. Replay it verbatim.
2. **The recorded value no longer holds** under current rules — it is
   inside a pedestal, off the required approach's clearance, or on a
   surface the room no longer declares. A move is needed and must not be
   silent.
3. **No valid placement exists** in that room at all. The Zone cannot be
   replayed as committed and must fail safely rather than strand a
   player in a dead end with no way out.

The measurement for (1) and (2) already exists and is the one the engine
and the bridge both read: `RoomAudit._settle_return_anchors`'
`arrival_is_supported` ∧ `clear_of_arrival` ∧ `clear_of_content_path`.
Nothing new has to be invented to judge an anchor.

## Option A — replay, re-measure, refuse *(recommended)*

The smallest change that is compatible with the save contract as
written, because it adds no new persisted state and performs no
migration.

**`zone_builder._build_once`** reads `layout["anchors"]` where it has one
and uses the recorded point instead of calling `ChamberBuilders.return_spot`.
**`RoomAudit._settle_return_anchors`** then judges it exactly as it
judges a freshly reserved one. Three outcomes, all of which the pipeline
already has vocabulary for:

| | |
|---|---|
| Holds | replayed verbatim; the manifest's promise is kept |
| Fails, a valid spot exists | **not moved.** The layout is refused, naming the room |
| Fails, no valid spot | the layout is refused, naming the room |

The refusal path is `Verdict.unhostable_rooms`, which exists for exactly
this shape: *"Naming them turns a whole-Zone loss into a different
host."* A refused replay sends the Zone back to be composed again, keeps
its Checks, and the player re-enters a Zone that is certified under the
current rules. That is the campaign's existing recovery loop, and it
already has a refusal budget and an exhaustion path.

**Cost, stated plainly:** a save whose recorded anchor no longer holds
loses that Zone's committed geometry and plays a recomposed one. For the
owner's campaign that is one room in one Zone. It is a visible,
explicable outcome rather than a device that moved while the file said
otherwise.

**Size:** one read in `_build_once`, one branch in the settle, no schema
change, no new field, no write-back, nothing to migrate. Old saves work
unchanged the moment it lands.

## Option B — replay, re-measure, repair and record

As A, except that a failing anchor whose room still offers a valid spot
is **repaired** and the repair is **written into the manifest** with the
room, the old point, the new point and the rule that rejected the old
one, under a `anchor_repairs` key; `commit_layout` is the only writer, so
the rewrite goes through the path that already refuses to replace a
committed layout with a different digest.

Better play (the Zone survives), worse contract (the save is rewritten).
It is a migration, so it needs the owner's explicit decision, a backup of
the primary before the first rewrite, and a way for a player to see that
their level changed. **Not recommended for this repair**, whose blast
radius is one room.

## Option C — version the placement rules

Stamp the manifest at commit time with a digest of the placement rules
(the `controller_digest` already in every manifest is the nearest
existing thing). A replay whose stamp matches adopts every anchor
verbatim with no re-measure; a replay whose stamp differs falls back to A
or B.

This is an optimisation of A, not an alternative to it: it makes the
common case free and makes "this save predates the current rules" a fact
the engine can state. Worth doing **after** A, and only if re-measuring
proves expensive — it costs one physics query per anchor today.

## Recommendation

**Take Option A.** It is the only one of the three that changes no
persisted state, needs no migration, and cannot move a device while the
save says otherwise. It converts a silent relocation into a refusal the
campaign already knows how to recover from.

Do not take it as licence to revert the return-placement repair: with
the repair in place a freshly composed Zone puts the device off the
required approach, and A is about what happens to the Zones committed
before it.

## What must not happen

* No silent migration of an existing campaign.
* No reverting the placement repair to make old saves agree.
* No relaxing the settle's predicates so an old anchor "passes".
* The owner's original diagnostic save stays read-only and private.
