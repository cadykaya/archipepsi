# SigmAudio Godot 4.5+ layer runtime. No autoplay or stinger-audio placeholders.
# Source WAV smpl endpoints are inclusive. Private PCM copies handle the detected
# engine loop convention; see godotengine/godot#119778. Original assets stay intact.
extends Node

signal state_changed(state_id: String, boundary_seconds: float)
signal transition_queued(source_id: String, boundary_seconds: float)

const DATA_JSON: String = "{\"schemaVersion\":1,\"minimumGodot\":\"4.5\",\"semantics\":\"sigmaudio-godot-layer-runtime-v1\",\"bpm\":144,\"beatsPerBar\":4,\"beatUnit\":4,\"loopBars\":16,\"phraseLengthBars\":2,\"sampleRate\":48000,\"loopStartSamples\":0,\"loopEndSamples\":1279999,\"loopFrames\":1280000,\"mainFile\":\"audio/freight_bay_four_parts_loop.wav\",\"adaptive\":true,\"gameplayInputCapture\":{\"version\":1,\"available\":true,\"cueId\":\"cue_000000001gsfsyz4334vqn\",\"cueRevisionFormat\":\"cue-v1\",\"cueSha256\":\"0f4448b3796160893732e8e8f9019bf1f58780ef5b741e9f2d8a95ca7a833946\",\"meter\":{\"beatsPerBar\":4,\"beatUnit\":4,\"subdivisionTree\":[2,2,2,2]},\"maximumSeconds\":300,\"maximumInputs\":1024,\"maximumBytes\":262144,\"acceptedKinds\":[\"parameter\",\"state\",\"event\"],\"clock\":\"elapsed-seconds\",\"scope\":\"Accepted controls from fresh Play. Pause/restart/overflow/multi-event batches invalidate capture. Selected stinger packs refuse capture; inputs are not decisions or PCM.\"},\"scenarioReplay\":{\"version\":1,\"mode\":\"music-only\",\"available\":false,\"scenarios\":[],\"maximumInputLatenessSeconds\":0.12,\"maximumReceiptRecords\":256,\"controller\":\"Authored BPM/meter and shared 120ms lookahead commit policy; scheduled state is distinct from native audible state. Layer gains and Stop apply on observed engine frames.\",\"scope\":\"Explicit saved inputs, ramps and retained-state repeats on the native playback clock. No reference recordings, inferred stinger/duck audio, cold seek or sample-accurate transition/endpoint promise.\"},\"audioBake\":{\"renderVersion\":\"sigmaudio-audio-12\",\"stateId\":\"sta_00000001v7k443fh5d4esw\",\"appliedSnapshotIds\":[],\"manualSnapshotIds\":[],\"resolvedTracks\":[{\"trackId\":\"trk_0000000001z5paqsjz5axv\",\"offset\":{\"trackId\":\"trk_0000000001z5paqsjz5axv\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-5,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.3,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000000066e5fa4sbn0dz\",\"offset\":{\"trackId\":\"trk_00000000066e5fa4sbn0dz\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-10,\"lowpassHz\":3000,\"highpassHz\":null,\"sendWet\":0.3,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_000000000h1nwwn6ty852y\",\"offset\":{\"trackId\":\"trk_000000000h1nwwn6ty852y\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-6,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.25,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_0000000034pj203ead212f\",\"offset\":{\"trackId\":\"trk_0000000034pj203ead212f\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-4,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.35,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_000000005kwwxx0tbp3089\",\"offset\":{\"trackId\":\"trk_000000005kwwxx0tbp3089\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-5,\"lowpassHz\":4000,\"highpassHz\":null,\"sendWet\":0.4,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_000000009prbysceaysd78\",\"offset\":{\"trackId\":\"trk_000000009prbysceaysd78\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-6,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.45,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000000a5963vxb177wf3\",\"offset\":{\"trackId\":\"trk_00000000a5963vxb177wf3\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-8,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.6,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000000ag6p3mgnxwfpa2\",\"offset\":{\"trackId\":\"trk_00000000ag6p3mgnxwfpa2\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-3.8,\"lowpassHz\":5000,\"highpassHz\":null,\"sendWet\":0.1,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000000j5wpc445fs9mf4\",\"offset\":{\"trackId\":\"trk_00000000j5wpc445fs9mf4\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":2.3,\"lowpassHz\":5000,\"highpassHz\":null,\"sendWet\":0.1,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000000mm982b3rwkqay7\",\"offset\":{\"trackId\":\"trk_00000000mm982b3rwkqay7\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-9.5,\"lowpassHz\":5000,\"highpassHz\":null,\"sendWet\":0.1,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000000w95312hnd9y6aj\",\"offset\":{\"trackId\":\"trk_00000000w95312hnd9y6aj\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":3.4,\"lowpassHz\":5000,\"highpassHz\":null,\"sendWet\":0.1,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000000yrqkd2zmfwpznf\",\"offset\":{\"trackId\":\"trk_00000000yrqkd2zmfwpznf\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-7.2,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.18,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001638b0g8z28906g\",\"offset\":{\"trackId\":\"trk_00000001638b0g8z28906g\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-8.7,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.25,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001bp7w515p6sq0x9\",\"offset\":{\"trackId\":\"trk_00000001bp7w515p6sq0x9\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-7.7,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001exdg97tkj5aw7m\",\"offset\":{\"trackId\":\"trk_00000001exdg97tkj5aw7m\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-1.5,\"lowpassHz\":6000,\"highpassHz\":null,\"sendWet\":0.3,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001q0ny1nkks7vxsj\",\"offset\":{\"trackId\":\"trk_00000001q0ny1nkks7vxsj\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":9.3,\"lowpassHz\":5500,\"highpassHz\":null,\"sendWet\":0.3,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001r5dt7eqwn3yrmr\",\"offset\":{\"trackId\":\"trk_00000001r5dt7eqwn3yrmr\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-8.5,\"lowpassHz\":3500,\"highpassHz\":null,\"sendWet\":0.35,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001sas3g2a6nemqd7\",\"offset\":{\"trackId\":\"trk_00000001sas3g2a6nemqd7\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-4,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.25,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001sdy8fgj5s5pwff\",\"offset\":{\"trackId\":\"trk_00000001sdy8fgj5s5pwff\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":8,\"lowpassHz\":500,\"highpassHz\":null,\"sendWet\":0.3,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001sgrcbv9b96q0s9\",\"offset\":{\"trackId\":\"trk_00000001sgrcbv9b96q0s9\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":1,\"lowpassHz\":5000,\"highpassHz\":null,\"sendWet\":0.1,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001skmkwsf812q287\",\"offset\":{\"trackId\":\"trk_00000001skmkwsf812q287\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":0,\"lowpassHz\":5000,\"highpassHz\":null,\"sendWet\":0.2,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001spmest8a2z4yyt\",\"offset\":{\"trackId\":\"trk_00000001spmest8a2z4yyt\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-5,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.25,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001ssddrq40dcz20y\",\"offset\":{\"trackId\":\"trk_00000001ssddrq40dcz20y\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-9,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.35,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001sw318wan090gte\",\"offset\":{\"trackId\":\"trk_00000001sw318wan090gte\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-4,\"lowpassHz\":3500,\"highpassHz\":null,\"sendWet\":0.35,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001szsta38psammn9\",\"offset\":{\"trackId\":\"trk_00000001szsta38psammn9\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-6,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001t2msq8znqv73mm\",\"offset\":{\"trackId\":\"trk_00000001t2msq8znqv73mm\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":1.5,\"lowpassHz\":5000,\"highpassHz\":null,\"sendWet\":0.4,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001t513kxzf4ga2js\",\"offset\":{\"trackId\":\"trk_00000001t513kxzf4ga2js\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":12,\"lowpassHz\":5000,\"highpassHz\":null,\"sendWet\":0.45,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001t8zr3gsc36rm0j\",\"offset\":{\"trackId\":\"trk_00000001t8zr3gsc36rm0j\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-6,\"lowpassHz\":3500,\"highpassHz\":null,\"sendWet\":0.4,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001tb7k6xyaa7enhb\",\"offset\":{\"trackId\":\"trk_00000001tb7k6xyaa7enhb\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-6,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.4,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001teawg50zqdb322\",\"offset\":{\"trackId\":\"trk_00000001teawg50zqdb322\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-4,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.1,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001thrjc3zfhqbhpg\",\"offset\":{\"trackId\":\"trk_00000001thrjc3zfhqbhpg\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-10,\"lowpassHz\":3000,\"highpassHz\":null,\"sendWet\":0.3,\"interpolationMs\":0,\"snapshotIds\":[]},{\"trackId\":\"trk_00000001tmx25taxartvj4\",\"offset\":{\"trackId\":\"trk_00000001tmx25taxartvj4\",\"gainDb\":0,\"lowpassHz\":null,\"highpassHz\":null,\"sendWet\":null},\"gainDb\":-6,\"lowpassHz\":20000,\"highpassHz\":null,\"sendWet\":0.25,\"interpolationMs\":0,\"snapshotIds\":[]}],\"conflicts\":[],\"snapshotProcessingBaked\":true,\"layerActiveGainsBaked\":true,\"trackEffectsBaked\":true,\"gainAutomationBaked\":true},\"supportedStateIds\":[\"sta_00000001v7k443fh5d4esw\",\"sta_00000001v89xte10pbe1py\",\"sta_00000001v9s8wt0mxc3eaa\",\"sta_00000001vak5tx46aefbvg\"],\"unsupportedStateIds\":[],\"capabilities\":{\"synchronizedLayers\":true,\"layerStateSwitching\":true,\"parameterTransitions\":true,\"eventTransitions\":true,\"sampleAccurateTransitions\":false,\"stateSnapshotSwitching\":false,\"stingerAudio\":false,\"gameplayInputCapture\":true,\"savedScenarioReplay\":false,\"stingerDucking\":false,\"crossCueSequencing\":false,\"exactMainMixReconstruction\":false,\"maximumLayers\":32},\"baseStateId\":\"sta_00000001v7k443fh5d4esw\",\"layers\":[{\"id\":\"lay_00000001v3qr5xnq7cztv6\",\"name\":\"Bay\",\"file\":\"audio/stems/freight_bay_four_parts_bay.wav\",\"fadeBeats\":4},{\"id\":\"lay_00000001v4k5xbnm4jpe6q\",\"name\":\"Exploration\",\"file\":\"audio/stems/freight_bay_four_parts_exploration.wav\",\"fadeBeats\":4},{\"id\":\"lay_00000001v5yjwm3ddwx2fb\",\"name\":\"Combat\",\"file\":\"audio/stems/freight_bay_four_parts_combat.wav\",\"fadeBeats\":0},{\"id\":\"lay_00000001v62res57hpe232\",\"name\":\"Stingers\",\"file\":\"audio/stems/freight_bay_four_parts_stingers.wav\",\"fadeBeats\":0}],\"states\":[{\"id\":\"sta_00000001v7k443fh5d4esw\",\"name\":\"Exploration\",\"activeLayerIds\":[\"lay_00000001v3qr5xnq7cztv6\",\"lay_00000001v4k5xbnm4jpe6q\"],\"mixSnapshotId\":null},{\"id\":\"sta_00000001v89xte10pbe1py\",\"name\":\"Entry\",\"activeLayerIds\":[\"lay_00000001v3qr5xnq7cztv6\"],\"mixSnapshotId\":null},{\"id\":\"sta_00000001v9s8wt0mxc3eaa\",\"name\":\"Combat\",\"activeLayerIds\":[\"lay_00000001v3qr5xnq7cztv6\",\"lay_00000001v5yjwm3ddwx2fb\"],\"mixSnapshotId\":null},{\"id\":\"sta_00000001vak5tx46aefbvg\",\"name\":\"Victory\",\"activeLayerIds\":[\"lay_00000001v3qr5xnq7cztv6\"],\"mixSnapshotId\":null}],\"parameters\":[],\"events\":[{\"id\":\"evt_00000001vbejm4jadjh931\",\"name\":\"engage\"},{\"id\":\"evt_00000001vcxjjj4smgb0x1\",\"name\":\"victory\"}],\"transitions\":[{\"id\":\"trn_00000001vd9t0hf1szaaxz\",\"fromStateId\":\"sta_00000001v7k443fh5d4esw\",\"toStateId\":\"sta_00000001v89xte10pbe1py\",\"when\":{\"kind\":\"event\",\"eventId\":\"evt_00000001vbejm4jadjh931\"},\"quantize\":\"phrase\",\"fadeBeats\":0,\"priority\":5,\"enterAbove\":null,\"exitBelow\":null,\"dwellMs\":0},{\"id\":\"trn_00000001ve6sn7zpha31jw\",\"fromStateId\":\"sta_00000001v89xte10pbe1py\",\"toStateId\":\"sta_00000001v9s8wt0mxc3eaa\",\"when\":{\"kind\":\"always\"},\"quantize\":\"phrase\",\"fadeBeats\":0,\"priority\":5,\"enterAbove\":null,\"exitBelow\":null,\"dwellMs\":3000},{\"id\":\"trn_00000001vfbde968nsz3cm\",\"fromStateId\":\"sta_00000001v9s8wt0mxc3eaa\",\"toStateId\":\"sta_00000001vak5tx46aefbvg\",\"when\":{\"kind\":\"event\",\"eventId\":\"evt_00000001vcxjjj4smgb0x1\"},\"quantize\":\"phrase\",\"fadeBeats\":0,\"priority\":6,\"enterAbove\":null,\"exitBelow\":null,\"dwellMs\":0},{\"id\":\"trn_00000001vgq3c3ebbct5jj\",\"fromStateId\":\"sta_00000001vak5tx46aefbvg\",\"toStateId\":\"sta_00000001v7k443fh5d4esw\",\"when\":{\"kind\":\"always\"},\"quantize\":\"phrase\",\"fadeBeats\":4,\"priority\":1,\"enterAbove\":null,\"exitBelow\":null,\"dwellMs\":3000},{\"id\":\"trn_00000001vhd414hbvg939a\",\"fromStateId\":\"sta_00000001vak5tx46aefbvg\",\"toStateId\":\"sta_00000001v89xte10pbe1py\",\"when\":{\"kind\":\"event\",\"eventId\":\"evt_00000001vbejm4jadjh931\"},\"quantize\":\"phrase\",\"fadeBeats\":0,\"priority\":5,\"enterAbove\":null,\"exitBelow\":null,\"dwellMs\":0}],\"mixSnapshots\":[],\"stingers\":[{\"id\":\"stg_00000001w5gjxk3h7pb9z8\",\"name\":\"Entry: press\",\"patternId\":\"pat_00000001vj4b2jqbdv92y8\",\"trackId\":\"trk_00000001sas3g2a6nemqd7\",\"eventId\":\"evt_00000001vbejm4jadjh931\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":0.8,\"allowedStateIds\":[\"sta_00000001v7k443fh5d4esw\",\"sta_00000001vak5tx46aefbvg\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001wf52mbg5fq33ec\",\"name\":\"Entry: motor\",\"patternId\":\"pat_00000001w65xh8t0bgpfda\",\"trackId\":\"trk_00000001sdy8fgj5s5pwff\",\"eventId\":\"evt_00000001vbejm4jadjh931\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":0.6,\"allowedStateIds\":[\"sta_00000001v7k443fh5d4esw\",\"sta_00000001vak5tx46aefbvg\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001x49dkwx3qkdsh2\",\"name\":\"Entry: muted guitar\",\"patternId\":\"pat_00000001wgxyempn27z7kz\",\"trackId\":\"trk_00000001sgrcbv9b96q0s9\",\"eventId\":\"evt_00000001vbejm4jadjh931\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":0.4,\"allowedStateIds\":[\"sta_00000001v7k443fh5d4esw\",\"sta_00000001vak5tx46aefbvg\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001xpz5qcsk4gt28n\",\"name\":\"Entry: guitar\",\"patternId\":\"pat_00000001x547txrwrq8mnc\",\"trackId\":\"trk_00000001skmkwsf812q287\",\"eventId\":\"evt_00000001vbejm4jadjh931\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":0.8,\"allowedStateIds\":[\"sta_00000001v7k443fh5d4esw\",\"sta_00000001vak5tx46aefbvg\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001y4hgmykcrar02k\",\"name\":\"Entry: kit\",\"patternId\":\"pat_00000001xqxz0mw8h6tzfb\",\"trackId\":\"trk_00000001spmest8a2z4yyt\",\"eventId\":\"evt_00000001vbejm4jadjh931\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":0.6,\"allowedStateIds\":[\"sta_00000001v7k443fh5d4esw\",\"sta_00000001vak5tx46aefbvg\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001yaedbepn51xeb8\",\"name\":\"Entry: impacts\",\"patternId\":\"pat_00000001y548m8m3m2qyf6\",\"trackId\":\"trk_00000001ssddrq40dcz20y\",\"eventId\":\"evt_00000001vbejm4jadjh931\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":1.2,\"allowedStateIds\":[\"sta_00000001v7k443fh5d4esw\",\"sta_00000001vak5tx46aefbvg\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001ygymf87ysbyev5\",\"name\":\"Entry: air horn\",\"patternId\":\"pat_00000001ybc71xfphq3wjv\",\"trackId\":\"trk_00000001sw318wan090gte\",\"eventId\":\"evt_00000001vbejm4jadjh931\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":0.6,\"allowedStateIds\":[\"sta_00000001v7k443fh5d4esw\",\"sta_00000001vak5tx46aefbvg\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001yyz3qrp1qkp9w7\",\"name\":\"Entry: bass\",\"patternId\":\"pat_00000001yhv28w25d3fzxa\",\"trackId\":\"trk_00000001szsta38psammn9\",\"eventId\":\"evt_00000001vbejm4jadjh931\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":0.4,\"allowedStateIds\":[\"sta_00000001v7k443fh5d4esw\",\"sta_00000001vak5tx46aefbvg\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001z51fp1yn4tb2c8\",\"name\":\"Victory: E major\",\"patternId\":\"pat_00000001yzdb7bnjwzbgre\",\"trackId\":\"trk_00000001t2msq8znqv73mm\",\"eventId\":\"evt_00000001vcxjjj4smgb0x1\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":1.5,\"allowedStateIds\":[\"sta_00000001v9s8wt0mxc3eaa\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001zd3ga51dq1c2e9\",\"name\":\"Victory: lead\",\"patternId\":\"pat_00000001z66dety97zwq4e\",\"trackId\":\"trk_00000001t513kxzf4ga2js\",\"eventId\":\"evt_00000001vcxjjj4smgb0x1\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":1.5,\"allowedStateIds\":[\"sta_00000001v9s8wt0mxc3eaa\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001zkxsw0jdz1pfmy\",\"name\":\"Victory: air horn\",\"patternId\":\"pat_00000001zeck11d6427me8\",\"trackId\":\"trk_00000001t8zr3gsc36rm0j\",\"eventId\":\"evt_00000001vcxjjj4smgb0x1\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":1,\"allowedStateIds\":[\"sta_00000001v9s8wt0mxc3eaa\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001zrczem8ng26d0y\",\"name\":\"Victory: impacts\",\"patternId\":\"pat_00000001zmztcv1bsqnz6y\",\"trackId\":\"trk_00000001tb7k6xyaa7enhb\",\"eventId\":\"evt_00000001vcxjjj4smgb0x1\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":1.5,\"allowedStateIds\":[\"sta_00000001v9s8wt0mxc3eaa\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001zvwate73cz52eb\",\"name\":\"Victory: low E\",\"patternId\":\"pat_00000001zs1xspj5p6hhkr\",\"trackId\":\"trk_00000001teawg50zqdb322\",\"eventId\":\"evt_00000001vcxjjj4smgb0x1\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":1,\"allowedStateIds\":[\"sta_00000001v9s8wt0mxc3eaa\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_00000001zyxxtg3yrjadt9\",\"name\":\"Victory: motor\",\"patternId\":\"pat_00000001zwvnj51d4twq5k\",\"trackId\":\"trk_00000001thrjc3zfhqbhpg\",\"eventId\":\"evt_00000001vcxjjj4smgb0x1\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":1,\"allowedStateIds\":[\"sta_00000001v9s8wt0mxc3eaa\"],\"file\":null,\"audioStatus\":\"not-rendered\"},{\"id\":\"stg_0000000209nphtngmwt742\",\"name\":\"Victory: press\",\"patternId\":\"pat_00000001zz4ymr6cyqjvtz\",\"trackId\":\"trk_00000001tmx25taxartvj4\",\"eventId\":\"evt_00000001vcxjjj4smgb0x1\",\"quantize\":\"phrase\",\"keyLock\":false,\"duckBed\":null,\"cooldownMs\":0,\"maxVoices\":1,\"tailSeconds\":0.8,\"allowedStateIds\":[\"sta_00000001v9s8wt0mxc3eaa\"],\"file\":null,\"audioStatus\":\"not-rendered\"}],\"stingerAudio\":false,\"warnings\":[\"Godot 4.5+ is required. State fades and decisions run on engine frames, not sample-accurate automation callbacks.\",\"Stems include their authored active gains and effects. The runtime switches unity/silence without applying those gains twice.\",\"Stems are rendered separately through bus compression/effects. Their sum is not guaranteed to reconstruct the combined live or main mix exactly.\",\"Authored stingers have no rendered files in this pack. Godot stinger playback and ducking are not exported.\"]}"
const LOOKAHEAD_SECONDS: float = 0.12
const QUANTIZE: Array = ["immediate", "beat", "bar", "phrase"]
var data: Dictionary = JSON.parse_string(DATA_JSON)
var _player: AudioStreamPlayer
var _sync: AudioStreamSynchronized
var _ready_ok: bool = false
var _playing: bool = false
var _manual_pause: bool = false
var _tree_pause: bool = false
var _state: String = ""
var _now: float = 0.0
var _active_since: float = 0.0
var _cycle_seconds: float = 0.0
var _last_position: float = 0.0
var _last_wall: float = 0.0
var _serial: int = 0
var _last_commit_time: float = -INF
var _last_commit_priority: int = -9007199254740991
var _parameters: Dictionary = {}
var _holds: Dictionary = {}
var _latches: Dictionary = {}
var _pending: Array = []
var _fades: Dictionary = {}
var _levels: Dictionary = {}
var _guard_pcm: bool = false

