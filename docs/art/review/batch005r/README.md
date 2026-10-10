# Batch 005-R — the targeted revision

**`R_state_family_far_inset.png` is the sheet.** Everything else supports it.

You asked for one non-hue, non-ring cue separating **LOCKED** from
**CONFIRMED** at ~39.6 m, without redesigning the Check. This is it: the
spent husk has collapsed, swallowed the cage uprights and overflowed the
hood, so the head goes from *an open lantern you can see daylight through*
to *a solid lump*.

Nothing else changed. Same mast, same ring, same beam; locked, available
and sending are exactly what you approved.

## The measurement, at 39.6 m on the engine's own lens, at 1080p

Background fraction inside the cage band — the five pixels the cage
interior occupies. Lower is more solid.

| State | Head width | Background in the cage band |
| --- | --- | --- |
| locked | 10 px | **43%** |
| available | 10 px | 44% |
| sending | 10 px | 49% |
| confirmed | 11 px | **16%** |

The three unspent states sit within six points of each other. Confirmed is
27 points clear of locked.

## Why the first attempt was thrown away

A shutter descending inside the cage. It is a better-looking object and it
does not work: at 39.6 m the cage interior is **five pixels tall**, and
filling all five only moved 58% to 48%. The cue had to go outside the cage,
where there is width instead of height — which is your fourth option, *the
spent husk occupies a deliberately larger / different negative-space
pattern*.

## One thing the revision also fixed

The `dead` states were emitters, and measured against the mast head at
luminance 80, the locked cradle came out at 83 and the confirmed husk at
94 — the deadest things on the object were the brightest. Both are now
albedo only. `reward.gd`'s 0.4 / 0.2 energies can add whatever glow the
engine wants; the mast's own lit band is what says *there is a Check here*.

| Image | What it answers |
| --- | --- |
| `R_state_family_far_inset.png` | **start here** — 39.6 m, 4×, unfiltered |
| `R_state_family_far.png` · `_grey` | the frame that inset came from |
| `R_state_family.png` · `_grey` · `_silhouette` | the four states, one camera |
| `R_head_compare.png` · `_silhouette` | locked and confirmed at 85 mm |

If they separate, Batch 005 is a `PASS`. Nothing here is approved yet.
