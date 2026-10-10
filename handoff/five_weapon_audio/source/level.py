"""Compute master gains that bring each sound to its loudness target (momentary-max LUFS,
the loudest 400 ms) and update levels.mjs. Run, rebuild, re-render, re-measure; repeat until
every sound is within 0.3 dB. usage: python3 -I level.py measure.json levels.mjs"""
import sys, json, re
W = -21.0  # weapon fire target (single shot; Switchback by its 2-second series)
TARGET = {
  'foundry_fire': W, 'sightline_fire': W, 'bulkhead_fire': W, 'massdriver_release_full': W,
  'switchback_series_demo': W, 'massdriver_release_early': W - 2,
  'impact_metal': W - 4, 'impact_stone': W - 4, 'impact_organic': W - 4,
  'massdriver_impact_metal': W - 2, 'massdriver_impact_stone': W - 2, 'massdriver_impact_organic': W - 2,
  'massdriver_charge': W - 3, 'massdriver_charge_hold': W - 5, 'massdriver_powerdown': W - 6, 'bulkhead_pump': W - 7, 'switchback_release_tail': W - 9,
}
FOLLOW = {'switchback_fire_a': 'switchback_series_demo', 'switchback_fire_b': 'switchback_series_demo'}
rows = {r['file'][:-4].removesuffix('_loop'): r for r in json.load(open(sys.argv[1]))}
src = open(sys.argv[2]).read(); cur = {k: float(v) for k, v in re.findall(r"(\w+): (-?[\d.]+)", src)}
new = dict(cur)
for name, t in TARGET.items():
    if name in rows: new[name] = round(cur.get(name, 0) + t - rows[name]['momentary_max_lufs'], 2)
for name, lead in FOLLOW.items(): new[name] = new.get(lead, 0)
open(sys.argv[2], 'w').write('// Master gain per sound, from level.py. Do not edit by hand.\nexport default {\n' + ''.join(f'  {k}: {v},\n' for k, v in sorted(new.items())) + '}\n')
for k in sorted(new): print(f'{k:28s} {cur.get(k,0):7.2f} -> {new[k]:7.2f}')
