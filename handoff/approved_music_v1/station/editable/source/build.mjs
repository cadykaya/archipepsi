// Build an authored SigmAudio project from a composition module.
// usage (from sigmaudio root): node build.mjs <composition.mjs> <starter.json> <out.json>
import { readFileSync, writeFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { createServer } from 'vite'
import { H } from './score.mjs'

const [compPath, starterPath, outPath] = process.argv.slice(2)
const comp = (await import(pathToFileURL(compPath).href)).default(H, process.env.V ? { version: Number(process.env.V) } : {})
const server = await createServer({ root: process.cwd(), logLevel: 'error',
  server: { middlewareMode: true }, optimizeDeps: { noDiscovery: true } })
try {
  const { migrateProject } = await server.ssrLoadModule('/src/model/migrations.ts')
  const { idFactoryFor } = await server.ssrLoadModule('/src/model/ids.ts')
  const { stepsPerBar } = await server.ssrLoadModule('/src/core/meter.ts')
  const { hasInstrument, instrumentsFor } = await server.ssrLoadModule('/src/audio/instruments.ts')
  const loaded = migrateProject(JSON.parse(readFileSync(starterPath, 'utf8')))
  if (!loaded.project) throw new Error(loaded.problems.join('\n'))
  const project = loaded.project
  const base = project.cues[0]
  const ids = idFactoryFor(`condi:${comp.name}:v${comp.version ?? 1}`)
  const meter = H.METERS[comp.meter]
  const transport = { ...base.transport, bpm: comp.bpm, meter, key: comp.key, lengthBars: comp.lengthBars, phraseLengthBars: comp.phraseLengthBars ?? 4 }
  const spb = stepsPerBar(meter)
  if (spb !== H.METERS_SPB[comp.meter]) throw new Error(`steps per bar mismatch ${spb}`)
  const total = spb * comp.lengthBars
  const layerId = ids.next('lay')
  const perTrackLayers = !!process.env.STEMS
  const tracks = [], patterns = [], clips = []
  const problems = []
  for (const t of comp.tracks.filter((x) => !process.env.ONLY || x.name === process.env.ONLY)) {
    if (!hasInstrument(t.instrumentId)) throw new Error(`unknown instrument ${t.instrumentId}`)
    if (!instrumentsFor(t.role).some((i) => i.id === t.instrumentId)) throw new Error(`${t.instrumentId} not allowed for ${t.role}`)
    const trackId = ids.next('trk'), patId = ids.next('pat')
    const notes = t.notes.map((n) => {
      if (n.t < 0 || n.t >= total) problems.push(`${t.name}: note at ${n.t} outside cue`)
      const len = Math.max(1, Math.min(Math.round(n.d), total * 2))
      return { id: ids.next('nte'), startStep: Math.round(n.t), lengthSteps: len,
        pitch: n.p, velocity: Math.max(1, Math.min(127, Math.round(n.v))), microOffsetTicks: Math.round(n.off ?? 0) }
    }).sort((a, b) => a.startStep - b.startStep || a.pitch - b.pitch)
    const track = { id: trackId, name: t.name, role: t.role, instrumentId: t.instrumentId, layerId: perTrackLayers ? `lay_stem${String(tracks.length).padStart(2, '0')}xxxxxxxxxxxxxxx` : layerId,
      mix: { gainDb: 0, pan: 0, mute: false, solo: false, toneHz: 20000, spaceAmount: 0.2, ...t.mix } }
    if (t.effects?.length) track.effects = t.effects.map((e, i) => ({ id: `${t.name.replace(/\W+/g, '-').toLowerCase()}-fx${i}`, bypass: false, ...e }))
    if (t.synthPatch) track.synthPatch = t.synthPatch
    tracks.push(track)
    patterns.push({ id: patId, lengthSteps: total, notes })
    clips.push({ id: ids.next('clp'), trackId, patternId: patId, startStep: 0, lengthSteps: total, transposeSteps: 0, mute: false })
  }
  if (problems.length) throw new Error(problems.join('\n'))
  const pl = transport.phraseLengthBars, roles = ['statement', 'answer', 'variation', 'turnaround']
  const phrases = []
  for (let b = 0, i = 0; b < comp.lengthBars; b += pl, i++) phrases.push({ id: ids.next('phr'), startBar: b, lengthBars: Math.min(pl, comp.lengthBars - b), role: roles[i % 4] })
  const arrangement = comp.sections.map((s) => ({ id: ids.next('sec'), name: s.name, kind: s.kind, startBar: s.startBar, lengthBars: s.lengthBars, repeat: 0 }))
  const adaptive = { ...base.adaptive,
    layers: perTrackLayers
      ? tracks.map((t, i) => ({ id: t.layerId, name: t.name, purpose: i ? 'harmony' : 'base', trackIds: [t.id], activeGainDb: 0, fadeBeats: 0 }))
      : [{ id: layerId, name: 'Full mix', purpose: 'base', trackIds: tracks.map((t) => t.id), activeGainDb: 0, fadeBeats: 0 }],
    states: base.adaptive.states.map((s) => ({ ...s, activeLayerIds: perTrackLayers ? tracks.map((t) => t.layerId) : [layerId] })) }
  // adaptive layering (optional): named layers, states, parameters, events and transitions
  let adaptiveOut = adaptive
  if (comp.adaptive) {
    const A = comp.adaptive, byTrack = new Map(tracks.map((t) => [t.name, t]))
    const layers = A.layers.map((l) => ({ id: ids.next('lay'), name: l.name, purpose: l.purpose ?? 'harmony',
      trackIds: l.tracks.filter((n) => byTrack.has(n)).map((n) => byTrack.get(n).id), activeGainDb: l.gainDb ?? 0, fadeBeats: l.fadeBeats ?? 2 }))
    for (const l of A.layers) for (const n of l.tracks) { if (!comp.tracks.some((t) => t.name === n)) throw new Error(`layer ${l.name}: no track ${n}`) }
    for (const t of comp.tracks) { const owners = A.layers.filter((l) => l.tracks.includes(t.name)); if (owners.length !== 1) throw new Error(`track ${t.name} is in ${owners.length} layers`) }
    layers.forEach((l, i) => l.trackIds.forEach((id) => { tracks.find((t) => t.id === id).layerId = l.id }))
    const lay = (n) => { const i = A.layers.findIndex((l) => l.name === n); if (i < 0) throw new Error(`no layer ${n}`); return layers[i].id }
    const states = A.states.map((st) => ({ id: ids.next('sta'), name: st.name, activeLayerIds: st.layers.map(lay), mixSnapshotId: null }))
    const sta = (n) => n === '*' ? '*' : (states.find((x) => x.name === n) ?? (() => { throw new Error(`no state ${n}`) })()).id
    const parameters = (A.parameters ?? []).map((q) => ({ id: ids.next('prm'), name: q.name, min: q.min ?? 0, max: q.max ?? 1, defaultValue: q.defaultValue ?? 0, smoothingMs: q.smoothingMs ?? 250 }))
    const prm = (n) => (parameters.find((x) => x.name === n) ?? (() => { throw new Error(`no parameter ${n}`) })()).id
    const events = (A.events ?? []).map((e) => ({ id: ids.next('evt'), name: e.name }))
    const cond = (w) => w.kind === 'param' ? { kind: 'param', paramId: prm(w.param), op: w.op, value: w.value, ...(w.holdMs ? { holdMs: w.holdMs } : {}) }
      : w.kind === 'event' ? { kind: 'event', eventId: events.find((e) => e.name === w.event).id }
        : w.kind === 'all' || w.kind === 'any' ? { kind: w.kind, of: w.of.map(cond) } : { kind: 'always' }
    const transitions = A.transitions.map((x) => ({ id: ids.next('trn'), fromStateId: sta(x.from), toStateId: sta(x.to), when: cond(x.when),
      quantize: x.quantize ?? 'bar', fadeBeats: x.fadeBeats ?? 2, priority: x.priority ?? 1, enterAbove: x.enterAbove ?? null, exitBelow: x.exitBelow ?? null, dwellMs: x.dwellMs ?? 0 }))
    adaptiveOut = { ...base.adaptive, baseStateId: sta(A.base), layers, states, parameters, events, transitions, stingers: [], mixSnapshots: base.adaptive.mixSnapshots ?? [] }
  }
  const cue = { ...base, name: comp.name, seed: `condi-${comp.name}`, transport, tracks, patterns, clips, phrases, arrangement, adaptive: adaptiveOut,
    updatedAt: new Date().toISOString() }
  if (comp.master) cue.mixer = { buses: [], master: { gainDb: -3, pan: 0, mute: false, effects: [], ...comp.master,
    effects: (comp.master.effects ?? []).map((e, i) => ({ id: `master-fx${i}`, bypass: false, ...e })) } }
  const out = { ...project, name: comp.name, cues: [cue] }
  const checked = migrateProject(JSON.parse(JSON.stringify(out)))
  if (!checked.project) throw new Error(checked.problems.join('\n'))
  writeFileSync(outPath, JSON.stringify(checked.project, null, 2) + '\n')
  const noteCount = tracks.length && patterns.reduce((a, p) => a + p.notes.length, 0)
  console.log(JSON.stringify({ ok: true, name: comp.name, tracks: tracks.length, notes: noteCount, bars: comp.lengthBars,
    seconds: +(comp.lengthBars * meter.beatsPerBar * 60 / comp.bpm).toFixed(2) }))
} finally { await server.close() }
