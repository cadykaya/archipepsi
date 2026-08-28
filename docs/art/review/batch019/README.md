# Batch 019 — treasure rooms and corners: §7 complete

**Open `R_treasure_family.png` first.** Three treasure rooms from above:
same 8 × 8 × 4.5 box, same reward position, three different rooms. That
image is the whole argument, because `TreasureRoomChamber` has **no
dimensional parameters** — the side and height are literals, and
`reward_position` is the centre — so nothing here could differ by being
bigger.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 019*.

| Shell | The room says |
| --- | --- |
| `shell_treasure_vault` | **this was protected** — door frames, a curb ring, a coffered ceiling |
| `shell_treasure_cache` | **this was stored** — racking and empties; the plinth is the pallet nobody took |
| `shell_treasure_coffer` | **this was displayed** — the ceiling steps up 0.90 m over the plinth |

| Image | What it answers |
| --- | --- |
| `R_vault_entry.png` · `R_cache_entry.png` · `R_coffer_entry.png` | the same camera in each |
| `R_coffer_under.png` | at the plinth, looking up — a closed recess, not a well |
| `R_corner_left.png` · `R_corner_right.png` | one design and its reflection |
| `R_corner_turning.png` | mid-turn, where `corner()` paints orange and this does not |

## The one thing I need you to rule on

`corner()` marks its turn with a **hazard-orange stripe** — orange used as
a navigation cue. Your Batch 010 ruling was that orange must remain warning
/ hazard language and that generic dressing gets neutral vocabulary
instead. A turn is not a warning.

So these corners carry no hazard material, and mark the turn by form: a
stepped chamfer on the far edge of the opening, a deep jamb reveal, and the
skirting carried around. The opening itself is the primary cue — at 6 m
across, nothing has to announce it.

That is **interface requirement 20**. I have not removed a gameplay cue on
my own authority; I have declined to spend orange on it and am asking what
should replace it. If the engine keeps its stripe, the chamber will
contradict the asset standing in it.

## And one thing the render caught

The two corners were **named backwards** in the first pass. `corner(+1)`
exits through the +X wall, and facing +Z a player's left *is* +X — so +1 is
the left turn. The review sheet disagreed with its own caption, and the fix
was the name rather than the camera.

Status: **PENDING**. Not self-marked.

**Tier 7 is complete**: 19 shells across six families.