var _input_capture_status: String = "idle"
var _input_capture_source: String = ""
var _input_capture_message: String = ""
var _input_capture_events: Array = []
var _input_capture_result: Dictionary = {}
var _input_capture_last: float = 0.0
var _input_capture_calls: int = 0


var _scenario_status: String = "idle"
var _scenario_message: String = ""
var _scenario_rejection: String = ""
var _scenario_source: Dictionary = {}
var _scenario_epoch: int = 0
var _scenario_index: int = 0
var _scenario_cycle: int = 0
var _scenario_read: int = 0
var _scenario_actions: int = 0
var _scenario_last_clock: float = 0.0
var _scenario_lateness: float = 0.0
var _scenario_requested: Dictionary = {}
var _scenario_ramps: Dictionary = {}
var _scenario_records: Array = []
var _scenario_omitted: int = 0
var _scenario_audio_states: Array = []
var _scenario_audio_state: String = ""


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _reset()
    var convention: int = _detect_loop_convention()
    if convention < 0:
        push_error("SigmAudio: unsupported PCM loop convention; playback refused.")
        return
    _guard_pcm = convention == 1
    _player = AudioStreamPlayer.new()
    add_child(_player)
    if data.adaptive:
        _sync = AudioStreamSynchronized.new()
        _sync.stream_count = data.layers.size()
        for index in data.layers.size():
            var stream: AudioStreamWAV = _load_loop(data.layers[index].file)
            if stream == null:
                return
            _sync.set_sync_stream(index, stream)
        _player.stream = _sync
    else:
        _player.stream = _load_loop(data.mainFile)
        if _player.stream == null:
            return
    _ready_ok = true
    _apply_state(0.0, 0.0)

