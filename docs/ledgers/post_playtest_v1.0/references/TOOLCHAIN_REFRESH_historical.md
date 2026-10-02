# Archipepsi toolchain refresh — ECMS GLYPH and SigmAudio

Review date: 2026-09-22.

## Scope and status

This is a read-only repository review and an adoption recommendation, not a new implementation packet. Branch references, selected implementation paths, agent guides and reported verification were inspected. Neither application nor its tests was executed by this review; no rendered image was visually assessed and no audio was heard. No repositories, agent sessions, installations, subscriptions or existing projects were changed.

The last recorded Glyph handoff used main `727129e` and the separate Arty-tooling revision `6c80b63`. The last recorded usable SigmAudio code baseline was `ebd750e` (schema 11 / renderer audio-10); earlier discussions also inspected `2d208d7`. An agent's actual installed checkout must be checked on resumption rather than inferred from these historical references.

## 1. The versions that matter

| Repository / lane | Inspected revision | Meaning |
|---|---|---|
| cadykaya/ECMS-GLYPH — main | `727129e14ade02eee6ee8b21843d4cad6e03ed9b` | Still the older main implementation. Pulling main does not obtain the new roadmap features. |
| ECMS-GLYPH — claude/archipepsi-glyph-tooling | `6c80b6315912a70b44c28d566ddff608eafa234a` | The older Arty-specific tools branch. |
| ECMS-GLYPH — claude/feature-planning-roadmap-5oibiu | `ebe949b613b9426e22320ea87069641149ba46e0` | New artist-facing implementation, open draft PR #5, not merged at inspection. Candidate for an isolated authoring-tool upgrade trial. |
| cadykaya/SigmAudio — main | `2d76a5a3a6f77b5849ae0014178069ab642a6aa3` | Current main head. The comparison from `ebd750e` has twelve commits and four changed Markdown files; application code is still the established reverb baseline. |
| SigmAudio — codex/parameter-automation-2026-09-13 | `6897ce23f92dad6be13055e957049322e03999fe` | New development implementation: MIDI intake, selection/clipboard editing, saved-work protection, and advanced explicitly opt-in automation. Not a promoted release. |

Pin by full SHA for a trial. A branch name is discovery, not a reproducible version. Do not merge these branches into main or replace someone's installed build merely because this review inspected them.

## 2. Glyph: a material improvement to Arty's workflow

### 2.1 A direct drawing-and-looking interface

The new `packages/mcp` implementation serves Glyph over stdio. Render responses are encoded as PNG image content blocks rather than only returning paths or a numerical pixel array. Transactions can span calls within that process, and acting identity is fixed when the server starts.

Its default advertised surface is intentionally compact. `glyph_find`, `glyph_help` and `glyph_call` reach the larger command registry. An absent command in the initial tool list does not establish that the command is unimplemented.

This helps only when the agent's actual host accepts MCP and exposes image content to its vision input. This review did not connect such a host. The CLI/easel route remains available; there the agent must open the generated PNG separately. A successful render is not a visual review.

### 2.2 Authoring helpers are now part of the reusable tool

The roadmap incorporates the earlier derived-study work into `@glyph/easel`, with the old `tools/easel.mjs` path retained as a compatibility re-export according to the plan. The documented workflow includes scoped drawing, history, checkpoints/comparisons, integer-scale previews, tiled/value/checker studies, and construction helpers for shapes, lighting fields, palette ramps and dither.

`x-glyph.render_text` and `x-glyph.diff_text` expose a symbolic pixel grid. The documented cel round-trip uses the grid as a patch body. These are particularly useful when an unwanted pixel boundary is difficult to diagnose from enlarged previews alone.

The studio work includes timeline playback using the authored holds, onion skin, overlays/redlines, palette-ramp presentation and a repaired export dialog. These are reported implementations; this review did not exercise the UI.

### 2.3 New facilities relevant to the theme and UI backlog

The current core command surface includes `x-glyph.check_set`, `x-glyph.check_tiling`, `x-glyph.nine_slice`, `x-glyph.check_material`, and Godot sidecar commands. The material implementation additionally exports declared palette/ramp data, including a Blender palette-script option.

Recommended uses in Archipepsi:

- Repeating wall/floor/trim texture trials: inspect actual tiled output rather than treating one attractive tile as sufficient.
- Status/consumable icon families: compare a set at consistent native scales and on multiple backgrounds while preserving the approved semantic meanings.
- Equipment menu panels: author stretchable panel edges/corners with nine-slice metadata rather than making a separately distorted PNG for every widget size.
- Palette consistency between 2D textures and Blender assets: export the declared values instead of selecting them again by eye.

The new material facilities do NOT authorize a PBR/shader redesign. Preserve Archipepsi's existing material authority, approved style, semantic colours, protected symbols and texture roles. Validate colour-space interpretation against the actual game consumer rather than adopting a generic tool note blindly.

### 2.4 Animation and interchange

The branch implements APNG output, animation contact/volume diagnostics, declared-grid sheet slicing, autotile layout/map helpers, and Godot SpriteFrames/TileSet/NinePatch sidecars. These reduce repetitive hand-translation of an asset sheet's geometry into engine data.

