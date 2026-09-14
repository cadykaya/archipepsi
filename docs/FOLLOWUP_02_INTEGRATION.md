# Follow-up 02 — integration: the lower-budget generation variant

**Branch:** `claude/archipepsi-echoes-continuation-b1adno`
**Merged from the bridge lane:** `fdac6ab`, then `fc7b6fb`
**Tested revision:** `a820ca3` — every number in §8 is that
tree, clean, with nothing else running against it.

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

Those totals are over different numbers of Zones — **five baseline
builds and two variant builds**, the ones that placed — so **per
composed Zone** is the comparison that means something. The
denominators are what they are; these averages describe successful
builds only and say nothing about the three that did not place:

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

**The finding is the first column** — and it belongs to a different
stage, which I reported badly the first time.

**Two stages, two questions.** Bridge validation asks *is this proposal
structurally sound* — the right Checks, only offered shells, a budget
inside its band. The engine's layout router asks *can these rooms be
physically placed without overlapping*. A proposal can be perfectly
sound and still have no arrangement that fits. So **12/12 validated and
3/5 router-refused do not contradict each other**, and my earlier
framing of "the two sides disagreeing" was wrong.

| stage | what it asks | baseline | lower-budget |
|---|---|---|---|
| bridge validation (`validate_zone`) | is the proposal sound | 12/12 | **12/12** |
| engine layout router (`ZoneBuilder`) | can the rooms be placed | 5/5 placed | **2/5 placed** |

All three refusals are the same shape:

> `branch room 'c018' off 'c017' could not be placed clear of the 19
> room(s) already standing`

Not an artefact of my instrument: reversing the census order gives
identical numbers. The third stage — what happens live, when ordinary
bounded recovery gets its turn — is §6a, and it is the one that
matters.

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

## 6a. The bounded default-scale live check

`make godot-integration-variant-live`. **One Zone**, default scale,
variant on, through the machinery that already exists — no 450-Check
campaign, no solver. Nothing is arranged: the campaign starts fresh and
takes the Zone it is given, which at this scale with this flag is the
same `zone_001` the offline census measured as a router refusal. No seed
was chosen, `0.72` was not touched, no validation was loosened, and the
router was not rewritten.

**The band is genuinely lower, not clamped.** From the bridge's own log:

```
QUIET GENERATION: zone zone_001 asks for 720 of the 1000 this campaign
would normally spend, and offers switch_sequence, target_challenge
```

720 of 1000. The target fails if that line is absent or if the clamp
warning appears, so a run that measured the family narrowing cannot be
reported as a run that measured the variant.

**What ordinary bounded recovery did: it never started.**

| | |
|---|---|
| layouts the **router** refused at build time | **1** |
| layouts the **bridge** refused after certification | 0 |
| Zones that spent every attempt | 0 |
| outcome | **blocked at the router** — not exhaustion |
| leave / resume | not reached; entry never succeeded |

**Why, exactly.** `ZoneController.setup` has two ways to not produce a
playable Zone, and only one of them has a recovery:

- a **certification** refusal happens *after* a successful build — the
  client measures what it placed, sends `layout_result`, the bridge
  refuses it, the Zone is composed again, and `MAX_LAYOUT_REFUSALS`
  bounds the loop. This works.
- a **router** refusal happens *during* the build — `ZoneBuilder` cannot
  place a room clear of the others, `setup` records `layout_failed` and
  returns. **Nothing is sent.** The bridge never learns, no verdict ever
  arrives, and the bounded recovery never begins. `layout_failed` has no
  consumer anywhere in the engine.

**This is pre-existing and not the variant's doing.** A router refusal
is the same dead end on normal generation; the variant reaches one often
(3 of 5) where the baseline reaches one rarely (0 of 5). Fixing it means
giving the client a way to tell the bridge "I could not lay this out",
which is a protocol change across both lanes — **not made here**, and
not something to decide while you are away.

**So the variant is parked, with its reproduction.** The target passes
by *reporting* the blocker rather than by hiding it, and says so in its
output; it will also pass if a Zone ever plays through, and fails only
on an outcome with no cause. `make godot-integration-variant-live`
reproduces it in about a minute.

**Recommendation: not yet for owner play at default scale.** The
ordinary diagnostic replay is unaffected and stays available.

---

## 7. The startup intermittency — open

Dess reported `test_startup`'s second-bridge case failing and measured
it as **intermittent**: 2 of 3 full-suite runs in their container, 5 of
5 passing in isolation. Re-run here on the combined tree:

| | |
|---|---|
| the case alone, 5× | 5 passed |
| the whole file, 3× | 14 passed, 3× |
| inside the full suite | passed, every run |

**It does not reproduce here, and that does not resolve it.** Passing in
one container says nothing about the one it failed in; an intermittent
failure that two environments disagree about is still an intermittent
failure. **Not waived.**

