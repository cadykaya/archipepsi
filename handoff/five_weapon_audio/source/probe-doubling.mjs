// Repro for the doubled-note render defect: one note per project at a range of onsets.
// Build with build-sfx.mjs (SHIFT_MS unset), render each with render-one-shot and compare
// peaks. On SigmAudio main 66b3f6e: 330, 340, 350 and 450 ms render about +5.4 dB peak
// (-4.71 vs -10.08 dBFS); every other onset matches. Add 1000 ms to every onset and all match.
const env = (attack, decay, sustain, release, brightnessOctaves = 0, resonance = .7) => ({ attack, decay, sustain, release, brightnessOctaves, resonance })
const o = {}
for (const ms of [100, 200, 250, 275, 290, 300, 305, 310, 320, 330, 340, 350, 375, 400, 425, 450, 500, 600, 700])
  o[`p${ms}`] = { bodyMs: 800, tailMs: 200, layers: [{ name: 'punch', inst: 'subBass', patch: env(.002, .035, 0, .025, .5, 1), notes: [[ms, 25, 43, 120]] }] }
export default o
