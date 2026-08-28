# v0.9 open questions

Decisions that block a stage and that the contracts do not settle. Each
one names what is already built, what is blocked, and what changes under
each option — so the answer is a choice, not a design exercise.

Nothing here is guessed at in code. Where a question blocks part of a
stage, the rest of that stage is finished and the hooks the answer will
need are in place.

---

## Q1 — How does an authored room shell honour a generator-chosen size?

**Status:** blocks the "convert existing chamber archetypes to graybox
shells" half of S15. The connector grammar half is done and shipped.

### The conflict

Every chamber archetype carries **continuous, generator-chosen
dimensions** (`bridge/archipepsi_bridge/schemas/zone.py`):

| Archetype | Generator chooses |
|---|---|
| `corridor` | `length` 6–30 m, `width` 4–10 m |
| `arena` | `width` 10–28 m, `depth` 10–28 m, `wall_height` 4–8 m |
| `platform_path` | `segment_count` 3–8, `gap_size` 0.5–`SAFE_BASE_JUMP_GAP`, `vertical_step` 0–`MAX_VERTICAL_STEP` |
| `tower` | `floors` 2–5 |

A `.tscn` is a fixed size. So an authored shell cannot honour a
continuous range, and converting the archetypes as written would mean
one of:

- **ignoring the requested dimensions** — a corridor is always 12 m
  whatever the generator asked for; or
- **a size mechanism** that does not exist yet.

### Why this is not a small problem

For `platform_path` it is an invariant, not an aesthetic. `gap_size` is
bounded by `SAFE_BASE_JUMP_GAP` **in the schema** — that bound is how
I3/I4 are enforced for platforming today, before any geometry exists. A
graybox with a baked gap escapes that enforcement: the gap becomes a
property of an asset nobody validates rather than of a value pydantic
refuses. The first oversized gap would be a seed that cannot be
finished, and the schema would have had nothing to say about it.

### The options

**A. Size variants.** A shell registers discrete sizes (`shell_arena_s`,
`_m`, `_l`) and the pipeline picks the nearest to the requested
dimensions. The registry already carries `variants` and `size`.
*Cost:* the generator's continuous range becomes effectively discrete;
an artist authors 3× the shells. *Keeps:* every existing schema bound,
untouched.

**B. Stretch zones.** A shell declares which spans may be scaled or
tiled (a corridor's middle section repeats; an arena's floor scales, its
corners do not). *Cost:* the most work by far, and the most ways for an
artist to produce something subtly wrong. *Keeps:* the continuous range,
exactly.

**C. Authored shells stop being sized by the generator.** Epsilon
specifies *intent* (`arena`, `combat`, `open`) and the shell's own
dimensions win; the schema's size fields apply only to procedural
chambers. *Cost:* a real change to what Epsilon controls, and
`platform_path` still needs its gaps validated some other way — most
likely the shell declaring them so the registry can bound them.
*Keeps:* authoring simple, which is the point of authored content.

### Recommendation

**A**, then **B** for the archetypes that turn out to need it. It is the
only option that changes no existing bound, and the registry fields it
needs are already there and validated. **C** is the one that needs your
decision most, because it moves authority away from Epsilon.

### What is already built for this

- `variants` and `size` on every registry entry, validated in both
  languages (a variant must be the same category as what it varies).
- `ContentInstantiator` resolves an id to an entry and derives the build
  contract from declared metadata, so a variant-picking step is one
  function, not a rework.
- `ConnectorGrammar.chainable()` proves a shell can be entered and left
  by the base kit, whichever option is chosen.

### What is NOT built, deliberately

No graybox archetype shells. Authoring five fixed-size shells before
this is decided would either bake the answer in as option C without
anyone choosing it, or produce five scenes that get rebuilt.


---

## Q2 — What licence covers bundled third-party assets and models?

**Status:** not blocking anything yet. Recorded because the moment it
blocks something is the moment a decision is needed, and that moment is
usually "we already committed the file".

Nothing third-party is bundled today. `test_packaging.py` fails the
instant a `.glb`, `.wav`, `.ttf` or similar becomes tracked, and its
message points here.

### What needs deciding, when it comes up

1. **Licence compatibility.** What licence is Archipepsi released under,
   and what asset licences are compatible with it? CC0 and CC-BY are
   usually fine; CC-BY-NC and most asset-store licences are not
   compatible with an open release.
2. **Attribution.** CC-BY needs a credits file that ships with the game,
   not just a line in the README.
3. **Fonts.** Almost always separately licensed, and almost always the
   thing that gets missed.
4. **AI-generated assets**, if any are ever considered: whose, under
   what terms, and whether that is consistent with
   `AUTHORED_CONTENT.md` at all -- the answer there is probably "no",
   since the whole document exists to say humans make the alphabet.

### What is already built

- No third-party binary is tracked, and a test enforces it.
- API keys come only from the environment; `.env` is ignored and git
  agrees; a test refuses any tracked file containing a key-shaped
  string.