I had previously named `TEST_PORT` being a fixed constant as the
mechanism. That was a **hypothesis**, not an identification — I never
observed a collision, only reasoned that one could occur — and it is
recorded as such. **No decision about test ports is being asked of
you**, and nothing was changed.

**Status: open.** It needs to be caught in the environment where it
actually fails, with whatever holds the port at that moment identified,
before anyone can say what it is.

---

## 8. Verification

One run on a clean tree at **`a820ca3`** (`0 dirty`).
**29 targets, 29 green, final exit 0.**

| | |
|---|---|
| bridge | **1414 passed** (130 s) |
| apworld | **39 passed, 627 subtests** |
| schemas | **131 passed** |
| Godot | **26 targets**, including all three integration loops |

The parked probe is one of them, and it is green because it reproduced
its blocker and said so — 1 router refusal, 0 certification refusals, 0
exhausted, band at 720 of 1000. §6a.

| | |
|---|---|
| `godot-physics` | OK (**68 checks**) |
| `godot-traverse` | OK (**23 checks**) |
| `godot-reload` | OK (**2**, then **18 checks**) |

Carried forward from the engine work earlier in this batch, unchanged:
22 SEALED sockets and 44 passable ones measured on the assembled Zone,
every SEALED one solid; **15 of 27** SHOT elements mounted on a wall;
29 activities audited with **0 structural failures**.

The variant loop's log shows the clamp doing its job rather than hiding:

```
WARNING QUIET GENERATION: zone zone_015 asked for 144, which is below
the contract floor of 200. Clamping to the floor -- this Zone's band is
equal to the baseline's, so it is filter-only, NOT the lower-budget
variant. The comparison wants a campaign at default scale.
```

### Two failures from an earlier attempt, and what they were

The first attempt at this run reported two, and one was mine:

- **`test_ci_runs_every_godot_suite_the_makefile_defines`** — a real
  gap. `godot-integration-quiet` existed as a Makefile target and
  nowhere in CI, so the variant loop would have been green locally and
  unwatched on every push. Fixed, and it is in the run above.
- **`test_a_playtime_record_says_which_build_played_it`** — `tree:
  clean` against `tree: dirty`. I was editing this page while that run
  was in flight, which changed `build_metadata()` under it. My own
  race, not a defect; the run above was started on a committed tree and
  nothing touched it.

### What this run does not establish

- **Neither mode has an end-to-end client/bridge run at default
  scale.** §6 — the harness fails there for the baseline too.
- **The variant was exercised live only with its band clamped**, so the
  loop above proves the family narrowing survives a real campaign, not
  the lower band.
- **Windows.** No `cmd.exe` here; neither `.bat` has ever been executed.
  Both delegate every decision to Python, where it is tested — the new
  one adds only `--quiet` in front of the caller's own options.
- **Five Zones per arm** is a sample, not a certificate. The 3-of-5
  router refusals are a strong signal, not a rate.
- **The live check is one Zone**, bounded on purpose. It establishes
  that the band really drops and that this refusal has no recovery; it
  does not measure how often a variant campaign would stall.
- **Your Zone.** Nothing here reproduces `.diagnostic-582e954`, and
  nothing has touched it.

---

## 9. Left for you

**The variant is parked, not abandoned.** It is an opt-in experimental
candidate, normal generation is untouched, no budget policy is selected,
and the ordinary diagnostic replay works exactly as it did — so nothing
here waits on a decision from you.

When you want to decide:

- **The router dead end (§6a)** is the thing standing between the
  variant and owner play. It is *not* the variant's fault and fixing it
  helps normal generation too, but it needs a way for the client to tell
  the bridge "I could not lay this out" — a protocol change across both
  lanes. I did not make it, and it is the one I would want your go-ahead
  on before either lane starts.
- **Whether the variant is worth pursuing at all**, given it cannot
  currently be the matched comparison. Honestly: (a) review it as a
  lower-budget variant on those terms once §6a is unblocked, (b)
  decouple the three derivations in the composer so rooms and enemies
  hold still — a real generation change, or (c) drop it.
- **The budget shape**, still unselected. Nothing here enables a policy.
- Everything still open from the previous page: your save, stair
  comfort, the unmounted target look, whether the F5 schematic is the
  map.

**Not asking you anything:** `test_startup` (§7) is an open
intermittency for whoever next reproduces it, not a policy question.

**Dess's `_accepts` correction is integrated** (`fc7b6fb`). Their two
rejection controls are retained, and I re-verified independently that
they are decisive rather than decorative: the same two sabotaged Zones
they build pass the old argument set and are refused by the corrected
one. The re-reported **12/12 is now a measurement** — and §5 explains
why it never contradicted the 3-of-5 router refusals.