For this 3D game, repeating-texture checks, UI panels and sprite/marker presentation are the immediate applications. An autotile table is not a new 3D room-composition system, and a SpriteFrames resource is not a rig or animation controller for the 3D enemies.

Sidecars remain generated text/resources to be saved and consumed at agreed resource paths. They do not automatically register assets in Archipepsi, establish collision correctness, or bind game state to animation.

### 2.5 Scene inspection improves, with a specific boundary

`x-glyph.render_scene` composites several declared placements in depth order and reports visibility/occlusion. Its implementation resolves variants from the current Glyph project at the selected revision. It is not an arbitrary cross-file importer.

The command is explicitly inspection-only: it creates neither canonical source artwork nor a production scene export. That improves the previous one-foreground/one-background review situation, but it does not justify claiming that unrelated `.glyph` projects can now be automatically merged into a persistent production composition. Inspect the installed API and deliberately arrange/import assets where required.

### 2.6 Verification and adoption

The current PLAN reports 511 tests with 510 passing. PR #5's body still reports an earlier 488/487 count, and HANDOFF.md contains older baseline counts. Use the pinned revision and its actual run output, not the nearest headline.

`GLA-PRF-001` remains an unresolved recorded certified-scale performance gate. The branch reports edit-path improvements on bounded workloads, but these do not replace the certifying measurement or prove the maximum-envelope gate passed. Do not weaken it or spend Arty's asset session repeatedly running the expensive certification benchmark.

Recommendation: try the new branch in a separate tool checkout, preserve the old working version, and verify one disposable edit/render/reopen/export loop before producing new project assets with it. Do not mass-migrate or re-render approved content just to use a new tool.

## 3. SigmAudio: useful updates, but not all belong in the team's default tool yet

### 3.1 Established source build remains useful today

Main still contains the existing external authoring workflow: editable Project JSON, source-bound draft editing, validation, authored-project critique, short WAV auditions, private-source bundles supplied explicitly, loop/stem/MIDI exports and a Godot handoff. The recorded production code baseline includes the verified reverb integration.

The new commits on main since `ebd750e` update status documentation. They do not install the newer automation or MIDI-editor work. Someone already using that main-code baseline will not receive those features merely by pulling main.

The existing portable executable is not established as rebuilt at either inspected head. Use an explicitly verified source build rather than identifying a binary by its filename alone.

### 3.2 New agent-accessible authoring on the development branch

The development branch adds these documented workflows:

- MIDI file inspect/confirm intake, including an `import-midi` CLI path, exact source hashes and explicit acknowledgement of conversion losses.
- Selected-note transpose, velocity, quantization and duplication using the source-bound edit envelope.
- Symbolic phrase copy/cut/paste across patterns, cues and projects, with explicit scope and compatible instrument/kit checks.
- Piano-roll navigation across MIDI 0–127 without changing authored pitches.
- Revision-checked saves, stale-window change notices and durable recoverable drafts, rather than silent overwriting by another window.

These are useful composition improvements, not proof that every automation feature is available in ordinary CLI/export.

MIDI conversion is intentionally not lossless. Its contract supports formats 0/1 with PPQ timing; rounds note boundaries to the supported grid; reports flattened tempo/meter changes; omits controllers such as sustain/pitch bend with warnings; and explicitly substitutes initial instruments. Imported notes are a starting draft, not a faithful reproduction of original performance or sound.

Use only original or appropriately authorized input material. A theme reference is not a requirement to reproduce a game's soundtrack.

### 3.3 Advanced automation is still an isolated development path

The new grouped AudioEngine work coordinates parameters, snapshots, state/layer changes and source revisions while preserving playing voices. Newer work covers read-off/resume and native a-rate/k-rate destinations.

The important status is equally explicit: this is opt-in development behavior. Ordinary GUI/AI/MIDI/export callers are not automatically promoted to it. The branch records retained native PCM/capture failures and unfinished parity/load/promotion work. New passing matrices do not erase unexplained prior failures.

That is not a reason to ignore the whole branch. It is a reason to separate a limited authoring trial (for example MIDI import and phrase editing without enabled experimental automation) from replacing the game's dependable audio-production path.

Schema 12 development projects must not be opened in an older schema-11 app expecting down-conversion. Keep projects, tool SHAs and rendering receipts together. Test the actual intended render/export route in the candidate checkout before using it for a deliverable.

### 3.4 The Godot limits have not disappeared

I inspected `src/export/godotRuntime.ts` in main and checked its blob SHA on the development branch: both are `d33a636b6a77bfa19df485efc246934bfe87771c`.

The adapter supports synchronized layers and supported parameter/event-driven state transitions. It explicitly reports these limits:

- At most 32 exported synchronized layers; this is distinct from the 128-track authoring limit.
- No rendered stinger audio or stinger ducking.
- No cross-cue sequencing.
- No sample-accurate transition-automation guarantee.
- No runtime switch into a state whose resolved snapshot processing differs from the baked mix.
- Separately rendered stems are not guaranteed to sum exactly to the combined mix when nonlinear shared processing is involved.

