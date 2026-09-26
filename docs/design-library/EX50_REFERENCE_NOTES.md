# Source lock and interpretation boundaries

**Experiment date:** 18 September 2026. **Status:** design work, not a runtime audit.

This run uses the exact source copies in `source_baseline/`, recovered from the approved charter ZIP rather than the older loose notebook. Their SHA-256 digests match `source_baseline/SOURCE_MANIFEST.json`: notebook **0.11**, scope **0.3**, environmental direction **0.2**. The source notebook's thirty SP IDs and six worked explorations are not new EX50 entries and remain unchanged.

All EX50 arrangements, names, numbers, walkthroughs, proposed adapters and playtest predictions are newly authored proposals. None is an account of a player session. Commercial-game names in the source notebook are owner analogies; this experiment makes no new factual claims about specific Portal, Zelda, Destiny or Metroid rooms.

## Pinned written-design sources

Repository: `cadykaya/archipepsi`. Read-only baseline: **`c954b1eaf98ecbf3d69d991bf5fb82571397c83d`**. This is deliberately a named historical design baseline, not a claim about the latest branch. Source sections below were read through the connected repository, alongside the already supplied Amalgam excerpts. File blob hashes identify the returned files, not executed builds.

| Reference | Source and inspected subject | Consequence for this experiment |
|---|---|---|
| **R-SIGNAL** | `docs/design-proposals/01_RELIABLE_CORE.md` §§19.1–19.6; `06_THE_AMALGAM.md` §19. Blob `9ebb498c69d167ae6d10d73c6d064a072f1ce0f3` for D1. | Typed Boolean, pulse and value ports are different. TIMER refreshes on a new pulse; DELAY tracks both edges. Graphs are acyclic. Visible conduits report the same logic, but travelling light is not mechanical latency. |
| **R-INPUT** | D1 §§20.1–20.4; Amalgam §20. | A semantic class plate does not add small debris into a heavy object. `WEIGHT_THRESHOLD` is a different summed-kilogram sensor. A ranged receiver's source eligibility must be named. A remote target needs a reachable firing point, not floor directly under the target. |
| **R-MOTION** | D1 §§21.1–21.9; Amalgam §§21–21.11. | Command reversal is not power loss. A binary OFF command can return a mover; loss of power holds player-carrying machinery. Doors use closure interlocks. Rotating an internal assembly is not rotating the whole room. |
| **R-PHYSICS** | `02_PHYSICS_IS_THE_GAME.md` §§14.1–14.9, read especially 14.3–14.8; Amalgam §14. Blob `22af6fcdc396a5d16b5423a1a0b30f5f4c9d1c99`. | Force, range and mass eligibility matter. PIN is temporary; TETHER is not a permanent structural weld. Authored constraints are bounded. A field changing mass is not gravity; gravity is not a signal or electrical supply. |
| **R-STATUS** | `05_STATUS_AS_GRAMMAR.md` §§15.2–15.8, §20.5; Amalgam §§15.2–15.3. Blob `559910a7304bd02555856cb444699a0fdfb6c68d`. | Status names carry specific target and trait rules. Conductive propagates existing electric-hazard contact; it does not generate power. Brittle affects eligible objects/surfaces, not enemy damage multipliers. Temporary applications and compounds do not become permanent inventory upgrades. |
| **R-VERBS** | `03_THE_DUNGEON_IS_ONE_MACHINE.md` §§14.1–14.5. Blob `9286b7679b9d550cc0b566caa030d5a7bd5b7f0d`. | PROBE/BRIDGE/INVERT/HOLD_SIGNAL/CUT act on supported nodes, with legality and duration. No temporary signal verb directly sets a macro variable or becomes a required progression guarantee. |
| **R-PERSIST** | `06_THE_AMALGAM.md` §§5.2–5.6. Blob `ce1eba9c95f7d7d3bcc27ce9201add5d9460ade9`. | Saved accepted consequences, package-local object configurations, ephemeral signals and confirmed Checks have distinct lifecycles. Restore semantic facts before deriving live outputs. Never recompose a saved room to conceal a defect. |
| **R-PACKAGE** | Amalgam §§23–24 and their explicit pins to D1/D2/D3/D5. | Required offers, actual spatial compatibility, typed components, resets and reference solutions are separate from good gameplay. The written puzzle-family list is not evidence that every family has a working runtime. |
| **R-ACCESS** | Amalgam §§29.3–29.5a, §§30.1–30.3. | Qualify the usable loadout, not a name in the Archive. AP-relevant requirements need matching guarantees. Room-local baseline solutions can be required after validation; an optional tool-only route cannot quietly hold the sole allocated Check. Epsilon's authority is not widened by these designs. |
| **R-GRAVITY** | Packaged notebook §5.2, citing Amalgam §27 and D2 §27.5 at its recorded pin. | A local downward gravity-magnitude field is in the written vocabulary. Player-affecting mandatory routes and directional gravity are not inferred. The EX50 gravity example affects a declared object, not the player. |
| **R-OLD** | Packaged notebook §§3–9 and §14. | Lineage and nearest-neighbor comparisons use the actual six worked experiences plus the thirty seeds. An SP seed is an umbrella, not a completed mechanic to rename and count again. |

## Evidence labels used in every entry

**SPECIFIED-NOT-VERIFIED (S):** an inspected written design supplies the primitive; runtime support for this new arrangement has not been established.

**BOUNDED-EXTENSION (B):** a proposed additional component or binding. Its inputs, outputs, limits, save/recovery behavior and authoring burden are described in the entry. A proposed name is not an existing API.

**DEFERRED/NEW-SYSTEM (D):** a larger dependency; a candidate with an unresolved central dependency is not counted as revised-on-paper merely because it sounds attractive.

**RUNTIME-OBSERVED (R):** reserved for actually inspected implementation/evidence. No EX50 entry is claimed implemented or engine-tested in this writing experiment. The existence of earlier crate/plate evidence is not used to certify any new crane, carrier or circuit.

## Shared design assumptions, not newly enacted game rules

All room dimensions, masses, speeds, timer durations and encounter counts proposed in the entries are **untested prototype settings** unless explicitly attributed to a source. Coordinates use local metres with Y up; plan diagrams explicitly name their axes. Numerical examples are chosen to make the geometry discussable, not to certify it.

Local apparatus can supply a function without granting a permanent player ability. A local button is not an undocumented new control scheme. Input bindings are referred to by action, not by a new mandatory keyboard key. Any local manipulator not already expressible by the pinned parts is marked B.

A circuit's cosmetic wire never conducts real electricity unless the design explicitly uses the material-contact system. Turning power off is not a command to drop a supported body. An explicit latch/catch or command adapter is required wherever a description says 'move, then hold.'

A mandatory version of a room requires its own offered-shell fit, reachable arrival and objective, valid exits under its supported states, guaranteed local resources, and implemented validation. A prose witness or an abstract model does not supply that certificate. The models in this package, where present, examine only the state transitions they explicitly encode.

No normal generation, game source, save, player item, agent brief, or milestone was changed by this experiment. No private campaign save is included in the deliverables.
