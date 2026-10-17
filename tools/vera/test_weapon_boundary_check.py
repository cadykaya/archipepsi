#!/usr/bin/env python3
"""Sabotage suite: does the boundary check actually catch what it claims?

    python3 tools/vera/test_weapon_boundary_check.py [--on REF]

Each case builds one throwaway commit on a TEMPORARY DETACHED WORKTREE
of REF (default `origin/review/hand-cannon`), runs the checker against
it, asserts the verdict, and removes the worktree. No branch, tag or
remote is created or touched; the commits are unreferenced and git's
own gc removes them.

A checker that has only ever been run on clean branches has proven
nothing, so the first case is the control and every other case is a
deliberate violation of one line the brief draws.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
CHECK = HERE / "weapon_boundary_check.py"


def run(*args: str, cwd: str | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True)


def edit(root: pathlib.Path, path: str, fn) -> None:
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    before = target.read_text() if target.exists() else ""
    after = fn(before)
    assert after != before, "sabotage made no change to %s" % path
    target.write_text(after)


# Each case: (name, list of (path, edit fn), expected verdict, must-contain)
def cases():
    pulse = "godot/scripts/autoload/constants.gd"
    player = "godot/scripts/gameplay/player.gd"
    yield ("control: the branch as it is", [], None, None)
    yield ("Static Pulse damage changed by value",
           [(pulse, lambda s: s.replace("STATIC_PULSE_DAMAGE = 6.0",
                                        "STATIC_PULSE_DAMAGE = 7.0", 1))],
           "RED", "STATIC_PULSE_DAMAGE")
    yield ("Static Pulse cooldown changed by value",
           [(pulse, lambda s: s.replace("STATIC_PULSE_COOLDOWN = 0.35",
                                        "STATIC_PULSE_COOLDOWN = 0.30", 1))],
           "RED", "STATIC_PULSE_COOLDOWN")
    yield ("_fire_static_pulse body edited",
           [(player, lambda s: re.sub(
               r"(func _fire_static_pulse\(\) -> void:\n)",
               r"\1\tpass  # sabotage\n", s, count=1))],
           "RED", "_fire_static_pulse differs")
    yield ("G1 room script touched",
           [("godot/scripts/content/impact_relay.gd",
             lambda s: s + "\n# sabotage\n")],
           "RED", "G1 / Impact Relay")
    yield ("campaign bridge touched",
           [("bridge/archipepsi_bridge/campaign.py",
             lambda s: s + "\n# sabotage\n")],
           "RED", "campaign path")
    yield ("enemy roster touched",
           [("godot/scripts/enemies/enemy.gd",
             lambda s: s + "\n# sabotage\n")],
           "RED", "enemy roster")
    yield ("an ammo system added in a new host",
           [("godot/scripts/content/vera_sabotage_range.gd",
             lambda s: "extends Node3D\n\nvar ammo := 30\n")],
           "AMBER", "excluded-system word 'ammo'")
    yield ("Player fire state written from a new host",
           [("godot/scripts/content/vera_sabotage_range.gd",
             lambda s: "extends Node3D\n\nfunc f(player) -> void:\n"
                       "\tplayer._pulse_cooldown = 0.1\n")],
           "AMBER", "writes Player fire state")
    yield ("a new isolated-looking host with no ReviewIsolation",
           [("godot/scripts/content/vera_sabotage_range.gd",
             lambda s: 'extends Node3D\n\nconst FLAG := "--vera-range"\n')],
           "AMBER", "never mentions ReviewIsolation")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--on", default="origin/review/hand-cannon")
    args = ap.parse_args(argv)
    base_sha = run("git", "rev-parse", "--verify", args.on).stdout.strip()
    if not base_sha:
        print("cannot resolve %s" % args.on)
        return 2

    failures = 0
    for name, edits, want, must in cases():
        with tempfile.TemporaryDirectory(prefix="vera-sabotage-") as tmp:
            wt = pathlib.Path(tmp) / "wt"
            made = run("git", "worktree", "add", "--detach", str(wt),
                       base_sha)
            if made.returncode != 0:
                print("FAIL %s: worktree: %s" % (name, made.stderr.strip()))
                failures += 1
                continue
            try:
                ref = base_sha
                if edits:
                    for path, fn in edits:
                        edit(wt, path, fn)
                    run("git", "add", "-A", cwd=str(wt))
                    done = run("git", "-c", "user.name=vera-sabotage",
                               "-c", "user.email=noreply@anthropic.com",
                               "commit", "-q", "-m", "sabotage: " + name,
                               cwd=str(wt))
                    if done.returncode != 0:
                        raise RuntimeError(done.stderr.strip())
                    ref = run("git", "rev-parse", "HEAD",
                              cwd=str(wt)).stdout.strip()
                out = run(sys.executable, str(CHECK), ref,
                          "--base", base_sha)
                text = out.stdout
                verdict = re.search(r"VERDICT: (\w+)", text)
                got = verdict.group(1) if verdict else "?"
                if want is None:
                    # the control: whatever the branch is, the checker
                    # must not invent a RED against itself
                    ok = got == "CLEAN" and out.returncode == 0
                else:
                    ok = (got == want and must in text
                          and out.returncode == (1 if want == "RED" else 0))
                print("%s  %-52s -> %s%s" % (
                    "ok  " if ok else "FAIL", name, got,
                    "" if ok else "  (wanted %s containing %r)"
                    % (want or "CLEAN", must)))
                if not ok:
                    failures += 1
                    print("\n".join("      " + l for l in
                                    text.splitlines()[:30]))
            except Exception as err:  # report and continue
                print("FAIL %s: %s" % (name, err))
                failures += 1
            finally:
                run("git", "worktree", "remove", "--force", str(wt))
    run("git", "worktree", "prune")
    print("\n%d case(s) failed" % failures if failures else
          "\nall cases behaved: the check catches what it claims")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
