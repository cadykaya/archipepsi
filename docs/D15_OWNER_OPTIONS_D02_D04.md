# D-15 — options for the owner: D-02, D-03, D-04

**Dess → Skyiah, 2026-09-24.** You asked for the concrete options before
any of these branches is built. Each section gives:
- what exists today, with citations;
- the real choices, and what each costs;
- my recommendation;
- what your pick unblocks.

Nothing here is implemented.

---

## D-02 — making the featured Echo actually supply the function

**The question.** Blindside's featured Check has to hand over something
that really crosses its gap. Today nothing ensures that.

**What exists:**
- **The capability check reads names, not function.** "Owning a
  grapple" counts any of three primitives
  (`schemas/mechanics.py:285-299`), and the check calls itself
  "IDENTITY, not qualification" (`:313-337`).
- **The parameter check has nothing to certify with.**
  `qualifies_for_gap` reads a parameter against a measured-crossing
  table (`:586-686`). The table is empty (`CROSSING_EVIDENCE = {}`,
  `:530`), and nothing in production calls it.
- **The request carries no requirement.** `EchoGenerationRequest` has
  no required-function field (`epsilon/requests.py:316-387`).
- **Validation never looks at function.** The pipeline is: call,
  validate, one repair, then fallback (`epsilon/base.py:80-149`). No
  check looks at capability.
- **The fallback reads names.** It makes a grapple only when the item's
  name contains "hook", "grapple", "chain", "longshot" or "clawshot"
  (`epsilon/fallback.py:1276`).
- **The room declares no geometry.** `FeaturedAcquisition` declares
  only a capability, a location and a room (`schemas/zone.py:842-866`).
  No gap, anchor, range or slot.
- **The physical need is known from the development scenario:**
  - the gantry deck is 3.1 m up and 7.5 m out;
  - a standing jump tops out at 1.33 m;
  - the pedestal's grapple is `grapple_to_surface`, range 20, pull 14,
    mobility slot (`godot/scripts/content/railway_scenario.gd:43-57,
    747-756`);
  - a 14 m/s pull tops out at 4.45 m (`:361-364`).
- **Design text already written:**
  - "Epsilon picks flavour, stats and name inside a family Python has
    already fixed" (`design-packet-v0.10/RESEARCH_MEMO.md:67-75`);
  - output "validated against the contract and regenerated or fallen
    back on if it misses" (`AP_CAPABILITY_LOGIC.md:163-180`).
- **D-01 (D14) already guarantees an Echo exists** at the featured
  Check, whoever the recipient is. Whether it works is D-02.

**Found while researching (DESS-26, latent).** `grapple_pull_target`
counts as `grapple` (`mechanics.py:296-297`). At runtime it moves the
enemy, not the player (`godot/scripts/gameplay/echo_runtime.gd:
1049-1072`). A crossing certified on it would be a crossing the player
cannot make. It is latent: the only composer that puts a capability on
an edge takes it from `featured_acquisition` (`cross_room.py:100-101`),
which nothing emits yet. **Every option below excludes it from
traversal.**

### Options

**A. The requirement is fixed first; Epsilon fills it in**
*(recommended)*
- **How it works:**
  - For the featured Check only, the request states the function:
    `grapple_to_surface`, meeting the room's envelope (range and pull
    enough to reach the deck).
  - Epsilon chooses the name, look, cooldown, modifiers and any extra
    components.
  - Output without a qualifying component is sent back once with the
    reason.
  - If it still misses, the deterministic fallback builds a qualifying
    grapple, named and flavoured from the item.
- **Result:** one Echo, earned by reaching the Check, that always
  works.
- **Cost:**
  - a request field;
  - one validation rule;
  - a fallback branch;
  - the envelope. The room has to declare its anchor distance and
    height, or the room type fixes them.
- **Risk:** the featured Echo is always a grapple. It is less
  surprising, but only at this one Check.

**B. Free interpretation, then patch what is missing**
- **How it works:** Epsilon interprets freely. If the result does not
  qualify, a second local grant bolts the missing function onto it.
