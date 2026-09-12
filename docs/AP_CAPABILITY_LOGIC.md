# Capability gates and Archipelago logic — a proposal

**Status: proposal. Nothing here is implemented and the item pool is
unchanged.** Written because the intended gameplay — *find the grapple,
come back, open the door you could not open* — needs an Archipelago
guarantee that does not exist yet, and the shape of that guarantee is an
owner decision rather than an implementation detail.

Until it is settled the bridge keeps refusing a capability gate on any
AP-relevant route (`topology.reachability`). That restriction is
temporary and is **not** a verdict on the gameplay.

---

## 1. What has to be true

`SOLUTIONS_CATALOGUE.md` §0-bis permits a local key, a required Check or
the Zone exit to sit behind a hard capability gate, on five conditions.
Three are already enforced in the bridge (the graph agrees with AP logic;
you can leave; you can come back). **Two are not, and both are about
Archipelago:**

1. *the matching AP location logic declares the same prerequisite;*
2. *Archipelago proves the capability progression is obtainable.*

Neither is expressible today, and the reason is not a missing wire.

## 2. How a capability reaches a player today

Traced, not assumed:

| Step | Where |
|---|---|
| the player claims a Check | an ordinary AP location |
| the item belongs to **another** player | `campaign.grant_echo` scouts it |
| **Epsilon interprets that foreign item** into an Echo | `generate_echo_validated` |
| the interpretation log folds into owned components | `derive_mechanics` |
| a capability is satisfied when an owned component carries a matching **primitive** | `owned_capabilities`, `ACTIVITY_CAPABILITIES` |

So `grapple` is held when some owned component's primitive is
`grapple_to_surface`, `grapple_pull_target` or `grapple_swing` — and
whether any component ever carries one is decided by **a creative
interpretation of whatever the multiworld happened to give you.**

The AP item pool, meanwhile, is `Signal Key` ×2, `Epsilon Coin`,
`Epsilon Static`, and the location logic is tier-based on Signal Key
count. **`grapple`, `blink` and `cross_long_gap` appear nowhere in it.**

## 3. Why that is not an AP proof

The generator already refuses to require what it cannot prove — owner
ruling *no requirement before guarantee*, `capability_guarantee`, four
cases: **A** permanent baseline, **B** already possessed, **C**
established in the Zone (no producer), **D** Forge-constructible (not
implemented). Case B is what runs, and B is a statement about **now**:
*this campaign currently owns a grapple component.*

Archipelago needs a statement about **obtainability**: *any player who
reaches this location can have got a grapple by then.* B cannot supply
it, because the thing that produced the grapple was Epsilon's
interpretation of someone else's item — a convenient random reward.
Feeding that set to AP, or passing it in as a caller-supplied list,
would be the bridge telling Archipelago what Archipelago is supposed to
be proving.

## 4. Option A — explicit capability items

Add progression items to Archipepsi's own pool: `Grapple Module`,
`Blink Module`, `Traversal Module` (for `cross_long_gap`).

| | |
|---|---|
| **Where the guarantee comes from** | Archipelago's fill. A progression item is placed in logic, so the solver proves every gated location is reachable — this is the mechanism AP exists to provide, and it needs no new trust. |
| **How location rules match** | Zone locations gain a rule alongside the tier rule: `state.has("Grapple Module", player)` for the locations a gated Zone's route depends on. The bridge sends the required capability with the Zone's allocation so the apworld can attach the rule to *those specific ids* rather than to a whole tier. |
| **How a qualifying provider reaches the player** | The item grants a **fixed, authored component** carrying the primitive — it does not go through `grant_echo`. Receiving it appends a deterministic interpretation, so the fold produces the capability every time. |

**What it costs.** `grant_echo` currently turns *every* foreign item into
an Epsilon Echo; these items would be the first that do not, and the
first authored mechanics in a game whose premise is that mechanics are
interpreted. It also puts your grapple in someone else's world, which is
the classic multiworld experience and a real change in how Archipepsi
plays.

