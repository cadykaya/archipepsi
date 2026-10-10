#!/usr/bin/env python3
"""Check a review branch against the lines the five-weapon brief draws.

    python3 tools/vera/weapon_boundary_check.py CANDIDATE [--base BASE]

Read-only. Uses git plumbing only (no checkout, no Godot), so it can be
pointed at any ref, including other people's live branches.

WHAT IT COMPARES. Only what CANDIDATE itself changed: the diff runs from
merge-base(BASE, CANDIDATE) to CANDIDATE, so work it inherited is not
blamed on it. BASE defaults to `origin/review/weapon-feel`, the
presentation baseline the brief names.

WHAT IT REPORTS, by severity:

  RED    a line the brief draws was crossed: a protected campaign or G1
         path changed, or a Static Pulse constant / `_fire_static_pulse`
         body differs from BASE.
  AMBER  read before believing: shared review plumbing every review host
         touches (main.gd, isolation, export presets), added lines naming
         a system the brief excludes (ammo, reload, inventory, ...), or a
         new content host that never mentions ReviewIsolation.
  INFO   the new host's numbers -- cadences, damages, charge times -- for
         a human to hold against the brief's candidate bands. Reported,
         never judged: the brief calls them candidates.

Heuristics are labelled as heuristics. A clean report is evidence that
the boundaries hold, not that the weapons are fun.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys

DEFAULT_BASE = "origin/review/weapon-feel"

# --- the lines the brief draws ---------------------------------------------

#: "must never silently mutate campaign base-kit damage or cadence";
#: "Separate G1 and campaign remain untouched"; "avoid touching G1,
#: Static Pulse, enemy roster or campaign". Prefix match on repo paths.
PROTECTED = {
    "campaign": (
        "bridge/archipepsi_bridge/",
        "apworld/",
        "godot/content/registry/",
        "godot/content/SCENE_PLAN.json",
        "godot/content/shells/",
        "godot/scripts/generation/",
        "docs/baselines/",
    ),
    "base kit": (
        "godot/scripts/gameplay/player.gd",
        "godot/scripts/gameplay/echo_runtime.gd",
    ),
    "enemy roster": (
        "godot/scripts/enemies/",
    ),
    "G1 / Impact Relay": (
        "godot/scripts/content/impact_relay",
        "godot/scripts/content/impact_lab",
        "godot/candidate/impact_relay/",
        "godot/tests/impact_relay_check.gd",
        "godot/tests/impact_lab_check.gd",
        "tools/impact_relay/",
        "tools/impact_lab/",
    ),
}

#: Files every isolated review host has touched so far (weapon-feel,
#: hand-cannon, G0, G1, Crossing D). Expected, but they are shared, so a
#: change there can reach other hosts. Listed for a human to read.
SHARED_PLUMBING = (
    "godot/scripts/main.gd",
    "godot/scripts/content/review_isolation.gd",
    "godot/export_presets.cfg",
    "tools/crossing_review_probe.py",
    "bridge/tests/test_ci_coverage.py",
    "godot/scripts/autoload/constants.gd",
    "assets/LICENSES.json",
    "Makefile",
    "docs/AGENT_FRONTIER.md",
)

#: The Static Pulse must stay 6 damage every 0.35 s. Checked by VALUE at
#: the candidate, and against BASE, so a changed baseline is visible too.
PULSE_CONSTANTS = {
    "STATIC_PULSE_COOLDOWN": 0.35,
    "STATIC_PULSE_DAMAGE": 6.0,
    "STATIC_PULSE_RANGE": None,   # no value in the brief; must equal BASE
}

#: "No new universal weapon slots, inventory, ammo, reload, economy or
#: armor systems." Word match on ADDED code lines only. A heuristic: the
#: word "reload" also means "reload the scene".
EXCLUDED_SYSTEMS = re.compile(
    r"\b(ammo|ammunition|magazine|reload|reloading|inventory|loot|"
    r"loot_table|rarity|"
    r"armou?r|economy|currency)\b", re.IGNORECASE)

#: The Static Pulse can be changed without touching `player.gd`: write
#: its private state from outside. `hand-cannon` does exactly this, on
#: purpose and only in its range (`player._pulse_cooldown = cadence`), so
#: it is AMBER, not RED -- the question for a human is whether that code
#: can ever run outside its isolated host.
PRIVATE_FIRE_WRITE = re.compile(
    r"\b\w+\._(pulse\w*|\w*cooldown\w*|\w*damage\w*|fire\w*)\s*"
    r"(?:[-+*/]?=)(?!=)")

#: Names of numbers worth showing next to the brief's candidate bands.
TUNING_NAME = re.compile(
    r"(cooldown|interval|cadence|rate|rps|per_second|delay|charge|"
    r"pellet|spread|damage|recoil|kick|impulse|knockback|decal|mark|"
    r"cap|max_|range|speed)", re.IGNORECASE)
CONST_LINE = re.compile(
    r"^\s*(?:const|var)\s+([A-Za-z_]\w*)\s*(?::\s*\w+)?\s*:?=\s*"
    r"(-?\d+(?:\.\d+)?)\b")

BRIEF_BANDS = (
    "Foundry hand cannon   ~0.65-0.80 s between shots",
    "Sightline scout       ~0.30-0.40 s recovery",
    "Switchback carbine    ~6-8 rounds per second held",
    "Bulkhead scattergun   ~0.9-1.1 s, several pellets",
    "Mass Driver           hold to charge, release; slower than the rest",
    "Static Pulse          6 damage / 0.35 s -- UNCHANGED",
)


# --- git ---------------------------------------------------------------------

def git(*args: str, check: bool = True) -> str:
    done = subprocess.run(("git",) + args, capture_output=True, text=True)
    if check and done.returncode != 0:
        raise SystemExit("git %s failed: %s" % (" ".join(args),
                                               done.stderr.strip()))
    return done.stdout


def show(ref: str, path: str) -> str | None:
    done = subprocess.run(("git", "show", "%s:%s" % (ref, path)),
                          capture_output=True, text=True)
    return done.stdout if done.returncode == 0 else None


def changed(base: str, cand: str) -> list[tuple[str, str]]:
    """(status, path) for every path CANDIDATE changed since BASE."""
    out = []
    for line in git("diff", "--name-status", "-M", base, cand).splitlines():
        parts = line.split("\t")
        status, path = parts[0][0], parts[-1]
        out.append((status, path))
        if status == "R" and len(parts) == 3:
            out.append(("R-from", parts[1]))
    return out


def added_lines(base: str, cand: str, path: str) -> list[tuple[int, str]]:
    """Lines CANDIDATE added to `path`, with their new line numbers."""
    diff = git("diff", "-U0", base, cand, "--", path)
    out, line_no = [], 0
    for raw in diff.splitlines():
        hunk = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw)
        if hunk:
            line_no = int(hunk.group(1))
            continue
        if raw.startswith("+") and not raw.startswith("+++"):
            out.append((line_no, raw[1:]))
            line_no += 1
    return out


# --- the checks --------------------------------------------------------------

def category(path: str) -> str | None:
    for name, prefixes in PROTECTED.items():
        if any(path.startswith(p) for p in prefixes):
            return name
    return None


def pulse_values(ref: str) -> dict[str, float | None]:
    text = show(ref, "godot/scripts/autoload/constants.gd") or ""
    out: dict[str, float | None] = {}
    for name in PULSE_CONSTANTS:
        hit = re.search(r"^const\s+%s\s*(?::\s*\w+)?\s*=\s*([-\d.]+)"
                        % name, text, re.MULTILINE)
        out[name] = float(hit.group(1)) if hit else None
    return out


def function_body(ref: str, path: str, name: str) -> str | None:
    """The text of a GDScript `func name` up to the next top-level item."""
    text = show(ref, path)
    if text is None:
        return None
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if re.match(r"^func\s+%s\s*\(" % re.escape(name), line):
            body = [line]
            for nxt in lines[i + 1:]:
                if nxt and not nxt[0].isspace() and not nxt.startswith("#"):
                    break
                body.append(nxt)
            while body and not body[-1].strip():
                body.pop()
            return "\n".join(body)
    return None


def digest(text: str | None) -> str:
    return "absent" if text is None else \
        hashlib.sha256(text.encode()).hexdigest()[:12]


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("candidate", help="ref to check, e.g. origin/review/x")
    ap.add_argument("--base", default=DEFAULT_BASE,
                    help="presentation baseline (default %(default)s)")
    args = ap.parse_args(argv)

    cand = git("rev-parse", "--verify", args.candidate).strip()
    base_tip = git("rev-parse", "--verify", args.base).strip()
    base = git("merge-base", base_tip, cand).strip()
    red: list[str] = []
    amber: list[str] = []

    print("Vera's weapon boundary check")
    print("  candidate  %s  %s" % (args.candidate, cand[:12]))
    print("  base       %s  %s" % (args.base, base_tip[:12]))
    print("  compared   %s..%s  (merge-base..candidate)"
          % (base[:12], cand[:12]))
    paths = changed(base, cand)
    print("  changed    %d path(s)\n" % len(paths))

    # 1. protected paths
    for status, path in paths:
        name = category(path)
        if name:
            red.append("%s path %s: %s" % (name, status, path))

    # 2. Static Pulse, by value and by body
    at_cand, at_base = pulse_values(cand), pulse_values(base)
    for name, wanted in PULSE_CONSTANTS.items():
        got, was = at_cand[name], at_base[name]
        if got is None:
            red.append("Static Pulse: %s is missing at the candidate"
                       % name)
        elif wanted is not None and abs(got - wanted) > 1e-9:
            red.append("Static Pulse: %s = %s, the brief requires %s"
                       % (name, got, wanted))
        elif was is not None and abs(got - was) > 1e-9:
            red.append("Static Pulse: %s = %s, base had %s"
                       % (name, got, was))
    pulse_c = function_body(cand, "godot/scripts/gameplay/player.gd",
                            "_fire_static_pulse")
    pulse_b = function_body(base, "godot/scripts/gameplay/player.gd",
                            "_fire_static_pulse")
    if digest(pulse_c) != digest(pulse_b):
        red.append("Static Pulse: Player._fire_static_pulse differs from "
                   "base (%s -> %s)" % (digest(pulse_b), digest(pulse_c)))

    # 3. shared plumbing (expected for a review host; shared, so read it)
    for status, path in paths:
        if path in SHARED_PLUMBING and not category(path):
            amber.append("shared plumbing %s: %s" % (status, path))

    # 4. excluded systems, added code lines only (heuristic)
    code = [p for s, p in paths if s in "AMR" and p.endswith((".gd", ".py"))]
    for path in code:
        for line_no, text in added_lines(base, cand, path):
            stripped = text.strip()
            if stripped.startswith(("#", "##")):
                continue
            hit = EXCLUDED_SYSTEMS.search(text)
            if hit:
                amber.append("excluded-system word %r (heuristic) at %s:%d"
                             "  %s" % (hit.group(0), path, line_no,
                                       stripped[:90]))

    # 4b. private Player fire state written from outside player.gd
    for path in code:
        if path == "godot/scripts/gameplay/player.gd":
            continue
        for line_no, text in added_lines(base, cand, path):
            stripped = text.strip()
            if stripped.startswith("#"):
                continue
            if PRIVATE_FIRE_WRITE.search(text):
                amber.append("writes Player fire state from outside "
                             "player.gd at %s:%d  %s"
                             % (path, line_no, stripped[:90]))

    # 5. a new content host should say how it is isolated (heuristic)
    for status, path in paths:
        if status == "A" and path.startswith("godot/scripts/content/") \
                and path.endswith(".gd"):
            text = show(cand, path) or ""
            if re.search(r"^extends\s+Node3D", text, re.MULTILINE) \
                    and re.search(r"\bconst\s+FLAG\b|--[a-z-]+", text) \
                    and "ReviewIsolation" not in text:
                amber.append("new host never mentions ReviewIsolation "
                             "(heuristic): %s" % path)

    # 6. the numbers, for a human
    tuning: list[str] = []
    for path in code:
        if not path.startswith(("godot/scripts/", "godot/tests/")) \
                or category(path):
            continue
        for line_no, text in added_lines(base, cand, path):
            hit = CONST_LINE.match(text)
            if hit and TUNING_NAME.search(hit.group(1)):
                tuning.append("%-44s = %-8s %s:%d" % (
                    hit.group(1), hit.group(2), path, line_no))

    print("RED  -- a line the brief draws was crossed (%d)" % len(red))
    for item in red:
        print("  x " + item)
    if not red:
        print("  none")
    print("\nAMBER -- read before believing (%d)" % len(amber))
    for item in amber:
        print("  ! " + item)
    if not amber:
        print("  none")
    print("\nINFO -- numbers the candidate added, against the brief's bands")
    for band in BRIEF_BANDS:
        print("  band: " + band)
    for item in tuning[:80]:
        print("  " + item)
    if len(tuning) > 80:
        print("  ... %d more" % (len(tuning) - 80))
    if not tuning:
        print("  (no matching constants added)")
    print("\nStatic Pulse at candidate: %s" % ", ".join(
        "%s=%s" % (k.replace("STATIC_PULSE_", ""), v)
        for k, v in at_cand.items()))
    print("_fire_static_pulse body: base %s, candidate %s"
          % (digest(pulse_b), digest(pulse_c)))
    print("\nVERDICT: %s" % ("RED" if red else
                             "AMBER" if amber else "CLEAN"))
    return 1 if red else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