- **Cost:** two grants for one Check, and the second one decides the
  function.
- **Risk:** the second grant is the "inject the featured ability" the
  packet forbids (`03_DELIVERY_PLAN.md` §6). I do not recommend it.

**C. Build the room around the Echo** *(rejected, listed for
completeness)*
- The room would be shaped after the item is known.
- The item is only known in advance by scouting, and letting it shape
  level structure is the leak `SOLUTIONS_CATALOGUE.md` §1 option 3
  rejects.
- The Echo also does not exist until the Check is confirmed.

### Choices inside A

**1. Where the envelope comes from:**
- **(i)** The proven pedestal numbers: range ≥ 20 m, pull ≥ 14 m/s,
  since the development scenario reaches the deck with them. Prod
  confirms them once at integration.
- **(ii)** A measured table from the runtime (Prod), which fills
  `CROSSING_EVIDENCE` properly.

I recommend **(i) now and (ii) as the later refinement.** Either is a
parameter check, not a name check.

**2. Which slot:** any slot the Action declares, but not a consumable,
because charges run out (`_runs_out`). The player equips it themselves;
there is no auto-equip (O05-05.3). The map already shows "you own it;
equip it" until they do.

**3. Targeting:** `grapple_to_surface` only bites a `StaticBody3D`
(`echo_runtime.gd:1023-1047`). The deck's anchor must be one, which is
Prod's placement.

**Unblocks:** H-QUALIFY (`O05-05.3`/`.6`), the working half of
Blindside's earned loop. D-03 is still needed before an AP location may
sit behind the gate.

---

## D-03 — letting Archipelago know about a capability gate before the seed exists

**The question.** May an AP Check sit behind a capability gate such as
Blindside's grapple gantry? If so, how does Archipelago know about it
when it generates the multiworld?

**What binds the answer: your ruling of 2026-09-05**
(`design-proposals/06_THE_AMALGAM.md` §29.5a):

> "An allocated AP Check, a local key relevant to AP reachability, or a
> Zone exit may sit behind a capability gate only when the matching
> Archipelago access rule declares the same prerequisite and Archipelago
> proves that prerequisite obtainable. Until that AP integration exists,
> Zone composition rejects such placement."

**What exists:**
- **The APWorld knows only Signal-Key tiers.** Tier 1 needs 1 key and
  Tier 2 needs 2. The pool is Signal Keys plus filler; there are no
  capability items, bosses or shards (`apworld/archipepsi/__init__.py:
  108-144`).
- **The bridge enforces the ruling.** `topology.reachability` refuses
  the exit, a Check or a key room reachable only through an undeclared
  gate (`topology.py:1692-1711`). No production caller declares a
  capability.
- **Options are already drafted** in `AP_CAPABILITY_LOGIC.md`: A
  (capability items), B (a local schedule) and C (keep the restriction).
  Both A and B need a pre-seed export of which locations need which
  capability (§4a). An event-based design was prototyped, generated
  clean solo and multiworld, and was reverted (`RESEARCH_MEMO.md:14-29`).
- **What D-01 and D-02 now change.** With D14 and D-02 option A, the
  featured Check always yields a working grapple. So "the capability
  exists once Blindside's Check is reached" can become a deterministic
  fact, not a hope.

### Options

**C. Keep the restriction for now** *(recommended as the near-term
step)*
- **How it works:** no AP location goes behind a capability gate.
  Blindside's grapple opens the way back, the restored span and local
  rewards, but never a Check.
- **Cost:** none. It is what ships.
- **Gets you:** Blindside's whole earned loop can be finished and played
  **without touching the APWorld or any seed**:

  > earned branch → working function → useful return → restored span

  The last packet requirement, "AP-safe access", holds trivially.

