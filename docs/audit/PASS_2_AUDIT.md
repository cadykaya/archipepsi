# Archipepsi Design Packet v0.4 — Audit, Pass 2

**Date:** 2026-08-26
**Subject:** `docs/design-packet-v0.4/` — 9 documents, a 5-module tested schema package, and `bootstrap.py`
**Method:** Pass-1's 50 findings re-checked against v0.4, then a fresh hostile read of the new material.

A note on standing: I wrote v0.4. An author auditing their own work catches less than a stranger would, and the pass-1 result is the evidence — the sharpest finding there (B5, the purchasable ending) came from the reviewer who had *not* written the packet. Treat §4 below as the least trustworthy section of this document, and weight a third-party pass on v0.4 accordingly.

---

## 0. Verdict

**v0.4 is buildable.** The four pass-1 blockers are resolved, the eight correctness bugs are fixed, and the generation contract is now executable code with 36 passing tests rather than prose plus an example.

The character of the packet changed. v0.3 was a design document that a coding agent would have had to *interpret*. v0.4 is an implementation contract: `constants.py` holds every gameplay number, `zone.py` and `echo.py` are the Zone and Echo specification rather than a description of one, and the numbers are asserted rather than asserted-to.

**Three real bugs were found in v0.4 during this audit and fixed before publication** (§4). One of them — the finale mode collapse — would have stranded up to five Checks as permanently unreachable content, which is the same *class* of error as pass-1's B5 and arrived by the same route: two rules that are individually correct and wrong together.

Pass-1 status: **31 fixed, 9 decided, 8 documented, 2 open**, and the 2 open items are a LICENSE file and a session-length estimate that cannot exist before something is playable.

**Remaining risk is concentrated in one place:** scope. Even resequenced, the full POC does not fit a single session, which is why §1's success criterion is "advance the slice, never break it" rather than "finish." That reframing is the most important thing in v0.4 and the easiest to quietly ignore under time pressure.

---

## 1. Pass-1 findings — verification

Spot-checked rather than taken on trust. Each claim below was checked against the v0.4 text or the test suite.

**Blockers.** B1 resolved with a pinned checkout *and* a working `bootstrap.py` — verified to parse, run, and fail cleanly on a bad `ARCHIPELAGO_ROOT`. B2 resolved: the ownership table puts all persistent state in Python. B3 resolved by reframing the success criterion and adding the T−60 rule. B4 resolved in `constants.py`, with `SAFE_BASE_JUMP_GAP` derived and test-pinned. B5 resolved: Check 030 excluded from both allocation and shop eligibility, with acceptance tests 22–23 asserting it.

**Correctness.** C1 has its own section in `TECHNICAL_ARCHITECTURE.md` §5, which is proportionate — it is the most misread mechanism in the design. C2's rollback now keys on a locally-checkable condition. C3's bulk guard caps Echo generation at 3 per load. C4 is explicit and has acceptance test 40. C5 gives the literal manifest and forbids hand-rolled packaging. C7 and C8 are done, C8 with a pinned seed value in the tests.

**Verified by execution, not by reading:**

```
36 passed in 0.19s
apex 1.333 · airtime 0.667 · flat reach 4.667 · SAFE GAP 3.0 · MAX STEP 1.0
pepsi dps 17.1 · worst-case zone TTK 25.2s
```

Also verified directly: nested discriminated unions round-trip through `CampaignSave.model_dump_json()` without losing subtype (`PrimaryEcho`, `HitscanDamage`, `ArenaChamber` all survive); `export.py` produces JSON Schema and `constants.gd`; and the schema package imports both standalone and nested inside `archipepsi_bridge` (see §4.3).

---

## 2. What v0.4 does better than the fix list required

**The schema is now the specification, not a description of one.** This is the structural difference between the two versions. Three v0.3 guarantees that were prose promises are now unrepresentable states:

- *"No Echo-gated mandatory traversal"* — there is no field capable of expressing it. Test: `test_zone_has_no_way_to_express_a_mandatory_echo_gate`.
- *"Passive Echoes don't have cooldowns"* — `PassiveEcho` has no such field.
- *"Modifiers need something to modify"* — enforced by composition, not by a validator remembering.