func _detect_loop_convention() -> int:
    for guard in [false, true]:
        var wav := AudioStreamWAV.new()
        wav.format = AudioStreamWAV.FORMAT_16_BITS
        wav.mix_rate = int(AudioServer.get_mix_rate())
        wav.data = PackedByteArray([0, 16, 0, 32, 0, 48, 0, 64, 0, 16])
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        wav.loop_begin = 0
        wav.loop_end = 4 if guard else 3
        var playback: AudioStreamPlayback = wav.instantiate_playback()
        playback.start()
        var pcm: PackedVector2Array = playback.mix_audio(1.0, 18)
        playback.stop()
        var correct: bool = pcm.size() == 18
        for frame in range(2, pcm.size()):
            var expected: float = float((frame - 2) % 4 + 1) * 4096.0 / 32767.0
            correct = correct and absf(pcm[frame].x - expected) < 0.0001
        if correct:
            return 1 if guard else 0
    return -1

func _load_loop(file: String) -> AudioStreamWAV:
    var path: String = get_script().resource_path.get_base_dir().get_base_dir().path_join(file)
    if not ResourceLoader.exists(path, "AudioStreamWAV"):
        push_error("SigmAudio: missing imported WAV %s" % path)
        return null
    var source: AudioStreamWAV = load(path) as AudioStreamWAV
    if source == null or source.format != AudioStreamWAV.FORMAT_16_BITS or source.mix_rate != int(data.sampleRate):
        push_error("SigmAudio: WAV must import as unchanged 16-bit PCM at manifest rate. Reimport using its sidecar.")
        return null
    var frame_bytes: int = 4 if source.stereo else 2
    var pcm: PackedByteArray = source.data
    if pcm.size() != int(data.loopFrames) * frame_bytes:
        push_error("SigmAudio: WAV frame count does not match the manifest. Reimport or replace the complete pack.")
        return null
    if _guard_pcm:
        pcm.append_array(pcm.slice(0, frame_bytes))
    var stream := AudioStreamWAV.new()
    stream.format = source.format
    stream.stereo = source.stereo
    stream.mix_rate = source.mix_rate
    stream.data = pcm
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = int(data.loopStartSamples)
    stream.loop_end = int(data.loopEndSamples) + (1 if _guard_pcm else 0)
    return stream