Consequently, a richer DAW automation branch does not automatically give Archipepsi dynamic runtime filter/reverb changes or a stinger API. Use the exported capabilities, and implement any additional game-side behavior deliberately through the game's audio ownership rather than assuming the pack supplies it.

No retrieved command establishes that an AI listened to the sound. Rendered measurements, auditions delivered to a listener, musical judgments and owner approval remain separate.

## 4. Recommended rollout to the team

This is a tool refresh, not another scope expansion or an instruction to stop all current verification.

### Arty

At a safe checkpoint, trial Glyph PR #5 at the pinned head. Read `AGENTS.md` and `USING_GLYPH_AS_AN_AGENT.md`, then discover actual commands. Use it first on one disposable repeating texture or icon/panel candidate. Validate edit -> render -> actual image inspection -> close/reopen -> export. Preserve author/owner attribution and keep candidates separate from owner-approved art.

Then use relevant helpers for the existing kit and theme queue. Blender still owns 3D mesh authoring. Glyph does not supersede the game's texture roles, material loader or review process.

### Prod

Treat the new Glyph sidecars and SigmAudio pack as content inputs to existing game-owned integration. Prove an exported panel/marker and one audio cue in an isolated scene before bulk replacement. Retain authoritative event timing; a preview animation or an audio layer does not decide whether machinery has completed.

Use a working SigmAudio main source build for immediate established audio needs. A separate development checkout may be tried for clearly supported authoring improvements, without enabling the unfinished automation engine or converting the entire asset library.

### Dess

Help define cue intent and state relationships from actual gameplay: exploration/anticipation/combat/accepted machine change are distinct, and a musical description is not an implemented transition. The exported audio capability table is the boundary. The room-research reports may inform the brief (recognition, information, consequence), but do not replace later owner decisions or current engine contracts.

### Small, useful smoke deliveries

1. Glyph: one new repeating texture and one nine-slice/icon candidate with editable source and the exact resource export.
2. SigmAudio: one short original Blindside cue with two supported layer states, editable source, a short audition and a canonical game pack. Keep baked processing compatible across those states.
3. Prod: use those exports in an isolated copy of an existing gameplay scene, checking actual image sampling and audio state changes. Do not replace approved production assets before review.

These are recommended adoption checks, not additional approvals or assignments already dispatched.

## 5. Commands for the installed checkouts

Glyph, from the isolated candidate checkout (Node requirement in package.json: >=22.5.0):

```sh
npm ci
npm run build
node packages/cli/dist/main.js doctor
```

For an existing disposable project with an agent actor already granted access:

```sh
node packages/cli/dist/main.js mcp trial.glyph --actor act_agent_arty
```

The host must deliberately connect that stdio server and support images. Without that host integration, use the CLI/easel workflow and open the resulting PNG with the host's image-viewing tool. Do not assume the assistant in this conversation acquired a Glyph MCP connection.

SigmAudio, from the chosen source checkout:

```sh
npm ci
node tools/sigmaudio.mjs doctor --json
node tools/sigmaudio.mjs doctor --render --json
node tools/sigmaudio.mjs describe
```

Use the matching checkout's `docs/AI_QUICKSTART.md`. Discover exact cue, instrument, editing and capability fields rather than replaying commands from a newer branch against an older install.

No instruction here schedules work, alters billing, requests model credentials, dispatches agents, approves artwork, merges a tool PR, or changes original saves. Keep the team's no-watchers/no-heartbeat rule.

## Source index

All source observations above are tied to immutable revisions. Repository reports of test execution are not this review's independent execution.

- Glyph branches and open PR: repository branch listing; PR #5, `ebe949b613b9426e22320ea87069641149ba46e0`.
- Glyph agent surface: `AGENTS.md`, `USING_GLYPH_AS_AN_AGENT.md`, `packages/mcp/src/core.ts`, `packages/mcp/src/server.ts` at that revision.
- Glyph workflow/reporting: `PLAN.md`, `HANDOFF.md`, `package.json`, `packages/cli/package.json` at that revision.
- Glyph implementation boundaries: `packages/protocol/src/commands/extensions/scene.ts`, `material.ts` and the extension directory at that revision.
- SigmAudio main comparison: `ebd750e96f2cc7cbfa388d062d86fa2e268044fd...2d76a5a3a6f77b5849ae0014178069ab642a6aa3`.
- SigmAudio production workflow: `README.md`, `AI_README.md`, `docs/AI_QUICKSTART.md`, `AI_PRIMARY_PLAN.md`, `src/export/godotRuntime.ts` at main `2d76a5a3a6f77b5849ae0014178069ab642a6aa3`.
- SigmAudio new development status: `AI_README.md`, `docs/MIDI_FILE_IMPORT.md` at `6897ce23f92dad6be13055e957049322e03999fe`.
- Identical Godot adapter: `src/export/godotRuntime.ts` at both SigmAudio revisions above.
