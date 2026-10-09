# Where Archipepsi stands — independent audit, 2026-10-09

**Read-only. No code changes, merges, PRs, watchers or check-ins. No work assigned.**

Revisions audited (all pinned at the time of reading):

| Thing | Ref | SHA |
| --- | --- | --- |
| G1 art candidate | `review/impact-relay-g1-art` | `23f8fd00` |
| G1 baseline | `review/impact-relay-g1` | `21b5fb2f` |
| G0 lab | `review/impact-lab-g0` | `c45086e1` |
| Crossing D (readable) | `review/crossing-d-readability` | `0e54caab` |
| Campaign diagnostic build | `claude/campaign-diagnostic-build-gwgp6t` | `bd906f44` |
| Launcher | `claude/dev-launcher-mvp-6mlaoc` | `fecff7c1` |
| Build standard | `claude/build-package-standard-nvkv55` | `24354078` |
| Batch 065 art | `claude/archipepsi-art-bloom-g1-2026-10-08` | `ce4eb4ec` |
| **`main`** | `main` | **`fb040c22`** — the initial commit, one file |

**Evidence labels, used throughout.** `[source]` = read in the committed
code or config. `[reported]` = a claim in someone's report, not
independently checked. `[reproduced]` = I ran it here. `[CI]` = read from
GitHub Actions logs. `[inference]` = my reasoning over the above.
**No Godot or Blender binary in this environment**, so no claim about
engine behaviour is reproduced; those are `[reported]` or `[source]`.

---

## Verdict first

**The machinery is in better shape than the project around it.** G0/G1 are
careful, well-measured work and their own reports are unusually honest
about what they do not prove. The risk is not in the rooms. It is that
**the rooms Skyiah likes and the artefact that could ship are two
different products**, and almost nothing has crossed between them.

Nothing I found should stop the next playtest. Two things should change
*before* it: which build gets played first, and knowing that Crossing D
still enforces the old anti-skip rule.

---

## 1 · The single most consequential fact: the review rooms are not the game

`[source]` Crossing D's own header says it plainly
(`godot/scripts/content/crossing_d.gd:1-13`):

> **A comparison build for review, not a Zone and not the campaign.** It
> owns what only a launcher has — the player, the HUD, a pause menu,
> checkpoints and a session tally … isolated before any connection exists
> (`ReviewIsolation`): no bridge socket, no campaign, no save.

`[reproduced]` The content registry the generator reads
(`godot/content/registry/authored_art.json`, 22 entries) contains **no**
entry matching `impact`, `relay`, or `crossing`. The only new room in it
is `shell_concourse_pier`, still `review: pending` — so still not
offerable. `[source]` `godot-impact-relay` is its own Makefile target
(`Makefile:552`), described as "the Impact Relay (G1), **isolated**, no
enemies".

`[inference]` So Crossing D, Impact Lab and Impact Relay are bespoke
hosts entered *instead of* `Main.boot()`. They are not shells, the
generator cannot pick them, and nothing a player does in them touches a
save or a Check. Three months of the most interesting design work sits
outside the shippable artefact, by construction.

**Why this matters more than it looks.** The development sequence says
*make exploration and rooms enjoyable*. G1 does that — for one
hand-authored room. The thing that ships is the **generator**, and the
generator has learned nothing from G0/G1: not a shell, not a part, not a
constant. Polishing bespoke rooms is a good way to *discover* what is fun
and a poor way to *deliver* it. **This is the thing I would challenge
hardest in the current plan.**

This is not an argument for integrating them now. It is an argument for
deciding, explicitly, which of the two products the end-of-2026 release
is — because right now the work is funding both.

## 2 · Which G1 build to play first — the opposite of the obvious order

`[CI]` This is the finding most likely to change what you do tonight.

| PR | Build | PR gate (15 min, no Godot) | Integration (30 min cap) |
| --- | --- | --- | --- |
| **#27** | **G1 baseline** `21b5fb2f` | **FAILURE** (3m 02s) | **FAILURE** (4m 35s) |
| **#28** | **G1 art candidate** `23f8fd00` | **SUCCESS** (3m 10s) | **CANCELLED** at 30m 18s |

`[CI]` PR #27's integration job did **not** time out — it died at the
`Full Python suite` step (`make test`, `Makefile:19`, exit 2) after 3m 30s:
`1 failed, 2307 passed, 2 skipped, 627 subtests passed`. The failure is
`test_packaging.py::test_every_bundled_binary_is_first_party_or_licensed`
— sixteen files under `godot/candidate/crossing_kit/` are neither
first-party nor registered in `assets/LICENSES.json`.

