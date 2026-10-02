# 10 — Verification that matches the claim

## 1. The four questions

**Does the mechanism exist? Does normal play reach and use it? Does the state survive the promised lifecycle? Does the player understand and enjoy the situation?** A different kind of evidence answers each question. Preserve that separation.

Historical 64/64 success remains valid for the tested revision and tests. It does not refute a new bypass, unfair blast or confusing room. Add a case for the demonstrated gap; do not rewrite a test to accept the defect or discard a source fixture because it is inconvenient.

## 2. Targeted acceptance matrix

| Case | Setup/action | Required observation / distinguishing control |
|---|---|---|
| V-01 artillery isolation | Player and artillery in neighbouring sealed rooms, then same layout with a real opening | No damage through intact barrier; legitimate open-path attack still possible |
| V-02 shell path | Fire toward a reachable target with ceiling/obstacle intersecting the arc | Shell contacts the obstacle; no teleport through it; explosion uses actual impact |
| V-03 blast cover | Two players/probes or repeated trials equally near blast, one behind solid cover | Covered target is protected according to real occlusion; open target responds normally |
| V-04 flyer targeting | Normal player camera shoots visible body across near/mid/far views | Hit volume follows rendered body; intentional miss outside it remains a miss |
| V-05 flyer action | Actual declared role with ground/air/range/sight states recorded | Correct attack/wait state, real launched/impact events and cumulative damage; respawn cannot erase evidence |
| V-06 full clear reload | Clear a room, leave an object, quit both processes, resume same candidate | Item state returns, defeated population does not ambush player, no duplicate reward |
| V-07 partial/old-save reload | Kill subset, or load copied save lacking new fields | Explicit safe policy; no invented clear flags, silent reset or attacks during build |
| V-08 pressure semantics | Eligible pressure applied then removed | Ordinary plate output follows pressure; permanent lever/bolt is visibly distinct |
| V-09 puzzle cheap route | Fresh hosted minor with only base movement and real pickup range | No immediate reward bypass of the meaningful state; inspect actual geometry, not only room membership |
| V-10 movement assistance | Actual available double-jump/blink/grapple variants under their real rules | Useful alternatives remain; room still has a meaningful interaction, no global movement nerf |
| V-11 alternate Counterfire | Gunner-driven path and designed kill-first/service fallback | Both legitimate outcomes work; identify the owner's remembered instance before removing a fallback |
| V-12 return | Claim by intended and accepted alternate route, move carriers, die/re-enter | Clear, usable return without relying on optional random teleport |
| V-13 circuit legibility | Source control and remote door, same/adjacent rooms, replay | Colours/symbols/labels map consistently; pending/refused distinct from physical open |
| V-14 local keys | Inspect fresh Zone's keys, matching realized locks and open state | Meaningful matching local use; no useless awarded key with no declared consumer |
| V-15 bombs | Natural candidate claim, not injected component | Item discoverable, compatible equip and real authorized use; absent/owned/empty cases distinguished |
| V-16 paused equipment | Open via Escape/Tab; inspect/equip; type binding characters | World and gameplay clocks stop, UI remains usable, no input leakage |
| V-17 pause transaction | Authorization response/disconnect arrives during pause/page turn | No free/duplicate launch, no refund of irreversible work, safe reconciliation on resume |
| V-18 actual 3D navigation | Turn all four faces both ways; rapid/cancelled interaction | True panel transforms; correct face order; one active interaction surface; no accumulated turns |
| V-19 equipment data | Upgraded item, mixed Echo, empty slot, rejected equip, snapshot during selection | Current fold identity shown; no history-duplicates or false acceptance |
| V-20 two maps one state | Find green circuit, carry part, install, open, reverse, reload | Both maps match actual known passage state at each step |
| V-21 miniature integrity | Open actual multilevel Zone map repeatedly | Real connector/height geometry, no duplicated actors/scripts/rewards/physics |
| V-22 import/readability | Glyph source→export→Godot import→live menu at intended sizes | Correct font metrics/texture sampling, readable names/icons, actual input works |
| V-23 natural occurrence | Request fresh candidate through normal launcher/profile | Existing checks/identities preserved; proper selected content, no hand-edited save masquerading as generation |
| V-24 final journey | Start, acquire/equip, use machinery, claim, return, restart, continue | One coherent ordinary journey across contracts, not a collage of unrelated local proofs |

