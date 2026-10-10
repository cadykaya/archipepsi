# Archipepsi — Decisions to Review for v0.3

This file contains the remaining choices that are consciously **not** fully locked. They should not be interpreted as permission for an implementation agent to redesign surrounding systems.

# 67. Human-review decisions for design pass 0.3

The v0.2 self-audit intentionally removed choices that were dangerous for autonomous implementation. These are the remaining product decisions worth reviewing together.

## A. Is 30 the right POC Check count?

Current:

**30**

Recommendation:

keep 30.

It gives enough multiworld item variety without making the POC campaign enormous.

---

## B. Is 3 Checks per Zone the right density?

Current:

target 3, max 3.

This probably produces roughly 10 Zones for a full 30-check clear.

---

## C. Do we want the POC goal to be exactly Check 030?

Current:

yes.

Alternative later:

generated final boss / explicit Final Core event.

---

## D. Should Coins always be forced non-local?

Current recommended YAML:

yes, for the intended six-player POC.

The APWorld itself does not force it, so solo testing remains possible.

---

## E. How literal should Echoes be by default?

Current:

`Playful`

Conservative and Unhinged remain runtime choices.

---

## F. Should duplicate source items make duplicate/different Echoes?

Current:

yes.

Echo identity is source-location based, so two separately sent Hookshots can become two different interpretations.

This feels appropriately cursed but should be consciously confirmed.

---

## G. When do we reintroduce hard Echo-gated rooms?

Current:

not POC.

Recommendation:

only after implementing explicit gate templates such as `grapple_gate`, `dash_gate`, etc. whose solvability can be mechanically verified.

---

## H. Shop stock size/cost

Current:

2 items, fixed costs 2/4/6.

This is intentionally boring on the economy side so the weirdness stays in Epsilon’s item interpretation.

---

## I. Epsilon tone

Current target:

creative, playful, internally coherent, occasionally funny, never pure “lol random.”

This deserves a later tone pass after we see actual outputs.


## Additional review target created by the packet split

Before the final autonomous handoff, Skyiah + ChatGPT should do one more pass specifically for **game feel**, not architecture:

- exact movement constants after a 5-minute in-engine feel test
- how long a normal Zone should take in practice
- whether Check 030 should remain the POC finish trigger or become a tiny fixed/generated finale
- how much exact unrevealed item identity Epsilon should be permitted to use privately when designing a Zone
- whether two copies of the same source item should normally become different Echoes or share a semantic family
- whether the default creativity setting remains `Playful`
- whether the first live six-game seed should force only Coins non-local or also bias Pepsi Keys outward for demonstration purposes

Until changed, the defaults already stated in the authority documents remain valid.