**E. Capability events in AP logic** *(recommended as the target)*
- **How it works:**
  - The APWorld adds one locked event per capability milestone ("Grapple
    acquired"). It sits at an event twin of the featured location, with
    that location's access rule.
  - Every location behind the gate requires the event.
  - Archipelago then declares the prerequisite and proves it
    obtainable, which is the letter of your 09-05 ruling.
- **What the bridge must guarantee:** the event is physically true.
  - The featured Check always yields a working grapple (D14 + D-02 A).
  - Its Zone is allocated as soon as AP logic can reach it. This is the
    "real allocation/reachability proof" D-03 asks for, as a bridge
    check against the slot-data export at connection.
- **Keeps:** the capability local, and Blindside as its source.
- **Cost:**
  - an event and rules in the APWorld;
  - the §4a export;
  - the allocator guarantee and its proof;
  - a new APWorld version. Existing seeds are unaffected.
- **Risk:** Archipelago trusts the bridge that the event is real. The
  proof makes that a checked fact, not an assumption.

**A. Capability items in the multiworld**
- **How it works:** three progression items (Grapple, Blink and
  Traversal Modules) go into the pool, with `has(item)` rules and the
  §4a export.
- **Gets you:** Archipelago's fill proves everything, and fails loudly
  at generation.
- **Cost:**
  - the capability can arrive from any world;
  - Blindside stops being its source, since the module is wherever fill
    put it;
  - the module still needs D-02 A's fixed family to work, and three new
    items change every future seed's pool.
- **Choose it if** you want Archipelago, not the bridge, to carry the
  whole proof.

**B. A local schedule beside AP** *(needs your 09-05 ruling changed)*
- **How it works:** the tier rule only. The bridge promises the
  capability by a milestone Archipelago never hears of.
- **Risk:** "a seed is quietly unwinnable and Archipelago never knew"
  (`AP_CAPABILITY_LOGIC.md` §7). It contradicts §29.5a as written, so I
  list it only so the choice is complete.

**Later: bosses and shards.** Their breachpoints are 0.5 design and
must be "represented before seed generation"
(`06_VERSION_0_5_PROGRAMME.md:59-63`). Whichever of E or A you choose is
the mechanism they reuse. Nothing for them is built.

**Unblocks:**
- C: finishing Blindside now.
- E or A: H-AP-GATE (`O05-05.5`), and later H-05-SHARDS.

---

## D-04 — how the twelve manipulation verbs reach a player

**The question.** The engine runs twelve physics verbs: PUSH, PULL,
HOLD, ALIGN, TETHER, PIN, ATTACH, DETACH, ROTATE, LIGHTEN_FIELD,
ANCHOR_FIELD and SETTLE (`godot/scripts/gameplay/verb_*.gd`). Only a
test driver can call them (`godot/tests/verb_runtime_driver.gd:15-20`).
How should an Echo deliver one?

**What exists:**
- **Echo Actions are ECHOES v0.8.** Each holds one `primitive` from a
  28-type union (`schemas/echo.py:326-337, 857-863`), and none reaches a
  verb.
- **The destination is the Amalgam's Ability grammar.** An Ability is
  one atom in each of five dimensions: form, effect, targeting,
  recharge and scaling (`design-proposals/06_THE_AMALGAM.md:805-807`).
  The verbs enter as `effect` atoms, each carrying a verb discriminator:
  - basic 24: PUSH, PULL, ALIGN, SETTLE;
  - hold 30: HOLD, ROTATE, PIN, TETHER;
  - structural 34: ATTACH, DETACH;
  - mass field 32: the two fields;
  - master 62, HIGH only: all twelve (`:670-686`).

  Epsilon "emits selections, never numbers". None of this is built for
  Abilities; the only atom grammar in the bridge is Gear's, which is
  data only.
- **Prod's analysis** (`ledgers/PROD_OV05.md:1022-1089`). A
  `physics_verb` primitive would carry the verb and its numbers, but not
  the atom semantics:
  - cost;
  - HIGH tier;
  - separate form, target and scaling;
  - a shared price per atom;
  - CHARGE_RELEASE.

  So it would be "the parallel ability system the owner excludes" unless
  you approve it as an interim.
- **No consumer needs a verb in this packet.** The Unweighted Switch
  allows a qualified manipulation tool only as an optional alternative
  (EX50-033:44). Its repair names the crate, drive and applicator. The
  power cell is base-kit carry, and the lever is `E`.
- **Two facts every delivery option inherits:**
  - **Canon status.** The Amalgam says "Not canon until selected by the
    owner" (`06:5`). Later work orders call it accepted. I found no
    promotion record for its Ability grammar.
  - **Migration.** It adopts Design 4's rule that "old Echoes become
    Archive entries… the Loadout is cleared". That text is at
    `04_EPSILON_IS_THE_CONTENT.md:937`, pinned by `06:985`. That
    contradicts your standing no-migration rule, so any grammar work
    must keep legacy campaigns' Echoes as they are.
- **Runtime gaps Prod must close before any verb ships**
  (`PROD_OV05.md`):
  - SETTLE versus PIN;
  - weld persistence;
  - enemy mass;
  - HOLD's input;
  - the fields' cast time.

### Options

**H. Hold delivery until a consumer is named** *(recommended now)*
- **How it works:** the verbs stay runtime-only. They are proven and
  kept, and nothing mints them.
- **Cost:** none. Nothing in the post-playtest scope is waiting on them.
- **When it ends:** when Prod names a real consumer, meaning a room
  whose intended solution is a verb. That is the packet's own "Prod
  names actual consumers" condition.

**G. The Amalgam grammar, only the slice verbs need** *(recommended as
the delivery path)*
- **How it works:** a new component kind, an Ability composed of the
  five atom dimensions, containing only the atoms verb Abilities use,
  with their costs, tiers and budget bands as the Amalgam defines them.
  Epsilon selects atoms and never numbers. Existing Actions stay v0.8.
- **Gets you:** the accepted destination, partly populated, rather than
  a second system. Other Abilities move to it later.
- **Legacy campaigns** keep their Echoes, with no migration. The
  per-campaign policy pattern from D14 applies.
- **Cost:** medium, and several waves across schema, fold, validation,
  the Epsilon prompt, fallback, and Prod's runtime dispatch.
- **Needs from you:** confirm the Amalgam's Ability grammar as canon, and
  replace its migration rule with "legacy campaigns keep their Echoes".

**P. An interim `physics_verb` primitive, explicitly approved**
- **How it works:** one v0.8-style primitive with a closed verb list and
  resolved numbers, labelled temporary, with a named removal condition.
- **Cost:** small.
- **Risks:**
  - It cannot carry the atom semantics.
  - Every Echo minted with it becomes saved data the grammar must later
    either convert, which is a migration, or carry forever.
  - It is exactly the "temporary authority change" the packet requires
    you to approve.

**F. The full Ability grammar at once**
- **How it works:** every Ability is re-expressed in atoms, all
  migrated.
- **Cost:** the largest. The migration rule collides with the standing
  one.
- **Verdict:** not proportionate to a packet with no verb consumer.

**Unblocks:**
- H: nothing needed.
- G or P: H-ATOM-DELIVERY (`O05-08.5`). Its acceptance test is:
  create, fold, equip, activate, qualify, persist.

---

## Summary

| | the choice | my recommendation | unblocks |
|---|---|---|---|
| **D-02** | how the featured Echo is made to work | **A**: the function is fixed by Python; Epsilon names and flavours it; a qualifying deterministic fallback; the pedestal envelope (range ≥ 20 m, pull ≥ 14 m/s) now, measured later; `grapple_pull_target` excluded from traversal | H-QUALIFY |
| **D-03** | capability gates and Archipelago | **C now**: finish Blindside with a non-AP payoff, no seed change. **E later**: AP capability events, with a bridge-side allocation proof. **A** only if you want AP fill to carry the whole proof | Blindside now; H-AP-GATE later |
| **D-04** | how verbs reach a player | **H now**: no consumer yet. **G** when one is named: the Amalgam slice for new campaigns, which needs your canon confirmation and a new migration rule | nothing now; H-ATOM-DELIVERY later |
