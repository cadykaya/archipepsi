// "Freight Bay" — adaptive FPS combat for the Shunter encounter in Archipepsi. Condi, 2026-10-13.
// 144 BPM, E minor, one 16-bar loop. 144 is the stamping press's own speed: in its recording it strikes every
// 0.31 s, which is a dotted eighth at 144. So the room's machine rhythm (3+3+3+3+4 sixteenths) is the tempo grid,
// and the combat riff lands on the press strokes.
// The Shunter's horn sounds a B major chord (D#, F#, B): the dominant of E minor. The hook is the horn's signal
// rhythm (long, long, short, long). In combat it climbs B, B, D#, F# and stays unresolved on the horn's chord;
// in Victory the same signal lands on E.
//   Working     bay + working             the room at work: press, clanks, valves, motor, a quiet bell
//   Noticed     bay + alert               the machines stop grooving; a rising motor and muted chugs on E
//   Combat      bay + drive + hook        riff on the press strokes, machine kit layered on a rock kit, bass,
//                                         lead guitar doubled by a tuned air horn
//   Escalation  ... + overload            heavy impacts, tremolo guitar, synth arpeggios, double-time snare,
//                                         a pneumatic hammer and big pressure releases
//   Recovery    bay + breath              badly hurt: half time
//   Victory     bay + clear               E major, a pressure-release sigh, the hook resolved; then Working
// Small hits play the Flinch stinger.
export default function (h, opt = {}) {
  const { seq, drums, midi } = h
  const v = opt.version ?? 1
  const B = (bar) => (bar - 1) * 16, L = 16
  //                      1    2    3    4    5    6    7    8    9   10   11   12   13   14   15   16
  const roots = v >= 2 ? ['E', 'E', 'E', 'C', 'E', 'D', 'E', 'B', 'E', 'E', 'E', 'C', 'E', 'F', 'E', 'B']   // every odd bar is E
    : ['E', 'E', 'E', 'E', 'C', 'C', 'A', 'B', 'E', 'E', 'E', 'E', 'C', 'D', 'F', 'B']
  const rootOf = (bar) => roots[(bar - 1 + L) % L]
  // where a guitarist plays each root: never under E2, the low open string
  const gtr = { E: midi('E2'), F: midi('F2'), A: midi('A2'), B: midi('B2'), C: midi('C3'), D: midi('D3') }
  const bassNote = { E: midi('E1'), F: midi('F1'), A: midi('A1'), B: midi('B1'), C: midi('C2'), D: midi('D2') }
  const P = (r, t, d, vel) => [r, r + 7, r + 12].map((p) => ({ t, d, p, v: vel }))            // power chord
  const BMAJ = (t, d, vel) => ['B2', 'F#3', 'B3', 'D#4'].map((n) => ({ t, d, p: midi(n), v: vel })) // the horn's chord
  const M = (r, t, vel = 80) => [{ t, d: 1, p: r, v: vel, m: 1 }]                                  // palm-muted chug
  const K = { kick: 36, snare: 38, clap: 39, ch: 42, oh: 46, ride: 51 }

  // ================= bay: the room, under every state =================
  // the conveyor bed (two overlapping notes so it never stops) and the motor, tuned to the key
  const conveyor = [{ t: 0, d: 136, p: 60, v: 100 }, { t: 128, d: 128, p: 60, v: 100 }]
  const motor = []
  for (let bar = 1; bar <= L; bar += 2) motor.push({ t: B(bar), d: 34, p: midi('E3'), v: 90 })

  // ================= working: the restrained, mechanical exploration =================
  const press = [], clank = [], valves = [], bell = [], pulse = [], lift = []
  const PRESS = [0, 3, 6, 9, 12]                                                                  // 3+3+3+3+4
  for (let bar = 1; bar <= L; bar++) {
    const o = B(bar)
    for (const s of PRESS) press.push({ t: o + s, d: 1, p: K.kick, v: s === 0 ? 96 : 74 })
    for (let s = 2; s < 16; s += 4) clank.push({ t: o + s, d: 1, p: K.ch, v: s === 14 ? 70 : 52 })
    if (bar % 2 === 0) valves.push({ t: o + 14, d: 2, p: K.clap, v: 64 })
    if (bar % 4 === 1) valves.push({ t: o, d: 1, p: K.ride, v: 58 })                                // a struck plate, a clock
    // a soft pulse on the root in eighths, the way the Crossing exploration pulses
    const r = gtr[rootOf(bar)] + 24
    for (let s = 0; s < 16; s += 2) pulse.push({ t: o + s, d: 1, p: s % 4 ? r + 7 : r, v: s === 0 ? 70 : 54 })
  }
  // the hydraulic lift sighs up a semitone (E to F, the room's Phrygian edge) and back, every four bars
  for (let bar = 1; bar <= L; bar += 4) lift.push(...seq(B(bar) + 4, 'E4/8 F4/12 E4/20', 74).map((n) => ({ ...n, p: n.p - 12 })))
  // the bell plants the hook, slowly and far away, in phrases 2 and 4
  bell.push(...seq(B(6), 'B4/4 ./2 B4/4 ./2 D#5/2 E5/18', 70))
  bell.push(...seq(B(14), 'B4/4 ./2 B4/4 ./2 D#5/2 F#5/18', 70))

  // ================= alert: the Shunter has noticed =================
  // the grooving stops; straight quarter strokes, muted eighths on E, a motor that climbs every phrase.
  // Nothing sustains between about 300 Hz and 1.5 kHz, where the horn's tones are.
  const alertPress = [], alertChug = [], alertMotor = [], alertHyd = [], alertHiss = []
  for (let bar = 1; bar <= L; bar++) {
    const o = B(bar)
    alertPress.push(...drums(o, { [K.kick]: 'x...o...x...o...' }))
    for (let s = 0; s < 16; s += 2) alertChug.push(...M(gtr.E, o + s, s % 8 === 0 ? 86 : s % 4 ? 60 : 72))
    if (bar % 2 === 0) alertHiss.push({ t: o + 12, d: 4, p: K.oh, v: 70 })
  }
  // bar 16 winds up in sixteenths so the loop seam pushes forward (Overclock's Engage taught this one)
  for (const n of alertChug.filter((n) => n.t >= B(16))) n.v = 0
  for (let s = 0; s < 16; s++) alertChug.push(...M(gtr.E, B(16) + s, 54 + s * 2.5))
  const climb = ['E3', 'F3', 'F#3', 'G3']
  climb.forEach((n, i) => { alertMotor.push({ t: B(1 + i * 4), d: 34, p: midi(n), v: 92 }, { t: B(3 + i * 4), d: 32, p: midi(n), v: 96 }) })
  for (let bar = 1; bar <= L; bar += 2) alertHyd.push({ t: B(bar), d: 32, p: midi('B2'), v: 80 })   // a dominant pedal, below the horn

  // ================= drive: combat =================
  const riffBar = (bar, vel = 108) => {
    const root = rootOf(bar), r = gtr[root], o = B(bar)
    if (root === 'E') {
      // E, E, F (the Phrygian grind), E, then G or the horn's B; muted chugs fill between the press strokes
      const last = bar % 2 ? [...P(gtr.E + 3, o + 12, 3, vel + 6)] : [...P(gtr.B, o + 12, 4, vel + 8)]
      return [...P(r, o, 2, vel + 8), ...M(r, o + 2), ...P(r, o + 3, 2, vel), ...M(r, o + 5), ...P(gtr.F, o + 6, 2, vel + 4),
        ...M(r, o + 8), ...P(r, o + 9, 2, vel), ...M(r, o + 11), ...last, ...(bar % 2 ? M(r, o + 15, 70) : [])]
    }
    if (root === 'B') {
      if (bar === 16) {
        // the guitars brake on beat 4 and the machines play the fill
        return [...BMAJ(o, 6, vel + 10), ...M(r, o + 6), ...M(r, o + 7), ...BMAJ(o + 8, 4, vel + 4)]
      }
      return [...BMAJ(o, 8, vel + 10), ...M(r, o + 8), ...M(r, o + 9), ...BMAJ(o + 10, 2, vel), ...M(r, o + 12), ...M(r, o + 13), ...BMAJ(o + 14, 2, vel + 4)]
    }
    // C, A, D, F: the press grouping on a pedal
    return [...P(r, o, 2, vel + 6), ...M(r, o + 2), ...P(r, o + 3, 2, vel), ...M(r, o + 5), ...P(r, o + 6, 2, vel + 2),
      ...M(r, o + 8), ...P(r, o + 9, 2, vel), ...M(r, o + 11), ...P(r, o + 12, 2, vel + 4), ...M(r, o + 14), ...M(r, o + 15, 70)]
  }
  const riff = []
  for (let bar = 1; bar <= L; bar++) riff.push(...riffBar(bar))
  const riff2 = riff.map((n) => ({ ...n, v: n.v - 4, off: 10 }))                                // double-tracked, a hair late
  // the rock kit gives the punch; the machine kit, layered on the same hits, gives the room
  const kit = [], machine = [], bass = []
  const kickFor = (bar) => rootOf(bar) === 'B' ? (bar === 16 ? 'x.......x.......' : 'x.........x...x.') : 'x..x..x..x..x...'
  for (let bar = 1; bar <= L; bar++) {
    const o = B(bar), fill = bar === 16
    kit.push(...drums(o, { [K.kick]: kickFor(bar), [K.snare]: fill ? '....x.......' : bar % 4 === 0 ? '....x.......x.xx' : '....x.......x...', [K.ch]: fill ? 'x.x.x.x.x.x.' : 'x.x.x.x.x.x.x.x.' }))
    machine.push(...drums(o, { [K.kick]: kickFor(bar), [K.snare]: fill ? '....x.......XxXx' : '....x.......x...', [K.ch]: '..x...x...x...x.', [K.clap]: bar % 2 === 0 && !fill ? '..............x.' : '' }))
    const b = bassNote[rootOf(bar)] + 12
    if (rootOf(bar) === 'E') for (const s of [0, 3, 6, 9, 12, 14]) bass.push({ t: o + s, d: s === 12 ? 2 : 3, p: s === 6 ? bassNote.F + 12 : s === 12 ? (bar % 2 ? b + 3 : bassNote.B + 12) : b, v: s === 0 ? 104 : 90 })
    else for (let s = 0; s < 16; s += 2) { if (!(fill && s >= 12)) bass.push({ t: o + s, d: 2, p: b, v: s % 4 ? 84 : 100 }) }
  }

  // ================= hook: the horn signal (long, long, short, long) =================
  // statement over C, C, A, B; it ends on the horn's own chord tones, unresolved, and the riff answers with E
  const hook = [
    ...seq(B(5), 'E5/4 ./1 E5/3 ./1 D5/2 C5/5', 102),
    ...seq(B(6), 'B4/2 C5/2 B4/2 G4/2 E4/8', 96),
    ...seq(B(7), 'A4/4 ./1 A4/3 ./1 B4/2 C5/5', 102),
    ...seq(B(8), 'B4/4 ./1 B4/3 ./1 D#5/2 F#5/5', 108),
    ...seq(B(13), 'E5/4 ./1 E5/3 ./1 D5/2 C5/5', 104),
    ...seq(B(14), 'F#5/4 ./1 F#5/3 ./1 E5/2 D5/5', 104),
    ...seq(B(15), 'F5/4 ./1 F5/3 ./1 E5/2 C5/5', 106),
    ...seq(B(16), 'B4/4 ./1 B4/3 ./1 D#5/2 F#5/5', 110),
  ]
  // the tuned air horn doubles the hook an octave down: the machine sings the theme with the guitar
  const hornHook = hook.map((n) => ({ ...n, p: n.p - 12, v: n.v - 8 }))

  // ================= overload: escalation =================
  const trem = [], heavy = [], arp = [], sub = [], snare2 = [], brass = []
  for (let bar = 1; bar <= L; bar++) {
    const o = B(bar), root = rootOf(bar), r = gtr[root] + 24
    const cell = root === 'B' ? [r, r + 4, r + 7, r + 4] : root === 'E' ? [r, r + 1, r, r + 7] : [r, r + 7, r + 12, r + 7]
    for (let beat = 0; beat < 4; beat++) for (let k = 0; k < 4; k++) trem.push({ t: o + beat * 4 + k, d: 1, p: cell[beat], v: k ? 84 : 104 })
    // heavy impacts on the press accents, the hammer at each phrase end, a pressure release opening each phrase
    heavy.push(...drums(o, { [K.kick]: root === 'E' ? 'x.....x.....x...' : 'x.......x.......', [K.snare]: '....x.......x...' }))
    if (bar % 4 === 0) heavy.push({ t: o + 12, d: 4, p: K.clap, v: 110 })
    if (bar % 4 === 1) heavy.push({ t: o, d: 8, p: K.oh, v: 100 })
    snare2.push(...drums(o, { [K.snare]: '..o...o...o...o.' }))
    // synth arpeggio in sixteenths: chord tones climbing, the electronic layer
    const chord = root === 'B' ? [0, 4, 7, 11] : root === 'E' ? [0, 3, 7, 1] : root === 'F' ? [0, 4, 7, 11] : [0, 4, 7, 12]
    const ar = bassNote[root] + 36
    for (let s = 0; s < 16; s++) arp.push({ t: o + s, d: 1, p: ar + chord[s % 4] + (s >= 8 ? 12 : 0), v: s % 4 ? 70 : 92 })
    sub.push({ t: o, d: 16, p: bassNote[root], v: 100 })
    if (!(root === 'E')) brass.push(...[0, 7, 12].map((i) => ({ t: o, d: 6, p: bassNote[root] + 24 + i, v: 100 })), ...[0, 7, 12].map((i) => ({ t: o + 8, d: 6, p: bassNote[root] + 24 + i, v: 92 })))
  }

  // ================= breath: recovery =================
  const breath = [], breathKit = [], breathBass = []
  for (let bar = 1; bar <= L; bar++) {
    const root = rootOf(bar), o = B(bar)
    if (root === 'B') breath.push(...BMAJ(o, 15, 90))
    else breath.push(...P(gtr[root], o, 15, root === rootOf(bar - 1) ? 74 : 92))
    breathKit.push(...drums(o, { [K.kick]: 'x..o....x..o....', [K.snare]: '........x.......' }))
    breathBass.push({ t: o, d: 14, p: bassNote[root], v: 92 })
  }
  // ================= clear: victory (a four-bar cadence, repeated so it works from any phrase) =================
  const clearChord = [], clearLead = [], clearHits = [], clearBass = []
  for (let ph = 0; ph < 4; ph++) {
    const b = 1 + ph * 4
    clearChord.push(...['E2', 'B2', 'E3', 'G#3', 'B3'].map((n) => ({ t: B(b), d: 28, p: midi(n), v: 120 })))  // E major: the horn resolved
    clearHits.push({ t: B(b), d: 1, p: K.kick, v: 120 }, { t: B(b), d: 8, p: K.oh, v: 110 })               // heavy boom and the pressure-release sigh
    clearBass.push({ t: B(b), d: 24, p: bassNote.E, v: 110 })
    clearLead.push(...seq(B(b) + 8, 'B4/4 ./1 B4/3 ./1 D#5/2 E5/5 | G#5/4 E5/12', 96))
  }
  // ================= the flinch: a small hit =================
  const flinch = seq(0, "[E4,F4]/1' ./1 [D#4,E4]/1'", 88)

  const crunch = (driveDb, outDb) => [{ kind: 'saturation', character: 'hard', driveDb, wet: 1, outputGainDb: outDb }, { kind: 'eq', lowDb: 2, midDb: -4, midHz: 3000, midQ: 0.7, highDb: -8 }]
  const leadAmp = [{ kind: 'saturation', character: 'soft', driveDb: 14, wet: 1, outputGainDb: -8 }, { kind: 'eq', lowDb: -3, midDb: 3, midHz: 1200, midQ: 0.8, highDb: -8 }, { kind: 'delay', seconds: 0.3125, feedback: 0.25, wet: 0.18 }]
  const open = (n) => n.filter((x) => !x.m), muted = (n) => n.filter((x) => x.m)
  const tracks = [
    { name: 'Bay: conveyor', role: 'texture', instrumentId: 'bayConveyor', mix: { gainDb: -6, pan: 0, spaceAmount: 0.3 }, notes: conveyor },
    { name: 'Bay: motor', role: 'pad', instrumentId: 'bayMotor', mix: { gainDb: -10, pan: -0.15, spaceAmount: 0.3, toneHz: 3000 }, notes: motor },
    { name: 'Working: press', role: 'drums', instrumentId: 'bayMachine', mix: { gainDb: -6, pan: 0, spaceAmount: 0.25 }, notes: press },
    { name: 'Working: clanks and valves', role: 'drums', instrumentId: 'bayMachine', mix: { gainDb: -12, pan: 0.25, spaceAmount: 0.35 }, notes: [...clank, ...valves] },
    { name: 'Working: pulse', role: 'motif', instrumentId: 'brightPluck', mix: { gainDb: -16, pan: -0.2, spaceAmount: 0.4, toneHz: 4000 }, effects: [{ kind: 'delay', seconds: 0.3125, feedback: 0.3, wet: 0.25 }], notes: pulse },
    { name: 'Working: hydraulic lift', role: 'pad', instrumentId: 'bayHydraulic', mix: { gainDb: -12, pan: 0.2, spaceAmount: 0.45 }, notes: lift },
    { name: 'Working: bell', role: 'melody', instrumentId: 'glassBell', mix: { gainDb: -14, pan: 0.3, spaceAmount: 0.6 }, effects: [{ kind: 'delay', seconds: 0.625, feedback: 0.35, wet: 0.3 }], notes: bell },
    { name: 'Alert: press', role: 'drums', instrumentId: 'bayMachine', mix: { gainDb: -4, pan: 0, spaceAmount: 0.25 }, notes: alertPress },
    { name: 'Alert: muted guitar', role: 'motif', instrumentId: 'hollowGuitarMuted', mix: { gainDb: 2, pan: -0.2, spaceAmount: 0.1, toneHz: 5000 }, effects: crunch(14, -10), notes: alertChug },
    { name: 'Alert: climbing motor', role: 'pad', instrumentId: 'bayMotor', mix: { gainDb: -8, pan: 0.15, spaceAmount: 0.3, toneHz: 2500 }, notes: alertMotor },
    { name: 'Alert: hydraulic pedal', role: 'pad', instrumentId: 'bayHydraulic', mix: { gainDb: -12, pan: -0.1, spaceAmount: 0.3, toneHz: 1200 }, notes: alertHyd },
    { name: 'Alert: steam', role: 'drums', instrumentId: 'bayMachine', mix: { gainDb: -10, pan: 0.3, spaceAmount: 0.4 }, notes: alertHiss },
    { name: 'Drive: rhythm guitar, open', role: 'motif', instrumentId: 'hollowGuitar', mix: { gainDb: -1, pan: -0.35, spaceAmount: 0.1, toneHz: 5000 }, effects: crunch(18, -12), notes: open(riff) },
    { name: 'Drive: rhythm guitar, muted', role: 'motif', instrumentId: 'hollowGuitarMuted', mix: { gainDb: 1, pan: -0.35, spaceAmount: 0.1, toneHz: 5000 }, effects: crunch(18, -12), notes: muted(riff) },
    { name: 'Drive: second guitar, open', role: 'motif', instrumentId: 'clubGuitar', mix: { gainDb: -11, pan: 0.4, spaceAmount: 0.1, toneHz: 5000 }, effects: crunch(18, -12), notes: open(riff2) },
    { name: 'Drive: second guitar, muted', role: 'motif', instrumentId: 'clubGuitarMuted', mix: { gainDb: 1, pan: 0.4, spaceAmount: 0.1, toneHz: 5000 }, effects: crunch(18, -12), notes: muted(riff2) },
    { name: 'Drive: kit', role: 'drums', instrumentId: 'rockKit', mix: { gainDb: -5, pan: 0, spaceAmount: 0.18 }, notes: kit },
    { name: 'Drive: machine kit', role: 'drums', instrumentId: 'bayMachine', mix: { gainDb: -6, pan: 0.1, spaceAmount: 0.25 }, notes: machine },
    { name: 'Drive: bass', role: 'bass', instrumentId: 'driveBass', mix: { gainDb: -6, pan: 0, spaceAmount: 0 }, effects: [{ kind: 'saturation', character: 'soft', driveDb: 6, wet: 0.35, outputGainDb: -2 }], notes: bass },
    { name: 'Hook: lead guitar', role: 'motif', instrumentId: 'hollowGuitar', mix: { gainDb: 8, pan: 0.15, spaceAmount: 0.3, toneHz: 5500 }, effects: leadAmp, notes: hook },
    { name: 'Hook: air horn', role: 'melody', instrumentId: 'bayHorn', mix: { gainDb: -10, pan: -0.1, spaceAmount: 0.35, toneHz: 3500 }, notes: hornHook },
    { name: 'Hook: flinch guitar', role: 'motif', instrumentId: 'hollowGuitar', mix: { gainDb: 14, pan: 0.15, spaceAmount: 0.3, toneHz: 5500 }, effects: leadAmp, notes: [] },
    { name: 'Overload: tremolo guitar', role: 'motif', instrumentId: 'clubGuitar', mix: { gainDb: 9, pan: 0.3, spaceAmount: 0.35, toneHz: 5000 }, effects: crunch(16, -12), notes: trem },
    { name: 'Overload: heavy impacts', role: 'drums', instrumentId: 'bayHeavy', mix: { gainDb: -6, pan: 0, spaceAmount: 0.35 }, notes: heavy },
    { name: 'Overload: double-time snare', role: 'drums', instrumentId: 'rockKit', mix: { gainDb: 2, pan: -0.05, spaceAmount: 0.2 }, notes: snare2 },
    { name: 'Overload: synth arpeggio', role: 'motif', instrumentId: 'supersaw', mix: { gainDb: -16, pan: -0.3, spaceAmount: 0.3, toneHz: 6000 }, effects: [{ kind: 'delay', seconds: 0.3125, feedback: 0.2, wet: 0.15 }], notes: arp },
    { name: 'Overload: sub', role: 'bass', instrumentId: 'subBass', mix: { gainDb: -12, pan: 0, spaceAmount: 0 }, notes: sub },
    { name: 'Overload: synth brass', role: 'chords', instrumentId: 'synthBrass', mix: { gainDb: -12, pan: 0.2, spaceAmount: 0.35 }, notes: brass },
    { name: 'Breath: ringing guitar', role: 'motif', instrumentId: 'hollowGuitar', mix: { gainDb: 1, pan: -0.2, spaceAmount: 0.35, toneHz: 4500 }, effects: crunch(10, -7), notes: breath },
    { name: 'Breath: heartbeat press', role: 'drums', instrumentId: 'bayMachine', mix: { gainDb: -4, pan: 0, spaceAmount: 0.25 }, notes: breathKit },
    { name: 'Breath: bass', role: 'bass', instrumentId: 'roundBass', mix: { gainDb: -5, pan: 0, spaceAmount: 0.05 }, notes: breathBass },
    { name: 'Clear: E major', role: 'motif', instrumentId: 'hollowGuitar', mix: { gainDb: 1.5, pan: 0, spaceAmount: 0.4, toneHz: 5000 }, effects: crunch(18, -12), notes: clearChord },
    { name: 'Clear: lead', role: 'motif', instrumentId: 'hollowGuitar', mix: { gainDb: 6, pan: 0.15, spaceAmount: 0.45, toneHz: 5000 }, effects: leadAmp, notes: clearLead },
    { name: 'Clear: boom and release', role: 'drums', instrumentId: 'bayHeavy', mix: { gainDb: -4, pan: 0, spaceAmount: 0.4 }, notes: clearHits },
    { name: 'Clear: low E', role: 'bass', instrumentId: 'roundBass', mix: { gainDb: -4, pan: 0, spaceAmount: 0.1 }, notes: clearBass },
  ]
  // per-track trims, measured from solo stems (see NOTES); empty until the first render is measured
  // version 3: every part of version 2 was rendered on its own and set to a target; these are (target - measured), in dB
  const TRIM3 = {
    'Bay: conveyor': 1, 'Working: clanks and valves': 8, 'Working: pulse': 11, 'Working: hydraulic lift': 6, 'Working: bell': 6,
    'Combat: rhythm guitar, open': -2.8, 'Combat: rhythm guitar, muted': 1.3, 'Combat: second guitar, open': 1.5, 'Combat: second guitar, muted': 2.4,
    'Combat: kit': -2.2, 'Combat: machine kit': -2.7, 'Combat: bass': -1.7, 'Combat: synth arpeggio': 18.5, 'Combat: lead guitar': 1.3, 'Combat: air horn': 1.5,
    'Entry: motor': 14, 'Entry: air horn': 6, 'Entry: impacts': -3, 'Entry: guitar': 1,
    'Victory: lead': 6, 'Victory: air horn': 4, 'Victory: impacts': -2,
  }
  const trim = opt.trim ?? (v >= 3 ? TRIM3 : {})
  for (const t of tracks) if (trim[t.name]) t.mix = { ...t.mix, gainDb: Math.round((t.mix.gainDb + trim[t.name]) * 10) / 10 }

  // ================= version 2: four parts (Skyiah, 2026-10-13) =================
  // An exploration loop, a combat-entry stinger, a combat loop and a victory stinger, sharing tempo, key and motifs.
  // In SigmAudio terms: two loop states plus two short holding states, and the stingers are fired by the game's
  // `engage` and `victory` events. A SigmAudio stinger plays on one track, so each multi-instrument stinger is a set
  // of single-track stingers on the same event. States share one timeline, so a phrase here is two bars: entry and
  // victory wait for the next two-bar line, and combat therefore always starts on an odd bar, which is always E.
  function fourParts() {
    // ----- combat riff: odd bars are the press riff on E; even bars answer on C, D, F or the horn's B
    const riffBar2 = (bar, vel = 108) => {
      const root = rootOf(bar), r = gtr[root], o = B(bar)
      if (root === 'E' && bar % 2) return [...P(r, o, 2, vel + 8), ...M(r, o + 2), ...P(r, o + 3, 2, vel), ...M(r, o + 5), ...P(gtr.F, o + 6, 2, vel + 4),
        ...M(r, o + 8), ...P(r, o + 9, 2, vel), ...M(r, o + 11), ...P(gtr.E + 3, o + 12, 3, vel + 6), ...M(r, o + 15, 70)]
      if (root === 'E') return [...P(r, o, 2, vel + 8), ...M(r, o + 2), ...P(r, o + 3, 2, vel), ...M(r, o + 5), ...P(gtr.F, o + 6, 2, vel + 4),
        ...M(r, o + 8), ...P(r, o + 9, 2, vel), ...M(r, o + 11), ...P(gtr.B, o + 12, 4, vel + 8)]
      // the horn's chord in the horn's signal rhythm: long, long, short, long (the entry stinger's figure)
      if (root === 'B') return [...BMAJ(o, 4, vel + 10), ...M(r, o + 4), ...BMAJ(o + 5, 3, vel + 4), ...M(r, o + 8), ...BMAJ(o + 9, 2, vel + 2), ...BMAJ(o + 11, 5, vel + 12)]
      return [...P(r, o, 2, vel + 6), ...M(r, o + 2), ...P(r, o + 3, 2, vel), ...M(r, o + 5), ...P(r, o + 6, 2, vel + 2),
        ...M(r, o + 8), ...P(r, o + 9, 2, vel), ...M(r, o + 11), ...P(r, o + 12, 2, vel + 4), ...M(r, o + 14), ...M(r, o + 15, 70)]
    }
    const riffA = [], kitA = [], machineA = [], bassA = [], arpA = []
    for (let bar = 1; bar <= L; bar++) {
      riffA.push(...riffBar2(bar))
      const o = B(bar), root = rootOf(bar), isB = root === 'B'
      const kick = isB ? 'x....x...x.x....' : 'x..x..x..x..x...'
      kitA.push(...drums(o, { [K.kick]: kick, [K.snare]: isB ? 'x....x...x.x....' : bar % 4 === 0 ? '....x.......x.xx' : '....x.......x...', [K.ch]: isB ? '' : 'x.x.x.x.x.x.x.x.', [K.oh]: isB ? '...........x....' : '' }))
      machineA.push(...drums(o, { [K.kick]: kick, [K.snare]: isB ? '............xxXX' : '....x.......x...', [K.ch]: isB ? '' : '..x...x...x...x.', [K.clap]: bar % 2 === 0 && !isB ? '..............x.' : '' }))
      const b = bassNote[root] + 12
      if (isB) for (const [s, d] of [[0, 4], [5, 3], [9, 2], [11, 5]]) bassA.push({ t: o + s, d, p: b, v: 108 })
      else if (root === 'E') for (const s of [0, 3, 6, 9, 12, 14]) bassA.push({ t: o + s, d: s === 12 ? 2 : 3, p: s === 6 ? bassNote.F + 12 : s === 12 ? (bar % 2 ? b + 3 : bassNote.B + 12) : b, v: s === 0 ? 104 : 90 })
      else for (let s = 0; s < 16; s += 2) bassA.push({ t: o + s, d: 2, p: b, v: s % 4 ? 84 : 100 })
      // the electronic layer: a synth arpeggio in sixteenths on the chord, the E bars carrying the F grind
      const chord = isB ? [0, 4, 7, 11] : root === 'E' ? [0, 3, 7, 1] : [0, 4, 7, 12]
      const ar = bassNote[root] + 36
      for (let s = 0; s < 16; s++) arpA.push({ t: o + s, d: 1, p: ar + chord[s % 4] + (s >= 8 ? 12 : 0), v: s % 4 ? 66 : 88 })
    }
    const riffB = riffA.map((n) => ({ ...n, v: n.v - 4, off: 10 }))
    // ----- the hook: the signal on C, D, F and B, an answering run on E, the riff alone at the top of each half
    const hookA = [
      ...seq(B(4), 'E5/4 ./1 E5/3 ./1 D5/2 C5/5', 102),
      ...seq(B(5), 'B4/2 C5/2 B4/2 G4/2 E4/8', 96),
      ...seq(B(6), 'F#5/4 ./1 F#5/3 ./1 E5/2 D5/5', 104),
      ...seq(B(8), 'B4/4 ./1 B4/3 ./1 D#5/2 F#5/5', 108),
      ...seq(B(12), 'E5/4 ./1 E5/3 ./1 D5/2 C5/5', 104),
      ...seq(B(13), 'B4/2 C5/2 B4/2 G4/2 E4/8', 98),
      ...seq(B(14), 'F5/4 ./1 F5/3 ./1 E5/2 C5/5', 106),
      ...seq(B(16), 'B4/4 ./1 B4/3 ./1 D#5/2 F#5/5', 110),
    ]
    const hornA = hookA.map((n) => ({ ...n, p: n.p - 12, v: n.v - 8 }))

    // ----- entry stinger, 2 bars: the machines speed up, then the band plays the horn's signal on B
    const signal = [[16, 4], [21, 3], [25, 2], [27, 5]]
    const entry = {
      press: drums(0, { [K.kick]: 'x...x...x.x.xxxx', [K.ch]: '................x.x.x.x.x.x.....', [K.snare]: '............................xxxx' })
        .map((n) => (n.p === K.kick ? { ...n, v: 76 + n.t * 3 } : n.p === K.snare ? { ...n, v: 90 + (n.t - 28) * 10 } : n)),
      motor: ['E3', 'F3', 'F#3', 'G3', 'G#3', 'A3', 'A#3', 'B3'].map((n, i) => ({ t: i * 4, d: 4, p: midi(n), v: 84 + i * 3 })),
      muted: [...Array.from({ length: 16 }, (_, s) => ({ t: s, d: 1, p: gtr.E, v: 50 + s * 3.4 })), ...[20, 24, 26].map((t) => ({ t, d: 1, p: gtr.B, v: 84 }))],
      guitar: signal.flatMap(([t, d], i) => BMAJ(t, d, i === 3 ? 124 : 114)),
      kit: [...signal.flatMap(([t]) => [{ t, d: 1, p: K.kick, v: 118 }, { t, d: 1, p: K.snare, v: 110 }]), ...[28, 29, 30, 31].map((t) => ({ t, d: 1, p: K.snare, v: 80 + (t - 28) * 12 }))],
      impacts: [{ t: 0, d: 4, p: K.kick, v: 112 }, { t: 16, d: 4, p: K.kick, v: 124 }, { t: 27, d: 4, p: K.snare, v: 110 }, { t: 28, d: 4, p: K.clap, v: 104 }],
      horn: signal.map(([t, d], i) => ({ t, d, p: midi(['B3', 'B3', 'D#4', 'F#4'][i]), v: 100 })),
      bass: [...[0, 2, 4, 6, 8, 10, 12, 14].map((t) => ({ t, d: 2, p: bassNote.E + 12, v: 70 + t * 2 })), ...signal.map(([t, d]) => ({ t, d, p: bassNote.B + 12, v: 110 }))],
    }
    // ----- victory stinger, 4 bars: E major with a pressure-release sigh, the signal landing on E, the machines restarting
    const victory = {
      // version 3: the chord rang for 24 steps and the lead rested on step 27, which left a 23 dB hole; both now overlap
      chord: ['E2', 'B2', 'E3', 'G#3', 'B3'].map((n) => ({ t: 0, d: v >= 3 ? 40 : 24, p: midi(n), v: 122 })),
      lead: seq(4, v >= 3 ? 'B4/4 ./1 B4/3 ./1 D#5/2 E5/13 G#5/4 E5/18' : 'B4/4 ./1 B4/3 ./1 D#5/2 E5/12 | ./1 G#5/4 E5/18', 100),
      horn: seq(4, 'B3/4 ./1 B3/3 ./1 D#4/2 E4/12', 92),
      impacts: [{ t: 0, d: 2, p: K.kick, v: 124 }, { t: 0, d: 32, p: K.oh, v: 116 }, { t: 15, d: 4, p: K.snare, v: 96 }],
      bass: [{ t: 0, d: 30, p: bassNote.E, v: 112 }],
      motor: [{ t: 32, d: 32, p: midi('E3'), v: 80 }],
      press: drums(32, { [K.kick]: 'x..x..x..x..x...', [K.ch]: '..x...x...x...x.' }).map((n) => ({ ...n, v: n.v * 0.6 })),
    }
    const leadAmp2 = [{ kind: 'saturation', character: 'soft', driveDb: 14, wet: 1, outputGainDb: -8 }, { kind: 'eq', lowDb: -3, midDb: 3, midHz: 1200, midQ: 0.8, highDb: -8 }, { kind: 'delay', seconds: 0.3125, feedback: 0.25, wet: 0.18 }]
    const keep = (prefix) => tracks.filter((t) => t.name.startsWith(prefix))
    const empty = (name, role, instrumentId, mix, effects) => ({ name, role, instrumentId, mix: { pan: 0, spaceAmount: 0.3, ...mix }, ...(effects ? { effects } : {}), notes: [] })
    const t2 = [
      ...keep('Bay:'), ...keep('Working:'),
      { name: 'Combat: rhythm guitar, open', role: 'motif', instrumentId: 'hollowGuitar', mix: { gainDb: -1, pan: -0.35, spaceAmount: 0.1, toneHz: 5000 }, effects: crunch(18, -12), notes: open(riffA) },
      { name: 'Combat: rhythm guitar, muted', role: 'motif', instrumentId: 'hollowGuitarMuted', mix: { gainDb: 1, pan: -0.35, spaceAmount: 0.1, toneHz: 5000 }, effects: crunch(18, -12), notes: muted(riffA) },
      { name: 'Combat: second guitar, open', role: 'motif', instrumentId: 'clubGuitar', mix: { gainDb: -11, pan: 0.4, spaceAmount: 0.1, toneHz: 5000 }, effects: crunch(18, -12), notes: open(riffB) },
      { name: 'Combat: second guitar, muted', role: 'motif', instrumentId: 'clubGuitarMuted', mix: { gainDb: 1, pan: 0.4, spaceAmount: 0.1, toneHz: 5000 }, effects: crunch(18, -12), notes: muted(riffB) },
      { name: 'Combat: kit', role: 'drums', instrumentId: 'rockKit', mix: { gainDb: -5, pan: 0, spaceAmount: 0.18 }, notes: kitA },
      { name: 'Combat: machine kit', role: 'drums', instrumentId: 'bayMachine', mix: { gainDb: -6, pan: 0.1, spaceAmount: 0.25 }, notes: machineA },
      { name: 'Combat: bass', role: 'bass', instrumentId: 'driveBass', mix: { gainDb: -6, pan: 0, spaceAmount: 0 }, effects: [{ kind: 'saturation', character: 'soft', driveDb: 6, wet: 0.35, outputGainDb: -2 }], notes: bassA },
      { name: 'Combat: synth arpeggio', role: 'motif', instrumentId: 'supersaw', mix: { gainDb: -20, pan: -0.3, spaceAmount: 0.3, toneHz: 6000 }, effects: [{ kind: 'delay', seconds: 0.3125, feedback: 0.2, wet: 0.15 }], notes: arpA },
      { name: 'Combat: lead guitar', role: 'motif', instrumentId: 'hollowGuitar', mix: { gainDb: 8, pan: 0.15, spaceAmount: 0.3, toneHz: 5500 }, effects: leadAmp2, notes: hookA },
      { name: 'Combat: air horn', role: 'melody', instrumentId: 'bayHorn', mix: { gainDb: -10, pan: -0.1, spaceAmount: 0.35, toneHz: 3500 }, notes: hornA },
      empty('Entry: press', 'drums', 'bayMachine', { gainDb: -4, spaceAmount: 0.25 }),
      empty('Entry: motor', 'pad', 'bayMotor', { gainDb: -6, toneHz: 500 }),
      empty('Entry: muted guitar', 'motif', 'hollowGuitarMuted', { gainDb: 1, pan: -0.3, spaceAmount: 0.1, toneHz: 5000 }, crunch(18, -12)),
      empty('Entry: guitar', 'motif', 'hollowGuitar', { gainDb: -1, pan: 0.1, spaceAmount: 0.2, toneHz: 5000 }, crunch(18, -12)),
      empty('Entry: kit', 'drums', 'rockKit', { gainDb: -5, spaceAmount: 0.25 }),
      empty('Entry: impacts', 'drums', 'bayHeavy', { gainDb: -6, spaceAmount: 0.35 }),
      empty('Entry: air horn', 'melody', 'bayHorn', { gainDb: -10, pan: -0.1, spaceAmount: 0.35, toneHz: 3500 }),
      empty('Entry: bass', 'bass', 'driveBass', { gainDb: -6, spaceAmount: 0 }, [{ kind: 'saturation', character: 'soft', driveDb: 6, wet: 0.35, outputGainDb: -2 }]),
      empty('Victory: E major', 'motif', 'hollowGuitar', { gainDb: 1.5, spaceAmount: 0.4, toneHz: 5000 }, crunch(18, -12)),
      empty('Victory: lead', 'motif', 'hollowGuitar', { gainDb: 6, pan: 0.15, spaceAmount: 0.45, toneHz: 5000 }, leadAmp2),
      empty('Victory: air horn', 'melody', 'bayHorn', { gainDb: -10, pan: -0.1, spaceAmount: 0.4, toneHz: 3500 }),
      empty('Victory: impacts', 'drums', 'bayHeavy', { gainDb: -4, spaceAmount: 0.4 }),
      empty('Victory: low E', 'bass', 'roundBass', { gainDb: -4, spaceAmount: 0.1 }),
      empty('Victory: motor', 'pad', 'bayMotor', { gainDb: -10, pan: -0.15, toneHz: 3000 }),
      empty('Victory: press', 'drums', 'bayMachine', { gainDb: -6, spaceAmount: 0.25 }),
    ]
    // kept tracks (Bay, Working) were trimmed above already
    for (const t of t2) if (trim[t.name] && !/^(Bay|Working):/.test(t.name)) t.mix = { ...t.mix, gainDb: Math.round((t.mix.gainDb + trim[t.name]) * 10) / 10 }
    const names = (prefix) => t2.filter((t) => t.name.startsWith(prefix)).map((t) => t.name)
    const sting = (name, track, event, lengthSteps, notes, states, tail) => ({ name, track, event, lengthSteps, notes, quantize: 'phrase', keyLock: false, cooldownMs: 0, maxVoices: 1, tailSeconds: tail, states })
    const E = entry, W = victory
    return {
      name: 'Freight Bay (four parts)', version: v, bpm: 144, meter: '4/4', key: { tonic: 4, mode: 'aeolian' }, lengthBars: L, phraseLengthBars: 2,
      sections: [
        { name: 'Phrase 1: the riff on the press (E)', kind: 'loop', startBar: 0, lengthBars: 4 },
        { name: 'Phrase 2: the horn signal (C, D, B)', kind: 'loop', startBar: 4, lengthBars: 4 },
        { name: 'Phrase 3: the riff again (E)', kind: 'loop', startBar: 8, lengthBars: 4 },
        { name: 'Phrase 4: the signal climbs (C, F, B)', kind: 'loop', startBar: 12, lengthBars: 4 },
      ],
      tracks: t2,
      adaptive: {
        layers: [
          { name: 'Bay', purpose: 'base', fadeBeats: 4, tracks: names('Bay:') },
          { name: 'Exploration', purpose: 'texture', fadeBeats: 4, tracks: names('Working:') },
          { name: 'Combat', purpose: 'combat', fadeBeats: 0, tracks: names('Combat:') },
          { name: 'Stingers', purpose: 'harmony', fadeBeats: 0, tracks: [...names('Entry:'), ...names('Victory:')] },
        ],
        base: 'Exploration',
        states: [
          { name: 'Exploration', layers: ['Bay', 'Exploration'] },
          { name: 'Entry', layers: ['Bay'] },
          { name: 'Combat', layers: ['Bay', 'Combat'] },
          { name: 'Victory', layers: ['Bay'] },
        ],
        parameters: [],
        events: [{ name: 'engage' }, { name: 'victory' }],
        transitions: [
          // the game fires `engage` as the Shunter sounds its horn: the entry stinger and this cut land on the next two-bar line
          { from: 'Exploration', to: 'Entry', when: { kind: 'event', event: 'engage' }, quantize: 'phrase', fadeBeats: 0, priority: 5, dwellMs: 0 },
          // eligible 3.0 s into the 3.33 s stinger, so it is queued in time for the very next two-bar line
          { from: 'Entry', to: 'Combat', when: { kind: 'always' }, quantize: 'phrase', fadeBeats: 0, priority: 5, dwellMs: 3000 },
          { from: 'Combat', to: 'Victory', when: { kind: 'event', event: 'victory' }, quantize: 'phrase', fadeBeats: 0, priority: 6, dwellMs: 0 },
          // exploration fades back in over the second half of the victory stinger
          { from: 'Victory', to: 'Exploration', when: { kind: 'always' }, quantize: 'phrase', fadeBeats: 4, priority: 1, dwellMs: 3000 },
          { from: 'Victory', to: 'Entry', when: { kind: 'event', event: 'engage' }, quantize: 'phrase', fadeBeats: 0, priority: 5, dwellMs: 0 },
        ],
        stingers: [
          sting('Entry: press', 'Entry: press', 'engage', 32, E.press, ['Exploration', 'Victory'], 0.8),
          sting('Entry: motor', 'Entry: motor', 'engage', 32, E.motor, ['Exploration', 'Victory'], 0.6),
          sting('Entry: muted guitar', 'Entry: muted guitar', 'engage', 32, E.muted, ['Exploration', 'Victory'], 0.4),
          sting('Entry: guitar', 'Entry: guitar', 'engage', 32, E.guitar, ['Exploration', 'Victory'], 0.8),
          sting('Entry: kit', 'Entry: kit', 'engage', 32, E.kit, ['Exploration', 'Victory'], 0.6),
          sting('Entry: impacts', 'Entry: impacts', 'engage', 32, E.impacts, ['Exploration', 'Victory'], 1.2),
          sting('Entry: air horn', 'Entry: air horn', 'engage', 32, E.horn, ['Exploration', 'Victory'], 0.6),
          sting('Entry: bass', 'Entry: bass', 'engage', 32, E.bass, ['Exploration', 'Victory'], 0.4),
          sting('Victory: E major', 'Victory: E major', 'victory', 64, W.chord, ['Combat'], 1.5),
          sting('Victory: lead', 'Victory: lead', 'victory', 64, W.lead, ['Combat'], 1.5),
          sting('Victory: air horn', 'Victory: air horn', 'victory', 64, W.horn, ['Combat'], 1.0),
          sting('Victory: impacts', 'Victory: impacts', 'victory', 64, W.impacts, ['Combat'], 1.5),
          sting('Victory: low E', 'Victory: low E', 'victory', 64, W.bass, ['Combat'], 1.0),
          sting('Victory: motor', 'Victory: motor', 'victory', 64, W.motor, ['Combat'], 1.0),
          sting('Victory: press', 'Victory: press', 'victory', 64, W.press, ['Combat'], 0.8),
        ],
      },
    }
  }
  if (v >= 2) return fourParts()
  const of = (prefix) => tracks.filter((t) => t.name.startsWith(prefix)).map((t) => t.name)
  const clearWhen = { kind: 'param', param: 'threat', op: '<=', value: 0.1, holdMs: 1500 }
  const toVictory = (from) => ({ from, to: 'Victory', when: clearWhen, quantize: 'phrase', fadeBeats: 0, priority: 6, exitBelow: 0.1, dwellMs: 1600 })
  const hurt = { kind: 'param', param: 'health', op: '<=', value: 0.25 }
  return {
    name: 'Freight Bay (adaptive combat)', version: v, bpm: 144, meter: '4/4', key: { tonic: 4, mode: 'aeolian' }, lengthBars: L, phraseLengthBars: 4,
    sections: [
      { name: 'Phrase 1: the riff on the press (E)', kind: 'loop', startBar: 0, lengthBars: 4 },
      { name: 'Phrase 2: the horn signal (C, A, B)', kind: 'loop', startBar: 4, lengthBars: 4 },
      { name: 'Phrase 3: the riff again (E)', kind: 'loop', startBar: 8, lengthBars: 4 },
      { name: 'Phrase 4: the signal climbs (C, D, F, B)', kind: 'loop', startBar: 12, lengthBars: 4 },
    ],
    tracks,
    adaptive: {
      layers: [
        { name: 'Bay', purpose: 'base', fadeBeats: 4, tracks: of('Bay:') },
        { name: 'Working', purpose: 'texture', fadeBeats: 4, tracks: of('Working:') },
        { name: 'Alert', purpose: 'danger', fadeBeats: 1, tracks: of('Alert:') },
        { name: 'Drive', purpose: 'combat', fadeBeats: 0, tracks: of('Drive:') },
        { name: 'Hook', purpose: 'combat', fadeBeats: 0, tracks: of('Hook:') },
        { name: 'Overload', purpose: 'combat', fadeBeats: 0, tracks: of('Overload:') },
        { name: 'Breath', purpose: 'harmony', fadeBeats: 2, tracks: of('Breath:') },
        { name: 'Clear', purpose: 'harmony', fadeBeats: 0, tracks: of('Clear:') },
      ],
      base: 'Working',
      states: [
        { name: 'Working', layers: ['Bay', 'Working'] },
        { name: 'Noticed', layers: ['Bay', 'Alert'] },
        { name: 'Combat', layers: ['Bay', 'Drive', 'Hook'] },
        { name: 'Escalation', layers: ['Bay', 'Drive', 'Hook', 'Overload'] },
        { name: 'Recovery', layers: ['Bay', 'Breath'] },
        { name: 'Victory', layers: ['Bay', 'Clear'] },
      ],
      parameters: [
        { name: 'threat', min: 0, max: 1, defaultValue: 0, smoothingMs: 200 },
        { name: 'intensity', min: 0, max: 1, defaultValue: 0, smoothingMs: 300 },
        { name: 'health', min: 0, max: 1, defaultValue: 1, smoothingMs: 150 },
      ],
      events: [{ name: 'noticed' }, { name: 'escalate' }, { name: 'hurt' }],
      transitions: [
        // the Shunter notices: the game fires `noticed` with its horn, and the room stops grooving on the next beat
        { from: 'Working', to: 'Noticed', when: { kind: 'any', of: [{ kind: 'event', event: 'noticed' }, { kind: 'param', param: 'threat', op: '>=', value: 0.25, holdMs: 500 }] }, quantize: 'beat', fadeBeats: 1, priority: 3, dwellMs: 0 },
        { from: 'Working', to: 'Combat', when: { kind: 'param', param: 'threat', op: '>=', value: 0.5 }, quantize: 'bar', fadeBeats: 1, priority: 5, enterAbove: 0.5, dwellMs: 0 },
        { from: 'Noticed', to: 'Combat', when: { kind: 'param', param: 'threat', op: '>=', value: 0.5 }, quantize: 'bar', fadeBeats: 0, priority: 5, enterAbove: 0.5, dwellMs: 0 },
        { from: 'Noticed', to: 'Working', when: { kind: 'param', param: 'threat', op: '<=', value: 0.1, holdMs: 3000 }, quantize: 'phrase', fadeBeats: 4, priority: 2, exitBelow: 0.1, dwellMs: 3300 },
        { from: 'Combat', to: 'Escalation', when: { kind: 'any', of: [{ kind: 'event', event: 'escalate' }, { kind: 'param', param: 'intensity', op: '>=', value: 0.8, holdMs: 1000 }] }, quantize: 'bar', fadeBeats: 0, priority: 6, dwellMs: 1700 },
        { from: 'Escalation', to: 'Combat', when: { kind: 'param', param: 'intensity', op: '<=', value: 0.5, holdMs: 4000 }, quantize: 'phrase', fadeBeats: 2, priority: 3, exitBelow: 0.5, dwellMs: 6700 },
        toVictory('Combat'), toVictory('Escalation'),
        { from: 'Combat', to: 'Recovery', when: hurt, quantize: 'bar', fadeBeats: 2, priority: 7, exitBelow: 0.25, dwellMs: 1700 },
        { from: 'Escalation', to: 'Recovery', when: hurt, quantize: 'bar', fadeBeats: 2, priority: 7, exitBelow: 0.25, dwellMs: 1700 },
        { from: 'Recovery', to: 'Combat', when: { kind: 'param', param: 'health', op: '>=', value: 0.5, holdMs: 1000 }, quantize: 'bar', fadeBeats: 0, priority: 4, enterAbove: 0.5, dwellMs: 3300 },
        { ...toVictory('Recovery'), priority: 8 },
        { from: 'Victory', to: 'Working', when: { kind: 'always' }, quantize: 'bar', fadeBeats: 4, priority: 1, dwellMs: 3300 },
        { from: 'Victory', to: 'Combat', when: { kind: 'param', param: 'threat', op: '>=', value: 0.5 }, quantize: 'bar', fadeBeats: 1, priority: 5, enterAbove: 0.5, dwellMs: 0 },
      ],
      stingers: [{ name: 'Flinch', track: 'Hook: flinch guitar', event: 'hurt', lengthSteps: 4, notes: flinch, quantize: 'immediate', keyLock: false, cooldownMs: 1200, maxVoices: 1, tailSeconds: 0.4 }],
    },
    master: { gainDb: -3 },
  }
}
