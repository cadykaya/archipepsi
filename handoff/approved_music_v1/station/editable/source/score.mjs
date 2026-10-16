// Tiny notation helpers for writing music as text. All times are in grid steps.
const NOTE = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }
export function midi(name) {
  if (typeof name === 'number') return name
  if (/^\d+$/.test(name)) return Number(name)
  const m = /^([A-G])(#|b|x)?(-?\d)$/.exec(name)
  if (!m) throw new Error(`bad note ${name}`)
  const acc = m[2] === '#' ? 1 : m[2] === 'b' ? -1 : m[2] === 'x' ? 2 : 0
  return 12 * (Number(m[3]) + 1) + NOTE[m[1]] + acc
}
// seq(start, "D5/4 A4/2! G#4/2_ [D4,A4]/8 ./2 E5/2~", baseVel)
//  /n duration in steps (default: last), ! accent +18, _ soft -18, ' staccato (half length, min 1)
//  ~ legato (+1 step overlap), . is a rest, [a,b] is a chord, @n sets velocity absolutely
//  >n shifts the onset by n steps without moving the cursor (for pushes)
export function seq(start, text, vel = 90, opts = {}) {
  const out = []; let t = start, dur = 4
  for (const tok of text.trim().split(/\s+/)) {
    if (tok === '|') continue
    const m = /^(\[[^\]]+\]|[A-G][#bx]?-?\d|\.)(?:\/(\d+(?:\.\d+)?))?([!_'~]*)(?:@(\d+))?$/.exec(tok)
    if (!m) throw new Error(`bad token ${tok}`)
    if (m[2]) dur = Number(m[2])
    const flags = m[3] || ''
    if (m[1] !== '.') {
      const pitches = m[1].startsWith('[') ? m[1].slice(1, -1).split(',').map(midi) : [midi(m[1])]
      let v = m[4] ? Number(m[4]) : vel
      if (flags.includes('!')) v += 18
      if (flags.includes('_')) v -= 18
      let d = dur * (opts.gate ?? 1)
      if (flags.includes("'")) d = Math.max(1, dur / 2)
      if (flags.includes('~')) d = dur + 1
      for (const p of pitches) out.push({ t, d, p: p + (opts.transpose ?? 0), v })
    }
    t += dur
  }
  return out
}
// drums(start, { 36: "x...x...", 42: "x.x.x.x." }) — x=100 X=122 o=72 g=46 .=rest, one char per step
const DV = { x: 100, X: 122, o: 72, g: 46, '-': 30 }
export function drums(start, lanes, scale = 1) {
  const out = []
  for (const [p, str] of Object.entries(lanes)) {
    const chars = str.replace(/\s|\|/g, '')
    for (let i = 0; i < chars.length; i++) if (DV[chars[i]]) out.push({ t: start + i, d: 1, p: Number(p), v: DV[chars[i]] * scale })
  }
  return out
}
export const shift = (notes, dt, dp = 0, dv = 0) => notes.map((n) => ({ ...n, t: n.t + dt, p: n.p + dp, v: n.v + dv }))
export const velScale = (notes, k) => notes.map((n) => ({ ...n, v: n.v * k }))
export const ramp = (notes, from, to) => {
  if (!notes.length) return notes
  const t0 = Math.min(...notes.map((n) => n.t)), t1 = Math.max(...notes.map((n) => n.t)) || 1
  return notes.map((n) => ({ ...n, v: n.v * (from + (to - from) * (n.t - t0) / Math.max(1, t1 - t0)) }))
}
export const repeatEvery = (fn, from, to, every) => { const o = []; for (let t = from; t < to; t += every) o.push(...fn(t)); return o }
// sustained parts release inside their gate, so chords that only touch leave a gap: overlap them
export const legato = (notes, extra = 2) => notes.map((n) => ({ ...n, d: n.d + extra }))
export const METERS = {
  '4/4': { beatsPerBar: 4, beatUnit: 4, subdivisionTree: [2, 2, 2, 2] },
  '3/4': { beatsPerBar: 3, beatUnit: 4, subdivisionTree: [3, 2, 2] },
  '6/8': { beatsPerBar: 6, beatUnit: 8, subdivisionTree: [2, 3, 2] },
  '12/8': { beatsPerBar: 12, beatUnit: 8, subdivisionTree: [4, 3, 2] },
  '5/4': { beatsPerBar: 5, beatUnit: 4, subdivisionTree: [5, 2, 2] },
  '7/8': { beatsPerBar: 7, beatUnit: 8, subdivisionTree: [7, 2] },
}
export const METERS_SPB = { '4/4': 16, '3/4': 12, '6/8': 12, '12/8': 24, '5/4': 20, '7/8': 14 }
export const H = { legato, midi, seq, drums, shift, velScale, ramp, repeatEvery, METERS, METERS_SPB }
