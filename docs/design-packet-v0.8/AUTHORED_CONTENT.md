# Authored Content — the boundary Epsilon does not cross

**Status: authoritative.** This document is normative for what Epsilon may
author and what it may only arrange. It constrains future art and content
work; it does not describe work already done.

> **HUMANS MAKE THE ALPHABET.
> GODOT ENFORCES THE GRAMMAR.
> EPSILON WRITES SENTENCES.**

---

## 1. The rule

> **If it must be recognizable, mechanically trustworthy, or repeatedly
> seen, humans and game code author it. If its value comes from surprise
> and recombination, Epsilon composes it.**

Epsilon is **not an asset generator.** It does not own anything whose
value depends on consistency, readability, identity, repeated exposure, or
exact mechanical dimensions.

This is a boundary about *kind of value*, not about difficulty. A thing
does not become Epsilon's because it would be tedious to author, and it
does not stay ours because it would be hard for Epsilon. The question is
always: does this thing get better when it is the same every time, or when
it is different every time?

Three failure modes the rule exists to prevent:

- **A door you cannot recognise as a door.** Anything the player must read
  at a glance, under pressure, in an unfamiliar room, has to look the same
  in every room. Novelty is a cost here, not a feature.
- **A ledge that is 1.4 m in one Zone and 1.9 m in another.** The player
  learns the jump once. A generator that varies it has not added variety,
  it has made the jump untrustworthy — and I3's movement floor exists
  precisely so that what you learned stays true.
- **An Epsilon that is a different character each time you meet it.**
  Epsilon has a voice and a presence. Both are identity, and identity is
  the thing repetition builds.

---

## 2. Authored by humans and game code

Not Epsilon's, at any creativity setting. Each of these is either an
identity the player learns, a surface the player must read instantly, or a
dimension the player's muscle memory depends on.

### Spaces the player returns to

| | Why it is authored |
| --- | --- |
| Hub | Seen more than any Zone. It is the game's home and its progression display. |
| Echo Lab | Its whole purpose is a known quantity to measure new mechanics against. A Lab that varied would measure nothing. |
| Finale space and its architectural spine | Arrival has to land. It lands because it is the one room built to be arrived at. |
| First-run / onboarding / first Zone | The most constrained space in the game. Everything the player learns later, they learn to read here. |

### Identity and presentation

| | Why it is authored |
| --- | --- |
| Epsilon's physical and presentational identity | A character, not a style. |
| Check object and reveal presentation | The single most repeated moment in the game. |
| Echo acquisition presentation | The payoff beat; it must read the same every time to mean anything. |
| Shop terminal, Archive, loadout presentation | Read under no time pressure but read *often*; consistency is legibility. |
| Hub progression visuals and postgame state | Progression is only legible against an unchanged frame. |
| Loading, generation and failure presentation | Especially failure: the moment the player most needs to trust what they see. |

### The player's own body and their opponents

| | Why it is authored |
| --- | --- |
| Player viewmodels and first-person animations | Twenty hours of looking at them. |
| Enemy archetype models, silhouettes, animations, **telegraphs** | A telegraph is a promise. A generated telegraph is a lie waiting to happen. |

### Anything the player must read to move correctly

| | Why it is authored |
| --- | --- |
| Objective and interactable objects | "Can I use this?" must never be a guess. |
| Movement affordance visuals | The seven §13 affordances look the same everywhere or they teach nothing. |
| Doors, portals, elevators, transitions | Navigation vocabulary. |
| Navigation and signage language | Same. |
| HUD/UI layout and accessibility cues | §7's fifteen channels are pre-laid and never reflow, for this reason. |

### The vocabularies compositions are made from

| | Why it is authored |
| --- | --- |
| Materials | |
| VFX vocabulary | |
| Audio vocabulary | |
| Lighting and atmosphere presets | Epsilon *selects* a preset; it does not author one. |
| Sky and background packages | |
| Reusable prop library | |
| Environmental storytelling clusters | |
| Authored encounter templates | |
| Authored traversal motifs | |
| Reusable room connectors | |
| Reusable landmarks and hero props | |
| Authored room shells and room seeds | |

