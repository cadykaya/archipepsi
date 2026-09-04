# v0.9 open questions

**Q1, Q2 and Q3 were answered on 2026-08-28. The decisions live in
`OWNER_DECISIONS.md`; the analysis below is kept as the record of what
was weighed, not as a live question.** Two items remain genuinely open
and are at the bottom: `challenge_marker`, and the finale pacing
question the owner raised once the campaign-scale work landed.

Each entry names what was already built, what was blocked, and what
changed under each option — so the answer was a choice, not a design
exercise. Nothing here was guessed at in code.

---

## Q1 — How does an authored room shell honour a generator-chosen size?

**DECIDED 2026-08-28 — `OWNER_DECISIONS.md` D1.** A hybrid of options A
and C: Epsilon emits spatial/design INTENT (archetype, size class, intent
tags, a shell id from a legal catalog), the authored shell owns its exact
measured geometry, and **Godot validates physical truth by measuring the
instantiated result** rather than trusting the shell's metadata. Size
variants are a vocabulary, not a mandatory triplication rule. No generic
stretching of gameplay rooms. The procedural fallback keeps its existing
continuous-dimension system.

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

**DECIDED 2026-08-28 — `OWNER_DECISIONS.md` D2.** Development-time
Claude-authored assets are first-party content once reproducibly
authored, reviewed, approved, committed and registered; **runtime**
Epsilon generation stays forbidden. Third-party assets are
first-party-by-default and need a full licence record before entering the
repo. The packaging gate becomes "first-party or an approved licence
record" rather than "no binaries at all".

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
4. **AI-generated assets** — answered: a *developer's* Claude-authored
   asset is first-party content once reviewed and registered. This was
   the item I guessed wrong about: I read `AUTHORED_CONTENT.md` as
   forbidding it, and the rule was always about RUNTIME generation, not
   about which tool a developer uses at their desk. Third-party
   AI-service outputs with unclear terms are still refused.

### What is already built

- No third-party binary is tracked, and a test enforces it.
- API keys come only from the environment; `.env` is ignored and git
  agrees; a test refuses any tracked file containing a key-shaped
  string.

---

## Q3 — What is the ending, and what is the Hub afterwards?

**DECIDED 2026-08-28 — `OWNER_DECISIONS.md` D3.** Check 030 produces a
short authored completion beat, not a cinematic and not forced credits;
the goal is sent normally and play continues. At `ALL_CHECKS_CLEARED` the
Hub is **finished but still alive** — portal dormant, shop complete,
Epsilon acknowledges, Lab and Archive still usable, AP connection active,
no forced exit. Final wording is not locked. Tiers get a presentation arc
but no player-facing names (D4).

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


---

## DEFERRED — `challenge_marker` world semantics

**The one genuinely open item.** Reaffirmed deferred on 2026-08-28.

No AP truth or progression may depend on it. The existing hook stays
dormant and is **not** removed. It is not to be guessed at until all of
these are defined:

- what starts a challenge
- what completes or fails it
- the retry lifecycle
- what local-only reward or record it creates

A challenge is not an excuse to give Epsilon authored content
(`AUTHORED_CONTENT.md` §7).


---

## OPEN — when should the finale actually become available?

**Raised by the owner, 2026-08-28, after CS0–CS10 landed. Recorded and
deliberately NOT acted on. `CAMPAIGN_SCALE.md` 3 is the full record.**

At the defaults, `FINALE_REQUIRED_FRACTION = 0.8` puts goal availability
at 360 of 449 Checks — exactly 24 Zones at 15 per Zone — against 30
Zones for a 100% clear. At the provisional 40 minutes per Zone that is
**~16 hours to the goal and ~20 to a full clear**, while the campaign is
described as ~20+ hours.

### Why it is open rather than fixed

Both hour figures are the 40-minute target multiplied out, and that
target is unmeasured. Retuning a real progression gate to satisfy a
number nobody has observed is the mistake this whole document exists to
avoid. It waits on the first 1000-budget human playtests.

### Why "raise the percentage" is not obviously the answer

| fraction | Checks | Zones | hours at 40m |
|---|---|---|---|
| 80% (current) | 360 | 24 | 16.0 |
| 85% | 382 | 26 | 17.3 |
| 90% | 405 | 27 | 18.0 |
| 95% | 427 | 29 | 19.3 |
| 100% | 449 | 30 | 20.0 |

Only 100% reaches the full-clear mark, and at 100% there is no early
finale left to gate — the choice the threshold exists to offer is gone.

### The candidates

1. **Increase the completion percentage.** Simple, and the table shows
   how little it buys short of removing the early ending.
2. **Expose `finale_check_percent` as a YAML campaign option.** Consistent
   with how the other three pacing levers were handled, and it makes the
   answer a per-seed choice rather than one global guess. Would need the
   same treatment as the others: bounded range, carried in slot data,
   owned by the save, tested at both ends.
3. **Adjust the intended Zone-time target.** If a 1000-budget Zone
   measures at 50 minutes, 24 Zones is already 20 hours and nothing
   needs changing.
4. **State both numbers and stop describing the campaign by one.** A game
   with an optional early finale honestly has two lengths. "~16 hours to
   the goal, ~20 to a full clear" may simply be the description.

### What must not happen meanwhile

The 20-hour figure may not be quoted as the campaign length while the
goal can normally arrive four hours earlier. Pinned by
`test_campaign_config.py::test_goal_availability_and_a_full_clear_are_different_numbers`.
