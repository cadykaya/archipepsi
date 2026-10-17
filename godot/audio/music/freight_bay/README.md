# Freight Bay (four parts)

Made with SigmAudio 0.1.0-alpha.1.

- **Tempo** 144 BPM, 4/4
- **Key** E Natural minor
- **Musical loop** 16 bars, 26.67 s, 2-bar phrases

- **Loop point** samples 0–1279999 at 48000 Hz
- **Peak** -15.52 dBFS · **average** -32.9 dBFS
- **Endpoint difference (historical)** -52.52 dBFS between adjacent boundary samples; not a click measurement.
- **Rendered continuation** -95.68 dBFS error across 1200 frames (25.00 ms). Scope: next-loop opening block, compared with the corresponding captured loop samples. A numeric comparison, not a hearing test or an inaudibility guarantee.
- **Main render work** warmup iterations in the final pass: 1; render attempts: 1. These counters do not measure listening quality or total stem-render work.
- **Review** draft

## What's in here

| File | What it's for |
|---|---|
| `audio/freight_bay_four_parts_loop.wav` | The whole cue as one file that repeats forever. Use this if your game just needs music. |
| `audio/stems/*.wav` | One file per layer. Play them together and fade them in and out for music that reacts. |
| `midi/freight_bay_four_parts.mid` | The notes. Open in any other music program to keep editing. |
| `manifest.json` | Machine-readable loop, layer, state and transition data. |
| `project.sigmaudio.json` | Reopen this in SigmAudio to keep working. |
| `godot/sigmaudio_cue.gd` | Godot 4.5+ synchronized layer runtime. |
| `godot/runtime.json` | Full configuration snapshot embedded in the Godot script. |
| `audio/**/*.wav.import` | Adjacent Godot WAV import settings, including the main mix. |

## Using it in Godot (4.5+)

1. Copy this entire pack folder into your project, including the adjacent WAV .import files, before Godot imports it. Preserve its internal folders; the pack itself can be renamed or nested.
2. Allow the editor to import the WAVs. When replacing an existing pack, reimport its WAVs with the included settings: uncompressed 16-bit PCM, original rate/channels, Forward loop (import enum 2), no trim or normalization.
3. Add godot/sigmaudio_cue.gd as an autoload named SigmAudioCue. Nothing plays automatically.
4. Call the generated API using stable IDs (or unambiguous authored names):

```gdscript
SigmAudioCue.play()
SigmAudioCue.set_state("sta_00000001v89xte10pbe1py", "bar")
```

play() restarts at the authored base state and parameter defaults. stop(), pause() and resume() affect the common player and runtime clock; SceneTree pause also pauses both. Adaptive calls return false without stems, before play, while paused, or for invalid inputs. Parameter values must be finite and within authored bounds. get_state() returns the stable ID; get_state_name() returns its display name.

set_state(id, quantize="bar", priority=0) accepts immediate, beat, bar or phrase. Automatic transitions use the authored condition tree, parameter smoothing/holds, hysteresis, dwell, priorities and musical quantization. trigger_event(id) and trigger_events([ids]) feed transition conditions only; this pack has no rendered stinger audio or play_stinger API. Queued events latch event truth while live parameter conditions remain cancellable. runtime.json is an audit copy of the configuration embedded in the script; regenerate the pack to update both.

To record controls, stop playback, call begin_input_capture("my-game:session-1"), then explicitly play(). Accepted set_parameter, set_state and single trigger_event calls retain their resolved IDs, invocation order and elapsed playback times. Call finish_input_capture() before Stop; on success it returns {ok, capture: {sourceText, sha256}, receipt}. Explicitly save only sourceText to a fresh UTF8 file without a BOM; do not reserialize it. Import that file in SigmAudio's Gameplay scenarios or through the source-bound import-gameplay-trace edit operation. input_capture_snapshot() reports status and failure reason. Nothing writes a file automatically.

Capture is bounded to 300 seconds, 1024 inputs and 256 KiB. Pause, Stop/restart before Finish, clock loss, overflow, unsafe priorities and accepted multi-event batches invalidate the capture. They never publish a truncated or sequential substitute. Recording failure does not veto normal game controls. A completed source remains available after Stop until explicit begin_input_capture replaces it. The receipt pins the exported cue-v1 hash; configuration and source text retain the full subdivision tree. Supplied source names are not authenticated game identity. Inputs are not runtime decisions or PCM. Existing stinger/snapshot/layer limitations still apply to replay comparisons.


For saved inputs, inspect runtime.json scenarioReplay.scenarios and each supported/reasons entry. Explicit play_scenario(EXACT_ID, "music-only") starts a fresh replay; unknown IDs, other monitoring modes and unsupported scenarios refuse before changing existing playback. Validated parameter/ramp/state/transition-event inputs retain order and state across repeats. Reference recordings are excluded. Events needing authored stinger/duck behavior, differing automatic/manual snapshot processing, finite cues, missing stems and selected-stinger packs refuse. Full later policies remain open.

scenario_snapshot() reports exact cue/scenario/capture-source hashes, intended/accepted input times, repeats, maximum lateness, last256 inputs and omitted count. It separates scheduledStateId from audibleStateId/pendingAudioStateChanges. Saved replay uses authored BPM/meter and the shared120ms controller lookahead; future logical commits do not change native layer levels early. Layer gains and endpoint Stop apply on engine frames, not at sample-accurate callbacks. Native clock gaps above120ms or backwards time fail/stop instead of skipping inputs. Manual controls refuse until Stop. Stop/restart cancels owned work; settled pause/resume freezes and continues it. Starting replay invalidates an unfinished game-input capture. These receipts do not prove complete PCM equivalence, owner-game execution or listening approval. See docs/GODOT_SCENARIO_REPLAY.md in the source handoff.