`[inference]` Two consequences:

1. **The G1 baseline's Godot suites have never run on CI at all.** The job
   stops before them. Every suite result quoted for `21b5fb2f` is local
   and unreproduced.
2. `[reproduced]` The art candidate's diff **adds `assets/LICENSES.json`**
   (`git diff review/impact-relay-g1 review/impact-relay-g1-art`), which
   is why its gate is green. The candidate silently fixed the baseline's
   only real test failure, and its report does not mention doing so.

**So the "art-integrated candidate" is the better-evidenced build and the
"mechanics baseline" is the red one.** If you only play one, play the
candidate. The mechanics are measured identical between them
(`[reported]`, 40/40 throws, 2,178 J, same strike spread), so you lose no
mechanical fidelity by doing so.

## 3 · A correction to my own first reading

`[reproduced]` I initially measured a **second** failing test on both G1
branches — `test_bomb_fixture.py::test_the_committed_fixture_matches_its_generator`
— and traced it back through five review branches to 2026-09-28, which
looked like a guard that had been red and unnoticed for eleven days.

**That was my environment, not the repository.** `[CI]` CI runs Python
**3.11.16** (`pr.yml:33`, `integration.yml:40`) and reports this test
passing; I ran 3.13 with newer pydantic. `[reproduced]` The difference is
one notification (`coin_received`) that the generator emits under 3.11 and
not under 3.13.

Recording it because it is the exact trap this audit exists to catch, and
I walked into it first: **a local run that disagrees with CI is not
evidence until the versions match.** The G1 report's claim — one failing
Python test, the licensing one — is **accurate**.

One small discrepancy stands: the G1 report says "the Python suites:
2,142 pass". `[CI]` CI reports 2,307; `[reproduced]` I get 2,266. The
number in the report matches neither. Cosmetic, but it means nobody
checked it.

## 4 · The branch stack, measured

`[reproduced]` It is not a pile — it is a **chain of ten draft PRs**, and
that is both better and worse than "a large unmerged stack".

```
#28 impact-relay-g1-art  → #27 impact-relay-g1    → #22 impact-lab-g0
→ #21 crossing-d-readability → #20 crossing-d-review → #18 concourse-pier
→ #16 0.4-art-catchup → #12 0.4-blindside → #4 echoes-continuation
→ #3 build-inzshp → main
```

Better: the chain is **linear** (verified with `git merge-base
--is-ancestor` at each link), so the candidate at the top genuinely
contains everything below it. There is one head, not twenty-nine.

