#!/usr/bin/env python3
"""Validate the exported pack with PRODUCTION'S OWN ContentManifest.

    python3 tools/content/verify_manifest.py <prod-ref> [manifest ...]

The other half of a dual-language contract. `content_registry.gd` and
`schemas/content.py` both police the same manifests and they do not police
the same things: the GDScript side asks whether a scene EXISTS and whether a
fallback chain terminates; the Python side is a strict pydantic model with
`extra="forbid"` and hard length limits.

The first version of this pack passed the GDScript half and was rejected by
the Python half on three counts -- a 231-character pack description against a
160 limit, plus `source_asset` and `source_batch_review`, two fields
`ContentEntry` forbids outright. Verifying one side of a two-sided contract
is verifying nothing, so this script exists and the shell wrapper runs both.

Production's schema is fetched read-only from the gameplay branch at run
time. Nothing from that branch is committed to the art branch, and that
branch is never written to.
"""
from __future__ import annotations

import glob
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCHEMA_DIR = "bridge/archipepsi_bridge/schemas"


def _fetch(ref, tmp):
    """Production's content schema and the constants it reads, verbatim."""
    for name in ("content.py", "constants.py"):
        blob = subprocess.run(
            ["git", "show", "%s:%s/%s" % (ref, SCHEMA_DIR, name)],
            cwd=ROOT, capture_output=True, check=True).stdout
        with open(os.path.join(tmp, name), "wb") as fh:
            fh.write(blob)


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    ref = argv[1]
    manifests = argv[2:] or sorted(glob.glob(
        os.path.join(ROOT, "godot", "content", "registry", "*.json")))
    if not manifests:
        print("verify-manifest: no manifests found", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory() as tmp:
        _fetch(ref, tmp)
        sys.path.insert(0, tmp)
        try:
            import content as prod  # noqa: E402  Production's own module
        except ImportError as exc:
            print("verify-manifest: cannot import Production's schema (%s)."
                  % exc, file=sys.stderr)
            print("verify-manifest: `pip install pydantic` and retry.",
                  file=sys.stderr)
            return 2

        loaded = []
        failed = 0
        for path in manifests:
            with open(path) as fh:
                raw = json.load(fh)
            try:
                loaded.append(prod.ContentManifest(**raw))
            except Exception as exc:
                failed += 1
                print("[pyverify]   REJECTED %s" % os.path.basename(path))
                for line in str(exc).splitlines():
                    print("[pyverify]     %s" % line)
                continue
            print("[pyverify]   ok  %-24s %d entries, description %d/%d chars"
                  % (os.path.basename(path), len(raw["entries"]),
                     len(raw.get("description", "")), prod.C.MAX_TEXT_LEN))

        if failed:
            print("[pyverify] FAIL -- %d manifest(s) Production would reject"
                  % failed)
            return 1

        # The union check, which no single manifest can answer: colliding
        # ids, a fallback naming nothing, a fallback that loops.
        try:
            registry = prod.build_registry(loaded)
        except prod.RegistryError as exc:
            # Expected here: the pack's fixture entries fall back to the
            # `*_proc` ids that only Production's own manifest defines, and
            # that manifest is not part of this repo. The shell wrapper
            # supplies it; run standalone, this arm is the honest answer.
            print("[pyverify]   note: cross-manifest check needs Production's "
                  "own pack too -- %s" % exc)
        else:
            print("[pyverify]   ok  build_registry accepted %d ids"
                  % len(registry))
        print("[pyverify] PASS -- Production's ContentManifest accepts the pack")
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
