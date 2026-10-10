// Build one authored SigmAudio one-shot project per sound in a sound-design module.
// usage (from the sigmaudio checkout root):
//   node build-sfx.mjs <sounds.mjs> <starter.sigmaudio.json> <outDir> [name ...]
// Times in the sound module are milliseconds. The cue runs at 600 BPM in 4/4, so a grid
// step is 25 ms and each onset is placed exactly with microOffsetTicks (480 per beat,
// about 0.21 ms). Every layer is an ordinary track: notes, instrument, synth patch, mix
// and effect inserts, editable in SigmAudio like any other cue.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { join } from 'node:path'
import { createRequire } from 'node:module'
// vite comes from the SigmAudio checkout this runs in, not from this folder.
const { createServer } = await import(pathToFileURL(createRequire(join(process.cwd(), 'package.json')).resolve('vite')).href)

const [soundsPath, starterPath, outDir, ...only] = process.argv.slice(2)
const sounds = (await import(pathToFileURL(soundsPath).href)).default
// SHIFT_MS delays the whole event (used to dodge and detect the doubled-note render defect).
const SHIFT = Number(process.env.SHIFT_MS ?? 0)
const BPM = 600, STEP_MS = 60000 / BPM / 4, TICK_MS = 60000 / BPM / 480
const KIT = { K: 36, S: 38, C: 39, CH: 42, OH: 46, R: 51 }
mkdirSync(outDir, { recursive: true })
const server = await createServer({ root: process.cwd(), logLevel: 'error',
  server: { middlewareMode: true }, optimizeDeps: { noDiscovery: true } })
try {
  const { migrateProject } = await server.ssrLoadModule('/src/model/migrations.ts')
  const { idFactoryFor } = await server.ssrLoadModule('/src/model/ids.ts')
  const { hasInstrument, instrumentsFor } = await server.ssrLoadModule('/src/audio/instruments.ts')
  const loaded = migrateProject(JSON.parse(readFileSync(starterPath, 'utf8')))
  if (!loaded.project) throw new Error(loaded.problems.join('\n'))
  const base = loaded.project.cues[0]
  const roles = ['drums', 'bass', 'motif', 'chords', 'texture']
  for (const [name, s] of Object.entries(sounds)) {
    if (only.length && !only.includes(name)) continue
    const ids = idFactoryFor(`condi:five-weapon:${name}:v${s.version ?? 1}`)
    const bodyMs = s.bodyMs + SHIFT
    const lengthBars = Math.ceil(bodyMs / (STEP_MS * 16)) || 1
    const total = lengthBars * 16
    const tracks = [], patterns = [], clips = []
    for (const t of s.layers) {
      if (!hasInstrument(t.inst)) throw new Error(`${name}: unknown instrument ${t.inst}`)
      const role = t.role ?? roles.find((r) => instrumentsFor(r).some((i) => i.id === t.inst))
      if (!role || !instrumentsFor(role).some((i) => i.id === t.inst)) throw new Error(`${name}: ${t.inst} fits no role`)
      const notes = t.notes.map(([ms0, durMs, pitch, vel]) => {
        const ms = ms0 + SHIFT
        if (ms >= s.bodyMs + SHIFT) throw new Error(`${name}/${t.name}: attack at ${ms} ms is after the ${s.bodyMs} ms body`)
        const step = Math.floor(ms / STEP_MS)
        const ticks = Math.round((ms - step * STEP_MS) / TICK_MS)
        return { id: ids.next('nte'), startStep: step, lengthSteps: Math.max(1, Math.round(durMs / STEP_MS)),
          pitch: typeof pitch === 'string' ? KIT[pitch] : pitch, velocity: Math.max(1, Math.min(127, Math.round(vel))),
          microOffsetTicks: ticks }
      }).sort((a, b) => a.startStep - b.startStep || a.microOffsetTicks - b.microOffsetTicks || a.pitch - b.pitch)
      const trackId = ids.next('trk'), patId = ids.next('pat')
      const track = { id: trackId, name: t.name, role, instrumentId: t.inst, layerId: null,
        mix: { gainDb: t.gain ?? 0, pan: t.pan ?? 0, mute: false, solo: false, toneHz: t.tone ?? 20000, spaceAmount: 0 } }
      if (t.patch) track.synthPatch = t.patch.modulation ? { version: 2, ...t.patch } : { version: 1, ...t.patch }
      if (t.fx?.length) track.effects = t.fx.map((e, i) => ({ id: `${t.name.replace(/\W+/g, '-').toLowerCase()}-fx${i}`, bypass: false, ...e }))
      tracks.push(track)
      patterns.push({ id: patId, lengthSteps: total, notes })
      clips.push({ id: ids.next('clp'), trackId, patternId: patId, startStep: 0, lengthSteps: total, transposeSteps: 0, mute: false })
    }
    const cue = { ...base, id: ids.next('cue'), name: s.title ?? name, seed: `condi-five-weapon-${name}`,
      transport: { ...base.transport, bpm: BPM, lengthBars, phraseLengthBars: lengthBars },
      ...(s.loop ? {} : { playback: { version: 1, mode: 'one-shot', bodySeconds: bodyMs / 1000, tailSeconds: s.tailMs / 1000 } }),
      tracks, patterns, clips,
      phrases: [{ id: ids.next('phr'), startBar: 0, lengthBars, role: 'statement' }],
      arrangement: [{ id: ids.next('sec'), name: 'Event', kind: 'loop', startBar: 0, lengthBars, repeat: 0 }],
      adaptive: { ...base.adaptive, layers: [] , states: base.adaptive.states.map((st) => ({ ...st, activeLayerIds: [] })) },
      mixer: { buses: [], master: { gainDb: s.masterDb ?? 0, pan: 0, mute: false,
        effects: (s.master ?? []).map((e, i) => ({ id: `master-fx${i}`, bypass: false, ...e })) } },
      updatedAt: '2026-10-10T00:00:00.000Z' }
    delete cue.generationTrace
    if (s.loop) delete cue.playback
    const project = { ...loaded.project, id: ids.next('prj'), name: s.title ?? name, seed: `condi-five-weapon-${name}`, cues: [cue] }
    const checked = migrateProject(JSON.parse(JSON.stringify(project)))
    if (!checked.project) throw new Error(`${name}: ${checked.problems.join('\n')}`)
    writeFileSync(join(outDir, `${name}.sigmaudio.json`), JSON.stringify(checked.project, null, 2) + '\n')
    console.log(JSON.stringify({ ok: true, name, tracks: tracks.length, notes: patterns.reduce((a, p) => a + p.notes.length, 0), bodyMs, tailMs: s.tailMs, shiftMs: SHIFT }))
  }
} finally { await server.close() }
