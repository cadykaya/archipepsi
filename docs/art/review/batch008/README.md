# Batch 008 — the three projectiles

**Start with `X_projectile_family.png`, then `X_projectile_in_hub.png`.**

Tier 4 is the enemy roster and most of it is blocked — seven of the ten
roles have no collider, and the telegraph has no node in `enemy.gd` to hang
an authored asset on. `enemy_projectile` is the Pri-A row with nothing in
its way.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 008*.

| Image | What it answers |
| --- | --- |
| `X_projectile_family.png` · `_grey` · `_silhouette` | do the three separate by shape alone |
| `X_projectile_above.png` · `_silhouette` | from overhead — how a falling shot is met |
| `X_projectile_in_hub.png` · `_grey` | in the real room at 12 m, on the engine's lens |

## What to look at

1. **Three, where the engine draws one.** Straight, falling and lobbed
   demand three different reactions — step sideways, get out from under,
   get clear — and today they are one sphere, scaled 1.5× for the lob. The
   one distinction the engine draws is the least useful of the three.
2. **Hue is already spent.** `EchoProjectile.tint` is the *source world's*
   colour, so the projectile wears whichever multiworld game the Echo came
   from. Nothing about hue is free to say which kind it is; all of it is in
   the silhouette.
3. **The Hub shot is one theme of six.** The other five are behind the
   theme-kit gate. It is not the full trackability test and is not labelled
   as one.

Nothing here is approved. `PASS` is yours.