## 5. Option B — guaranteed local acquisition, represented in AP logic

Keep Epsilon and the Forge as the only source of mechanics, and make the
*timing* of acquisition something AP logic can state. AP never names a
capability; it names the milestone that guarantees one.

| | |
|---|---|
| **Where the guarantee comes from** | A **deterministic local schedule**: by milestone *M*, the campaign is certain to be able to produce a qualifying provider. Certainty is the whole requirement — "probably, by then" is not a guarantee, and AP fill is not a probabilistic argument. |
| **How location rules match** | The existing tier rule, unchanged. If the schedule says "a grapple provider is guaranteed from Tier 1", then gated locations may only be placed in Tier ≥ 1, and `unlocked_location_ids` already expresses that. No new item, no new rule kind. |
| **How a qualifying provider reaches the player** | Two candidate mechanisms, and neither exists: **B1 — the Forge** (`capability_guarantee` case D): Forge access, guaranteed ingredients, and a proof that a legal configuration carrying the primitive can be built from them. **B2 — a scheduled grant**: the campaign appends an authored interpretation carrying the primitive at a defined milestone. B2 is B1 without the Forge, and is much smaller. |

**What it costs.** The schedule becomes load-bearing for solvability: if
the grant slips, or the Forge cannot actually build the thing, the seed
is unwinnable and Archipelago never knew. It also means capabilities are
never in anyone else's world — Archipepsi's own progression, with AP
merely told when it is safe to place a gated location.

## 6. Option C — the current restriction, kept

Gate only **optional** content: hidden Checks, shortcuts, flavour. No
AP-relevant route depends on a capability, §0-bis's five conditions never
have to be met for a required route, and no AP change is needed.

This is what ships today. It is listed because it is a real answer, not
because it is the intended one — the whole point of §0-bis is that
"NOT YET" on a required route is good gameplay.

## 7. The owner choice

Options A and B are both viable and they are **different games**:

> **A** puts capability progression into the multiworld. Your grapple may
> be in someone else's world; another player's Check is what opens your
> door. That is the Archipelago experience, and it costs Archipepsi its
> rule that every item becomes an interpretation.
>
> **B** keeps every mechanic interpreted or forged, and uses Archipelago
> only for *when it is safe to place a gated location*. That preserves
> the premise, and it moves the solvability guarantee from AP's fill —
> which is proven — onto a schedule the project has to keep, which is
> not.

Nothing in the design packet settles this. It is the choice.

**If B, one sub-choice follows:** B2 (a scheduled grant) is implementable
now; B1 (the Forge) needs a system that does not exist. B2 first, B1 as
the eventual home, is coherent.

## 8. One repair that is needed under A *and* B

`_capability_is_satisfied` tests **primitives only** — every entry in
`ACTIVITY_CAPABILITIES` has an empty `stats` requirement. So a `dash`
component satisfies `cross_long_gap` regardless of how far it actually
dashes, and a gate asking for a 6-metre crossing is "satisfied" by a
2-metre one.

§0-bis is explicit that this is not relaxed: *"`max_safe_gap` and the
movement floor still bound what a gate may ask of the kit you do have. A
declared Grapple gate is legal; an undeclared 3-metre jump is still a
bug."* And §29.3.2 already has the pattern for `manipulate` — a
**mandatory-route envelope** the provider must meet, with the reference
solution authored against the minimum so anything qualifying can solve
it.

The same floor is owed for `cross_long_gap` at least, and the `stats`
branch of `_capability_is_satisfied` is where it goes. **Without it,
"the player has the capability" and "the player can make this jump" are
different claims and the gate is proved against the wrong one** — which
is the guarantee failing quietly rather than loudly, whichever of A or B
is chosen.

---

## What this lane does next, either way

Nothing until the choice is made. `topology.reachability` keeps refusing
an AP-relevant gate with no matching guarantee, `declared_capabilities`
stays unpassed by production, and composition emits no gates — so the
restriction costs nothing today and removes no option tomorrow.
