# What automation cannot complete

The v0.9 roadmap's final requirement: an explicit list of work that no
amount of autonomous iteration will finish. Each item says **why** it is
blocked, because "needs a human" and "needs a human *for this specific
reason*" are different amounts of useful.

Nothing here is a bug, and nothing here is waiting on more testing.

---

## 1. Authored art, audio and models

**Why automation cannot do it:** `AUTHORED_CONTENT.md` is the reason,
and it is a rule rather than a limitation. **Humans make the alphabet.**
Generating "final art" procedurally to close an authored-content stage
is explicitly forbidden, and doing it well would be worse than doing it
badly — it would look finished.

**What exists instead:** every procedural asset is registered with
`procedural_fallback: true`, which is the registry stating plainly that
it is generated geometry. The pipeline resolves *authored scene if
available → validated placeholder otherwise*, so an artist replaces one
asset at a time with no flag day.

**What a human needs to do:** model things, to `docs/ART_ASSET_SPEC.md`.
That document exists so the answer is "follow the spec" rather than "ask
which way is up" — units, axes, origins, collision, sockets, naming,
materials, LOD, import settings, and the five-step "add an asset without
touching generator logic".

---

## 2. The three open design questions

`OPEN_QUESTIONS.md` states each precisely, with options, costs and a
recommendation.

| | Blocks | Why a human |
|---|---|---|
| **Q1** | graybox archetype shells (S15) | Moves sizing authority between Epsilon and the asset. Picking one silently is picking for you. |
| **Q2** | nothing yet | Licence compatibility is a legal choice about how the project is released. |
| **Q3** | the ending and postgame (S20) | Narrative. The roadmap explicitly reserves it. |

Q1 is the one with a code consequence worth restating: `platform_path`'s
`gap_size <= SAFE_BASE_JUMP_GAP` is enforced **in the schema**, and that
bound is how I3/I4 are held for platforming today. A fixed-size graybox
with a baked gap escapes it. Authoring shells before Q1 is answered
would silently choose option C.

---

## 3. Playtesting

**Why automation cannot do it:** every invariant that can be stated has
a test. What is left is whether the game is *good* — whether a 4.5 m gap
in the Echo Lab reads as a challenge or as a bug, whether Epsilon's
voice is charming or grating at hour three, whether the reveal moment
lands.

The suites can prove a check is claimable. They cannot prove claiming it
feels like anything.

**What a human needs to do:** play it. `make doctor` says whether the
clone is ready; the README has the route.

---

## 4. The real-multiworld cases that need other people

Dual-Archipepsi is proven (`make dual-real-soak`, ten properties, two
slots in one real multiworld). What is not proven, and cannot be by one
machine:

- A multiworld with **other games'** worlds in it, over a real network,
  with real latency and real disconnections.
- An **async** game running for days, where the interesting states are
  "the other player was offline for two days and came back" and
  "everything cleared while others still play" (which is Q3's question 2,
  and the reason it is the one worth answering).
- A **race-mode** room. The client refuses to scout in one, deliberately
  and with a test — but refusing correctly and behaving well are
  different things.

---

## 5. Judgement calls that look like bugs

Two things are currently *deliberate* and would be reasonable for a
playtester to report. Both need a human to say which way they go:

- **The Echo Lab's gap is 4.5 m**, inside the base kit's flat reach
  (4.667 m) and well outside the safe mandatory gap (2.6 m). It is meant
  to be crossable but not comfortable. If it reads as broken rather than
  as a demonstration, that is a design change, not a fix.
- **A Check reveals its recipient GAME but not its item** before it is
  claimed. That is deliberate (themes derive from the game) and enforced
  in both directions. Whether it gives away too much is a taste call.

---

## What automation HAS finished

For contrast, and so this list is not read as "v0.9 is stuck":

- CI in three tiers, green on real runners, with a documented
  failing-step → broken-layer table.
- The content registry and asset contract, in both languages.
- The instantiation pipeline, with the placeholder route pinned to
  produce exactly what the builder produces.
- Hub anchors, the Echo Lab's mechanical dimensions, the connector
  grammar, the presentation contract, the visual/mechanical separation,
  the Epsilon vocabulary audit, settings and rebinding, first-run and
  secrets.
- A real I3/I4 violation found and fixed (the tower asked for a 2.4 m
  mandatory jump where the bound was 2.0), and the bound exported to
  GDScript so no builder has to guess again.