func loop_seconds() -> float:
    return float(data.loopFrames) / float(data.sampleRate)

func musical_loop_seconds() -> float:
    return float(data.get("musicalLoopFrames", data.loopFrames)) / float(data.sampleRate)

func seconds_per_beat() -> float:
    # Anchor the musical grid to actual exported frames, including sample rounding.
    return musical_loop_seconds() / (float(data.loopBars) * float(data.beatsPerBar))

func _reset() -> void:
    _state = data.baseStateId
    _now = 0.0
    _active_since = 0.0
    _cycle_seconds = 0.0
    _last_position = 0.0
    _last_commit_time = -INF
    _last_commit_priority = -9007199254740991
    _pending.clear()
    _holds.clear()
    _latches.clear()
    _fades.clear()
    _scenario_audio_states.clear()
    _scenario_audio_state = data.baseStateId
    _parameters.clear()
    for parameter in data.parameters:
        _parameters[parameter.id] = {"from": parameter.defaultValue, "to": parameter.defaultValue, "start": 0.0, "end": 0.0}

func play() -> bool:
    if not _ready_ok:
        return false
    if _input_capture_status == "armed":
        _input_capture_status = "starting"
    stop()
    _playing = true
    _last_wall = Time.get_ticks_usec() / 1000000.0
    _apply_state(0.0, 0.0)
    _player.stream_paused = false
    _player.play()
    _input_capture_start()
    return true

