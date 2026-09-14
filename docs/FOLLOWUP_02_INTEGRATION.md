# Follow-up 02 — integration: the lower-budget generation variant

**Branch:** `claude/archipepsi-echoes-continuation-b1adno`
**Merged from the bridge lane:** `fdac6ab`
**Tested revision:** _§8, after the run_

Dess built the variant. This is Prod integrating it: the opt-in that
selects it, what selecting it turned out to actually require, what it
does to stations, and what both modes do through the real client and
bridge.

The engine work from earlier in this batch — the mounting
reconciliation, the two retracted fixture leads, the panel consumers —
is unchanged and is written up in **`docs/FOLLOWUP_02_HANDOFF.md`**.
This page is only the variant.

---

## 1. What the variant is, in your words

**A LOWER-BUDGET GENERATION VARIANT.** Not the same level with two
drills removed.

It does two things to a new Zone:

- offers neither standalone drill family (`timed_run`,
  `pressure_routing`), and
- builds to **72%** of the band, so the share those families held is
  not handed back as more of what remains.

And it does a third thing that nobody chose, because one budget number
derives three separate quantities in `fallback._build_to_budget` — the
room envelope, the enemy caps, and the per-room soft cap:

> measured over twelve cases, **+17 rooms and +27 enemies**, and it
> composes **different rooms** from the baseline.

**The strictly matched no-compensation comparison is therefore still
incomplete**, and this records that rather than papering over it.
Holding rooms and enemies constant means decoupling those three
derivations in the shipped composer, which is a generation change an
experiment may not make. The variant reduces the family *substitution*
the original brief objected to; it does not isolate the drills.

`0.72` is untouched. Nothing here tuned it to make anything pass.

Every place the variant announces itself — the bridge banner, the
launcher banner, `--help`, and the marker file written into its save
slot — carries those three differences.

---

## 2. Launching it

**Two launchers, two save slots, and they cannot be mixed.**

| | |
|---|---|
| normal | **`Diagnostic Campaign (Windows).bat`** → slot `current` |
| variant | **`Diagnostic Campaign - Lower Budget (Windows).bat`** → slot `quiet` |

Neither is the other's default, and neither can be pointed at the
other's campaign: the first variant run writes a `.quiet-generation`
marker into its slot, and every later run reads it. An ordinary run
aimed at a variant slot is refused; a variant run aimed at an ordinary
slot is refused. **Your `.diagnostic-582e954` has no marker, so it reads
as the ordinary campaign it is, and a variant run cannot touch it.**
The refusal happens before anything is opened, created or started.

There is still no reset switch anywhere in the launcher.

From a terminal, if you prefer:

```
cd bridge
python -m archipepsi_bridge.diagnostic --quiet            # the variant
python -m archipepsi_bridge.diagnostic                    # normal
python -m archipepsi_bridge.diagnostic --list             # what exists
python -m archipepsi_bridge.diagnostic --quiet --dry-run  # say, don't start
```

The raw flag, if you are starting the bridge yourself, is
`--quiet-generation`. It is off unless passed.

---

## 3. The comparison route

Fifteen minutes, two windows, one after the other. **Never both at
once** — they would fight over the port.

1. **Normal first.** `Diagnostic Campaign (Windows).bat`, then launch
   the game. Take the first Zone. Note how many activities you meet and
   which kinds — you should see races and plate routes among them.
2. Leave the Zone from a station (*Save and Return to Hub*), close the
   game, close the bridge window.
3. **Variant second.** `Diagnostic Campaign - Lower Budget (Windows).bat`.
   The banner says `LOWER-BUDGET VARIANT` before anything starts; if it
   does not, you are in the wrong launcher. Take its first Zone.
4. **The question to hold in mind** is not "is it quieter" — it will be.
   It is whether the *rooms* feel worth walking through with a third of
   the content taken out of them, since there are also more of them.
5. `--list` at any point shows both slots side by side, with their
   folders.

To go back to a campaign later, use the launcher that made it. The
marker will tell you if you picked the wrong one.

---

## 4. Selecting the variant turned out to need two fixes

Your note was that separate save folders alone do not select quieter
mode. They did not, and the switch as first wired did not either.

**The band was being set where nothing reads it.** `preview_constraints`
narrows `constraints["zone_budget"]`, but both `fallback_zone_attempt`
and `generate_zone_validated` read `request.campaign.zone_budget`;
the constraints entry is the same fact spelled for a prompt. A Zone
asked for 72% of the band came out at **917 against a 648–792 band** —
the baseline size. That is the filter-only arm wearing the variant's
name: the families narrowed and their share handed straight back. Now
the band is set before the request is built, so the whole constraints
block derives from one consistent number and a live Epsilon would be
told the budget it will be judged against.

**And then it crashed at the small end.** `CampaignContext.zone_budget`
is bounded `ge=ZONE_BUDGET_MIN` (200), and at prototype scale a Zone's
budget *is* that minimum — so 72% of 200 is 144, the request could not
be built at all, and the failure was a `ValidationError` inside the
generation task with a client waiting for a `ZONE_READY` that never
came. It is clamped to the floor now, and **said out loud per Zone**,
because a clamp that bites leaves the families narrowed and the band
unchanged, which is the filter-only arm again.

Both were found by tests, not by reading.

---

