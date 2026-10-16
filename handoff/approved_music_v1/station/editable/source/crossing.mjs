// "One Note Apart: Crossing" — an adaptive prototype. Condi, 2026-10-10.
// One 16-bar loop at 150 BPM in E, written as six phase-locked layers. Four states choose which layers sound.
// The idea is One Note Apart's: two worlds argue about one note, G (synth world) against G# (old world).
//   Explore     floor + echoes     the worlds are far apart: a pedal, a machine pulse, and the cell in fragments,
//                                   G and G# never in the same bar, and never together
//   Combat      floor + engine + drums + argument     the bands trade phrases over a thirdless riff
//   Climax      floor + engine + drums + payoff       one band: the hook in octaves over E7#9, G and G# at once.
//                                   Nothing earlier sounds both, so the chord is the payoff
//   Resolution  floor + truce      a cadence onto an open fifth, no third at all: the argument is set down,
//                                   then the echoes return
// Every layer is written against one E pedal and one root plan, so any combination is in tune with any other.
export default function (h, opt = {}) {
  const { seq, drums, midi, legato } = h
  const v = opt.version ?? 2
  // v2: the first render measured Explore at -40 LUFS, 19 dB under Combat. Restrained, but too far away to be heard.
  // Floor +9 dB, echoes +12 dB, truce +3 dB brings Explore about 9 dB under Combat.
  const lift = (db1, db2) => (v >= 2 ? db2 : db1)
  const B = (bar) => (bar - 1) * 16, L = 16
  const roots = ['E', 'E', 'C', 'B', 'E', 'E', 'A', 'B', 'E', 'E', 'C', 'B', 'A', 'C', 'B', 'B']   // bar 1..16
  const rootOf = (bar) => roots[bar - 1]
  const hits = (start, mask, chord, vel, d = 2) => {
    const ps = chord.split(',').map(midi), o = []
    ;[...mask.replace(/\s/g, '')].forEach((c, i) => { if (c !== '.') ps.forEach((p) => o.push({ t: start + i, d, p, v: c === 'X' ? vel + 16 : c === 'o' ? vel - 20 : vel })) })
    return o
  }
  const lowRoot = { E: 'E2', C: 'C2', B: 'B1', A: 'A1' }

  // ================= FLOOR (every state): an E pedal and a machine pulse =================
  const drone = [{ t: 0, d: L * 16, p: midi('E2'), v: 74 }, { t: 0, d: L * 16, p: midi('B2'), v: 62 }]
  // v2: one 25.6 s note measured as dying at 22.5 s, so the pedal dropped out for the last two bars of every loop.
  // Two alternating drone tracks restrike it every phrase, overlapping by a bar, so no voice is ever retriggered.
  const droneA = [], droneB = []
  for (let ph = 0; ph < 4; ph++) for (const [p, vel] of [['E2', 74], ['B2', 62]])
    (ph % 2 ? droneB : droneA).push({ t: ph * 64, d: 80, p: midi(p), v: vel })
  // SigmAudio clips every note at the loop end (src/model/events.ts:36), and a held note measured as falling silent
  // about 0.7 s before the cue end (0.3 s before its end mid-cue). Nothing can sustain across the seam, so the seam
  // is written instead: the pedal lets go halfway through bar 16 and the pulse winds up into the downbeat.
  droneB.filter((n) => n.t === 192).forEach((n) => { n.d = 56 })
  const pulse = []
  for (let bar = 1; bar <= L; bar++) for (let s = 0; s < 16; s += 2)
    pulse.push({ t: B(bar) + s, d: 1, p: midi(s % 4 ? 'B3' : 'E3'), v: (s === 0 ? 70 : s % 8 === 6 ? 58 : 46) })
  if (v >= 2) {
    for (const n of pulse.filter((n) => n.t >= B(16) + 8)) pulse.splice(pulse.indexOf(n), 1)
    for (let s = 8; s < 16; s++) pulse.push({ t: B(16) + s, d: 1, p: midi(s % 2 ? 'B3' : 'E3'), v: 46 + (s - 8) * 5 })
  }

  // ================= ECHOES (explore): the cell in fragments, one world at a time =================
  const echoSynth = [
    ...seq(B(1), 'E4/4 B4/4 A#4/4 F#4/4 | G4/12 ./4', 74),                // the synth world asks, and says G
    ...seq(B(9), 'E4/4 B4/4 A#4/8', 70),                                   // ...and stops halfway
    ...seq(B(15), 'G4/12 ./4', 62),                                        // the question left over the seam
  ]
  const echoHorn = [
    ...seq(B(5), 'E3/4 B3/4 A#3/4 F#3/4 | G#3/12 ./4', 70),                // the old world answers with G#, far away
    ...seq(B(13), 'A3/4 E4/4 D#4/4 B3/4', 66),                             // the cell on A
    ...seq(B(16), 'G#3/12 ./4', 60),                                       // and answers the leftover G a bar later
  ]

  // ================= ENGINE (combat, climax): the riff, with its third taken out =================
  // The original riff walked through the third. Here it walks through the second instead,
  // so the engine belongs to neither world and can sit under both.
  const riff = (bar, vel = 100) => {
    const R = midi(lowRoot[rootOf(bar)])
    return [[0, 2, 0, 12], [2, 1, 0, -6], [3, 1, 12, 0], [6, 2, 0, -8], [8, 2, 2, -6], [10, 2, 5, -4], [12, 2, 6, -2], [14, 2, 7, 4]]
      .map(([s, d, iv, dv]) => ({ t: B(bar) + s, d, p: R + iv, v: vel + dv }))
  }
  const engine = []
  for (let bar = 1; bar <= L; bar++) engine.push(...riff(bar, bar % 4 === 0 ? 104 : 98))

  // ================= DRUMS (combat, climax): kept below the weapons =================
  // Kick and timpani carry the weight, the snare carries the backbeat, and there are no cymbals or open hats:
  // the 2-5 kHz band is left for gunfire, enemies and machinery.
  const kit808 = [], kitOrch = []
  for (let bar = 1; bar <= L; bar++) {
    const turn = bar % 4 === 0
    kit808.push(...drums(B(bar), { 36: turn ? 'X.....x...x.x.x.' : 'X.....x...x..x..', 42: 'g...g...g...g...' }))
    kitOrch.push(...drums(B(bar), { 38: turn ? '....x......gx.gg' : '....x.......x...' }))
  }

  // ================= ARGUMENT (combat): two-bar phrases, each world in its own register =================
  const argSynth = [
    ...seq(B(1), 'E5/2 ./1 E5/1 B5/3 A#5/3 F#5/4 G5/2 | A5/3 G5/3 F#5/2 E5/2 D5/2 E5/4', 98),
    ...seq(B(7), 'A4/2 ./1 A4/1 E5/3 D#5/3 B4/4 C5/2 | D5/3 C5/3 B4/2 A4/2 F#4/2 A4/4', 98),
    ...seq(B(9), 'E5/2 ./1 E5/1 B5/3 A#5/3 B5/2 D6/2 C#6/2 | B5/6 A5/2 G5/2 F#5/2 E5/4', 100),
    ...seq(B(13), 'E5/2 B5/2 A#5/4 G5/8', 102),                            // single bars now
    ...seq(B(15), 'E5/2 B5/2 G5/4', 104),                                  // half bars
    ...seq(B(16), 'B4/2 C5/2 D#5/2 E5/2 F#5/2 G5/1 G#5/1 A5/2 A#5/2', 96), // both run up one scale that holds both notes
  ]
  const argHorn = [
    ...seq(B(3), 'C4/3 G#4/3 E4/3 C4/3 B3/4 | B3/3 D#4/3 F#4/2 A4/4 G#4/4', 94),
    ...seq(B(5), 'E4/3 B4/3 A#4/3 F#4/3 G#4/4 | A4/3 G#4/3 F4/2 E4/8', 96),
    ...seq(B(11), 'G#4/3 E4/3 C4/3 E4/3 G#4/4 | B4/3 A4/3 F#4/2 D#4/8', 96),
    ...seq(B(14), 'E4/2 B4/2 A#4/4 G#4/8', 100),
    ...seq(B(15) + 8, 'E4/2 B4/2 G#4/4', 102),
    ...seq(B(16), 'B3/2 C4/2 D#4/2 E4/2 F#4/2 G4/1 G#4/1 A4/2 A#4/2', 92),
  ]
  // each world's chords sound only under its own phrases
  const synthChord = { E: 'E4,G4,B4,D5', C: 'E4,G4,C5', B: 'D#4,F#4,B4', A: 'E4,G4,A4,C5' }
  const oldChord = { E: '[E3,G#3,B3,D4]', C: '[C3,E3,G#3]', B: '[B2,D#3,F#3,A3]', A: '[A2,C3,E3,G#3]' }
  const stabMask = '..x..x....x...x.'
  const argStabs = [], argBrass = []
  const owner = [ 'S', 'S', 'H', 'H', 'H', 'H', 'S', 'S', 'S', 'S', 'H', 'H', 'S', 'H', '', '' ]
  for (let bar = 1; bar <= L; bar++) {
    if (owner[bar - 1] === 'S') argStabs.push(...hits(B(bar), stabMask, synthChord[rootOf(bar)], 76))
    if (owner[bar - 1] === 'H') argBrass.push(...seq(B(bar), `${oldChord[rootOf(bar)]}/14`, 78))
  }

  // ================= PAYOFF (climax): one band, the hook in octaves, both Gs at once =================
  const hook = [
    ...seq(B(1), 'E5/2 ./1 E5/1 B5/3 A#5/3 F#5/4 G5/2 | A5/3 G5/3 F#5/2 E5/2 D5/2 E5/4', 106),
    ...seq(B(3), 'C5/2 ./1 C5/1 G5/3 F#5/3 D5/4 E5/2 | D#5/3 F#5/3 A5/2 B5/8', 104),
    ...seq(B(5), 'E5/2 ./1 E5/1 B5/3 A#5/3 B5/2 D6/2 C#6/2 | B5/6 A5/2 G5/2 F#5/2 E5/2 D#5/2', 108),
    ...seq(B(7), 'A4/2 ./1 A4/1 E5/3 D#5/3 B4/4 C5/2 | B4/3 A4/3 F#4/2 D#4/8', 104),
    ...seq(B(9), 'E5/2 ./1 E5/1 B5/3 A#5/3 F#5/4 G5/2 | A5/3 G5/3 F#5/2 E5/2 D5/2 E5/4', 108),
    ...seq(B(11), 'C5/2 ./1 C5/1 G5/3 F#5/3 D5/4 E5/2 | D#5/3 F#5/3 A5/2 B5/8', 106),
    ...seq(B(13), 'A5/3 G#5/3 G5/2 E5/8', 110),                           // the peak: A, G#, G — both notes, one line
    ...seq(B(14), 'E5/3 G5/3 C6/2 B5/8', 108),
    ...seq(B(15), 'B5/4 A#5/4 F#5/4 G5/2 G#5/2 | B5/14 ./2', 110),
  ]
  const payHorn = hook.map((n) => ({ ...n, p: n.p - 12, v: n.v - 6 }))
  const lowVoicing = { E: 'E3,G#3,D4', C: 'E3,G3,C4', B: 'D#3,A3,B3', A: 'E3,A3,C4' }     // the old world's G# lives low
  const highVoicing = { E: 'D5,G5,B5', C: 'E5,G5,C6', B: 'D#5,F#5,B5', A: 'E5,A5,C6' }   // the synth world's G lives high
  const payBrass = [], payStabs = [], payHits = []
  for (let bar = 1; bar <= L; bar++) {
    payBrass.push(...hits(B(bar), 'X.....x.....x.x.', lowVoicing[rootOf(bar)], 92, 3))
    payStabs.push(...hits(B(bar), stabMask, highVoicing[rootOf(bar)], 68))
    // every phrase starts with a hit, so the climax lands on a downbeat whichever phrase it enters on
    payHits.push(...drums(B(bar), { 36: bar % 4 === 1 ? 'X.....x.....x...' : 'x.....x.....x...', 46: bar % 4 === 1 ? 'x...............' : '' }))
  }
  // fiddle: the E7#9 arpeggio, an octave lower than in the original so it doesn't pierce
  const fidE = 'E4/1 G#4 B4 D5 G5 D5 B4 G#4 E4 G#4 B4 D5 G5 D5 B4 G#4'
  const fidBar = { E: fidE, C: 'C4/1 E4 G4 C5 E5 C5 G4 E4 C4 E4 G4 C5 E5 C5 G4 E4', B: 'B3/1 D#4 F#4 A4 B4 A4 F#4 D#4 B3 D#4 F#4 A4 B4 A4 F#4 D#4', A: 'A3/1 C4 E4 A4 C5 A4 E4 C4 A3 C4 E4 A4 C5 A4 E4 C4' }
  const payFid = []
  for (let bar = 1; bar <= L; bar++) payFid.push(...seq(B(bar), fidBar[rootOf(bar)], 70))

  // ================= TRUCE (resolution): a four-bar cadence, repeated, so it works from any phrase =================
  const truceHit = [], truceUnisonS = [], truceUnisonH = [], truceLow = [], truceDrum = []
  for (let ph = 0; ph < 4; ph++) {
    const b = 1 + ph * 4
    truceHit.push(...seq(B(b), '[E3,B3,E4]/6', 112), ...seq(B(b + 2), '[E3,B3]/14', 60))
    truceLow.push({ t: B(b), d: 10, p: midi('E1'), v: 112 })
    truceDrum.push(...drums(B(b), { 36: 'X...............', 46: 'x...............' }))
    const cell = 'E4/4 B4/4 | A#4/4 F#4/4 E4/8 | E4/12'
    truceUnisonS.push(...seq(B(b) + 8, cell, 82))
    truceUnisonH.push(...seq(B(b) + 8, cell, 80))
  }

  const lead = { version: 2, attack: 0.006, decay: 0.18, sustain: 0.7, release: 0.15, brightnessOctaves: 0.3, resonance: 1.4,
    modulation: { waveform: 'sine', rateHz: 5.5, pitchCents: 12, tremolo: 0, filterOctaves: 0 } }
  const softLead = { ...lead, attack: 0.05, release: 0.6, brightnessOctaves: -0.6, resonance: 0.6 }
  const tame = { kind: 'eq', lowDb: 0, midDb: -4, midHz: 3200, midQ: 1, highDb: -4 }

  const tracks = [
    // floor
    ...(v >= 2 ? [
      { name: 'Floor: hurdy-gurdy pedal', role: 'texture', instrumentId: 'hurdyGurdy', mix: { gainDb: 0, pan: -0.15, spaceAmount: 0.35, toneHz: 3000 }, notes: droneA },
      { name: 'Floor: hurdy-gurdy pedal, alternate', role: 'texture', instrumentId: 'hurdyGurdy', mix: { gainDb: 0, pan: -0.1, spaceAmount: 0.35, toneHz: 3000 }, notes: droneB },
    ] : [{ name: 'Floor: hurdy-gurdy pedal', role: 'texture', instrumentId: 'hurdyGurdy', mix: { gainDb: -9, pan: -0.15, spaceAmount: 0.35, toneHz: 3000 }, notes: drone }]),
    { name: 'Floor: machine pulse', role: 'texture', instrumentId: 'brightPluck', mix: { gainDb: lift(-14, -5), pan: 0.2, spaceAmount: 0.3, toneHz: 1800 }, notes: pulse },
    // echoes
    { name: 'Echoes: synth (G)', role: 'motif', instrumentId: 'synthLead', mix: { gainDb: lift(-4, 8), pan: 0.35, spaceAmount: 0.55 }, synthPatch: softLead,
      effects: [{ kind: 'delay', seconds: 0.6, feedback: 0.4, wet: 0.35 }], notes: echoSynth },
    { name: 'Echoes: horn (G#)', role: 'motif', instrumentId: 'orchBrass', mix: { gainDb: lift(-3, 9), pan: -0.35, spaceAmount: 0.8 }, notes: legato(echoHorn, 1) },
    // engine
    { name: 'Engine: riff bass', role: 'bass', instrumentId: 'driveBass', mix: { gainDb: -7, pan: 0, spaceAmount: 0 },
      effects: [{ kind: 'saturation', character: 'soft', driveDb: 8, wet: 0.4, outputGainDb: -2 }], notes: engine },
    // drums
    { name: 'Drums: 808', role: 'drums', instrumentId: 'drums808', mix: { gainDb: -5, pan: 0, spaceAmount: 0.08, toneHz: 7000 }, notes: kit808 },
    { name: 'Drums: snare', role: 'drums', instrumentId: 'orchKit', mix: { gainDb: -8, pan: -0.1, spaceAmount: 0.3 }, notes: kitOrch },
    // argument
    { name: 'Argument: synth lead (G)', role: 'motif', instrumentId: 'synthLead', mix: { gainDb: 3, pan: 0.32, spaceAmount: 0.2 }, synthPatch: lead,
      effects: [{ kind: 'delay', seconds: 0.3, feedback: 0.2, wet: 0.15 }, tame], notes: argSynth },
    { name: 'Argument: horn (G#)', role: 'motif', instrumentId: 'orchBrass', mix: { gainDb: 3, pan: -0.32, spaceAmount: 0.35 }, notes: legato(argHorn, 1) },
    { name: 'Argument: synth chords', role: 'chords', instrumentId: 'supersaw', mix: { gainDb: -2, pan: 0.4, spaceAmount: 0.2 }, effects: [tame], notes: argStabs },
    { name: 'Argument: brass chords', role: 'chords', instrumentId: 'orchBrass', mix: { gainDb: -2, pan: -0.4, spaceAmount: 0.4 }, notes: legato(argBrass, 1) },
    // payoff
    { name: 'Payoff: synth hook', role: 'motif', instrumentId: 'synthLead', mix: { gainDb: 4, pan: 0.2, spaceAmount: 0.22 }, synthPatch: lead,
      effects: [{ kind: 'delay', seconds: 0.3, feedback: 0.2, wet: 0.15 }, tame], notes: hook },
    { name: 'Payoff: horn hook', role: 'motif', instrumentId: 'orchBrass', mix: { gainDb: 4, pan: -0.2, spaceAmount: 0.35 }, notes: legato(payHorn, 1) },
    { name: 'Payoff: brass (G#, low)', role: 'chords', instrumentId: 'orchBrass', mix: { gainDb: 0, pan: -0.3, spaceAmount: 0.35 }, notes: payBrass },
    { name: 'Payoff: synth stabs (G, high)', role: 'chords', instrumentId: 'supersaw', mix: { gainDb: -4, pan: 0.35, spaceAmount: 0.2 }, effects: [tame], notes: payStabs },
    { name: 'Payoff: fiddle', role: 'motif', instrumentId: 'fiddle', mix: { gainDb: -6, pan: -0.45, spaceAmount: 0.3 }, effects: [tame], notes: payFid },
    { name: 'Payoff: timpani and cymbal', role: 'drums', instrumentId: 'orchKit', mix: { gainDb: -6, pan: 0, spaceAmount: 0.35 }, notes: payHits },
    // truce
    { name: 'Truce: brass chord', role: 'chords', instrumentId: 'orchBrass', mix: { gainDb: lift(2, 5), pan: -0.1, spaceAmount: 0.45 }, notes: truceHit },
    { name: 'Truce: synth in unison', role: 'motif', instrumentId: 'synthLead', mix: { gainDb: lift(-2, 1), pan: 0.2, spaceAmount: 0.5 }, synthPatch: softLead,
      effects: [{ kind: 'delay', seconds: 0.6, feedback: 0.3, wet: 0.25 }], notes: truceUnisonS },
    { name: 'Truce: horn in unison', role: 'motif', instrumentId: 'orchBrass', mix: { gainDb: lift(0, 3), pan: -0.2, spaceAmount: 0.5 }, notes: legato(truceUnisonH, 1) },
    { name: 'Truce: low E', role: 'bass', instrumentId: 'roundBass', mix: { gainDb: lift(-6, -3), pan: 0, spaceAmount: 0.1 }, notes: truceLow },
    { name: 'Truce: timpani and cymbal', role: 'drums', instrumentId: 'orchKit', mix: { gainDb: lift(-5, -2), pan: 0, spaceAmount: 0.4 }, notes: truceDrum },
  ]
  const of = (prefix) => tracks.filter((t) => t.name.startsWith(prefix)).map((t) => t.name)
  return {
    name: 'One Note Apart: Crossing (adaptive)', version: v, bpm: 150, meter: '4/4', key: { tonic: 4, mode: 'dorian' }, lengthBars: L, phraseLengthBars: 4,
    sections: [
      { name: 'Phrase 1 (E E C B)', kind: 'loop', startBar: 0, lengthBars: 4 },
      { name: 'Phrase 2 (E E A B)', kind: 'loop', startBar: 4, lengthBars: 4 },
      { name: 'Phrase 3 (E E C B)', kind: 'loop', startBar: 8, lengthBars: 4 },
      { name: 'Phrase 4 (A C B B)', kind: 'loop', startBar: 12, lengthBars: 4 },
    ],
    tracks,
    adaptive: {
      layers: [
        { name: 'Floor', purpose: 'base', fadeBeats: 4, tracks: of('Floor:') },
        { name: 'Echoes', purpose: 'texture', fadeBeats: 4, tracks: of('Echoes:') },
        { name: 'Engine', purpose: 'pulse', fadeBeats: 1, tracks: of('Engine:') },
        { name: 'Drums', purpose: 'combat', fadeBeats: 1, tracks: of('Drums:') },
        { name: 'Argument', purpose: 'combat', fadeBeats: 1, tracks: of('Argument:') },
        { name: 'Payoff', purpose: 'magic', fadeBeats: 0, tracks: of('Payoff:') },
        { name: 'Truce', purpose: 'harmony', fadeBeats: 0, tracks: of('Truce:') },
      ],
      base: 'Explore',
      states: [
        { name: 'Explore', layers: ['Floor', 'Echoes'] },
        { name: 'Combat', layers: ['Floor', 'Engine', 'Drums', 'Argument'] },
        { name: 'Climax', layers: ['Floor', 'Engine', 'Drums', 'Payoff'] },
        { name: 'Resolution', layers: ['Floor', 'Truce'] },
      ],
      parameters: [
        { name: 'threat', min: 0, max: 1, defaultValue: 0, smoothingMs: 200 },
        { name: 'style', min: 0, max: 1, defaultValue: 0, smoothingMs: 300 },
      ],
      transitions: [
        // a fight starts on the next bar, with almost no fade: the music should react like the player does
        { from: 'Explore', to: 'Combat', when: { kind: 'param', param: 'threat', op: '>=', value: 0.5 }, quantize: 'bar', fadeBeats: 1, priority: 5, enterAbove: 0.5, dwellMs: 0 },
        // the payoff waits for a phrase: it has to land on a downbeat to feel earned
        { from: 'Combat', to: 'Climax', when: { kind: 'param', param: 'style', op: '>=', value: 0.8, holdMs: 1000 }, quantize: 'phrase', fadeBeats: 0, priority: 4, enterAbove: 0.8, dwellMs: 3200 },
        { from: 'Climax', to: 'Combat', when: { kind: 'param', param: 'style', op: '<=', value: 0.5, holdMs: 2000 }, quantize: 'bar', fadeBeats: 2, priority: 3, exitBelow: 0.5, dwellMs: 6400 },
        // the fight ends at the end of a phrase, cut clean onto the truce chord
        { from: 'Combat', to: 'Resolution', when: { kind: 'param', param: 'threat', op: '<=', value: 0.1, holdMs: 1500 }, quantize: 'phrase', fadeBeats: 0, priority: 6, exitBelow: 0.1, dwellMs: 1600 },
        { from: 'Climax', to: 'Resolution', when: { kind: 'param', param: 'threat', op: '<=', value: 0.1, holdMs: 1500 }, quantize: 'phrase', fadeBeats: 0, priority: 6, exitBelow: 0.1, dwellMs: 1600 },
        // two bars of truce, then the echoes come back while the cadence dies away
        { from: 'Resolution', to: 'Explore', when: { kind: 'always' }, quantize: 'bar', fadeBeats: 4, priority: 1, dwellMs: 3200 },
        { from: 'Resolution', to: 'Combat', when: { kind: 'param', param: 'threat', op: '>=', value: 0.5 }, quantize: 'bar', fadeBeats: 1, priority: 5, enterAbove: 0.5, dwellMs: 0 },
      ],
    },
    master: { gainDb: -3 },
  }
}
