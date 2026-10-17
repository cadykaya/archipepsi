# The Amalgam: what's built, what's only on paper

**Dess, 2026-10-17. A read-only inventory, text only.**

- **Spec:** `docs/design-proposals/06_THE_AMALGAM.md`, with its `_AUDIT`
  and 07/08.
- **Code read:** `integration/unified-1` `57ac4662`.
- **Method:** the ledgers (`05_INHERITED_0_4_QUEUE.md`, `AMALGAM_BRIDGE.md`,
  `PROD_POST_PLAYTEST.md`, `DESS_POST_PLAYTEST.md`) checked against the
  code. The ledger statuses date from `a745637` and are partly out of
  date. Spot-checked by hand:
  - `SUPPORTED_NODE_KINDS` and `SUPPORTED_SENSOR_KINDS`
    (`schemas/signal_graph.py:88, 97`);
  - `SUPPORTED_STATUS_TARGETS` (`echo.py:569`);
  - `SUPPORTED_GEAR_DOMAINS = ()` (`gear.py:83`);
  - `Zone.zone_state` capped at 4 (`zone.py:1571`);
  - no `POWER_OFF` or `PendingMacroChange` code, only a comment
    (`constants.py:1309`).

**Scope note.** The Amalgam is the **accepted 0.4 commitment** ("The 0.4
commitment remains the accepted Amalgam", RIFT §0.4). It is not 0.5, so
the "do not begin 0.5" hold doesn't cover it.

**What stays closed (owner holds):**
- **H-AP-GATE:** capability events in AP logic, DESS-28;
- **the Gear G1 gate;**
- **the Forge/Static economy** (B4);
- the spec's own §2.2 deferrals and §2.3 removals.

---

## 1. Status by part

**Key:** B = built; P = partial; N = not built; H = held; D = deferred or
removed by the spec.

| § | Part | Status | Evidence | Missing |
|---|---|---|---|---|
| 2.2 / 2.3 | Water, portals, gases, beams, directional gravity, programmable logic, rotating rooms, in-Zone loadout | D | 06:187-206 | — (a `water_volume` tag exists, 07 §7) |
| 4.2–4.6, 11, 12 | HostDefinition, atom alphabet, budgets, weapon space, action grammar | **H / N** | No `HostDefinition`; the engine uses its v0.8 primitives (`echo.py:341-418`) | The whole atom grammar (H-ATOM-DELIVERY) |
| 4.9a | TopologyEdge | P | `schemas/graph.py:121` | `connector_kind`, and the 12-value `crossing` (carry legality per edge) |
| 4.10 | State vector | P | `physics.py:167, 171, 722` | Macro variables capped at 4 vs the spec's 2–8 |
| 5.1 / 5.2 / 5.4a | Persistence categories, environmental agency | B | `protocol.py:508`, `ZoneProgress.macro_state` | Enemy resume (O05-03.3) |
| 5.5 | Latching | B | `transitions.py:758`, `signal_graph.gd` | — |
| 5.6 | Save/load order | P | `graph.py:100`, `protocol.py:236-250` | One ordered restore pipeline; step 7 (pending macro) |
| 13.6a / 29.1 / 29.3 | `manipulate` capability | P / **H** | `physics.py:202, 218` (uncalled) | Gating on it is held (H-AP-GATE). The numeric envelope conflicts with `zone.py` (07 §4). |
| 14 | 12 manipulation verbs | B (runtime) | `manipulation.gd`, `verb_*.gd` | Echo delivery (held); weld persistence |
| 15.2 | 13 Statuses | P | `echo.py:652` family; `:569` declares 3 targets | Runtime for 9 Statuses. Declare the done kinetic pair (N-17). `exposed` vs `vulnerable` undecided. |
| 15 | 8 compounds | N | — | All |
| 16 | Gear / Mods | **H** | `gear.py:83` | Waits on D-8 |
| 18 | Forge / Static economy | **H** | B4 pending | All. (`forge_screen.gd` is the D-22 Crossing Forge, a different thing.) |
| 19 | Signal graph nodes | P | 11 declared; 4 supported (NOT, LATCH, OR, TIMER) | AND, DIRECT, SEQUENCE, COUNTER, SELECTOR, DELAY, THRESHOLD |
| 19.7 | Machine graph | P | `zone_state.gd`, `zone_state_build.gd`, `state_gates.gd`, `cross_room.compose_zone_state` | Only the opt-in candidate composer emits it |
| 20 | 18 sensors | P | 3 supported | 15, including MACRO_*, STATUS_*, WEIGHT_THRESHOLD, HACK_TERMINAL |
| 21 | 12 actuators, 8 constraint kinds, power loss | B (runtime) | `actuator.gd:299`, `constraints.gd` | Power loss has no live use yet |
| 21.11 | 10 macro effects, POWER_OFF guard, PendingMacroChange | N | — | All |
| 22 | Hacking | N | — | All |
| 23.1 / 23.5 | Manifest, validation pipeline | P | `layout.py:881-1053`, `replay_harness.gd` | A `ZoneManifest` with provenance (§30.11.7); most numbered §30.5 checks |
| 23.4 | Reset groups | N | — | All |
| 24 | 34 puzzle families | N (~5 %) | 4 `ActivityKind`, 3 minors, levers, Crossing D | Most. They depend on the rows above. |
| 26.7 | Rails ⟂ constraints | P | `RailNetwork` (`zone.py:955`), runtime switches | Bridge switch schema (N-19); RB-F4 |
| 28.8 | 24 offer types | P | 4 kinds (`room_contract.gd:139`) | 20 |
| 29.5a | AP contract / check 23 | B (reduced) | `topology.py:1767, 1908` | AP integration (held) |
| 30.1 / 30.11 | Epsilon picks shells | P | `shells.py:206-237`, `zone.py:2518` | Provenance digest; named offline selector |
| 30.2 | Zone shape | P / disagrees | 1–40 rooms; spatial cycles refused (`zone_builder.gd:206`) | The spec wants 8–12 rooms and 1–4 cycles |
| 30.6 | Model check | P | `topology.reachability` | Physics properties 4–8; budget bound |
| 30.7 / 30.12 | Checkpoints, lifecycle | B | `warp_station.gd`; `protocol.py:111-150` | Only one held Zone at a time |
| 35 | Performance budgets | N | — | All |

---

## 2. The build order, for what isn't held

Size: S, M or L. Each stage keeps the repository's own checks green and
is reviewed before the next.

1. **N-17, declare the kinetic-pair Status targets** (S). `echo.py:569`,
   then regenerate `constants.gd`. The runtime already exists.
2. **N-19, rail switch schema plus switch-aware search** (M).
   `zone.py RailNetwork`, `topology._route_rails`, `rail_networks.gd`.
   Unblocks RB-F4.
3. **`TopologyEdge.crossing` and `connector_kind`** (M). `graph.py`,
   `topology.py`, `layout.py`. Needed for carry legality (§30.6 property
   4).
4. **The remaining graph nodes and sensors** (M–L), each landed only with
   a real consumer. `signal_graph.py`, `signal_graph.gd`, `room_graphs.gd`.
5. **The production composer emits zone_state; the gantry composer (D-6
   step 4); a retry composes the same Zone (N-20)** (M). `cross_room.py`,
   `candidate.py`, `composition.py`, `topology.py`.
6. **Macro effects, POWER_OFF guard, PendingMacroChange** (L; needs 4–5).
   `zone_state.gd`, `actuator.gd`, `protocol.py`, `transitions.py`.
7. **The other Statuses, then compounds, then status sensors** (L).
   `status_effects.gd`, `enemy.gd`, `player.gd`, `echo.py`.
8. **Reset groups and weld persistence** (M).
9. **The committed manifest with provenance, plus the offline selector**
   (M). `layout.py`, `epsilon/fallback.py`, `transitions.py`.
10. **Spatial cycle closing** (L). `zone_builder.gd`, `layout.py`.
11. **Hacking (M), then §24 families (L), then §35 performance (M).**

**Ownership.** Stages 1–3, 5 and 9 are in Dess-owned bridge files. The
others touch the engine runtime, which is Prod's (§4).

---

## 3. Where the spec and the engine disagree (my reading, carried forward)

| Point | Disagreement | My reading |
|---|---|---|
| **Rigid bodies** | 07 §3's "no rigid-body physics" is out of date (`ManipulableBody`, `constraints.gd`). | The engine is right. Fix the stale comment at `graph.py:73-76`. |
| **`manipulate` envelope** | 700 N / 20 m / 120 kg vs `zone.py`'s set-membership rule | Leave it ungated; it's held under H-AP-GATE. |
| **Zone shape** | 8–12 rooms and 1–4 cycles vs the engine's 1–40 rooms and no spatial cycles | The engine stands until stage 10. |
| **Macro variables** | 8 in the spec vs a cap of 4 | Raise the cap only when stage 6 needs it. |
| **COMPLETE re-entry** | §30.12.1 says no; the owner ruled yes (2026-09-11, and D2 on 2026-10-17) | **The owner's ruling wins.** |
| **`exposed` vs `vulnerable`** | Open | ★ Treat `exposed` as the existing `vulnerable`, renamed in the vocabulary only. **For Skyiah.** |
| **Families, sensors, offers** | 34 / 18 / 24 in the spec vs 4 / 3 / 4 built | Build only with consumers (stages 4 and 11). |

---

## 4. What needs Skyiah

1. **Building it.** Stages 1–11 mean code on **a new branch**, proposed as
   `claude/dess-amalgam` off `integration/unified-1`, plus Prod
   coordination for the engine-side stages. **Dess's standing branch rule
   needs her direct go-ahead in this session.** So far it has only been
   relayed through Condi.
2. **★ `exposed` = `vulnerable`?** My pick: yes, a rename only.
3. **The holds** (H-AP-GATE, Gear, Forge economy) stay closed. Any stage
   that needs one is skipped.
