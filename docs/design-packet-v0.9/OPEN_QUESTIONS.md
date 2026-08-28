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

---

## Q3 — What is the ending, and what is the Hub afterwards?

**Status:** blocks S20 (authored campaign spine). Nothing else depends
on it, so every other v0.9 stage was finished around it.

### What is already decided, and is not in question

The campaign's **mechanical** spine is complete and tested:

- 30 Checks, three tiers of ten (`TIER_BOUNDS`, `TIER_COUNT`).
- The goal is Check 030, reachable only through the finale Zone.
- The finale unlocks at `FINALE_REQUIRED_OTHER_CHECKS`; the Hub already
  offers a separate finale portal when it does.
- `goal_sent`, `postgame` and the `ALL_CHECKS_CLEARED` Hub mode all
  exist, are validated (`postgame` requires `goal_sent`), and reach
  Godot in the snapshot.

**Epsilon's voice is also decided** and should not be re-litigated: wry,
proprietorial about the rooms it built, faintly apologetic. "Room clear.
I will pretend that was the intended route." Whatever the ending says,
it should sound like that.

### What is NOT decided

Nothing in the packet says what *happens*. Concretely:

1. **Does sending the goal produce an ending sequence?** Today the goal
   is sent and the Hub carries on. Options: nothing (the AP client's own
   completion is the ending); a short Epsilon monologue in the Hub; a
   dedicated scene.
2. **What is the Hub in the postgame?** `ALL_CHECKS_CLEARED` means
   nothing is left to play. Options: unchanged; visibly finished (Epsilon
   stops generating, the portal goes dark); or something that
   acknowledges the player is still there for the rest of the
   multiworld — which, in a real async multiworld, is the *common* case,
   because other players are still going.
3. **Do the three tiers have identity?** They are currently pure
   arithmetic. If they have names, moods, or a change in Epsilon's
   attitude as they progress, that is authored content and needs
   writing.
4. **Does Epsilon have a physical presence in the Hub?** S14 reserved an
   `epsilon_presence` anchor and put nothing in it, because "Epsilon is
   a voice" is a defensible answer and so is "Epsilon is a terminal in
   the corner". The anchor is there either way.

### Recommendation

Question 2 is the one worth answering first, and not for narrative
reasons: in an async multiworld a player reaching `ALL_CHECKS_CLEARED`
while others are still playing is *normal*, and a Hub that just stops is
a bug-shaped experience even if every test passes. The other three can
stay open indefinitely without hurting anything.

### What is already built

- Hub anchors for `postgame`, `epsilon_presence` and `main_portal`,
  tested to exist so an authored ending attaches rather than plumbs.
- The state distinctions an ending would fire on, tested to survive into
  a snapshot.
- `EpsilonVoice` already has a `finale_open` line pool, so a monologue
  has a home.

### What is NOT built, deliberately

No ending, no postgame behaviour, no tier names. Writing any of them
would be inventing a narrative decision the roadmap explicitly reserves.
