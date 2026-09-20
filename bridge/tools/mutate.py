"""Neuter one refusal at a time and report the ones no test notices.

    python3 tools/mutate.py <source> <needle> <test path>...
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

**A BROKEN TEST RUN IS NOT A KILLED MUTANT.** The first version scored
any non-zero exit as "the tests noticed", so a directory where pytest
could not start at all reported `1 sites, 0 unmeasured` — a clean bill
of health from a run in which nothing ran. That is precisely the defect
this tool exists to find, in the tool itself. Two things stop it now:

* an **unmutated baseline** has to pass before a single mutation is
  written, so the harness knows the suite is runnable and green to
  begin with; and
* only pytest's exit code **1** (tests ran, tests failed) counts as a
  kill. Collection failure, usage error, internal error, interruption
  and anything else are HARNESS ERRORS, reported with their output and
  never silently counted either way.
"""

from __future__ import annotations

import os
import pathlib
import shutil
import subprocess
import sys

USAGE = "usage: mutate.py <source> <needle> <test path>..."

#: pytest's documented exit codes. Only TESTS_FAILED means a mutant died.
OK, TESTS_FAILED, INTERRUPTED, INTERNAL_ERROR, USAGE_ERROR, NO_TESTS = range(6)
_WHY = {
    INTERRUPTED: "the run was interrupted (exit 2)",
    INTERNAL_ERROR: "pytest hit an internal error (exit 3)",
    USAGE_ERROR: "pytest usage error — bad path or option (exit 4)",
    NO_TESTS: "no tests were collected (exit 5)",
}


def _why(code: int) -> str:
    if code in _WHY:
        return _WHY[code]
    if code < 0:
        return f"the run died on signal {-code}"
    return f"pytest exited {code}, which is not a test result"


class HarnessError(RuntimeError):
    """The run did not produce a verdict. Never a measurement."""


def _tail(run: subprocess.CompletedProcess, lines: int = 25) -> str:
    out = (run.stdout or "") + (run.stderr or "")
    kept = out.strip().splitlines()[-lines:]
    return "\n".join("    | " + ln for ln in kept) or "    | (no output)"


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(USAGE, file=sys.stderr)
        return 2
    target, needle, tests = argv[0], argv[1], argv[2:]
    path = pathlib.Path(target)
    if not path.is_file():
        print(f"mutate: no such source file: {target}", file=sys.stderr)
        return 2
    orig = path.read_text(encoding="utf-8")
    lines = orig.split("\n")
    sites = [i for i, ln in enumerate(lines) if needle in ln]
    if not sites:
        print(f"mutate: no occurrence of {needle!r} in {target}",
              file=sys.stderr)
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

    def run_tests() -> subprocess.CompletedProcess:
        purge()
        try:
            return subprocess.run(
                [sys.executable, "-m", "pytest", *tests, "-q", "-x",
                 "--no-header", "-p", "no:cacheprovider"],
                capture_output=True, text=True, env=env)
        except OSError as exc:                       # pragma: no cover
            raise HarnessError(f"could not start pytest: {exc}") from exc

    survivors: list[tuple[int, str]] = []
    try:
        # THE BASELINE, before a single byte is mutated. Without it,
        # "every mutant died" is indistinguishable from "the suite could
        # never run", and the second reads as a perfect score.
        base = run_tests()
        if base.returncode != OK:
            reason = ("the tests fail before anything is mutated"
                      if base.returncode == TESTS_FAILED
                      else _why(base.returncode))
            raise HarnessError(
                f"baseline run is not green: {reason}\n{_tail(base)}")

        for i in sites:
            mut = list(lines)
            mut[i] = mut[i].replace(needle, repl, 1)
            path.write_text("\n".join(mut), encoding="utf-8")
            run = run_tests()
            if run.returncode == OK:
                survivors.append((i + 1, lines[i].strip()[:88]))
            elif run.returncode != TESTS_FAILED:
                raise HarnessError(
                    f"{target}:{i + 1} produced no verdict: "
                    f"{_why(run.returncode)}\n{_tail(run)}")
    except HarnessError as exc:
        print(f"mutate: HARNESS ERROR — no result.\n{exc}", file=sys.stderr)
        return 2
    finally:
        # Restore unconditionally, including on KeyboardInterrupt and on
        # SystemExit: leaving a mutated validator behind is worse than
        # any report this tool could produce.
        path.write_text(orig, encoding="utf-8")
        purge()

    print(f"{len(sites)} sites, {len(survivors)} unmeasured")
    for ln, txt in survivors:
        print(f"  SURVIVES  {target}:{ln}  {txt}")
    return 1 if survivors else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