func stop() -> void:
    _scenario_finish("stopped", "Explicit Stop/restart cancelled saved scenario work.")
    if _input_capture_status != "starting":
        _input_capture_interrupt("Playback stopped or restarted before Finish. No partial trace was published.")
    _playing = false
    _manual_pause = false
    _tree_pause = false
    if is_instance_valid(_player):
        _player.stop()
    _reset()

func pause() -> void:
    if _playing and not _manual_pause:
        _input_capture_interrupt("Pause is outside this capture contract. Finish before pausing.")
        _advance(_clock_seconds())
        _manual_pause = true
        _player.stream_paused = true

func resume() -> void:
    _manual_pause = false
    if _playing:
        _player.stream_paused = _tree_pause
        _last_wall = Time.get_ticks_usec() / 1000000.0

func _exit_tree() -> void:
    stop()

func _clock_seconds() -> float:
    if not _playing or _manual_pause or _tree_pause:
        return _now
    var position: float = _player.get_playback_position()
    if position < _last_position - loop_seconds() * 0.5:
        _cycle_seconds += loop_seconds()
    _last_position = position
    return maxf(_now, _cycle_seconds + position + AudioServer.get_time_since_last_mix())

func _process(_delta: float) -> void:
    if not _playing:
        return
    var wall: float = Time.get_ticks_usec() / 1000000.0
    if get_tree().paused != _tree_pause:
        _tree_pause = get_tree().paused
        if _tree_pause:
            _input_capture_interrupt("SceneTree pause interrupted capture. No partial trace was published.")
        _player.stream_paused = _manual_pause or _tree_pause
        _last_wall = wall
    if _manual_pause or _tree_pause:
        _last_wall = wall
        return
    if wall - _last_wall > loop_seconds() * 0.5:
        _input_capture_interrupt("Long frame stall lost playback-clock continuity. No partial trace was published.")
        _scenario_finish("failed", "Long frame stall lost scenario playback-clock continuity.")
        stop()
        push_warning("SigmAudio: long frame stall lost loop-clock continuity. Call play() to restart.")
        return
    _last_wall = wall
    var clock: float = _clock_seconds()
    var replaying: bool = _scenario_status == "playing"
    var replay_epoch: int = _scenario_epoch
    _scenario_tick(clock)
    if replaying and not _scenario_owns(replay_epoch):
        return
    _advance(clock)
    if _input_capture_status == "recording":
        _input_capture_guard(_now)

func _resolve(items: Array, value: String) -> String:
    for item in items:
        if item.id == value:
            return value
    var found: String = ""
    for item in items:
        if item.name == value:
            if not found.is_empty():
                push_warning("SigmAudio: ambiguous name; use the stable ID.")
                return ""
            found = item.id
    if found.is_empty():
        push_warning("SigmAudio: unknown ID or name %s" % value)
    return found

func _can_adapt() -> bool:
    if not data.adaptive:
        push_warning("SigmAudio: this pack has only a fixed main mix; export stems for adaptive playback.")
        return false
    return _playing and not _manual_pause and not _tree_pause

func get_state() -> String:
    return _state

func get_state_name() -> String:
    for state in data.states:
        if state.id == _state:
            return state.name
    return ""

func set_state(value: String, quantize: String = "bar", priority: int = 0) -> bool:
    return _set_state(value, quantize, priority) if _scenario_manual_controls() else false

func _set_state(value: String, quantize: String = "bar", priority: int = 0, at_time: float = -1.0) -> bool:
    var id: String = _resolve(data.states, value)
    if id.is_empty() or not QUANTIZE.has(quantize) or not _can_adapt():
        return false
    if not data.supportedStateIds.has(id):
        push_warning("SigmAudio: this state's snapshot differs from the processing baked into the stems; state refused.")
        return false
    _now = _clock_seconds() if at_time < 0.0 else at_time
    _serial += 1
    _input_capture_append({"kind": "state", "stateId": id, "quantize": quantize, "priority": priority}, _now)
    _queue({"id": "manual-%s" % _serial, "state": id, "edge": {}, "events": [], "priority": priority}, quantize)
    return true

func _parameter_value(id: String) -> float:
    var ramp: Dictionary = _parameters[id]
    if float(ramp.end) <= _now:
        return float(ramp.to)
    return lerpf(float(ramp.from), float(ramp.to), clampf((_now - float(ramp.start)) / (float(ramp.end) - float(ramp.start)), 0.0, 1.0))

func get_parameter(value: String) -> float:
    var id: String = _resolve(data.parameters, value)
    return _parameter_value(id) if not id.is_empty() else 0.0

func set_parameter(value: String, target: float) -> bool:
    return _set_parameter(value, target) if _scenario_manual_controls() else false

func _set_parameter(value: String, target: float, at_time: float = -1.0) -> bool:
    var id: String = _resolve(data.parameters, value)
    if id.is_empty() or not is_finite(target) or not _can_adapt():
        return false
    for parameter in data.parameters:
        if parameter.id != id:
            continue
        if target < float(parameter.min) or target > float(parameter.max):
            push_warning("SigmAudio: parameter target is outside authored bounds.")
            return false
        _now = _clock_seconds() if at_time < 0.0 else at_time
        _parameters[id] = {"from": _parameter_value(id), "to": target, "start": _now, "end": _now + float(parameter.smoothingMs) / 1000.0}
        _input_capture_append({"kind": "parameter", "paramId": id, "value": target}, _now)
        _evaluate([])
        return true
    return false

func trigger_event(value: String) -> bool:
    return trigger_events([value])

func trigger_events(values: Array) -> bool:
    return _trigger_events(values) if _scenario_manual_controls() else false

func _trigger_events(values: Array, at_time: float = -1.0) -> bool:
    if values.size() > 256 or not _can_adapt():
        return false
    var ids: Array = []
    for value in values:
        if not value is String:
            return false
        var id: String = _resolve(data.events, value)
        if id.is_empty() or ids.has(id):
            return false
        ids.append(id)
    _now = _clock_seconds() if at_time < 0.0 else at_time
    _input_capture_event_batch(ids, _now)
    _evaluate(ids)
    return true

func _condition(condition: Dictionary, key: String, events: Array, override = null) -> bool:
    match condition.kind:
        "always": return true
        "event": return events.has(condition.eventId)
        "all", "any":
            var answers: Array = []
            for index in condition.of.size():
                answers.append(_condition(condition.of[index], key + "." + str(index), events))
            return not answers.has(false) if condition.kind == "all" else answers.has(true)
        "param":
            var value: float = _parameter_value(condition.paramId)
            var threshold: float = float(condition.value)
            var comparisons: Dictionary = {"<": value < threshold, "<=": value <= threshold, ">": value > threshold, ">=": value >= threshold, "==": value == threshold, "!=": value != threshold}
            var truth: bool = bool(comparisons[condition.op]) if override == null else bool(override)
            if not truth:
                _holds.erase(key)
                return false
            if not _holds.has(key):
                _holds[key] = _now
            return (_now - float(_holds[key])) * 1000.0 + 0.0000001 >= float(condition.get("holdMs", 0))
    return false