---

## 3. The five authoring levels

Reusable authored content is built at whatever scale is useful, and the
levels exist so that a piece of content has an obvious home and an obvious
granularity of reuse.

| Level | What it is | Example |
| --- | --- | --- |
| **0** | Props and details | a crate, a sconce, a cable run |
| **1** | Architectural modules | a wall section, a stair, a doorway |
| **2** | Composed alcoves, stations, perches | a lit alcove with a prop cluster |
| **3** | Room shells | a corridor shell, an arena shell |
| **4** | Landmarks and set pieces | the finale spine, a Hub feature |

Epsilon selects and arranges levels 0–4. It does not create at any level.

---

## 4. Epsilon's half: composition and selection

Epsilon owns the sentence, and the sentence is where the game's premise
lives. A foreign item becoming a locally-meaningful Echo is a *reading*,
and a Zone built around it is a *composition*. Neither needs new geometry
to be surprising, and constraining Epsilon to authored vocabulary makes
its output better rather than poorer: recombination reads as intent when
the pieces are recognisable, and as noise when they are not.

- Zone concept and theme
- Room graph and pacing
- Selection and arrangement of **legal authored modules**
- Encounter composition, from the authored encounter vocabulary
- Traversal combinations, from the authored motifs
- Optional affordances (§13 — optional is the operative word; see I4)
- Dressing choices
- Lighting and atmosphere **preset selection**
- Item interpretation and the Echo recipe (§15, `ECHOES.md`)
- Flavour text and dialogue

---

## 5. Godot's half: the grammar

Godot is the physical authority and refuses anything that would be unsafe
or illegal, whatever Epsilon asked for. This is already how the boundary
works and this document does not change it.

- Legal dimensions
- Collision
- Mandatory-path safety (I4)
- Spawning
- Mechanical affordance truth (I12)
- Actual asset instantiation
- Performance limits

A composition that violates the grammar is refused, not clamped into
something the player then has to survive.

---

## 6. Where we are now: placeholder, and the debt

**Every visual in the game today is procedural, and all of it is
placeholder.** There are zero imported assets in `godot/` — no meshes, no
textures, no audio files. Textures are generated at 64×64 in
`generation/textures.gd`, materials in `generation/theme_materials.gd`, and every
room, prop, enemy and fixture is built from primitives in code.

That was correct for a POC and it is **debt against this document**, not a
design. Recording it as debt rather than removing it: the placeholders are
load-bearing for every test in the frontier, and ripping them out before
authored content exists would leave the game unrunnable and the suites
untestable.

The specific conflicts, so later work can find them:

| Where | The conflict |
| --- | --- |
| `generation/chamber_builders.gd` | Builds room shells (level 3) procedurally from primitives. Should become *selection* among authored shells. |
| `generation/affordance_features.gd` | Builds the seven §13 affordances as primitives with per-tag footprints. The footprints and clearances are grammar and stay; the geometry is level 2 content and should become authored. |
| `generation/textures.gd`, `generation/theme_materials.gd` | Generates the material vocabulary. Materials are authored content; this is a placeholder vocabulary, not a generator to keep. |
| `hub/hub.gd`, `hub/echo_lab.gd`, `hub/lab_fixtures.gd` | The Hub and Lab are built in code. Both are explicitly authored spaces; these files are the strongest debt in the list. |
| `enemies/enemy.gd` | Archetype silhouettes are primitives. Silhouettes and telegraphs are authored. |
| `ui/`, `generation/source_identity.gd` | HUD and per-source identity are procedural. The *rules* (the sha256 glyph/palette derivation, §12) are grammar and stay; their rendering is authored. |

**None of this is Epsilon's to fix.** Replacing a procedural placeholder
with authored content moves the work from Godot to a human, never to
Epsilon. If a future change would move any row above into Epsilon's half,
that change is out of contract.

---

## 7. What this document does not settle

`challenge_marker` world semantics remain open (see `AGENT_FRONTIER.md`).
This document does not decide them, and a challenge is not an excuse to
give Epsilon authored content.