A rule that cannot be violated needs no discipline to enforce.

**`extra="forbid"` everywhere.** An invented field now fails loudly instead of being silently dropped. Without it, a model hallucinating `teleporter_destination` produces a Zone that validates and then quietly does nothing — the worst possible failure, because it looks like success.

**Reject-never-clamp.** v0.3 permitted clamping "otherwise semantically valid" numbers. A clamped Zone is one nobody designed, and it corrupts the generation archive that is meant to become the local-model benchmark.

**The derived jump gap.** `SAFE_BASE_JUMP_GAP = JUMP_FLAT_REACH × 0.64` means retuning movement recomputes the validator's guarantee automatically. v0.3 would have had the two drift apart the first time anyone touched a movement constant.

**`constants.gd` is generated.** The engine cannot drift from the bounds the validator enforces.

---

## 3. Things that improved beyond the audit's asks

`bootstrap.py` ships as working code rather than as a description. The canonical fixture replaced four inconsistent versions. `CHANGELOG_v0.3_to_v0.4.md` gives finding-level traceability, so this audit could verify rather than re-derive. Debug grant commands are mock-AP-only and rejected in live mode. Fallback output goes through the same validator as model output, which is what makes `--epsilon=fallback` a genuine test oracle rather than a bypass.

---

## 4. Bugs found in v0.4 during this audit

All three fixed before publication. Recorded because the *pattern* matters more than the individual fixes.

### 4.1 The finale collapsed two independent states into one enum — **fixed**

`HubMode` originally had a `FINALE_AVAILABLE` value alongside `ZONE_AVAILABLE`. Since `mode` is a single value, one had to win.

The finale unlocks at 24 of 29 Checks, so **up to five ordinary Checks normally remain when it becomes available**. If `FINALE_AVAILABLE` displaced `ZONE_AVAILABLE`, those five became permanently unreachable — the player would be forced to end the campaign the moment they qualified, in a game whose entire premise is that the seed's item pool becomes your content.

This is the same failure *class* as pass-1's B5: two individually-correct rules (reserve 030 for a finale; unlock the finale at 24) that are wrong in combination. Both were found by asking "what does the player actually do next?" rather than by reading either rule.

**Fix:** `finale_available` is a separate boolean, independent of `mode`. When both are possible the Hub offers both and the player chooses; `RequestNextZone.finale` carries the choice. `FINALE_ONLY` covers the narrower case. A model validator makes `WAITING_FOR_AP` + `finale_available` unrepresentable. Four new tests.

### 4.2 Two documents disagreed on Zone completion — **fixed**

`TECHNICAL_ARCHITECTURE.md` §8 said an `ACTIVE` Zone with all Checks confirmed "is complete." `DESIGN.md` §14.3 said the exit portal "unlocks on re-entry," implying the player must walk back in to finish it.

The second reading strands the player: an `ACTIVE` Zone blocks new generation, so a player who confirmed their last Check via the shop while standing in the Hub would have a Zone with nothing left to do that they must re-enter to dismiss.

**Fix:** a Zone with every Check confirmed completes automatically wherever the player is. The exit portal is how you travel, not how a Zone is marked done.

### 4.3 The schema package's imports broke exactly where the plan puts them — **fixed**

`IMPLEMENTATION_PLAN.md` Phase 0 instructs: copy `schemas/` into `bridge/archipepsi_bridge/schemas/` verbatim. The modules used flat imports (`import constants as C`), which work when running tests inside the folder and fail the moment the folder becomes a nested package:

```
ModuleNotFoundError: No module named 'constants'
```

Caught by actually performing the copy the plan describes and importing the result — not by reading the code, which looks fine.

**Fix:** relative imports with an absolute fallback, plus `__init__.py`. Verified working in both contexts.

This is the exact failure mode the packet exists to prevent: instructions that are correct in prose and broken in practice, costing an unattended agent fifteen minutes of confusion over a three-line problem.

