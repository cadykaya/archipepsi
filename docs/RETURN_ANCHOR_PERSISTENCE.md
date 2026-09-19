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

## What a refusal ACTUALLY does to a committed Zone

**Correcting this document.** An earlier draft said Option A's refusal
path "sends the Zone back to be composed again, keeps its Checks, and the
player re-enters a Zone that is certified under the current rules". That
is what happens to a **fresh** Zone. It is not what happens to a
committed one, and the difference is the whole argument.

Two guards, both deliberate, both read from the code rather than assumed:

* `campaign.py`, the host re-selection branch:
  `if verdict.unhostable_rooms and rec.manifest is None:` — recomposing
  the graph with a room barred is for **fresh proposals only**. The
  comment says why: *"a Zone holding a committed manifest is a solved
  Zone the player may be part-way through, and it keeps what it has."*
* `transitions.refuse_layout`: *"**A COMMITTED Zone is preserved, not
  recomposed.** … That Zone goes DORMANT with its manifest, its content
  and its progress intact."*

So a refused **replay** does not recompose. The Zone goes DORMANT
holding its locations; `hub_mode_for` turns exhaustion into
`ZONE_FAILED`; the Hub offers **ABANDON**, which releases the Zone's
locations and is explicitly the player's call and has a cost. Nothing
abandons it automatically.

**The committed-manifest protection is not to be removed to make an
option work.** It is what stops a solved Zone the player is part-way
through being silently replaced.

## Option A — replay, re-measure, refuse

`zone_builder._build_once` reads `layout["anchors"]` where it has one and
uses the recorded point instead of calling `ChamberBuilders.return_spot`.
`RoomAudit._settle_return_anchors` judges it with the predicates it
already uses.

| | |
|---|---|
| Holds | replayed verbatim; the manifest's promise is kept |
| Fails | the layout is refused |

**And the refusal costs the Zone.** Per the section above, a committed
Zone that is refused goes DORMANT with its progress intact and no way
back into it. For the owner's campaign that is `c021` — its Check, its
branch and whatever else it holds — parked behind an ABANDON the player
has to choose and pay for.

**What it would additionally need** to behave the way the earlier draft
claimed: a recovery path for committed Zones that does not exist today,
i.e. relaxing `rec.manifest is None` or adding a separate
"recompose a committed Zone whose anchors no longer validate" transition.
Both change what a committed layout means. Neither is authorized here.

**Size:** one read, one branch, no schema change, no write-back. Cheapest
to build, most expensive to play.

## Option B — replay, re-measure, repair the anchor explicitly

A recorded anchor that no longer holds is **repaired in place** — the
settle already finds a valid spot — and the repair is recorded as a
repair: the room, the old point, the new point, and the rule that
rejected the old one, under an `anchor_repairs` key written by
`commit_layout`, which is already the only writer and already refuses to
replace a committed layout with a different digest.

**What it would additionally need**, and the digest wording matters:

* **A NEW content digest, not a "same-digest repair".** `manifest_digest`
  is computed from the manifest's content; moving an anchor changes that
  content, so the repaired manifest has a DIFFERENT digest and must. A
  repair that kept the old digest would be a manifest whose name no
  longer describes it — exactly the drift the digest exists to catch.
* **Explicit linkage to the manifest it replaces.** The repaired
  manifest carries the digest it was derived from (`repaired_from`)
  together with the room, the old point, the new point and the rule that
  rejected the old one. That is what makes it a repair rather than a
  replacement: the chain back to what the player actually played is
  recorded, not overwritten.
* `commit_layout` taught that a manifest naming a predecessor is a
  repair, so it neither refuses it as a replacement nor accepts an
  unlinked one.
* A backup of the primary save before the first rewrite, and something
  that tells the player their level changed.

It is a save rewrite, so it is a migration and needs an explicit
decision.

**The comparison the choice actually turns on:**

| | Option A | Option B |
|---|---|---|
| Blast radius | the **whole committed layout** of that Zone | **one anchor** |
| Player sees | a Zone that will not open, and an ABANDON with a cost | the same level, one device moved |
| Save is rewritten | no | yes, and visibly |
| Committed-manifest protection | untouched | must learn "repair" ≠ "replace" (new digest + `repaired_from`) |
| Scope of the actual defect | one return device in one room | one return device in one room |

Losing a solved Zone to relocate one convenience device is a remedy out
of all proportion to the fault. **B is the better fit for the defect**,
and A is the honest fallback for an anchor no repair can satisfy.

## Option C — version the placement rules

Stamp the manifest with a digest of the placement rules; `controller_digest`
is the nearest existing field. A replay whose stamp matches adopts every
anchor verbatim with no re-measure. An optimisation of whichever of A or
B is chosen, not an alternative to either, and worth doing only if
re-measuring proves expensive — it costs one physics query per anchor.

## Recommendation

**Prepare Option B, and keep Option A as its floor.** Repair the one
anchor, record the repair explicitly, and refuse only when no valid
placement exists in that room. That keeps the committed layout, keeps the
protection intact, and keeps the cost proportional to the fault.

It is a save rewrite, so **nothing here is implemented and no campaign is
migrated in this batch.** What is needed before it can be: the owner's
decision that a recorded anchor repair is an acceptable rewrite, the
manifest field and version stamp, the `commit_layout` distinction between
a repair and a replacement, and a pre-rewrite backup.

Do not read any of this as licence to revert the return-placement repair:
with it in place a freshly composed Zone puts the device off the required
approach, and this document is about the Zones committed before it.

## What must not happen

* No silent migration of an existing campaign.
* No reverting the placement repair to make old saves agree.
* No relaxing the settle's predicates so an old anchor "passes".
* The owner's original diagnostic save stays read-only and private.
