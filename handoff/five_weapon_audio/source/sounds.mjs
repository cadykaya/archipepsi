// Five-weapon overnight SFX: every sound as SigmAudio layers. Times in milliseconds.
// Built into ordinary one-shot SigmAudio projects by build-sfx.mjs. T0 is where the
// shot "happens"; recorded kit hits are placed so their measured peak lands on time.
const T0 = 50
// Measured time from sample start to its envelope peak (ms), so layers line up.
const ONSET = {
  rockKit: { K: 23.1, S: 10.6, C: 2.7, CH: 14.9 }, drums808: { K: 17.6, S: 2.5, C: 39.9, CH: 3.4 },
  orchKit: { K: 12.6, S: 5.2, C: 2.3, CH: 4.1 }, clockworkKit: { K: 33, S: 46.1, C: 2.2, CH: 2.6, R: 2.4 },
  stingKit: { K: 1.5, S: 1.8, C: 1.1, CH: 1.0, OH: 1.0 }, softHands: { K: 30.2, S: 3.2, C: 14.4 },
}
const hit = (kit, piece, ms, vel) => [Math.max(0, T0 + ms - ONSET[kit][piece]), 25, piece, vel]
const at = (ms, durMs, pitch, vel) => [T0 + ms, durMs, pitch, vel]
// A deterministic scatter (LCG) for sparks, debris and crackle: same seed, same sound.
function scatter(seed, count, fromMs, toMs, pitchLo, pitchHi, velHi, velLo, durMs = 25, curve = 1.6) {
  let s = seed >>> 0; const rnd = () => ((s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 2 ** 32)
  const out = []
  for (let i = 0; i < count; i++) {
    const u = i / Math.max(1, count - 1), jitter = (rnd() - .5) * (toMs - fromMs) / count
    const t = fromMs + (toMs - fromMs) * u ** curve + jitter
    out.push(at(Math.max(fromMs, t), durMs, Math.round(pitchLo + rnd() * (pitchHi - pitchLo)), velHi + (velLo - velHi) * u))
  }
  return out
}
const env = (attack, decay, sustain, release, brightnessOctaves = 0, resonance = .7) => ({ attack, decay, sustain, release, brightnessOctaves, resonance })
const sat = (driveDb, wet = .5, character = 'soft') => ({ kind: 'saturation', character, driveDb, wet, outputGainDb: 0 })
const hp = (frequencyHz, q = .707) => ({ kind: 'filter', filterType: 'highpass', frequencyHz, q, wet: 1, outputGainDb: 0 })
const lp = (frequencyHz, q = .707) => ({ kind: 'filter', filterType: 'lowpass', frequencyHz, q, wet: 1, outputGainDb: 0 })
const bp = (frequencyHz, q = 1) => ({ kind: 'filter', filterType: 'bandpass', frequencyHz, q, wet: 1, outputGainDb: 0 })
const eq = (lowDb, midDb, midHz, highDb, midQ = 1) => ({ kind: 'eq', lowDb, midDb, midHz, midQ, highDb })
const verb = (decaySeconds, wet, dampingHz = 6000, preDelaySeconds = .01, width = 1) => ({ kind: 'reverb', decaySeconds, preDelaySeconds, dampingHz, width, wet, outputGainDb: 0 })
const delay = (seconds, feedback, wet) => ({ kind: 'delay', seconds, feedback, wet })
const comp = (thresholdDb, ratio, attackSeconds = .002, releaseSeconds = .12, kneeDb = 6, outputGainDb = 0) => ({ kind: 'compressor', thresholdDb, kneeDb, ratio, attackSeconds, releaseSeconds, outputGainDb })

const sounds = {}
// Shift a set of layers in time (for firing series). Notes before 0 are not allowed.
const shiftNotes = (notes, ms) => notes.map(([t, d, p, v]) => [t + ms, d, p, v])

// 1 FOUNDRY: sharp crack, weighty low body, short mechanical / sci-fi tail.
sounds.foundry_fire = { title: 'Foundry fire', bodyMs: 400, tailMs: 900, masterDb: 0,
  layers: [
    { name: 'Attack: muzzle blast noise', inst: 'windNoise', patch: env(0, .05, 0, .03, 3, .5), gain: 2,
      notes: [at(0, 75, 100, 127)], fx: [hp(900), sat(14, .7, 'hard')] },
    { name: 'Attack: crack (snare, driven)', inst: 'rockKit', gain: 0, notes: [hit('rockKit', 'S', 0, 127)],
      fx: [hp(900), sat(12, .7, 'hard'), eq(0, 3, 3200, 4), delay(.11, .15, .1)] },
    { name: 'Attack: snap', inst: 'rockKit', gain: -8, notes: [hit('rockKit', 'C', 1, 118)], fx: [hp(1500)] },
    { name: 'Body: sub thump', inst: 'subBass', patch: env(.001, .1, 0, .06, 0, 1), gain: 1,
      notes: [at(0, 100, 33, 127)], fx: [sat(10, .5), hp(30)] },
    { name: 'Body: punch', inst: 'driveBass', patch: env(.001, .06, 0, .04, .3, 1), gain: 2,
      notes: [at(0, 75, 36, 127)], fx: [sat(9, .5), lp(1500)] },
    { name: 'Body: short knock', inst: 'stingKit', gain: -6, notes: [hit('stingKit', 'K', 0, 120)], fx: [lp(1200)] },
    { name: 'Body: low thud', inst: 'subBass', patch: env(.001, .12, 0, .08, .5, 1), gain: 0,
      notes: [at(0, 150, 40, 120)], fx: [sat(14, .6), lp(900)] },
    { name: 'Body: discharge sweep', inst: 'driveBass', patch: env(.002, .2, 0, .09, 1.2, 5), gain: -5,
      notes: [at(0, 250, 28, 118)], fx: [sat(10, .5)] },
    { name: 'Tail: slide clack', inst: 'clockworkKit', gain: 1, notes: [hit('clockworkKit', 'CH', 72, 88)], fx: [hp(1200)] },
    { name: 'Tail: ratchet settle', inst: 'clockworkKit', gain: -17, notes: [hit('clockworkKit', 'S', 96, 72)], fx: [hp(2500)] },
    { name: 'Tail: coil ring', inst: 'clockworkKit', gain: -20, notes: [hit('clockworkKit', 'K', 8, 70)], fx: [bp(1400, 2)] },
    { name: 'Tail: air and room', inst: 'windNoise', patch: env(.003, .55, 0, .35, -.6, .7), gain: 11,
      notes: [at(0, 400, 64, 100)], fx: [verb(1.4, .65, 4500, .02)] },
  ],
  master: [comp(-12, 4, .001, .14, 6, 2), sat(3, .25)] }

// 2 SIGHTLINE: crisp dry report, mechanical reset, less low body than Foundry.
sounds.sightline_fire = { title: 'Sightline fire', bodyMs: 300, tailMs: 500,
  layers: [
    { name: 'Attack: supersonic snap', inst: 'windNoise', patch: env(0, .022, 0, .015, 3, .5), gain: -3,
      notes: [at(0, 25, 104, 127)], fx: [hp(2500), sat(12, .6, 'hard')] },
    { name: 'Attack: crack (snare, high-passed)', inst: 'rockKit', gain: -4, notes: [hit('rockKit', 'S', 0, 120)],
      fx: [hp(1800), sat(10, .6, 'hard'), eq(0, 4, 4500, 3), delay(.07, .1, .1)] },
    { name: 'Attack: tight 808 snare', inst: 'drums808', gain: -8, notes: [hit('drums808', 'S', 0, 120)], fx: [hp(1000)] },
    { name: 'Body: short punch', inst: 'driveBass', patch: env(.003, .04, 0, .03, .4, 1), gain: -2,
      notes: [at(0, 50, 43, 120)], fx: [sat(8, .5), hp(70), lp(2500)] },
    { name: 'Body: small sub', inst: 'subBass', patch: env(.001, .05, 0, .04, 0, 1), gain: -5,
      notes: [at(0, 50, 38, 110)], fx: [hp(40)] },
    { name: 'Reset: bolt back (claves)', inst: 'clockworkKit', gain: -4, notes: [hit('clockworkKit', 'CH', 135, 92)], fx: [hp(1500)] },
    { name: 'Reset: bolt home (click)', inst: 'stingKit', gain: -14, notes: [hit('stingKit', 'CH', 178, 110)], fx: [hp(2000)] },
    { name: 'Reset: steel tick', inst: 'funkClav', patch: env(.001, .03, 0, .03, 1.5, 3), gain: -16,
      notes: [at(180, 25, 86, 100)], fx: [hp(2500)] },
    { name: 'Tail: short room', inst: 'windNoise', patch: env(.002, .3, 0, .2, 0, .7), gain: 4,
      notes: [at(0, 200, 72, 90)], fx: [hp(500), verb(.7, .6, 7000, .01)] },
  ],
  master: [comp(-12, 4, .001, .1, 6, 2)] }

// 3 SWITCHBACK: one round (A and B alternate), a release tail, and a series demo.
const switchbackRound = (v) => [
  { name: 'Attack: crack (808 snare)', inst: 'drums808', gain: 10, notes: [hit('drums808', 'S', 0, v ? 118 : 124)], fx: [hp(1200, 1), hp(1200, 1), sat(10, .6, 'hard')] },
  { name: 'Attack: burst noise', inst: 'windNoise', patch: env(0, .02, 0, .012, 2.5, .5), gain: 4,
    notes: [at(0, 25, v ? 98 : 102, 127)], fx: [hp(1500), sat(8, .5, 'hard')] },
  { name: 'Body: punch', inst: 'subBass', patch: env(.002, .035, 0, .025, .5, 1), gain: -4,
    notes: [at(0, 25, v ? 44 : 43, 122)], fx: [sat(12, .6), hp(60), lp(1200)] },
  { name: 'Mech: bolt tick', inst: 'drums808', gain: -12, notes: [hit('drums808', 'CH', v ? 46 : 42, 100)], fx: [hp(3000)] },
  { name: 'Mech: bolt knock', inst: 'driveBass', patch: env(.002, .02, 0, .02, .5, 1), gain: -14, notes: [at(v ? 46 : 42, 25, 52, 100)], fx: [hp(150), lp(1500)] },
]
const roundTail = [
  { name: 'Tail: room', inst: 'windNoise', patch: env(.002, .12, 0, .1, -.3, .7), gain: 0,
    notes: [at(0, 50, 70, 80)], fx: [hp(400), verb(.5, .55, 6000, .01)] },
]
sounds.switchback_fire_a = { title: 'Switchback fire A', bodyMs: 125, tailMs: 300, layers: [...switchbackRound(0), ...roundTail],
  master: [comp(-12, 4, .001, .08, 6, 2)] }
sounds.switchback_fire_b = { title: 'Switchback fire B', bodyMs: 125, tailMs: 300, layers: [...switchbackRound(1), ...roundTail],
  master: [comp(-12, 4, .001, .08, 6, 2)] }
sounds.switchback_release_tail = { title: 'Switchback release tail', bodyMs: 200, tailMs: 900,
  layers: [
    { name: 'Tail: hall decay', inst: 'windNoise', patch: env(.004, .6, 0, .3, -.5, .7), gain: 6,
      notes: [at(0, 300, 64, 100)], fx: [hp(250), verb(1.3, .7, 4500, .02)] },
    { name: 'Tail: bolt settles', inst: 'clockworkKit', gain: -10, notes: [hit('clockworkKit', 'CH', 60, 80)], fx: [hp(1500)] },
    { name: 'Tail: ratchet', inst: 'clockworkKit', gain: -22, notes: [hit('clockworkKit', 'S', 75, 60)], fx: [hp(2500)] },
  ],
  master: [comp(-12, 4, .001, .1, 6, 2)] }
{
  // 15 rounds at 7.5 per second, alternating A and B, then the release tail.
  const period = 133.3, rounds = 15, a = switchbackRound(0), b = switchbackRound(1)
  const layers = a.map((track, i) => ({ ...track, notes: Array.from({ length: rounds }, (_, r) =>
    shiftNotes((r % 2 ? b : a)[i].notes.map(([t, d, p, v]) => [t, d, p, v - (r % 3 === 2 ? 6 : 0)]), r * period)).flat() }))
  const tail = sounds.switchback_release_tail.layers.map((t) => ({ ...t, notes: shiftNotes(t.notes, rounds * period - 40) }))
  sounds.switchback_series_demo = { title: 'Switchback 2-second series', bodyMs: 2200, tailMs: 1000, layers: [...layers, ...tail],
    master: [comp(-12, 4, .001, .08, 6, 2)] }
}

// 4 BULKHEAD: broad crack, thick body, wide space; the pump is its own event.
sounds.bulkhead_fire = { title: 'Bulkhead fire', bodyMs: 400, tailMs: 1300,
  layers: [
    { name: 'Attack: crack (snare)', inst: 'rockKit', gain: -1, notes: [hit('rockKit', 'S', 0, 127)],
      fx: [hp(600), sat(12, .7, 'hard'), delay(.13, .2, .12)] },
    { name: 'Attack: clap spread', inst: 'rockKit', gain: -9, notes: [hit('rockKit', 'C', 3, 120)], fx: [hp(800)] },
    { name: 'Attack: pellet blast L', inst: 'windNoise', pan: -.55, patch: env(0, .07, 0, .04, 2, .5), gain: -2,
      notes: [at(0, 100, 94, 127)], fx: [hp(700), sat(12, .6, 'hard')] },
    { name: 'Attack: pellet blast R', inst: 'windNoise', pan: .55, patch: env(0, .07, 0, .04, 2, .5), gain: -2,
      notes: [at(2.5, 100, 92, 127)], fx: [hp(700), sat(12, .6, 'hard')] },
    { name: 'Attack: thick mid blast', inst: 'waterNoise', patch: env(0, .09, 0, .05, 1, .7), gain: 7,
      notes: [at(1, 100, 84, 127)], fx: [hp(200), sat(10, .6)] },
    { name: 'Body: sub thump', inst: 'subBass', patch: env(.001, .13, 0, .08, 0, 1), gain: -2,
      notes: [at(0, 150, 31, 127)], fx: [sat(10, .5), hp(28)] },
    { name: 'Body: punch', inst: 'driveBass', patch: env(.003, .08, 0, .05, .2, 1), gain: 4,
      notes: [at(0, 100, 33, 127)], fx: [sat(10, .55), lp(1200)] },
    { name: 'Body: low thud', inst: 'subBass', patch: env(.001, .16, 0, .1, .5, 1), gain: 3,
      notes: [at(0, 175, 38, 124)], fx: [sat(12, .6), lp(800)] },
    { name: 'Tail: wide hall', inst: 'windNoise', patch: env(.004, .8, 0, .45, -.8, .7), gain: 13,
      notes: [at(0, 500, 62, 100)], fx: [verb(1.9, .7, 4000, .025)] },
  ],
  master: [comp(-12, 4, .001, .16, 6, 2), sat(3, .25)] }
sounds.bulkhead_pump = { title: 'Bulkhead pump', bodyMs: 300, tailMs: 250,
  layers: [
    { name: 'Back: ratchet', inst: 'clockworkKit', gain: -6, notes: [hit('clockworkKit', 'S', 0, 96)], fx: [hp(1500)] },
    { name: 'Back: claves knock', inst: 'clockworkKit', gain: -2, notes: [hit('clockworkKit', 'CH', 0, 100)], fx: [hp(900)] },
    { name: 'Back: low slide', inst: 'driveBass', patch: env(.001, .05, 0, .04, .8, 2), gain: -10, notes: [at(0, 75, 45, 100)], fx: [hp(90)] },
    { name: 'Forward: claves knock', inst: 'clockworkKit', gain: 0, notes: [hit('clockworkKit', 'CH', 175, 112)], fx: [hp(900)] },
    { name: 'Forward: lock tick', inst: 'drums808', gain: -10, notes: [hit('drums808', 'CH', 178, 115)], fx: [hp(3000)] },
    { name: 'Forward: low slam', inst: 'driveBass', patch: env(.001, .05, 0, .04, .5, 2), gain: -6, notes: [at(176, 75, 40, 115)], fx: [hp(70), lp(1500)] },
    { name: 'Room', inst: 'windNoise', patch: env(.002, .15, 0, .12, 0, .7), gain: -6, notes: [at(176, 75, 76, 80)], fx: [hp(800), verb(.6, .6)] },
  ],
  master: [comp(-12, 4, .001, .1, 6, 2)] }

// 5 MASS DRIVER: charge build, a loopable held charge, full and early release, power-down.
const crackle = (seed, count, from, to, curve, gain) => ({ name: 'Electric crackle', inst: 'windNoise', patch: env(0, .006, 0, .006, 3, .5), gain,
  notes: scatter(seed, count, from, to, 96, 108, 110, 126, 25, curve), fx: [hp(3500), sat(14, .7, 'hard')] })
sounds.massdriver_charge = { title: 'Mass Driver charge', bodyMs: 1250, tailMs: 150,
  layers: [
    { name: 'Latch click', inst: 'clockworkKit', gain: -4, notes: [hit('clockworkKit', 'CH', 0, 100)], fx: [hp(900)] },
    { name: 'Capacitor wind (ratchet)', inst: 'clockworkKit', gain: -12, notes: [hit('clockworkKit', 'S', 20, 90)], fx: [hp(1500)] },
    { name: 'Hum', inst: 'darkDrone', patch: { ...env(.5, .1, 1, .08, .5, 3), modulation: { waveform: 'triangle', rateHz: 15, pitchCents: 0, tremolo: .45, filterOctaves: .6 } },
      gain: 8, notes: [at(0, 1200, 33, 110)], fx: [sat(8, .5)] },
    { name: 'Rising whine', inst: 'supersaw', patch: { ...env(.012, .1, .8, .05, .4, 2), modulation: { waveform: 'sine', rateHz: 9, pitchCents: 30, tremolo: 0, filterOctaves: 0 } },
      gain: -6, notes: Array.from({ length: 24 }, (_, i) => at(i * 50, 75, 57 + i, 50 + i * 2.5)), fx: [hp(600), lp(7000)] },
    crackle(7, 40, 150, 1180, .55, -10),
  ],
  master: [comp(-14, 4, .003, .12, 6, 2)] }
// Held charge: rendered as a 3.6 s steady hold; loopcut.py takes a 1.6 s loop from its middle
// with a 100 ms equal-power crossfade (SigmAudio's loop export left a 40 ms dropout at the wrap).
sounds.massdriver_charge_hold = { title: 'Mass Driver charge held', bodyMs: 3600, tailMs: 100,
  layers: [
    { name: 'Hum', inst: 'darkDrone', patch: { ...env(.05, .1, 1, .08, .5, 3), modulation: { waveform: 'triangle', rateHz: 15, pitchCents: 0, tremolo: .45, filterOctaves: .6 } },
      gain: 8, notes: [at(0, 3600, 33, 110)], fx: [sat(8, .5)] },
    { name: 'Held whine', inst: 'supersaw', patch: { ...env(.05, .1, .8, .05, .4, 2), modulation: { waveform: 'sine', rateHz: 10, pitchCents: 30, tremolo: .15, filterOctaves: 0 } },
      gain: -6, notes: [at(0, 3600, 81, 110)], fx: [hp(600), lp(7000)] },
    { ...crackle(11, 50, 20, 3500, 1, -10), notes: scatter(11, 50, 20, 3500, 96, 108, 104, 122, 25, 1) },
  ],
  master: [comp(-14, 4, .003, .12, 6, 2)] }
const driverRelease = (full) => [
  { name: 'Attack: crack (snare)', inst: 'rockKit', gain: full ? -2 : -6, notes: [hit('rockKit', 'S', 0, 127)], fx: [hp(700), sat(14, .75, 'hard')] },
  { name: 'Attack: blast', inst: 'windNoise', patch: env(0, full ? .09 : .05, 0, .05, 2.5, .5), gain: full ? 0 : -4,
    notes: [at(0, 100, 98, 127)], fx: [hp(600), sat(14, .7, 'hard')] },
  { name: 'Attack: electric snap', inst: 'supersaw', patch: env(0, .025, 0, .02, 2, 4), gain: full ? -8 : -12,
    notes: [at(0, 25, 93, 127)], fx: [sat(18, .8, 'hard'), hp(1500)] },
  { name: 'Body: sub slam', inst: 'subBass', patch: env(.001, full ? .2 : .1, 0, .1, 0, 1), gain: full ? 0 : -3,
    notes: [at(0, 225, 28, 127)], fx: [sat(10, .5), hp(25)] },
  { name: 'Body: discharge sweep', inst: 'driveBass', patch: env(.001, full ? .32 : .16, 0, .12, 1.4, 8), gain: full ? 2 : -3,
    notes: [at(0, 350, 28, 124)], fx: [sat(12, .6), lp(3000)] },
  { name: 'Kinetic: slug ring (brake drum)', inst: 'clockworkKit', gain: full ? -6 : -12, notes: [hit('clockworkKit', 'K', 4, 110)], fx: [bp(1200, 1.5)] },
  ...(full ? [{ name: 'Kinetic: rail scrape (anvil)', inst: 'orchKit', gain: -16, notes: [hit('orchKit', 'C', 10, 90)], fx: [hp(3000)] }] : []),
  { name: 'Tail: hall', inst: 'windNoise', patch: env(.004, full ? 1 : .6, 0, .5, -.8, .7), gain: full ? 13 : 8,
    notes: [at(0, 600, 60, 100)], fx: [verb(full ? 2.2 : 1.4, .7, 3800, .03)] },
]
sounds.massdriver_release_full = { title: 'Mass Driver release (full charge)', bodyMs: 650, tailMs: 1500, layers: driverRelease(true),
  master: [comp(-12, 4, .001, .18, 6, 2), sat(3, .3)] }
sounds.massdriver_release_early = { title: 'Mass Driver release (early)', bodyMs: 400, tailMs: 900, layers: driverRelease(false),
  master: [comp(-12, 4, .001, .14, 6, 2)] }
sounds.massdriver_powerdown = { title: 'Mass Driver power-down', bodyMs: 700, tailMs: 400,
  layers: [
    { name: 'Falling whine', inst: 'supersaw', patch: { ...env(.004, .1, .8, .05, .4, 2), modulation: { waveform: 'sine', rateHz: 7, pitchCents: 25, tremolo: 0, filterOctaves: 0 } },
      gain: -6, notes: Array.from({ length: 22 }, (_, i) => at(i * 25, 40, 81 - i, 105 - i * 3)), fx: [hp(500), lp(6000)] },
    { name: 'Hum fade', inst: 'darkDrone', patch: env(.001, .55, 0, .1, .5, 3), gain: 6, notes: [at(0, 600, 33, 100)] },
    { name: 'Vent hiss', inst: 'windNoise', patch: env(.02, .45, 0, .2, 2, .7), gain: -2, notes: [at(120, 450, 96, 100)], fx: [hp(2500)] },
    { name: 'Vent click', inst: 'clockworkKit', gain: -6, notes: [hit('clockworkKit', 'CH', 100, 92)], fx: [hp(900)] },
    { name: 'Seat clunk', inst: 'driveBass', patch: env(.001, .05, 0, .04, .5, 2), gain: -6, notes: [at(560, 75, 40, 110)], fx: [hp(70), lp(1500)] },
    { name: 'Seat tick', inst: 'drums808', gain: -12, notes: [hit('drums808', 'CH', 562, 110)], fx: [hp(3000)] },
  ],
  master: [comp(-14, 4, .003, .12, 6, 2)] }

// IMPACTS: different acoustic worlds. Metal rings and sparks; stone chips and dusts; organic thuds.
const sparks = (seed, from, to, n, gain) => ({ name: 'Sparks (crackle)', inst: 'windNoise', patch: env(0, .005, 0, .005, 3, .5), gain,
  notes: scatter(seed, n, from, to, 100, 108, 120, 70, 25, 1.4), fx: [hp(4500), sat(10, .6, 'hard')] })
sounds.impact_metal = { title: 'Impact metal', bodyMs: 300, tailMs: 600,
  layers: [
    { name: 'Hit tick', inst: 'windNoise', patch: env(0, .01, 0, .01, 3, .5), gain: 0, notes: [at(0, 25, 104, 127)], fx: [hp(3000), sat(10, .6, 'hard')] },
    { name: 'Plate ring (anvil)', inst: 'orchKit', gain: -2, notes: [hit('orchKit', 'C', 0, 115)], fx: [hp(1800)] },
    { name: 'Plate body (brake drum)', inst: 'clockworkKit', gain: -3, notes: [hit('clockworkKit', 'K', 0, 110)], fx: [bp(1400, 1.2)] },
    { name: 'Punch thunk', inst: 'driveBass', patch: env(.003, .045, 0, .03, .3, 1), gain: 6, notes: [at(0, 50, 45, 124)], fx: [hp(80), lp(1200), sat(6, .4)] },
    sparks(23, 12, 240, 14, -6),
    { name: 'Short space', inst: 'windNoise', patch: env(.002, .15, 0, .12, 0, .7), gain: -6, notes: [at(0, 75, 76, 80)], fx: [hp(1000), verb(.6, .5)] },
  ],
  master: [comp(-12, 4, .001, .1, 6, 2)] }
sounds.impact_stone = { title: 'Impact stone', bodyMs: 475, tailMs: 600,
  layers: [
    { name: 'Chip crack (concert snare)', inst: 'orchKit', gain: 2, notes: [hit('orchKit', 'S', 0, 120)], fx: [hp(300, 1), lp(4500), sat(8, .5)] },
    { name: 'Chip knock (claves)', inst: 'clockworkKit', gain: 0, notes: [hit('clockworkKit', 'CH', 1, 90)], fx: [lp(3000)] },
    { name: 'Chip click', inst: 'stingKit', gain: -4, notes: [hit('stingKit', 'CH', 0, 120)], fx: [lp(5000)] },
    { name: 'Dull thud', inst: 'driveBass', patch: env(.001, .05, 0, .04, -.3, 1), gain: -3, notes: [at(0, 50, 40, 120)], fx: [hp(60), lp(700)] },
    { name: 'Debris patter', inst: 'windNoise', patch: env(0, .008, 0, .008, 1, .5), gain: -4,
      notes: scatter(31, 9, 30, 380, 45, 66, 112, 60, 25, 1.8), fx: [bp(1500, .7), sat(6, .5, 'hard')] },
    { name: 'Dust puff', inst: 'waterNoise', patch: env(.01, .35, 0, .15, -.5, .7), gain: 12, notes: [at(5, 300, 72, 90)], fx: [lp(1800), hp(150)] },
  ],
  master: [comp(-12, 4, .001, .1, 6, 2)] }
sounds.impact_organic = { title: 'Impact organic', bodyMs: 300, tailMs: 450,
  layers: [
    { name: 'Soft slap', inst: 'windNoise', patch: env(0, .025, 0, .02, -1, .7), gain: 9, notes: [at(0, 25, 84, 127)], fx: [lp(2200), sat(6, .4)] },
    { name: 'Slap (rim click, muffled)', inst: 'rockKit', gain: -6, notes: [hit('rockKit', 'C', 0, 105)], fx: [lp(1600)] },
    { name: 'Body thud', inst: 'subBass', patch: env(.001, .08, 0, .06, .3, 1), gain: -2, notes: [at(0, 100, 38, 124)], fx: [sat(6, .4), lp(500)] },
    { name: 'Muffled punch', inst: 'driveBass', patch: env(.001, .045, 0, .04, -.8, 1), gain: 2, notes: [at(0, 50, 33, 120)], fx: [lp(800)] },
    { name: 'Short knock', inst: 'stingKit', gain: -10, notes: [hit('stingKit', 'K', 0, 110)], fx: [lp(700)] },
  ],
  master: [comp(-12, 4, .001, .1, 6, 2)] }


// MASS DRIVER impacts: the generic material hit made heavier, plus a residual tone that
// depends on the surface (metal buzzes and rings, stone rumbles and settles, organic thrums).
const heavy = (name) => sounds[name].layers.map((t) => ({ ...t, gain: (t.gain ?? 0) + 2 }))
sounds.massdriver_impact_metal = { title: 'Mass Driver impact metal', bodyMs: 400, tailMs: 900,
  layers: [...heavy('impact_metal'),
    { name: 'Driver: slug slam', inst: 'subBass', patch: env(.001, .12, 0, .08, 0, 1), gain: 4, notes: [at(0, 150, 31, 127)], fx: [sat(10, .5)] },
    { name: 'Driver: plate buzz (residual)', inst: 'supersaw', patch: { ...env(.002, .45, 0, .15, .5, 4), modulation: { waveform: 'triangle', rateHz: 19, pitchCents: 40, tremolo: .6, filterOctaves: .5 } },
      gain: -10, notes: [at(5, 450, 45, 115)], fx: [bp(900, 1.5), sat(12, .6)] },
    { name: 'Driver: long ring', inst: 'clockworkKit', gain: -4, notes: [hit('clockworkKit', 'K', 6, 120)], fx: [bp(1200, 2), verb(1.2, .4)] },
  ],
  master: [comp(-12, 4, .001, .14, 6, 2)] }
sounds.massdriver_impact_stone = { title: 'Mass Driver impact stone', bodyMs: 600, tailMs: 900,
  layers: [...heavy('impact_stone'),
    { name: 'Driver: slug slam', inst: 'subBass', patch: env(.001, .14, 0, .08, 0, 1), gain: 5, notes: [at(0, 175, 31, 127)], fx: [sat(10, .5)] },
    { name: 'Driver: rubble rumble (residual)', inst: 'waterNoise', patch: env(.02, .6, 0, .25, -1.5, .7), gain: 10, notes: [at(20, 500, 48, 110)], fx: [lp(500), sat(6, .4)] },
    { name: 'Driver: falling chips', inst: 'windNoise', patch: env(0, .01, 0, .01, 1, .5), gain: -6,
      notes: scatter(57, 12, 120, 540, 45, 66, 100, 50, 25, 1.2), fx: [bp(1300, .7)] },
  ],
  master: [comp(-12, 4, .001, .14, 6, 2)] }
sounds.massdriver_impact_organic = { title: 'Mass Driver impact organic', bodyMs: 300, tailMs: 600,
  layers: [...heavy('impact_organic'),
    { name: 'Driver: deep body thud', inst: 'subBass', patch: env(.001, .16, 0, .1, .5, 1), gain: -2, notes: [at(0, 200, 33, 127)], fx: [sat(10, .5), lp(600)] },
    { name: 'Driver: thrum (residual)', inst: 'darkDrone', patch: { ...env(.005, .3, 0, .12, -.5, 2), modulation: { waveform: 'sine', rateHz: 11, pitchCents: 0, tremolo: .5, filterOctaves: 0 } },
      gain: 6, notes: [at(10, 300, 40, 110)], fx: [lp(700)] },
  ],
  master: [comp(-12, 4, .001, .14, 6, 2)] }

// Level matching (dB on the master): measured by measure.py, written by level.py.
import LEVELS from './levels.mjs'
for (const [name, db] of Object.entries(LEVELS)) if (sounds[name]) sounds[name].masterDb = (sounds[name].masterDb ?? 0) + db
export default sounds