## 5. Stations: the actual counts

You asked for the real station differences rather than activity-room
counts standing in for them. They are different questions — a station
exists only where a room's footprint reaches `STATION_ROOM_AREA`, so the
number of rooms holding an activity says nothing about how many stations
there are or which start broken.

`godot-room-contract` now builds **five real manifests of each variant**
and counts the `WarpStation` nodes that come out:

| | composed | rooms | with an activity | stations | broken | working |
|---|---|---|---|---|---|---|
| baseline | 5 of 5 | 109 | 96 | 49 | 39 | 10 |
| lower-budget | **2 of 5** | 46 | 27 | 20 | 12 | 8 |

Those totals are over different numbers of Zones, so **per composed
Zone** is the comparison that means something:

| per composed Zone | rooms | with an activity | stations | broken | working |
|---|---|---|---|---|---|
| baseline | 21.8 | 19.2 | 9.8 | 7.8 | 2.0 |
| lower-budget | 23.0 | 13.5 | 10.0 | 6.0 | 4.0 |
| **difference** | **+1.2** | **−5.7** | **+0.2** | **−1.8** | **+2.0** |

**A variant Zone has about the same number of stations and fewer broken
ones** — that is the station consequence, and it is the benign
direction: fewer repair-gated stations, more that simply work. Rooms per
Zone are up, consistent with the +17 measured over twelve cases, and
5.7 fewer of them per Zone hold anything to do.

**No station in either variant starts broken in a room with no activity
to repair it**, and the entrance and exit stations are whole in both. In
the engine that is one expression: a station is created broken only when
its own room's `activities` array is non-empty, and its `repair_room` is
that same room, so the promise cannot be made without something behind
it. It is asserted on real Zones anyway.

**The finding is the first column.** Three of five variant manifests are
**refused by the engine's layout router**, every one the same shape:

> `branch room 'c018' off 'c017' could not be placed clear of the 19
> room(s) already standing`

Baseline: none refused. I ruled this out as an artefact of my own
instrument by reversing the census order — identical numbers — and all
five variant manifests had already been **accepted by `validate_zone`**
on the bridge. So this is the two sides disagreeing, not a bad manifest.
Live, such a Zone costs a repair round rather than being fatal; but it
is a real quality difference, and it points the same way the +17 rooms
does.

---

## 6. Both modes through the real client and bridge

`make godot-integration` and the new `make godot-integration-quiet` run
the whole loop against a live bridge. **Both pass.**

Two limits worth stating plainly:

- At the harness's **prototype scale**, the variant's band is clamped to
  the contract floor, so what that run exercises is the **family
  narrowing, not the lower band**. The bridge logs that per Zone.
- **Default scale is not available in that harness** — it fails there
  for the *baseline* too. Both arms trip the same scale assumption
  (`FAIL: 30 locations scouted`) and then time out waiting for a
  verdict: the variant on `zone_001`'s layout, the baseline on the
  replacement Zone's. So neither mode has an end-to-end client/bridge
  run at 450 locations, and that is a property of the harness rather
  than of either arm.

Default scale is covered instead by Python — `test_quiet_integration.py`
generates and accepts a default-scale variant Zone through the same
provider and the same `validate_zone` — and in the engine by the station
census above, which builds real default-scale manifests.

---

## 7. The startup failure, re-run rather than waived

Dess reported `test_startup`'s second-bridge case failing and set it
aside as reproducing on the earlier head. Re-run here on the combined
tree, as you asked:

| | |
|---|---|
| the case alone, 5× | **5 passed** |
| the whole file, 3× | **14 passed, 3×** |
| inside the full suite | passed, twice |

It does not reproduce. **Not waived — and the mechanism that would
produce it is named:** `TEST_PORT` is a fixed constant
(`C.BRIDGE_PORT + 40`), and the case binds `TEST_PORT + 1` and then
spawns a real second bridge at it. Two pytest sessions on one machine,
or any leftover process on 38331, collide and the case fails for a
reason that has nothing to do with the code under test. That is a real
weakness in the test's port allocation. I have **not** changed it — a
test-infrastructure change was not in scope and fixing it blind could
mask a genuine failure — so it is on the list below as a decision for
you.

---

## 8. Verification

_§8, after the run_

---

## 9. Left for you

- **Whether the variant is worth pursuing at all**, given that it cannot
  currently be the matched comparison you asked for. The honest options
  are (a) review it as a lower-budget variant and judge it on those
  terms, (b) decouple the three derivations in the composer so rooms and
  enemies hold still — a real generation change, not an experiment, or
  (c) drop it.
- **The three refused-by-the-router Zones.** Worth a decision: is a
  variant that needs a repair round on 3 of 5 Zones acceptable for a
  review build?
- **`test_startup`'s fixed port**, per §7.
- **The budget shape**, still unselected. Nothing here enables a policy.
- Everything still open from the previous page: your save, stair
  comfort, the unmounted target look, whether the F5 schematic is the
  map.

**Waiting on Dess:** the `_accepts` correction you asked them for.
Nothing in this page depends on it — every number here comes from the
engine census, the live loops, or my own Python integration tests, none
of which go through `quiet_preview.py`. But the **12 of 12 accepted**
figure in their report does, and my 3-of-5 router refusals point the
other way, so their re-report is worth reading beside this.