All layers play continuously inside one AudioStreamSynchronized (maximum 32), including silent layers, so state changes never restart their phase. Stem gains/effects are already rendered; the runtime fades unity/silence, not the authored gain a second time. The musical clock is anchored to manifest PCM frame counts. Decisions and linear-amplitude fades occur on engine frames and audio mix blocks, not sample-accurate scheduled callbacks. A stall longer than half a loop stops playback with a warning instead of guessing missed loop wraps; call play() to restart.


WAV smpl endpoints and import settings are inclusive. Godot versions with the known PCM boundary inconsistency are detected using a short native PCM probe; only the runtime's private PCM copies receive a one-frame loop guard. Source WAVs remain unchanged. An unknown loop convention or mismatched imported frame count/rate/format refuses playback.

The base state's snapshot processing is baked into the main mix and every stem by the shared renderer. It is never applied again in Godot. States with different resolved snapshot processing are refused, including removing a baked filter/send/gain. Different snapshot IDs with identical resolved processing are safe. The manifest records audioBake, full authored snapshots and per-state capability limits. Manual preview snapshot selections never reach export.

Supported: synchronized layer switching and authored parameter/event transitions between supportedStateIds. Not supported: cross-cue sequencing, different state snapshot processing, rendered stingers/ducking, sample-accurate transition automation. Without stems only the fixed main mix plays. A passing headless consumer test is not hardware listening or game playtest evidence.

References: [AudioStreamSynchronized](https://docs.godotengine.org/en/4.5/classes/class_audiostreamsynchronized.html), [WAV importer settings](https://docs.godotengine.org/en/4.5/classes/class_resourceimporterwav.html), [audio timing](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html), [PCM loop boundary report](https://github.com/godotengine/godot/issues/119778).


## Adaptive states

- **Exploration** — 2 layers active
- **Entry** — 1 layers active
- **Combat** — 2 layers active
- **Victory** — 1 layers active

Transitions retain their authored conditions, holds, dwell, priority and quantization.
Hysteresis applies to direct parameter conditions with an explicit enter/exit pair.
Godot refuses target states listed in manifest.godot.unsupportedStateIds.

## Notes

- The stingers layer rendered as silence; its stem is included but empty.
- Bay: conveyor (texture): shortened 1 overlapping note of the same pitch (MIDI cannot hold two at once).
- Bay: motor (pad): shortened 7 overlapping notes of the same pitch (MIDI cannot hold two at once).
- Combat: bass (bass): shortened 4 overlapping notes of the same pitch (MIDI cannot hold two at once).
- Track EQ, delay and compression are rendered into WAV and kept in the editable project. MIDI does not carry these effects.
- This arrangement uses MIDI ports to keep parts independent. Import each track separately in software that ignores MIDI port metadata.
- This cue is still a review draft. The export is usable for testing, but it is not marked as the approved version.
- Godot 4.5+ is required. State fades and decisions run on engine frames, not sample-accurate automation callbacks.
- Stems include their authored active gains and effects. The runtime switches unity/silence without applying those gains twice.
- Stems are rendered separately through bus compression/effects. Their sum is not guaranteed to reconstruct the combined live or main mix exactly.
- Authored stingers have no rendered files in this pack. Godot stinger playback and ducking are not exported.

## Rights

SigmAudio generated this from editable note data, its synthesised instruments,
and the following bundled sample content:

- CC0 — Kinoton (Freesound) (https://freesound.org/people/Kinoton/sounds/519027/)
- CC0 — jasonLON (Freesound) (https://freesound.org/people/jasonLON/sounds/125401/)
- CC0 — mark646, kyles, mcpable, o_ciz, ronnyver (Freesound) (https://freesound.org/people/mark646/sounds/209219/ ; https://freesound.org/people/mark646/sounds/209217/ ; https://freesound.org/people/kyles/sounds/453303/ ; https://freesound.org/people/mcpable/sounds/131934/ ; https://freesound.org/people/o_ciz/sounds/475427/ ; https://freesound.org/people/ronnyver/sounds/488589/)
- CC0 — kyles (Freesound) (https://freesound.org/people/kyles/sounds/637811/)
- CC0 — Karoryfer Samples (Brian Wood), Black And Green Guitars v1.000 (https://github.com/sfzinstruments/karoryfer.black-and-green-guitars)
- CC0 — Karoryfer Samples (Brian Wood), Black And Green Guitars v1.000 (https://github.com/sfzinstruments/karoryfer.black-and-green-guitars)
- CC0 — Karoryfer Samples (Brian Wood), Black And Green Guitars v1.000 (https://github.com/sfzinstruments/karoryfer.black-and-green-guitars)
- CC0 — Karoryfer Samples (Brian Wood), Black And Green Guitars v1.000 (https://github.com/sfzinstruments/karoryfer.black-and-green-guitars)
- Public domain — Alexander Holm, Salamander Drumkit (https://archive.org/details/SalamanderDrumkit)
- CC0 — mcpable (Freesound) (https://freesound.org/people/mcpable/sounds/131930/)
- CC0 — magnuswaker, ldezem, davidlay1, mark646 (Freesound) (https://freesound.org/people/magnuswaker/sounds/614063/ ; https://freesound.org/people/magnuswaker/sounds/614062/ ; https://freesound.org/people/ldezem/sounds/386302/ ; https://freesound.org/people/davidlay1/sounds/416080/ ; https://freesound.org/people/mark646/sounds/209217/)

This receipt documents
how the cue was generated; **it does not guarantee copyright clearance**, and you
remain responsible for anything you add to it.
