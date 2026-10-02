"""CK9-F1 phase sweep, diagnostic only (never committed): shift the flyers'
wall-clock circle (`Enemy._drift`) by CK9_DRIFT_OFFSET_MS milliseconds, so
one machine can visit every phase of it. Offset 0 is the code unchanged.
    python3 drift_offset_patch.py TREE"""
import sys
p = sys.argv[1] + "/godot/scripts/enemies/enemy.gd"
s = open(p).read()
old = "\tvar around := Time.get_ticks_msec() / 1000.0 * 0.4\n"
new = ("\tvar around := (Time.get_ticks_msec() + OS.get_environment("
       "\"CK9_DRIFT_OFFSET_MS\").to_int()) / 1000.0 * 0.4\n")
assert s.count(old) == 1, "anchor"
open(p, "w").write(s.replace(old, new))
print("drift offset patch applied to", p)