func _eligible(edge: Dictionary, events: Array) -> bool:
    if not data.supportedStateIds.has(edge.toStateId):
        return false
    var override = null
    if edge.when.kind == "param" and edge.enterAbove != null and edge.exitBelow != null:
        var latch: Dictionary = _latches.get(edge.id, {"armed": true, "active": false})
        var value: float = _parameter_value(edge.when.paramId)
        if value <= float(edge.exitBelow):
            latch.armed = true
            latch.active = false
        elif latch.armed and (value > float(edge.enterAbove) if edge.when.op == ">" else value >= float(edge.enterAbove)):
            latch.active = true
        _latches[edge.id] = latch
        override = latch.armed and latch.active
    if edge.toStateId == _state or (edge.fromStateId != "*" and edge.fromStateId != _state) or _now < _active_since:
        return false
    var truth: bool = _condition(edge.when, edge.id, events, override)
    return truth and (_now - _active_since) * 1000.0 + 0.0000001 >= float(edge.dwellMs)

func _contains_event(condition: Dictionary) -> bool:
    if condition.kind == "event":
        return true
    if condition.kind == "all" or condition.kind == "any":
        for child in condition.of:
            if _contains_event(child):
                return true
    return false

func _evaluate(events: Array) -> void:
    var replaying: bool = _scenario_status == "playing"
    var epoch: int = _scenario_epoch
    var eligible: Array = []
    for edge in data.transitions:
        if _eligible(edge, events):
            eligible.append(edge)
    var retained: Array = []
    for request in _pending:
        if request.edge.is_empty() or _eligible(request.edge, request.events if not request.events.is_empty() else events):
            retained.append(request)
    _pending = retained
    var candidates: Array = []
    for index in eligible.size():
        var edge: Dictionary = eligible[index]
        if not _pending.any(func(request): return request.id == edge.id):
            candidates.append({"edge": edge, "order": index})
    candidates.sort_custom(func(a, b): return int(a.edge.priority) < int(b.edge.priority) if a.edge.priority != b.edge.priority else int(a.order) < int(b.order))
    var immediate: String = ""
    for candidate in candidates:
        if candidate.edge.quantize == "immediate":
            immediate = candidate.edge.id
    for candidate in candidates:
        var edge: Dictionary = candidate.edge
        if edge.quantize == "immediate" and edge.id != immediate:
            continue
        if edge.fromStateId != "*" and edge.fromStateId != _state:
            continue
        _queue({"id": edge.id, "state": edge.toStateId, "edge": edge, "events": events.duplicate() if _contains_event(edge.when) else [], "priority": int(edge.priority)}, edge.quantize)
        if replaying and not _scenario_owns(epoch):
            return

func _queue(request: Dictionary, quantize: String) -> void:
    if not _can_adapt():
        return
    if quantize == "immediate":
        if _scenario_status == "playing" and _now < _active_since:
            return
        request.target = _now
        _commit(request)
        return
    var beats: float = 1.0
    if quantize == "bar" or quantize == "phrase":
        beats *= float(data.beatsPerBar)
    if quantize == "phrase":
        beats *= float(data.phraseLengthBars)
    var quantum: float = beats * (60.0 / float(data.bpm) if _scenario_status == "playing" else seconds_per_beat())
    request.target = ceil((_now + LOOKAHEAD_SECONDS) / quantum) * quantum
    _pending = _pending.filter(func(existing): return not (request.priority > existing.priority and existing.target >= request.target or request.priority == existing.priority and existing.target == request.target))
    _pending.append(request)
    transition_queued.emit(request.id, request.target)

func _commit(request: Dictionary) -> void:
    if not data.supportedStateIds.has(request.state):
        return
    var edge: Dictionary = request.edge
    if float(request.target) == _last_commit_time and int(request.priority) < _last_commit_priority:
        return
    if not edge.is_empty() and edge.fromStateId != "*" and edge.fromStateId != _state:
        return
    _state = request.state
    _active_since = float(request.target)
    _last_commit_time = float(request.target)
    _last_commit_priority = int(request.priority)
    _holds.clear()
    if not edge.is_empty() and _latches.has(edge.id):
        _latches[edge.id] = {"armed": false, "active": false}
    var fade: float = float(edge.fadeBeats) if not edge.is_empty() else -1.0
    if _scenario_status == "playing":
        _scenario_audio_states.append({"state": _state, "target": request.target, "fade": fade})
    else:
        _apply_state(fade, float(request.target))
    state_changed.emit(_state, float(request.target))

func _advance(time: float) -> void:
    if not is_finite(time) or time < _now or not _playing or _manual_pause or _tree_pause:
        return
    _now = time
    var replaying: bool = _scenario_status == "playing"
    var epoch: int = _scenario_epoch
    if data.adaptive:
        _evaluate([])
    if replaying and not _scenario_owns(epoch):
        return
    var horizon: float = _now + LOOKAHEAD_SECONDS
    var due: Array = _pending.filter(func(request): return float(request.target) < horizon if replaying else float(request.target) <= _now)
    _pending = _pending.filter(func(request): return float(request.target) >= horizon if replaying else float(request.target) > _now)
    due.sort_custom(func(a, b): return float(a.target) < float(b.target) if a.target != b.target else int(a.priority) > int(b.priority))
    for request in due:
        _commit(request)
        if replaying and not _scenario_owns(epoch):
            return
    _update_fades()

func _level_at(index: int, time: float) -> float:
    if not _fades.has(index):
        return float(_levels.get(index, 0.0))
    var fade: Dictionary = _fades[index]
    var fraction: float = 1.0 if float(fade.end) <= time else clampf((time - float(fade.start)) / (float(fade.end) - float(fade.start)), 0.0, 1.0)
    return lerpf(float(fade.from), float(fade.to), fraction)

func _apply_state(fade_beats: float, boundary: float) -> void:
    _write_state_fades(fade_beats, boundary, _state)
    _update_fades()

func _write_state_fades(fade_beats: float, boundary: float, state_id: String) -> void:
    if _sync == null:
        return
    var active: Array = []
    for state in data.states:
        if state.id == state_id:
            active = state.activeLayerIds
    for index in data.layers.size():
        var layer: Dictionary = data.layers[index]
        var duration: float = (float(layer.fadeBeats) if fade_beats < 0.0 else fade_beats) * (60.0 / float(data.bpm) if _scenario_status == "playing" else seconds_per_beat())
        _fades[index] = {"from": _level_at(index, boundary), "to": 1.0 if active.has(layer.id) else 0.0, "start": boundary, "end": boundary + duration}

func _update_fades() -> void:
    if _sync == null:
        return
    _scenario_update_audio(_now)
    for index in data.layers.size():
        var level: float = _level_at(index, _now)
        _levels[index] = level
        _sync.set_sync_stream_volume(index, linear_to_db(level) if level > 0.0 else -INF)
        if _fades.has(index) and float(_fades[index].end) <= _now:
            _fades.erase(index)


