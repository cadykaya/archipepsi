# Batch 036 (029-R) — the secret cue revision

**Status: PENDING.** Targeted fixes to evidence-backed failures only. The
concept is not reopened.

Batch 029's sheet was built as a test with a pass mark, and it returned a
verdict on itself: **five of nine read.** These are the corrections.

## One cue is DELETED, and that is the main decision

**`repeated_motif` is gone.** Its premise — count the marks, one bay has an
extra — needs the marks to resolve, and at 1998 texel densities and player
distance they do not. That is a **premise failure, not a tuning one**: three
more passes at mark size would have been three passes at the wrong idea.

The brief permits exactly this: *"It is acceptable to delete a cue whose
premise does not work in this rendering language. Target a SMALLER reliable
secret grammar over a larger unreliable one."*

The builder branch is **kept** rather than deleted, per this lane's standing
rule that a rejected alternative stays visible. It is simply not in the set.

## Three re-tierings and two repairs

| change | why |
|---|---|
| `wear_traffic` **subtle → learning** | it was the clearest cue in the whole sheet while carrying the hardest tier. The useful reading is not "make it harder" — it is that **wear is a strong channel**, so it should be the cue that *teaches* the grammar |
| `broken_construction` **learning → subtle** | it read easily at learning; the coursing change survives being halved, so it can carry the tier that lost its occupant |
| `light_leak` **strengthened** | too weak for a learning tier. The leak is wider and now **spills onto the floor** — a leak that exists only as a bright edge is a bright edge; one that puts light on the floor is a door that is not shut |
| `partial_sightline` **neon_transit → temple_ruin** | the cue was fine; the pairing was not. Neon transit's own trim is bright vertical lines, so a gap between panels competed with the decoration |
| `unreachable_space` **ledge lowered 2.62 → 2.15 m** | it sat above the frame at a 1.6 m eye, so it was never actually tested rather than failed |

## The grammar now

**Eight cues, not nine.** Four learning, three medium, one subtle.

| cue | tier | theme |
|---|---|---|
| `displaced_panel` | learning | concrete_facility |
| `light_leak` | learning | gothic_stone |
| `wear_traffic` | learning | concrete_facility |
| `construction_seam` | medium | concrete_facility |
| `service_access` | medium | rusted_industrial |
| `partial_sightline` | medium | temple_ruin |
| `broken_construction` | subtle | rusted_industrial |
| `unreachable_space` | subtle | void_glitch |

The principle is unchanged: **a secret cue is a deviation from a learned
environmental pattern**, every asset carries both the pattern and the one
place it fails, and there is no universal secret glow or colour.

## The recognition test is run again

`A_secret_cues.png` — captions name the pattern and the tier and still never
say which bay is wrong. Same rule: **if you cannot find it, that tier is
wrong.**