These are candidate test cases, not test results from this packet. Exact automated implementations can reuse existing drivers. Tests involving multiple perspectives can use repeated independent trials; they do not require introducing multiplayer player bodies.

## 3. Reproduction before a five-minute theory

Print relevant preconditions first: correct revision/profile/save, one normally placed player, existing holds, target role, visible/collision transforms, room/door state, resource/equip state and whether geometry is loaded. For movement, record actual displacement/speed and collisions. For damage, record events and deaths, not just HP at interval endpoints. For a screenshot, confirm the intended camera is current.

A bot stuck against the entry wall cannot prove a Bulwark unflankable. A spawn overlap cannot prove rooted movement is broken. A player who died and respawned cannot prove artillery dealt zero damage. These are preserved lessons, not reasons to distrust owner feedback.

## 4. Efficient negative controls

Use a minimal targeted control for each important invariant: remove cover check and covered-target case fails; omit saved-defeat restoration and the reload case fails; disconnect the reward consumer and the room's outcome fails; omit the pack cache identity and another pack leaks. Confirm the control breaks the actual function under test.

Do not run ten-minute mutations for every UI border or a full suite after every documentation line. Never edit a source file while another process expects a different sabotage. Keep restore checksums and original copies outside the mutation target. If a process/container stops, inspect and restore before committing anything. A sabotage that is not caught is a coverage gap or an invalid sabotage, not a pass to report away.

## 5. Frozen integration and platforms

Derive the required command list from the current Makefile/CI configuration. Run focused checks during work; one full fixed-revision frontier at an integrated delivery checkpoint. Capture command, exit code, duration, environment, source SHA and complete logs. Keep logs outside mutable tracked source. Record expected generated provenance restamps separately from code changes. Do not count steps from a truncated log tail or compare test totals from different revisions as one run.

Historical Linux evidence does not establish Windows execution. Test the exact Windows launch family/import on Windows when available. Otherwise deliver explicitly labelled unrun Windows verification and a short owner smoke route. Keep old ordinary/candidate saves separate; never use `--new` as a default fix for a failing save.

No remote CI polling/subscription is needed for local evidence. A remote runner failure is neither a code failure nor a reason to waive a real local failure. No watcher or scheduled resumption is added.

## 6. Owner review should be short and spoiler-light

Ask the owner to play a small changed route, not personally repeat this matrix. Give a separate answer guide. Capture spontaneous positives and problems; a puzzle bypass is evidence, not player noncompliance. Useful questions are: What did you think the room wanted? Which object changed something? What helped you recognize the threat? What did your movement ability let you do differently? Could you return without guessing?

Review one real inventory task: find a new item, compare/equip it, understand its binding/charges. Review one navigation task: identify a named known blocked door on the miniature, operate its circuit, see the map change and walk the route. Review one resume: clear, close, reopen, continue without a manufactured ambush.

Keep outcomes separate: technically verified, naturally encountered, human-understood, liked, rejected, untested. Do not roll them into a single “fun score.” The owner is not required to solve a confusing puzzle as intended merely so the report can call it complete.

## 7. Final handoff receipt

Include tested code SHA; pushed documentation/art SHA and difference; platform/runtime/profile; fresh/resume steps; preserved-save locations; spoiler-light changed route; answer guide; known blockers; actual natural-acquisition limits; visual/audio review status; exact next ready IDs. State what did **not** run. No repeated transcript, fabricated screenshot, unperformed listening claim, or “everything survives” shorthand without its reset domains.
