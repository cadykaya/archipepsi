# Item D — a lower-budget generation variant, and the policy it needed

> **Status, owner ruling 2026-09-14.** Kept as an **opt-in experimental
> candidate**. Normal generation is unchanged and no permanent budget
> policy is selected. This is a **lower-budget generation variant** — it
> composes different rooms and comes out `+17` rooms and `+27` enemies —
> **not "the same level with only the drills removed"**. The strictly
> matched no-compensation comparison **remains incomplete**; §4 records
> exactly what would have to change to complete it.
>
> **Revision 2 (2026-09-14)** corrects the acceptance column, which the
> first revision reported wrongly. See §2a.

**Dess, bridge lane — 2026-09-13.** Follow-up 02 item D, on the current
Production tree. Integration and screenshots are Prod's.

**Two corrections to how I started, recorded because they changed the
work.** Before the brief arrived I began from the chat summary alone and
(a) picked the wrong two families — I reasoned `switch_sequence` and
`target_challenge` were the drills, when the brief and
`fallback.ACTIVITY_KINDS` both name **`timed_run` and
`pressure_routing`** — and (b) designed the variant to declare a budget
equal to whatever it happened to hold, which is exactly the
"normalise each output into passing itself" the brief forbids. Both were
discarded. Nothing from them is in this delivery.

---

## 1. What the experiment needed that did not exist

`tools/family_retirement.py` already measured the naive change and the
note in `fallback.ACTIVITY_KINDS` states the conclusion: the composer
picks a family by `kinds[(guard + len(acts)) % len(kinds)]`, so removing
two of four removes nothing. Re-run here on the current tree, twelve
default-scale Zones:

> **161 retired activities, 176 extra of the families that stay.**

That note ends *"the retirement needs a policy choice about what fills
the budget — and that choice is the bridge lane's to make."* That choice
is this item.

**The policy: retirement is a REDUCTION, not a REALLOCATION.** The share
a retired family held is not handed to the survivors, to enemies, to
more rooms or to a topped-up score. It is not spent. A quieter Zone is a
Zone that holds less; a preview whose point total matched the baseline
would be measuring nothing.

The share was measured, not guessed — over the same twelve cases the
retired families hold **27.4% mean** of Zone content value (median 27.8%,
range 22.8–32.8%). One constant, derived once, applied to every case:
`PREVIEW_BUDGET_FRACTION = 0.72`, so a 1000 band becomes 720. Deriving a
budget per Zone from that Zone's own content would make every Zone pass
by construction and leave the acceptance column carrying no information.

---

## 2. The results, on the twelve cases

```
                            baseline   filter-only       preview
  -----------------------------------------------------------------
  rooms                          248           248           265
  activities                     343           358           177
  enemies                        411           411           438
  Checks                         180           180           180
  rooms with a puzzle            223           224           154
  raw score                    10934         10892          7879
  accepted                     12/12         12/12         12/12

  pressure_routing                86             0             0  <- retired
  switch_sequence                 85           180            86
  target_challenge                97           178            91
  timed_run                       75             0             0  <- retired

  rooms by activity count
    0 activities                  25            24           111
    1 activity                   115           102           142
    2 activities                   96           110             1
    3 activities                   12            12            11

  SUBSTITUTION
    filter-only  161 retired, +176 of the families that stay,
                 enemies +0, rooms +0, score -42
    preview      161 retired,   -5 of the families that stay,
                 enemies +27, rooms +17, score -3055
```

**The thing the owner asked against is gone**: `+176` becomes `-5`. The
score falls 28%, which tracks the measured 27.4% share — the removed
content stayed removed.

**Acceptance — see §2a.** The first revision of this report claimed
"12/12 accepted" on a check that could not fail. The number survives the
correction, but the earlier claim did not deserve to be believed.

---

## 2a. The acceptance column was not measuring acceptance

Owner finding, and it is correct. `tools/quiet_preview.py::_accepts` had
three defects, all of which flattered the result:

| defect | effect |
|---|---|
| `expected_zone_id=z.zone_id` | read off the **generated Zone**, so the check compared the output with itself and could never fail |
| `allocated_location_ids=list(z.reward_location_ids)` | same — an allocation mismatch was undetectable by construction |
| `[e for e in errs if "shell" not in e]` | a whole class of real refusals discarded to keep a column clean |

So "12 of 12 accepted" was very nearly content-free, and I reported it as
evidence. It is now judged against the **originating request**, with the
same argument set `playtest.py` and `replay_archive.py` use — the id the
request asked for, the locations it allocated, the affordances and
capabilities it granted, and the shells it actually offered via
`shells.offer_of(request)`. **Nothing is filtered.** The tool also prints
why any Zone was refused.

**Re-reported honestly: still 12 of 12, and now the number means
something.** No Zone in any arm is refused against its own request.

**Two controls prove the check can say no**, because a corrected check
that still cannot fail is the same vacuous check in a new costume:

- a chamber naming a shell the request never offered → refused;
- a Check the request never allocated → refused.

Both fail if `_accepts` is reverted to its old form — sabotage-verified.
The first attempt at the shell control was itself wrong: it smuggled in
`shell_corner_left`, which the default catalogue **does** offer (twelve
legal ids), so it proved nothing. It now asks the offer what is absent
rather than assuming.

---

## 3. Station consequences, inspected as asked

A solved activity switches on the broken station in its own room
(`zone_controller._repair_station_for`), so **a room with no activity can
host no repair**.

| arm | rooms that can host a repair |
|---|---|
| baseline | 223 of 248 |
| filter-only | 224 of 248 |
| **preview** | **154 of 265** |