func _input_capture_token(value: String) -> bool:
    if value.is_empty():
        return false
    var units: int = 0
    for index in value.length():
        var code: int = value.unicode_at(index)
        units += 2 if code > 65535 else 1
        if code in [9, 10, 11, 12, 13, 32, 160, 5760, 8232, 8233, 8239, 8287, 12288, 65279] or code >= 8192 and code <= 8202:
            return false
    return units <= 160

# Arm before a fresh Play so replay can start from the same authored defaults.
func begin_input_capture(source_id: String) -> bool:
    if not _ready_ok or _playing or not data.gameplayInputCapture.available or not _input_capture_token(source_id):
        return false
    if _input_capture_status in ["armed", "starting", "recording"]:
        return false
    _input_capture_status = "armed"
    _input_capture_source = source_id
    _input_capture_events.clear()
    _input_capture_result.clear()
    _input_capture_last = 0.0
    _input_capture_calls = 0
    _input_capture_message = "Armed. Explicit Play starts a fresh capture."
    return true

func _input_capture_start() -> void:
    if _input_capture_status == "starting":
        _input_capture_status = "recording"
        _input_capture_message = "Accepted controls on the Godot playback clock."

func _input_capture_interrupt(reason: String) -> void:
    if _input_capture_status in ["armed", "starting", "recording"]:
        _input_capture_status = "failed"
        _input_capture_result.clear()
        _input_capture_message = reason

func _input_capture_guard(time: float) -> bool:
    if _input_capture_status != "recording":
        return false
    if not _playing or _manual_pause or _tree_pause or get_tree().paused:
        _input_capture_interrupt("Pause or stopped playback is outside this capture contract.")
    elif not is_finite(time) or time < _input_capture_last:
        _input_capture_interrupt("Playback clock lost continuity. No partial trace was published.")
    elif time > float(data.gameplayInputCapture.maximumSeconds):
        _input_capture_interrupt("Capture exceeded 300 seconds. No truncated trace was published.")
    return _input_capture_status == "recording"

func _input_capture_append(fields: Dictionary, time: float) -> void:
    if _input_capture_status != "recording":
        return
    _input_capture_calls += 1
    if not _input_capture_guard(time):
        return
    if _input_capture_events.size() >= int(data.gameplayInputCapture.maximumInputs) or time >= float(data.gameplayInputCapture.maximumSeconds):
        _input_capture_interrupt("Input or duration limit exceeded. No truncated trace was published.")
        return
    if fields.kind == "state" and (int(fields.priority) < -9007199254740991 or int(fields.priority) > 9007199254740991):
        _input_capture_interrupt("State priority is outside the shared safe-integer contract.")
        return
    var input: Dictionary = fields.duplicate(true)
    input.id = "input-%s" % (_input_capture_events.size() + 1)
    input.atSeconds = time
    _input_capture_events.append(input)
    _input_capture_last = time

# Multiple event truths in one evaluation cannot be replaced by sequential inputs.
func _input_capture_event_batch(ids: Array, time: float) -> void:
    if _input_capture_status != "recording" or ids.is_empty():
        return
    if ids.size() > 1:
        _input_capture_calls += 1
        _input_capture_interrupt("Simultaneous event batches need a matching replay contract. No sequential substitute was recorded.")
        return
    _input_capture_append({"kind": "event", "eventId": ids[0]}, time)

func input_capture_snapshot() -> Dictionary:
    return {"status": _input_capture_status, "sourceId": _input_capture_source,
        "cueId": data.gameplayInputCapture.cueId, "cueRevisionFormat": "cue-v1",
        "cueSha256": data.gameplayInputCapture.cueSha256,
        "inputsRecorded": _input_capture_events.size(), "acceptedCallsObserved": _input_capture_calls,
        "lastInputSeconds": _input_capture_last, "message": _input_capture_message,
        "evidence": "Accepted control inputs only. Not runtime-decision, audio, authenticated game identity or listening evidence."}

# Finish before Stop. This returns exact UTF8 text/hash; the caller owns saving it.
func finish_input_capture() -> Dictionary:
    if _input_capture_status == "complete":
        return _input_capture_result.duplicate(true)
    if _input_capture_status != "recording":
        return {"ok": false, "receipt": input_capture_snapshot()}
    var duration: float = _clock_seconds()
    if not _input_capture_guard(duration):
        return {"ok": false, "receipt": input_capture_snapshot()}
    if duration <= 0.0 or not _input_capture_events.is_empty() and duration <= _input_capture_last:
        return {"ok": false, "message": "Let the playback clock advance past the last input, then Finish again.", "receipt": input_capture_snapshot()}
    var trace: Dictionary = {"format": "sigmaudio-gameplay-trace", "version": 1,
        "sourceId": _input_capture_source, "cueId": data.gameplayInputCapture.cueId,
        "clock": "elapsed-seconds", "bpm": data.bpm,
        "meter": data.gameplayInputCapture.meter.duplicate(true),
        "durationSeconds": duration, "events": _input_capture_events.duplicate(true)}
    var source_text: String = JSON.stringify(trace, "", true, true)
    if source_text.to_utf8_buffer().size() > int(data.gameplayInputCapture.maximumBytes):
        _input_capture_interrupt("Trace exceeds 256 KiB. No partial capture was published.")
        return {"ok": false, "receipt": input_capture_snapshot()}
    _input_capture_status = "complete"
    _input_capture_message = "Finished. Explicitly save sourceText as UTF8 without a BOM."
    _input_capture_result = {"ok": true,
        "capture": {"sourceText": source_text, "sha256": source_text.sha256_text()},
        "receipt": input_capture_snapshot()}
    return _input_capture_result.duplicate(true)


func _scenario_owns(epoch: int) -> bool:
    return _scenario_epoch == epoch and _scenario_status == "playing"

func _scenario_manual_controls() -> bool:
    if _scenario_status == "playing":
        push_warning("SigmAudio: Stop saved scenario replay before sending manual controls.")
        return false
    return true

func _scenario_update_audio(now: float) -> void:
    var due: Array = _scenario_audio_states.filter(func(change): return float(change.target) <= now)
    _scenario_audio_states = _scenario_audio_states.filter(func(change): return float(change.target) > now)
    for change in due:
        _scenario_audio_state = change.state
        _write_state_fades(float(change.fade), float(change.target), change.state)

