# Batch 031 — PROPOSAL: the local Zone key family

**Status: PENDING.** Nothing here decides how many keys a Zone has, whether
one is consumed or retained, how it persists, or any AP behaviour.

## The A-vs-B question, answered by the receiver

The brief asked for **(A)** one universal key with theme treatment, or
**(B)** theme-native keys sharing one unmistakable semantic feature.

**The receiver settles it.** Batch 028 built `int_key_receiver` as *"an empty
shaped keyway with a shoulder"* — and a keyway is a picture of its key, drawn
in negative. The player learns the key by seeing the hole before they ever
hold one. So:

> **The part the receiver reads must be universal. Everything else may be
> themed.**

| zone | universal? | why |
|---|---|---|
| **shank + shoulder** — what enters the keyway | **universal, identical everywhere** | it must fit a hole the player already learned. Themed shanks means six keyways, and six keyways teach nothing |
| **bit** — the coded lug array | universal geometry, **per-channel count** | this is what makes channels scale |
| **grip** and its material | **themed** | the part a hand holds can afford to belong to its Zone |

That is A's semantic guarantee with B's local flavour, and the line is drawn
where the mechanism needs it rather than as a compromise.

## Channels are counted, never coloured

```
channel N  =  N lugs on the bit  +  the shoulder notch rotated N steps
```

Two redundant carriers of one fact, so the read never depends on counting
alone. That redundancy is deliberate: Batch 029 found that counting *fine
surface marks* fails at distance in this rendering language. Here the lugs
are **structural, at hand scale, read against the mat's own edge** — the
opposite case — and the notch backs them up regardless.

Three channels are built. The scheme extends without changing anything else.

## Distinct from everything it could be confused with

| | how |
|---|---|
| **Signal Key** (AP, `SIGNAL_KEY_COUNT = 2`) | scale and ceremony. **No Signal Key art exists yet** — recorded here as a constraint on that future batch so it is not discovered late |
| **Epsilon Coin** | silhouette: a disc on edge in a cradle vs a flat shank along the mat |
| **AP Check** | a pedestal you approach vs a thing you lift off the floor |
| **health / ammo / resources** | it joins Batch 027's silhouette test rather than dodging it |

**Not a keycard, not a fantasy key.** No coloured card, no icon plate, no
bow-and-ward, no ornament. It is a **machined interlock blank** — a shank, a
shoulder collar that seats against a face, a lug array that indexes. Colour
carries nothing at all.

## The mat is inherited on purpose

Every key sits on Batch 027's hexagonal pickup mat, unchanged. That grammar
already means *you can take this*, so the key joins the family rather than
arguing for itself.

## Metrics

| asset | channel | theme | tris | size (m) |
|---|---|---|---|---|
| `zkey_ch1` | 1 | concrete_facility | 288 | 0.59 × 0.59 × 0.19 |
| `zkey_ch2` | 2 | concrete_facility | 300 | 0.59 × 0.59 × 0.19 |
| `zkey_ch3` | 3 | concrete_facility | 312 | 0.59 × 0.59 × 0.19 |
| `zkey_ch1_rusted_industrial` | 1 | rusted_industrial | 288 | 0.59 × 0.59 × 0.19 |
| `zkey_ch1_void_glitch` | 1 | void_glitch | 288 | 0.59 × 0.59 × 0.19 |
| `zkey_receiver_ch1` | 1 | concrete_facility | 136 | 0.42 × 0.30 × 1.48 |
| `zkey_receiver_ch2` | 2 | concrete_facility | 148 | 0.42 × 0.30 × 1.48 |
| `zkey_receiver_ch3` | 3 | concrete_facility | 160 | 0.42 × 0.30 × 1.48 |

## Sheet

`A_zone_keys.png` — row 1 the three channels; row 2 one channel in three
themes, showing the shank never changes; row 3 each key beside the receiver
it mates with.