**The preview leaves 69 fewer repairable rooms, and rooms with zero
activities rise from 25 to 111.** This is a visible prototype change to
station availability, reported rather than backfilled with another
chore. **For Prod:** in the quieter mode a repair-gated station must not
be placed in a room with no activity, or it advertises a repair that
cannot happen. The tool prints the per-arm counts; the engine lane owns
where stations go.

---

## 4. The boundary — the matched comparison is INCOMPLETE

The policy removes the family substitution. It does **not** hold rooms
and enemies constant: the preview arm is **+17 rooms and +27 enemies**.

That is not a choice made here. `fallback._build_to_budget` derives three
separate quantities from the one `budget` number — the room envelope
(`C.zone_room_envelope`), the enemy caps (`C.max_enemies_per_zone`,
`C.max_brutes_per_zone`) and the per-room `soft_cap` that spreads content
across rooms. Lowering the band necessarily loosens the per-room cap and
buys more rooms and more enemies with what it saves. **Holding them
constant means decoupling those three derivations in the shipped
composer**, which is a generation change this experiment may not make.
Delivered with the difference reported instead, and **the strictly
matched no-compensation comparison is recorded as incomplete rather than
claimed.** What this variant demonstrates is narrower than what was
asked: the family substitution is gone, the room and enemy compensation
is not.

The same coupling has a second consequence: the provider seeds its rng
with the budget (`random.Random(f".../{n}/{budget}")`), so the preview
arm **does not compose the same rooms** as the baseline. Room-level
content is matched in the filter-only arm and is not matched in the
preview arm. That is why all three arms are reported rather than two.

---

## 5. One defect found and fixed on the way

`constraints["activity_kinds"]` has always been on the request and the
fallback provider always ignored it — the offer and the thing offered
from were two spellings of one fact that nothing compared. **They also
disagree**: the request lists the schema's order, the module lists its
own, and the picker is order-sensitive. Reading the request's list
directly moved the played Zone's digest `fe2b014761fbb449` →
`d3f1025fedf2dff2` **on a request that had narrowed nothing** — a
generation change smuggled in as a refactor.

I caught that because I had written "the digest does not move" into a
comment and then checked it. It did. The fix: the offer says *which*
families are permitted; the module keeps saying in what order it cycles
them. An un-narrowed request is now bit-identical, digest restored to
`fe2b014761fbb449`, and a control asserts it against four Zones rather
than one.

---

## 6. Scope kept

- **Normal generation unchanged** — proven by the digest, not asserted.
- **Old saves untouched.** `timed_run` and `pressure_routing` remain in
  `ActivityKind`, remain buildable, and a committed Zone holding one
  still loads and still validates. Retired from the offer, not from the
  game. Plate trigger/linger mechanics untouched. No retired race was
  translated into a switch sequence.
- **Nothing is enabled.** The preview is two keys on a request. No
  campaign setting changed; `CampaignScale.zone_budget` is untouched.
- **No new contract.** `constraints` was already caller-settable.

**Tests:** `make test` — **1520 passed, 6 skipped, 0 failed** on the
current tree.

**The startup-test failure stays visible rather than waived.**
`test_startup.py::test_a_second_bridge_says_so_in_words_rather_than_a_traceback`
is **intermittent**, not fixed: it failed 2 of 3 full-suite runs in this
container, passed the third, and passes **5 of 5 in isolation**. It also
reproduces on the engine head unmodified, checked in a worktree of that
commit — but that is context, not a reason to dismiss it. The symptom is
binding `127.0.0.1:38331` while no listener and no bridge process is
visible, which points at port contention with another test in the same
run rather than at this work. **Unresolved, and it should be re-run on
the combined tree during integration.**

`check_packet` green. Seven controls, the load-bearing ones
sabotage-proven.

---

## 7. For Prod, and a replay order

**Run the comparison:**

```
cd bridge && python3 -m tools.quiet_preview --zones 12
cd bridge && python3 -m tools.family_retirement --zones 12   # the baseline it builds on
```

**Build a preview Zone through the real path** — it is an ordinary
request with two keys set:

```python
from archipepsi_bridge import quiet
req = req.model_copy(update={
    "campaign": req.campaign.model_copy(
        update={"zone_budget": quiet.preview_budget(req.campaign.zone_budget)}),
    "constraints": quiet.preview_constraints(req)})
```

**Separate diagnostic slots, and do not touch the original save:**

```
ARCHIPEPSI_SAVE_DIR=./.diagnostic-saves/normal  ./start-archipepsi.sh
ARCHIPEPSI_SAVE_DIR=./.diagnostic-saves/quieter ./start-archipepsi.sh
```

**Short comparison route:** first Zone of each slot — arrive, cross to
the first branch, use one return, reach the exit. The difference to look
for is per-room: the same walk with roughly half the activities in it,
and many more rooms holding none.

---

## 8. Blocked, and what is for you

- **Screenshots are not delivered.** There is no Godot binary in this
  container, so nothing renders here. Prod integrates and captures.
- **Whether quieter is better is not claimed.** Fewer activities is not
  automatically more fun; the experiment exists so you can judge.
- **Choices left for you:** whether to adopt the policy at all; if so,
  whether `0.72` is the right fraction; and whether the `+17 rooms /
  +27 enemies` side-effect is worth the decoupling work in §4 to remove.
  None is decided here, and normal generation stays as it is until you
  say otherwise.
- Your exact Whistle crossing still waits for the private save; nothing
  here depends on it.