func play_scenario(exact_id: String, mode: String) -> bool:
    _scenario_rejection = ""
    if mode != "music-only" or not _ready_ok or get_tree().paused:
        _scenario_rejection = "Use a ready, unpaused player and explicit music-only mode."
        return false
    var selected: Dictionary = {}
    for scenario in data.scenarioReplay.scenarios:
        if scenario.id == exact_id:
            selected = scenario
    if selected.is_empty() or not selected.supported:
        _scenario_rejection = "Unknown exact scenario ID." if selected.is_empty() else "; ".join(selected.reasons)
        return false
    _input_capture_interrupt("Saved replay started. This is not a fresh game-input recording.")
    _scenario_epoch += 1
    _scenario_status = "starting"
    _scenario_source = selected.duplicate(true)
    _scenario_index = 0
    _scenario_cycle = 0
    _scenario_read = 0
    _scenario_actions = 0
    _scenario_last_clock = 0.0
    _scenario_lateness = 0.0
    _scenario_records.clear()
    _scenario_omitted = 0
    _scenario_ramps.clear()
    _scenario_requested.clear()
    for parameter in data.parameters:
        _scenario_requested[parameter.id] = parameter.defaultValue
    if not play():
        _scenario_status = "failed"
        _scenario_message = "Native player refused startup."
        return false
    _scenario_status = "playing"
    _scenario_message = "Saved music inputs on the native playback clock."
    return true

func _scenario_finish(status: String, message: String) -> void:
    if _scenario_status != "playing":
        return
    _scenario_status = status
    _scenario_message = message
    _scenario_ramps.clear()

func _scenario_fail(message: String) -> void:
    _scenario_finish("failed", message)
    stop()

func _scenario_dispatch(input: Dictionary, now: float, epoch: int) -> bool:
    var accepted: bool = false
    match input.kind:
        "state": accepted = _set_state(input.stateId, input.quantize, int(input.priority), now)
        "event": accepted = _trigger_events([input.eventId], now)
        "parameter": accepted = _set_parameter(input.paramId, float(input.value), now)
    if not _scenario_owns(epoch):
        return false
    if accepted:
        _scenario_actions += 1
    return accepted

func _scenario_sample_ramps(at_time: float, now: float, epoch: int) -> bool:
    for id in _scenario_ramps.keys():
        var ramp: Dictionary = _scenario_ramps[id]
        var fraction: float = clampf((at_time - float(ramp.start)) / (float(ramp.end) - float(ramp.start)), 0.0, 1.0)
        var target: float = float(ramp.to) if fraction == 1.0 else lerpf(float(ramp.from), float(ramp.to), fraction)
        if target != float(_scenario_requested[id]):
            _scenario_requested[id] = target
            if not _scenario_dispatch({"kind": "parameter", "paramId": id, "value": target}, now, epoch):
                return false
            if _manual_pause or _tree_pause or get_tree().paused:
                return true
        if fraction == 1.0:
            _scenario_ramps.erase(id)
    return _scenario_owns(epoch)

func _scenario_tick(now: float) -> void:
    if _scenario_status != "playing":
        return
    var epoch: int = _scenario_epoch
    if not is_finite(now) or now < _scenario_last_clock or now - _scenario_last_clock > float(data.scenarioReplay.maximumInputLatenessSeconds):
        _scenario_fail("Native scenario clock lost its scheduling horizon. Restart; missed inputs were not skipped.")
        return
    _scenario_last_clock = now
    if now >= float(_scenario_source.durationSeconds):
        if _scenario_read != int(_scenario_source.totalInputs):
            _scenario_fail("Scenario endpoint arrived before every authored input was read.")
        else:
            _scenario_finish("complete", "Authored endpoint reached; native Stop occurs on this engine frame.")
            stop()
        return
    while _scenario_cycle < int(_scenario_source.repeats):
        if _scenario_index >= _scenario_source.events.size():
            _scenario_cycle += 1
            _scenario_index = 0
            continue
        var input: Dictionary = _scenario_source.events[_scenario_index]
        var intended: float = float(_scenario_cycle) * float(_scenario_source.sequenceSeconds) + float(input.atSeconds)
        if intended > now + 0.000000001:
            break
        if not _scenario_sample_ramps(intended, now, epoch):
            if _scenario_owns(epoch):
                _scenario_fail("Native parameter-ramp control was refused.")
            return
        if _manual_pause or _tree_pause or get_tree().paused:
            return
        var cycle: int = _scenario_cycle
        if input.kind == "ramp":
            _scenario_ramps[input.paramId] = {"from": _scenario_requested[input.paramId], "to": input.toValue,
                "start": intended, "end": intended + float(input.durationSeconds), "cycle": cycle}
        else:
            if input.kind == "parameter":
                _scenario_ramps.erase(input.paramId)
                _scenario_requested[input.paramId] = input.value
            if not _scenario_dispatch(input, now, epoch):
                if _scenario_owns(epoch):
                    _scenario_fail("A saved native control was refused. No following inputs were applied.")
                return
        if not _scenario_owns(epoch):
            return
        _scenario_index += 1
        _scenario_read += 1
        _scenario_lateness = maxf(_scenario_lateness, now - intended)
        _scenario_records.append({"inputId": input.id, "kind": input.kind, "cycle": cycle,
            "intendedTime": intended, "acceptedTime": now, "clock": "audio"})
        if _scenario_records.size() > int(data.scenarioReplay.maximumReceiptRecords):
            _scenario_records.pop_front()
            _scenario_omitted += 1
        if _manual_pause or _tree_pause or get_tree().paused:
            return
    if not _scenario_sample_ramps(now, now, epoch) and _scenario_owns(epoch):
        _scenario_fail("Native parameter-ramp control was refused.")

func scenario_snapshot() -> Dictionary:
    return {"status": _scenario_status, "message": _scenario_message, "lastStartError": _scenario_rejection,
        "mode": "music-only", "scenarioId": _scenario_source.get("id", ""),
        "sourceIdentity": {"cueRevisionFormat": "cue-v1", "cueSha256": data.gameplayInputCapture.cueSha256,
            "scenarioSha256": _scenario_source.get("scenarioSha256", null),
            "captureSourceSha256": _scenario_source.get("captureSourceSha256", null)},
        "durationSeconds": _scenario_source.get("durationSeconds", 0.0), "observedSeconds": _scenario_last_clock,
        "inputsRead": _scenario_read, "actionsDispatched": _scenario_actions,
        "maxInputLatenessSeconds": _scenario_lateness, "omittedRecords": _scenario_omitted,
        "records": _scenario_records.duplicate(true), "paused": _manual_pause or _tree_pause,
        "referenceRegionsExcluded": _scenario_source.get("referenceRegionsExcluded", 0),
        "scheduledStateId": _state, "audibleStateId": _scenario_audio_state,
        "pendingAudioStateChanges": _scenario_audio_states.duplicate(true),
        "evidence": "Observed native input scheduling and lookahead controller decisions. Layer gains/Stop use engine frames; not complete PCM, owner-game execution or listening evidence."}

func snapshot() -> Dictionary:
    var values: Dictionary = {}
    for parameter in data.parameters:
        values[parameter.id] = _parameter_value(parameter.id)
    return {"stateId": _state, "time": _now, "activeSince": _active_since, "parameters": values,
        "pending": _pending.duplicate(true), "levels": _levels.duplicate(), "playing": _playing,
        "paused": _manual_pause or _tree_pause, "pcmGuard": _guard_pcm, "adaptive": data.adaptive}
