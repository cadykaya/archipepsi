# Integrated checkpoint — the combined tree, and what it is ready for

**Dess, bridge lane — 2026-09-13.** Integration owner for this batch was
the engine lane; this is the bridge lane's half of one handoff.

**Combined revision: `claude/archipepsi-amalgam-bridge` at the commit
below**, which is the engine lane's `37f225d` merged into the bridge
lane's `089dc64`. Art's `1a9f1c9` is not in this branch and nothing here
depends on it.

---

## 1. What had to be reconciled, and which side won

Both lanes repaired the same two defects independently, before either saw
this brief. They are now one of each, not two side by side.

### Procedural capacity — the engine lane's declaration

`C.PROCEDURAL_SOCKET_CAPACITY` is the authority. It is the wider
measurement: **both** producers that climb answer a side assignment with
a solid wall, and it is projected into `constants.gd`, so the composer
(`topology._sockets_for`), the schema (`Zone`'s socket invariant) and the
builder (`ChamberBuilders.procedural_sockets`) read one table.

| producer | side doorways |
|---|---|
| `corridor`, `arena`, `treasure_room` | hole + floor |
| **`platform_path`** | solid, no floor — its side wall is over the pit |
| **`tower`** | solid — the other producer that climbs |

This lane's `SIDELESS_PROCEDURAL_TYPES` covered `platform_path` only and
is **gone**. `procedural_sockets_for` survives as the projection of the
shared constant. **Kept from this lane:** the `validate_zone` refusal,
which turns back a *proposal* that assigns a door the producer will not
build — a different seam from the composer's own
`_refuse_doors_beyond_capacity` assertion, and the one reachable for
archived and replayed Zones.

### The attempt discriminator — the engine lane's, and this lane's was wrong twice

- It compared `!=` where `<` is right. A result from an attempt **ahead**
  of the record — a record that came back stale off disk — would have
  been dropped, stranding a client that knows something the bridge does
  not. The surviving guard takes it and logs.
- It added `ZoneReady.attempt`: a **second carrier** for a fact
  `layout_refusals` already puts on `active_zone` in every snapshot. That
  is precisely what `ZoneReady` forbids for progress, for the same
  reason. Removed; the client reads the ordinal with
  `BridgeClient.attempt_for`.

Preserved through the reconciliation, all five: content digest as content
identity; `layout_refusals` as the ordinal; an old result not charging a
replacement; a genuine new failure still charging its own attempt; and
the real snapshot/build/send path. **Kept from this lane:** one control
the other file lacked — the genuine-second-failure direction, which
matters more than discarding a stale result, because a discriminator that
swallows real failures keeps a broken Zone alive forever.

### Branch preservation — this lane's, and it matters more now

`_branch_routes` keeps a reserve and **replaces** a destination that can
find no junction instead of dropping the branch. With `tower` sideless
too the junction pool is smaller still, and the played Zone holds **23
rooms / 30 edges / 8 plugs** unchanged across both repairs. Tuning
untouched; `SPINE_SHARE` and `MAX_SIDE_DEPTH` are as they were.

### One gap found in the merged tree and closed

`tower` was in the capacity table and **no control ever handed the
composer one** — the declaration test proved the dict's contents, not the
behaviour. The climbing-room control is now parametrised over both
producers; removing the `tower` entry fails it. This is the project's own
recurring shape: a measurement that exists, is correct, and is never
handed the case that fails it.

### Test homes, so neither lane grows a second copy

| fact | home |
|---|---|
| the capacity declaration (both producers, three readers, old saves) | `test_socket_capacity.py` |
| the attempt discriminator | `test_attempt_identity.py` |
| what the composer *does* with a truthful capacity | `test_topology.py` |

Duplicated helpers were collapsed onto one: `_a_reselectable_host` and
`_a_host_that_cannot_move` now ask the question with the same call, so
two helpers cannot disagree about the same Zone.

---

## 2. Evidence re-run on the combined commit

**Bridge and packet — run here, on this tree:**

- `make test` — **1477 passed, 6 skipped**. The six skips are
  environment-only: no `anthropic` module, no Archipelago checkout.
- `check_packet.py` — green, 11 documents, 1072 identifiers, 287 enum
  members. Both packet mirrors reconciled.
- Derived artifacts regenerated from combined source: exported schemas
  and `constants.gd`, `played_zone.json`, the five controls, the
  twenty-Zone sample. **The originals are retained** under
  `generated-before-capacity/`, `sample-before-capacity/` and
  `played_zone-before-capacity.json` — 28 climbing-room side doors are
  still in those archives, deliberately, and **0** in the live fixtures.
  Nothing was swapped for a luckier seed and no expected value was
  hand-edited.

**Godot targets — NOT run here.** There is no Godot binary in this
container (`godot-bin/` is absent). The engine lane ran them on its own
tree and reports them in the frontier; I am relaying, not attesting.
Anything below the line "the whole journey, driven" in
`docs/AGENT_FRONTIER.md` is the engine lane's measurement, not mine.

**Which recovery ran — they are different successes.** The engine lane's
journey exercised the **refusal/recomposition** recovery: the host could
not be re-selected, `_reselect_hosts` stood down, the bounded refusal
took the Zone back to Epsilon, and the attempt ordinal moved 0 → 1.
**Host re-selection** — the branch moving to another host with the
arrangement preserved — is a different successful recovery and is
exercised by bridge controls, where the host can be chosen for the
property under test. A passing run of one is not evidence for the other.

**Scene reconstruction is not a two-process restart.** The manifest
replaying into a rebuilt scene and both processes being restarted are
separate claims; `godot-reload`'s PHASE 2 is the former.

---

## 3. The readiness findings, assessed on the merged tree

Bounded diagnosis only, and only what the bridge can settle without an
engine.

**Distinction 1 — an invalid or unreachable route — is ruled out for all
five journey inputs.** Every one composes a connected graph and
`topology.reachability` returns OK on the merged tree:

```
zone_01  23 rooms  30 edges  8 plugs   reachable: True
zone_02  23 rooms  30 edges  8 plugs   reachable: True
zone_03  23 rooms  30 edges  8 plugs   reachable: True
zone_04  20 rooms  27 edges  8 plugs   reachable: True
zone_05  20 rooms  27 edges  8 plugs   reachable: True
```

A failed journey leg on these inputs is therefore **not** a missing or
unreachable route in the logic. It is distinction 2 or 3 — geometry, or
steering — and both are the engine lane's to separate.

**Distinction 2 — a return pad interfering with access to content — can
never be ruled out by luck, and that is structural.** Every one of the 8
return rooms in all five Zones also holds a Check or a key: **8 of 8, in
every Zone.** That is a consequence of the composer's own rule that a
branch only goes somewhere worth going, not a coincidence. So
`ChamberBuilders._clear_spot` reconciling the return spot against the
reward pedestal and the key spots is load-bearing in **every branch room
of every Zone**, never occasionally. Pinned by a new control, which was
vacuous on its first attempt (every room in it carried a reward, so
relaxing the rule changed no outcome) and now fails when the rule it
guards is relaxed.

**Distinction 3 — a valid route the steering fails to follow — is not
mine to settle**, and I did not build anything toward it. No navigation
bot was written.

**Collision/overlap guarantees were not relaxed.** Nothing in this batch
touched them, and no sample count was improved by weakening one.

**Re-selection was not optimised back toward 8 of 8.** The old table
reached that number by planning routes through doors the engine then
measured as solid. 1 of 8 is the honest figure against real capacity and
is reported rather than tuned away.

---

## 4. Remaining demonstrated blockers

Engine lane's, unchanged by this batch and not claimed closed:

1. **Overlap reconciliation** — the join/collar distinction, separating
   "the router found a candidate" from "the bridge accepted it" in what
   gets published, and the bounds diagnosis for the four large-shell
   failures.
2. **The ordinary journey** — `re_entered` reaches 1 of 3 and is floored
   at 0 deliberately; the fall at waypoint 0 and the stop-shorts are
   unchanged.
3. **The pending-room integration proof** — stays on the backlog. No
   pending asset was promoted and no new room wave is required here.

Bridge lane: none outstanding that I can demonstrate on this tree.

---

## 5. For the next owner playtest

**Supported launch.** The bridge is the game's other half and must be
running first; the game reads BRIDGE OFFLINE until it is.

- Windows: double-click **`Start Archipepsi (Windows).bat`** and leave
  that window open, then launch the game.
- macOS / Linux: **`./start-archipepsi.sh`**, left running, then the
  game.

**Do not overwrite existing save data.** Saves live in `./saves` by
default, and `ARCHIPEPSI_SAVE_DIR` overrides it. Point the diagnostic run
at a throwaway directory and the existing campaign is untouched:

```
ARCHIPEPSI_SAVE_DIR=./.diagnostic-saves ./start-archipepsi.sh
```

(The engine lane's own harnesses already do this — `INTEGRATION_SAVES`
and `JOURNEY_SAVES` are throwaway directories for the same reason.)

**Readiness, stated as asked.** **Yes for a diagnostic playtest** — a run
whose purpose is to produce findings. A default-scale Zone is composed,
accepted, committed, replayed after a cold restart, and its returns are
real; the capacity the composer advertises is the capacity the builder
builds; and the recovery paths report which one ran.

That is **not** a claim that every backlog item is finished, that the
ordinary cross-Zone journey is reliable, or that Playable 0.3 is
complete. Items 1–3 above are open and will show up in a playthrough.

---

## 6. Scope

No fun-report implementation, no capability-progression decision, no new
reward system, no enemy redesign, no 0.4 setpiece work. No new framework.
No watchers and no recurring check-ins.
