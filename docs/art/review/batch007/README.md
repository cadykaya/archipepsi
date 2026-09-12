# Batch 007 — the kit that moves you

**Start with `T_corner_turn.png`**, then `T_climb_scale.png`.

Tier 3 opens with the architecture kit. Five of its twenty unbuilt modules
are Pri A and they are all the same kind of thing: the pieces that get the
player from one height to another and from one room to the next.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 007*.

| Image | What it answers |
| --- | --- |
| `T_corner_turn.png` | **start here** — inside the junction, both bores, engine lens |
| `T_corridor_eye.png` | standing in a straight run |
| `T_corridor_run.png` · `_grey` | six modules assembled — the seams are the 4 m grid |
| `T_climb_scale.png` · `_grey` · `_silhouette` | stair and ramp against a 1.78 m figure |
| `T_stair.png` · `T_ramp.png` · `T_ledge.png` | each on its own |
| `T_corner_left.png` | the junction as an object |

## What to look at

1. **The heights are the engine's.** Stair 2.0 m (twice `MAX_VERTICAL_STEP`,
   above `JUMP_APEX` — the first height that is neither walkable nor
   jumpable). Ramp exactly `JUMP_APEX`. Ledge `MIN_PLATFORM_SIZE` deep.
   None of them was picked for looks.
2. **Does a corridor made of these read as a corridor?** That is what the
   two eye-level shots are for. Both are at the engine's own 90° lens.
3. **The ramp has kerbs but no modelled grip battens.** A kerb is a
   silhouette that says *drop*; a tread pattern is paint.

Nothing here is approved. `PASS` is yours.