Worse: `[reproduced]` **`main` is still `fb040c22`, the initial commit
with one file** — `README.md`. Nothing has ever merged. All 27 open PRs
are drafts. The bottom two links have not moved since 2026-08-28 (#3) and
2026-09-20 (#4).

`[inference]` This is not a merge backlog, it is the **absence of a
trunk**. Practical effects: no PR can be reviewed against a stable base;
"is this a regression?" has no reference point; and the three tooling
branches (launcher #24, build standard #25, diagnostic build #29) are
based on the empty `main`, so **none of them shares a tree with the game**
and no single checkout can test a tool against the thing it packages.

## 5 · Release risks, in order

**R1 — The whole-campaign test has not run on CI since 2026-09-27.**
`[source]` `integration.yml` runs 66 `make godot-*` targets in a **single
serial step** (lines 114–181) and then 15 more steps, of which
`make godot-integration` — "Whole campaign, headlessly" — is line 213.
`[source]` `timeout-minutes: 30` (line 34). `[CI]` On #28 that step was
cancelled at 30m 18s. `[reproduced]` Condi's claim that
`godot-rail-zone` is target 33 of 66 is **exactly right**. `[source]` The
fast gate (`pr.yml`) is "schemas, bridge, packet (**no Archipelago, no
Godot**)" — so it can never cover the campaign either.

`[inference]` The structural point is sharper than the timeout: the only
gate that proves the campaign plays sits **behind the slowest step of a
single job**, and the gate that could run on every branch deliberately
excludes Godot. Raising the cap to 90 minutes makes it pass; it does not
make it reachable in under an hour on a branch like this one.

**R2 — The only installable campaign build cannot reach Archipelago.**
`[source]` The diagnostic build (`tools/diagnostic_build/README.md`) is a
genuinely self-contained Windows folder — Godot export, CPython 3.12
embeddable, bridge, registry, a Win32 starter that manages both processes
in a job object. It is real work and it answers "can a player run this
without installing Godot or Python" with yes. But `[source]`
`ACCEPTANCE.md:53-55` is explicit: *"The real Archipelago connection. The
bundled bridge runs in mock … not a server. Real Archipelago play still
needs the checkout."* It is prototype scale, ~10 Zones, ~30 Checks,
`--ap=mock`, offline.

`[inference]` For a game whose premise is Archipelago multiworld, the
installable artefact plays a fixture. That is a **release-scope question
for you**, not a defect: a single-player "station crawl" first release is
a legitimate answer, and so is "not until real AP packages". But it should
be chosen rather than discovered.

**R3 — The licensing gate blocks two jobs for a bookkeeping reason.**
Sixteen candidate art files need a line in `assets/LICENSES.json`. It is
the cheapest red thing in the project and it is currently the reason the
baseline has no Godot evidence at all. Already fixed on the art candidate.

**R4 — The launcher is proven on real builds but tested on miniatures.**
`[reproduced]` 50 launcher tests pass in 0.45 s — against fixtures of
**17–36 KB** standing in for the real 19.5 + 20.0 MB two-part packages.
`[reported]` Prod did exercise the real path under Wine, and `[reported]`
it installed and launched Crossing D on your actual PC, which is better
evidence than any test. `[inference]` The gap that remains is the
*campaign* package, which is a different shape (starter `.exe` + Python
runtime, not a bare Godot export) and lives on a branch the launcher has
never shared a tree with.

## 6 · What only appears to work because the tests are narrow

**N1 — Crossing D's combat passed 137 automated checks and you hated it.**
`[reported]` `docs/reports/2026-10-02-crossing-d-review.md:84`: *"137
checks with the fight … The Yard's three enemies were put down at
baseline numbers in 18 s of play."* `[reported]` Line 143-147: saves, HP,
damage, enemy AI, movement constants and the dash were **explicitly not
changed** in that revision.

`[inference]` The probe measured that the fight **resolved** — enemies
die, stay in the Yard, the player survives, the route completes. It never
measured engagement, reaction, or decision. Your judgement and the 137
checks are not in conflict; they are about different things. This is the
clearest case in the project of a measurement that cannot reach its
conclusion, and it is worth saying out loud because the same probe shape
is now used for G1.

**N2 — "No base-kit reach to the ledge" is arithmetic, not a probe.**
`[source]` `godot/tests/impact_relay_check.gd:518-540` computes
`WEIGHT_SIZE.y + CRATE_SIZE.y + jump` and compares it to `LEDGE_TOP`.
It assumes the only stackable objects are those two, stacked flat, with
one jump. It is almost certainly right, and it is not a measurement.
`[inference]` Low-stakes, and under your new skip ruling a base-kit route
to the ledge would be *legal* anyway — so this guard is now protecting a
rule you have relaxed.

**N3 — "Reachable" means "resting on a walkable surface", not "the player
can get to it".** `[source]` `impact_relay_check.gd:1033-1053` fires one
downward ray and requires a walkable collider within 1 m, inside the
room. There is no path check. `[inference]` A body at rest inside the
vault before the shutter breaks would satisfy it. The report's own
recovery line ("a weight in the vault stays there") shows they knew; the
word "reachable" in the results table is doing more work than the
function does.

**N4 — "No escape" tolerates being under the floor.** `[source]`
`impact_relay_room.gd:526-533`: `inside()` is the union of five floor
rects **grown by 0.8 m**, with `y` from **−2.0** to ceiling + 1. So a
body 1.9 m below the floor, or 0.8 m through a wall, counts as inside.
`[source]` The 480-swing sweep records the *highest* point reached (6.0 m)
and never the lowest. `[source]` `_physics_process` recovery sends
**`ManipulableBody`** home — not the player; I found no player
out-of-bounds recovery in this room.

`[inference]` This is the one narrow test I would not wave through. 480
swings is real breadth, and the pass criterion has 0.8 m of lateral slop
and 2 m of vertical slop under it. Whether that matters depends on whether
anything down there exists to stand on — which the test cannot tell you,
because it accepts the position either way.

**N5 — What the plate will not do.** `[source]`
`impact_lab_parts.gd:8-13`: *"**OBJECTS, NEVER THE PLAYER** … it never
looks at a `Player`."* So standing on the plate does nothing. Worth
knowing before you try it and read the non-event as a bug.

## 7 · A live policy conflict your new ruling creates

`[source]` Crossing D gates the swing tether to the Courtyard and
**confiscates it mid-swing** on exit (`crossing_d.gd:214-215`: *"taken
away — mid-swing included — the moment they leave it"*). The stated reason
(`crossing_d.gd:14-21`) is the **old** rule: *"the very routes Dess's
brief rules out (a route that needs none of the room's activity is a
defect)"*.

`[source]` G1 does the opposite: *"the swing tether, equipped from the
start"*, working on any surface everywhere
(`impact_relay.gd:8`, `TETHER` at line 32).

`[inference]` Your new direction — skips are legal, an intended sequence
is not sacred — retires Crossing D's justification. Two things follow:
the gating is now unmotivated policy rather than a fix, and **having your
tool yanked away in mid-air is a bad feeling that currently reads as a
bug**. If you replay Crossing D, you will meet the old rule.

## 8 · Condi's six findings, adjudicated

| # | Finding | My verdict |
| --- | --- | --- |
| 1 | The prototype campaign completes local automated tests | **Partly.** `[CI]` It completes nothing on CI — #27 died at the Python step, #28 was cancelled at the cap. Local results are `[reported]` only. |
| 2 | No self-contained player-installable Windows build of the full campaign | **Superseded by her own branch, with a caveat.** PR #29 *is* one. It is prototype-scale and mock-only (R2). |
| 3 | New review rooms aren't integrated into the campaign | **Verified, and understated.** They are not shells at all (§1). |
| 4 | The branches form a large unmerged stack | **Verified, and more precise.** Ten draft PRs deep; `main` is the initial commit (§4). |
| 5 | Remote Godot CI has repeatedly timed out | **Half.** `[CI]` #28 timed out. #27 failed in 4m at the Python step. The commoner failure is a red gate, not a slow one — and fixing only the cap leaves #27 red. |
| 6 | First-release scope needs finalising | **Agreed, and it is the decision everything else waits on.** |

Her CI measurements are the most reliable numbers I checked: the 30-minute
cap, the 66 targets, and `godot-rail-zone` as target 33 all reproduce
exactly. `[inference]` Where I differ is emphasis — she frames CI as a
timeout to raise; the structure (one serial job, campaign test last, fast
gate with no Godot) is the part that will keep biting.

`[source]` Note: there is **no committed release-readiness audit** in the
repository. `tools/diagnostic_build/README.md` cites
`reports/release-readiness-audit.md`; that path does not exist on any
branch I fetched. The findings are real; the document is not an auditable
artefact, which makes them hard for anyone else to check.

## 9 · Supposed blockers that are optional or deferrable

- **Campaign integration of the review rooms — deferrable for the
  playtest, blocking for release.** You do not need G1 in a Zone to judge
  whether it is fun. You do need to decide whether it ever goes in one.
- **Approved final music — not a blocker.** Three sketches you enjoyed is
  ahead of where the audio needs to be.
- **The Shunter — deferrable by your own sequence.** It is step 2; G1 is
  step 1 and deliberately enemy-free.
- **Bloom and the art candidates — deferrable.** `[reported]` Mechanics
  measure identical with Batch 065 fitted, so art is a parallel track.
- **Raising the CI cap — do it, but it is not the fix.** One line, and
  the job still wants 70–90 minutes.
- **Registering sixteen art files — trivial, and the highest-leverage
  red thing in the project.** It is the only reason the baseline has no
  Godot evidence.
- **Not deferrable: choosing the trunk and the release scope.** Every
  other sequencing question is downstream of those two, and both are
  yours.

## 10 · The highest-value questions for your next playtest

Play the **art candidate** (`23f8fd00`), not the baseline — §2.

1. **When the crate bounced off, did you know what to try next?** Prod's
   own first question, and the only one that tests whether the machine
   teaches itself.
2. **Did the lever, the plate and the shutter read as one machine, or as
   three props that happen to be wired?** This is the system-interaction
   question your Crossing D note was really about.
3. **Did coming back through the loop feel like the room had changed?**
4. **Try to break the room on purpose.** Stand on the plate (nothing will
   happen — §N5, by design: tell us whether that non-event reads as
   broken). Swing at the roof over the gap. Try to get under the floor.
   §N4 is the one guard I would want your hands on rather than a probe's.
5. **Then replay Crossing D and leave the Courtyard mid-swing** — §7. Does
   losing the tether read as a rule, or as the game malfunctioning?
6. **On combat, when you get to it:** the 18-second three-enemy fight
   passed 137 checks. What would have made it *one* interesting decision?
   A single concrete answer there is worth more than any further
   automated measurement — §N1.

---

### What I did not check

No engine here, so every claim about Godot behaviour in G0/G1 — the 480
swings, the 40/40 throws, the state machines, the Wine runs — is
`[reported]` and unverified by me. I did not read the Bloom study, the
Shunter concept, the SigmaAudio sketches, the GLYPH work, or the
mid-stack 0.4 branches (#12, #16, #18) beyond their position in the
chain. Prioritised correctness and release risk over coverage, as asked.
