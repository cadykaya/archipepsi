# Owner decisions — 2026-08-28

Decisions taken by the project owner that close v0.9 questions. **These
are later clarifications, not retroactive history.** The v0.8 packet said
what it said when it was written; where this document changes a rule, the
older text stays as written and carries a pointer here.

Anything below marked DEFERRED is still open and may not be guessed at.

---

## D1 — Authored room sizing and Epsilon's authority *(closes Q1)*

**Epsilon chooses spatial and design INTENT. Authored content owns exact
physical geometry. Godot validates physical truth.**

Epsilon does not emit `width=17.36`. For an authored room it emits a
bounded semantic vocabulary: archetype, a shell id drawn from a legal
catalog, a size class where useful (`small` / `medium` / `large`),
combat and traversal intent, openness, verticality.

An authored shell **owns and declares its own measured geometry**:
dimensions, sockets, mandatory traversal segments, gaps, rises and drops,
clearances, safe entry volume, enemy/objective/affordance sockets, size
class, intent tags, cost, legal variants.

**Godot decides whether that shell is safe.** Every mandatory traversal
segment is validated against shared engine truth — `max_safe_gap(step)`,
player clearance, and the base-kit invariants. *An art asset is not
trusted because its metadata claims it is safe.* Where practical the
instantiated geometry is measured, the way the S16 tower fix measures its
built ascent rather than reading its source.

Epsilon keeps real agency: it **may select** among a bounded list of legal
shell ids presented as semantic ids and metadata. It may not emit resource
paths, and may not invent dimensions for an authored shell. Selection
among otherwise-equivalent variants stays deterministic and replayable
under the project's existing generation guarantees.

**Size variants** (`arena_small_01`, `arena_large_01`, …) are good, and
are **not** a mandatory triplication rule — the inventory should carry
enough variety that size is a vocabulary, not a tax on every shell.

**No generic non-uniform stretching of gameplay rooms.** Explicitly
authored repeatable spans may exist later where safe (corridor middles,
wall bays, pipes, catwalk spans, trim runs) and must declare their repeat
axis and socket grammar. **Never** stretch a gameplay gap, staircase,
platforming segment or collision-critical feature to satisfy a requested
number.

**The procedural fallback keeps its existing continuous-dimension
system.** Authored mode is semantic selection with the shell owning
geometry; procedural fallback is bounded numeric generation. The safe
procedural system is not deleted because authored content now exists.

---

## D2 — Asset and licensing policy *(closes Q2)*

### Development-time Claude-authored assets are ALLOWED

A model or texture built by Claude during development becomes ordinary
**first-party authored game content** once it is reproducibly
generated/authored, reviewed, approved, committed, registered under a
stable id, and shipped as known content.

Still forbidden, and this is the part that matters: **runtime**
Epsilon-generated meshes, textures, shaders or audio; arbitrary runtime
asset or resource paths; executable runtime asset-generation
instructions.

The rule is therefore stated:

> **DEVELOPERS AUTHOR THE ALPHABET.
> GODOT ENFORCES THE GRAMMAR.
> EPSILON WRITES SENTENCES.**

This replaces the earlier "humans make the alphabet" phrasing. The
substance is unchanged — the boundary was always about *runtime
generation*, not about which tool a developer used at their desk.

### Third-party assets

Default is **first-party unless an external asset has been deliberately
reviewed.** Before any third-party binary enters the repository or the
shipped game, record: name, author/source, canonical URL, exact licence,
redistribution rights, modification rights, attribution requirement,
whether raw-source redistribution is permitted, and where attribution
must appear.

Safe by default: CC0/public domain, CC-BY with attribution, SIL OFL
fonts, permissively licensed code and tools.

**Not** accepted by default: NC, ND, unknown or unlicensed, copied or
ripped game assets, unclear AI-service outputs, and marketplace assets
whose licence permits use in a compiled game but forbids redistributing
the raw asset in a public repository.

A proprietary marketplace asset could be considered later for a packaged
build, but must never be committed publicly unless its licence explicitly
permits that form of redistribution.

The packaging gate evolves from *"all binaries forbidden"* to **"every
bundled binary is first-party, or explicitly registered with an approved
licence record."**

Project code licensing is a separate question and is not decided here.

---

## D3 — Goal, ending and postgame *(closes Q3 structurally)*

### Check 030

A **short authored completion beat**. Not a cinematic, not forced
credits, not a forced quit, and not a pretence that the whole multiworld
is finished.

