"""Neuter one refusal at a time and report the ones no test notices.

    python3 tools/mutate.py <source> <needle> <test file>...
    python3 tools/mutate.py archipepsi_bridge/layout.py "c.fail(" tests/test_layout.py
    python3 tools/mutate.py archipepsi_bridge/schemas/transitions.py \
        "raise ValueError(" tests/test_zone_progress.py

**The recurring failure in this project is a measurement that exists, is
correct, and is never handed the case that fails it.** A validator with
twenty-two refusals and a green suite says nothing about how many of
those refusals anything has ever triggered. This answers that: mute one,
run the tests, and if they still pass, nothing was reading it.

A survivor is not automatically a missing test. It is one of three
things, and saying which is the actual work:

1. a real gap -> write the test that fires it;
2. a branch unreachable by construction -> keep it as a backstop, say in
   a comment WHICH invariants keep it unreachable, and test those
   instead (see `check_physics_content`'s empty-`must` branch);
3. dead code -> delete it.

Never close a survivor by weakening the check.
"""

from __future__ import annotations

import os
import pathlib
import shutil
import subprocess
import sys

USAGE = "usage: mutate.py <source> <needle> <test path>..."


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(USAGE, file=sys.stderr)
        return 2
    target, needle, tests = argv[0], argv[1], argv[2:]
    path = pathlib.Path(target)
    orig = path.read_text(encoding="utf-8")
    lines = orig.split("\n")
    sites = [i for i, ln in enumerate(lines) if needle in ln]
    if not sites:
        print(f"no occurrence of {needle!r} in {target}", file=sys.stderr)
        return 2

    # `raise X(...)` cannot be muted by swapping in a no-op callable:
    # `raise None` still raises, and the test then fails for the wrong
    # reason and the site is scored as measured. Dropping the keyword
    # turns the statement into an assignment, which is what "this
    # refusal did not happen" actually looks like.
    repl = ("_MUTED = (" if needle.lstrip().startswith("raise ")
            else "(lambda *a, **k: None)(")

    # Every mutation changes the file by the same number of bytes, and
    # CPython validates a .pyc against (mtime in whole seconds, size).
    # Same size in the same second means a STALE .pyc is imported and
    # the mutation never ran, which reports measured checks as unmeasured
    # and back again on the next run. The harness that looks for checks
    # nothing exercises must not be one.
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")

    def purge() -> None:
        for d in pathlib.Path(".").rglob("__pycache__"):
            shutil.rmtree(d, ignore_errors=True)

    survivors = []
    try:
        for i in sites:
            mut = list(lines)
            mut[i] = mut[i].replace(needle, repl, 1)
            path.write_text("\n".join(mut), encoding="utf-8")
            purge()
            run = subprocess.run(
                [sys.executable, "-m", "pytest", *tests, "-q", "-x",
                 "--no-header", "-p", "no:cacheprovider"],
                capture_output=True, text=True, env=env)
            if run.returncode == 0:
                survivors.append((i + 1, lines[i].strip()[:88]))
    finally:
        path.write_text(orig, encoding="utf-8")
        purge()

    print(f"{len(sites)} sites, {len(survivors)} unmeasured")
    for ln, txt in survivors:
        print(f"  SURVIVES  {target}:{ln}  {txt}")
    return 1 if survivors else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