### 4.4 One rule was too strict, and strictness is not free — **fixed**

`validate_zone()` rejected a corridor holding both enemies and a reward, on the grounds that corridors have no objective so the enemies gate nothing.

True, but harmless — you walk past some enemies to a free reward. Making it a hard error spends the single repair attempt on a stylistic preference, and if the repair also fails the Zone falls back and Epsilon's actual design is discarded. **The repair budget is one; spend it on correctness.** Moved to prompt guidance.

---

## 5. Open issues in v0.4

Not fixed. None blocks the build.

### 5.1 Scope still exceeds one session — the residual risk

B3 was addressed by reframing rather than by shrinking, which is the right call — cutting features to fit an estimate would have produced a worse POC. But the underlying fact is unchanged: Phases 0–6 are not four hours of work.

The mitigations are the ordering, the T−60 rule, and the honest success criterion. All three depend on the agent *honoring* them under time pressure, which is exactly when an agent is most likely to think "one more subsystem." If v0.4 fails in practice, this is where.

Realistic expectation: **Phases 0–3 complete** (APWorld generating real seeds, the bridge connected and driving the whole loop headlessly, a Godot slice that plays one Zone end to end with the reveal). That is genuinely the demo. Phases 4–6 are upside.

### 5.2 Acceptance test count is still ambitious

59 numbered tests plus 11 end-to-end. Far more tractable than v0.3 now that most are pytest against the bridge, but a full run is not free. Not addressed: which subset is the *gate*. A reasonable default is bridge tests 1–20 plus end-to-end A and E.

### 5.3 The Godot half remains unverifiable by the building agent

B2 moved everything it could into Python. What is left in GDScript — the chamber builders, the controller, the effect runtime, the reveal — still cannot be run by an agent that cannot launch Godot. Acceptance tests 49–59 are written to be assertable headlessly, which helps, but "the platform builder never exceeds the safe gap" being *testable* is not the same as it being *tested* in a session where Godot never runs.

This is inherent to shipping a game from an unattended pass. The mitigation is that the Python half is now provably correct, so a human debugging the Godot half is debugging one layer rather than two.

### 5.4 `worst_case_zone_ttk()` models the wrong worst case, slightly

It assumes 13 melee (24 HP) plus 1 brute. But 8 enemies per chamber × 6 chambers exceeds the 14-per-Zone cap, so 14 is right — and melee at 24 HP is the highest-HP non-brute, so the figure is correct as an upper bound on *shooting* time.

What it does not model is time spent walking between chambers, waiting for enemies to close distance, or dying and re-clearing. Real clear time will exceed 25 seconds. The number bounds the plinkfest risk it was written for, which is what F2 asked; it is not a session-length estimate. Worth not over-reading.

### 5.5 Two pass-1 items remain open

LICENSE (G11) and session length (F5). The second cannot be answered before something is playable, which is why it is not a blocker.

### 5.6 Untested: the whole campaign brain

`schemas/` is tested. `campaign.py` — allocation, tier gating, finale gating, the never-starve rule, shop cadence — is *specified* but does not exist yet. Acceptance tests 21–35 describe it precisely, which is the best a design packet can do, but "specified and tested" and "specified" are different states and the packet should not be read as if the allocator has been validated. It has not. It has been described in enough detail to be validated.

---

## 6. Recommendation

**Hand v0.4 to the build pass.** The blockers are gone, the contract is executable, and the remaining risk is scope, which is managed by the ordering and the T−60 rule rather than by further design work.

Two things worth doing first, both cheap:

1. **A third-party pass on v0.4.** Pass 1 demonstrated the value concretely — the best finding came from the reviewer who had not written the packet, and §4.1 above is the same class of bug surviving into v0.4 despite the author knowing to look for exactly that. Someone who did not write this should read §10 of `DESIGN.md` and the `HubStatus` rules specifically.
2. **Decide the gate test subset** (§5.2), so T−60 has an unambiguous target.

Neither blocks anything. If the answer is "go now," v0.4 is ready to go now.
