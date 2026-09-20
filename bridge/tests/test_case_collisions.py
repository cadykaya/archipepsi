"""No two tracked files may differ only in capitalisation.

**What this cost.** `docs/art/review/glyph_layers_2026-09-10/` held
`WALL_FIELD_3x3.png` (the annotated review sheet, 54061 bytes) and
`wall_field_3x3.png` (the raw render it is made from, 14753 bytes).
On Linux that is two files and everything works. **On the owner's
Windows checkout it is one file**: git writes one, overwrites it with
the other, and then reports whichever lost as modified — permanently,
because the collision comes back on every checkout.

`Update Archipepsi (Windows).bat` refuses to pull over a modified file,
deliberately, so that it can never clobber real work. The result was
that the owner could not update the game at all, and got the same
dialog every single launch, about a file they had never touched.
`git reset --hard` does not fix it.

**The rule this enforces: a path must be unique ignoring case.** A sheet
and the render it is built from need different stems, not different
capitals.

This is not an art-lane rule. It is a repository rule, and it is checked
here rather than in the art lane's own suite because the collision can
be created by any lane, in any directory, and is invisible to everyone
developing on a case-sensitive filesystem — which is everyone here.
"""

from __future__ import annotations

import subprocess
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _tracked() -> list[str]:
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT,
                         capture_output=True, text=True, timeout=60)
    assert out.returncode == 0, f"`git ls-files` failed: {out.stderr}"
    return [p for p in out.stdout.split("\0") if p]


def test_no_two_tracked_paths_differ_only_in_case():
    paths = _tracked()
    # THE GUARD'S OWN GUARD. An empty listing would pass this test while
    # measuring nothing at all -- the failure mode every census here is
    # written against.
    assert len(paths) > 100, (
        f"only {len(paths)} tracked path(s) found; this test cannot see "
        "the repository, so its silence means nothing")

    by_lower: dict[str, list[str]] = defaultdict(list)
    for path in paths:
        by_lower[path.lower()].append(path)
    collisions = {k: v for k, v in by_lower.items() if len(v) > 1}

    assert not collisions, (
        "these paths differ only in capitalisation, so a Windows "
        "checkout cannot hold them both — git writes one, overwrites it "
        "with the other, and reports the loser as modified forever, "
        "which blocks the updater on a file nobody edited:\n"
        + "\n".join(f"  {' / '.join(sorted(v))}" for v in collisions.values())
        + "\nGive them different stems rather than different capitals.")


def test_no_directory_names_differ_only_in_case():
    """The same trap one level up, and worse: a whole folder's contents
    land in whichever spelling won, so the files look *missing* rather
    than modified."""
    dirs = {str(Path(p).parent) for p in _tracked()}
    by_lower: dict[str, list[str]] = defaultdict(list)
    for d in dirs:
        by_lower[d.lower()].append(d)
    collisions = {k: v for k, v in by_lower.items() if len(v) > 1}

    assert not collisions, (
        "these DIRECTORIES differ only in capitalisation; on Windows "
        "their contents merge into one folder and the rest appear to "
        "have vanished:\n"
        + "\n".join(f"  {' / '.join(sorted(v))}" for v in collisions.values()))