1. the finale Check completes
2. the goal is sent normally
3. a brief Epsilon acknowledgement
4. return to the Hub
5. if unchecked Archipepsi locations remain, normal cleanup play continues

**Final wording is not locked.** Build the event and voice hook; do not
invent a scene to fill it.

### All 30 Checks cleared

The Hub becomes **finished but still alive**:

- the Zone-generation portal goes dormant / powered down
- no new Zones can be requested, because none exist
- the shop is inactive / complete
- Epsilon acknowledges it has finished constructing this campaign
- the Echo Lab stays usable
- the Archive / loadout stays usable
- the Hub stays inhabitable
- the Archipelago connection stays active
- the player may remain while the rest of the multiworld continues
- **no forced credits, no forced exit**

Presentation language may use **TRANSMISSION COMPLETE** and **MULTIWORLD
CONNECTION ACTIVE**. The alien computer stays alive; it does not
disappear or die because content ran out.

---

## D4 — The three progression tiers

**No player-facing names.** They stay the existing mechanical bands.

They may carry a **presentation arc in the Hub**:

| | |
|---|---|
| **Early** | Epsilon's intrusion is localized; the facility still reads as abandoned human infrastructure; Epsilon is observational, tentative |
| **Middle** | alien infrastructure is established; visible integration around Epsilon-owned systems; Epsilon is more confident, proprietorial |
| **Late** | Epsilon is thoroughly embedded; its systems visibly occupy more of the old facility; it is comfortable, assured about what it is building |

**Presentation only.** No change to Archipelago logic or progression
requirements. **Do not wash generated Zones in Epsilon green as tiers
advance** — source-game and Zone theme identity must stay legible.

---

## D5 — Epsilon's physical presence

Epsilon **has** a Hub presence: **a big alien computer / intelligence
embedded into an old abandoned research facility.** Not a humanoid robot,
not a mascot terminal, not a desktop computer, not ordinary human lab
equipment.

- **Facility language:** cold grey concrete, white and pale-blue painted
  walls, yellow utility lights, corridors, pipes, vents, rails,
  catwalks — institutional, industrial, abandoned, human-built.
- **Epsilon language:** genuinely alien technology embedded into and
  invading that infrastructure; hostile, uncanny shapes; neon-green
  active signal language; glowing, humming, strange sounds; asymmetry and
  invasive construction welcome; alive and technologically foreign.

The art lane owns the actual design. Engineering provides hooks.

---

## D6 — Visual ownership and colour semantics

**ARCHIPELAGO TRUTH IS NOT EPSILON.** Not every important object shares
Epsilon's neon-green language.

**Epsilon-owned:** the Epsilon presence, the alien portal phenomenon and
active portal components, the Epsilon-fabricated enemy family, Echo
interpretation machinery where appropriate, corruption and intrusion,
active alien conduits and energy.

**Checks are not Epsilon.** They represent Archipelago locations and need
their own universal repeated identity — the art lane's pedestal/beacon
concept, chosen because it reads across a room. Keep its signal language
separate.

**Source-game identity** is its own layer too, and Epsilon green must not
overwrite it.

**Echoes and portals are hybrids:** human/facility mounting or
architectural collar, plus the alien Epsilon event inside or through it.
That contrast must stay expressible in every material and asset contract.

---

## D7 — Enemy family

One Epsilon-fabricated constructed-creature family with clearly different
combat silhouettes. Art review currently maps: **stooped → melee,
tripod → ranged, squat → brute.**

Engineering does not hardcode aesthetic detail, and keeps separate
visual and telegraph sockets per role.

---

## D8 — Track semantics: unchanged

Tracks stay grouped per recipient **game**, not per recipient slot, with
`recipient_is_self` for the self distinction. Not to be redesigned unless
human playtesting shows a concrete problem.

---

## DEFERRED — `challenge_marker`

**Still unresolved. Not to be guessed at.** No AP truth or progression
may depend on it. The hook stays dormant and is **not** removed until
these are defined: what starts a challenge, what completes or fails it,
the retry lifecycle, and what local-only reward or record it creates.

---

## Art-lane integration gate

The art lane is in **STYLE LOCK 001-R** and its assets are **not
subjectively approved**. Pending assets may not be merged, integrated, or
promoted to shipped content merely because files exist. Engineering may
prepare stable hooks and contracts, and build neutral technical fixtures;
it may not recreate the art lane's production art or choose between
pending variants.
