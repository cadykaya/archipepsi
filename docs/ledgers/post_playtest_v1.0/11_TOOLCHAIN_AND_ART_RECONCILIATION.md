# 11 — Toolchain and art reconciliation

## 1. The current cross-lane discrepancy

Arty's preserved `4093ded` delivery says the next pack lacks a material namespace and proposes alternatives. Later Prod/Dess deliveries have already settled and implemented D-11. Do not send Arty back to design a loader or describe this as waiting for the same decision. The remaining work is to **consume the delivered format**, produce appropriate material treatments and obtain review/selection—not to invent another schema. [S04, S06]

Prod's OV05 queue says no approved ready models/packs were available to bind. Arty's archive contains seven in-progress content kits. These statements can both hold: available candidate content is not an approved, selectable, integrated material pack. Reconcile by asset/revision/status rather than declare every Art delivery missing or promote all candidates.

## 2. D-11 contract to hand directly to Arty

`Zone.theme` remains one of six house families. `Zone.theme_pack` is separate and optional. A sibling **flat `pack_textures` table** uses keys `<pack>/<theme>/<role>` and the same fields as existing family texture rows. The bridge validates rows against the actual descriptor schema. Do not create a seventh house theme for each game or a separate folder-specific loader.

Resolution: exact pack/theme/role first; if absent, the unchanged family chain, including its existing one role fallback. The pack takes no fallback step of its own. Cache identity includes pack/theme/role; the Hub binds no pack, and teardown of an old owner must not clear a new owner's binding. Universal hazard roles remain universal; a pack cannot recolour them. [S04]

Candidate rows make artwork reviewable; selectable/approved status controls whether a Zone may name it. The source registry was empty at the handoff. A test-only pack does not establish production selection. Owner approval remains distinct from an agent's technical/import review. A controlled visual review mode is not permission to fake `approved` just to pass validation.

Arty must update her older README/frontier blocker with the consumed D-11 revision, without pretending her original report was wrong at its date. Complete one or two existing treatments and show them in real geometry before expanding T08 onward.

## 3. The seven existing kits and open course ruling

At the preserved Art delivery: **81 catalogue rows, 7 in progress, 0 completed**. This is a dated catalogue snapshot, not a fresh assertion about today's public Archipelago game count. Initial subthemes:

| ID | Reference game / chosen subtheme |
|---|---|
| T01 | Ocarina of Time / Forest Temple |
| T02 | Super Mario 64 / Tick Tock Clock |
| T03 | Bomb Rush Cyberfunk / Brink Terminal after hours |
| T04 | Super Metroid / Wrecked Ship |
| T05 | Kingdom Hearts II / Twilight Town service alley |
| T06 | Doom 1993 / UAC techbase |
| T07 | Dark Souls III / High Wall of Lothric aqueduct run |

The Twilight treatment's geometry differed but shared temple pixels still read like Forest Temple in Arty's own review. That is a recorded artist assessment, not a new visual judgment by this packet. Shared construction is encouraged; a generic tint/folder is not a completed pack. Distinctive material treatment, shapes, useful dressing and actual in-engine application are required.

The course candidate reports four broken axis/texture pairs reduced to zero while **18 of 22 pitches change**. It has not been applied. Art's preference was not uniform across themes. Keep the source/candidate comparison and obtain a treatment-specific ruling; do not resurrect the earlier incomplete “one line or start at half pitch” repair as a verified answer. Original source and updated findings are included under `references/`.

Preserve collision/clearance contracts and existing gates: doorway clearance, headroom, corridor fit, meaningful attachments and visual review are different. An overlap gate does not prove an architectural form looks supported. A surrounding model must not create an unapproved step or cover a landing, muzzle, control or hazard cue.

## 4. Glyph for the new interface

Verified reference branch while preparing this packet: `claude/feature-planning-roadmap-5oibiu` at **`87db9e20dd0c7cb1a1f7a3c617a47d5efa3526de`**. The older Arty authoring baseline is **`6c80b6315912a70b44c28d566ddff608eafa234a`**. Pulling main is not equivalent to using this newer tooling branch. [S08]

Use an isolated checkout and a disposable/new project for the new menu. Read the agent guide, discover actual commands and exercise granted artist attribution. The earlier trial already exercised an edit/render/open/reopen/export cycle; inspect those receipts rather than relitigate them, then prove the **specific font/panel import into the actual 3D menu**. An existing trial is not evidence of this new consumer.

The guide documents bitmap-font metrics/check/export, icon-family checks, nine-slice panels and Godot resource adapters. It does not make 3D mesh geometry or attach game callbacks. The documented bitmap-font import proof names Godot 4.3, while this game uses 4.5.1; test the actual target. No claim is made here that a new build/test/import run was executed.

Opening `.glyph` projects may checkpoint stored data; Arty recorded changed tracked fixtures during verification. Work on copies and inspect diffs. Do not mass-migrate/re-render approved content, run expensive certification benchmarks repeatedly, or equate `check_tiling` reports with automatic aesthetic rejection. New sources keep source SHA, exports/hashes and art-review state together.

## 5. SigmAudio stays in scope as a tool reference, not a DAW rebuild

The 22 September refresh is included unchanged. It inspected main at `2d76a5a3a6f77b5849ae0014178069ab642a6aa3` and development at `6897ce23f92dad6be13055e957049322e03999fe`. Those are **historical inspected pins**, not newly verified current heads for this handoff. No SigmAudio application was run and no audio was heard here. [S09]

Preserve useful existing threat audio. For new menu/control/death cues, use a supported original-authoring/export path and prove the actual game consumer. Do not copy referenced games' sounds or soundtracks. The documented development automation was opt-in; the older Godot adapter did not supply stinger playback/ducking, cross-cue sequencing or guaranteed sample-accurate automation. Do not assume that richer DAW authoring automatically added these runtime capabilities.

A small agreed cue/state handoff may be useful. It is not permission to rebuild the score, upgrade every project, or divert Prod/Arty into finishing SigmAudio. Listen through an available human/host path before reporting a sound judgment; rendering and numerical measurement are not listening.

## 6. Updated Art priority

First: the Glyph interface family, shared circuit/control cues and distance-readable current enemies. Second: replace functional machinery placeholders against the revised puzzle bounds; fix the receiver's z-fight as part of that replacement, not a separate high-priority polish task. Third: consume D-11 and finish initial material treatments. Then continue genuinely unblocked A15/A16/A17–A19 reserve work as authorized, preserving the original art queue.

Each delivery is a usable slice with actual consumer evidence and explicit review status. A state variant is not a new enemy, a cluster is not a dozen unique models, and a catalogue row is not a completed pack.
