"""Check that the numbers in the art documents match the built assets.

    python3 tools/blender/check_docs_metrics.py

## Why this exists

`ART_REVIEW.md` is the document the owner reads, and it quotes a triangle
count, a measured size and an anchor for all twenty-eight assets.
`ASSET_INVENTORY.md` quotes the same figures again. Both were transcribed by
hand from the build output.

A transcription error there is worse than a wrong asset: it makes the ledger
the owner is judging from lie, quietly, in the one place nobody would think
to re-check. mario-3's rule applies exactly -- *do not narrate a result you
have not read* -- and the honest form of it is to have a machine read the
result and compare.

So this parses the markdown tables and compares every number against the
`manifest.json` files the build writes. It has already caught nothing, which
is only worth saying because it is the answer that means the documents are
correct rather than the answer that means the check does not work: run
`tools/sabotage_checks.sh` for proof it can fail.
"""

from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine_truth  # noqa: E402

REPO_ROOT = engine_truth.REPO_ROOT
MODEL_DIR = os.path.join(REPO_ROOT, "assets", "models", "batch001")
DOCS = ("docs/art/ART_REVIEW.md", "docs/art/ASSET_INVENTORY.md")

#: `| `asset_id` | 248 | 1.22 × 1.22 × 2.23 | ...`  -- the shape both
#: documents use. The size separator is a multiplication sign, not an x.
ROW = re.compile(
    r"^\|\s*`?(?P<id>[a-z0-9_]+)`?\s*\|"          # id
    r"(?P<middle>[^|]*\|)*?"                        # anything before tris
)
TRIS_AND_SIZE = re.compile(
    r"`(?P<id>[a-z0-9_]+)`[^|]*\|"
    r"(?:[^|]*\|)*?"
    r"\s*(?P<tris>\d{1,5})\s*\|"
    r"\s*(?P<w>\d+\.\d\d)\s*×\s*(?P<d>\d+\.\d\d)\s*×\s*(?P<h>\d+\.\d\d)\s*\|")


def manifests():
    out = {}
    for family in sorted(os.listdir(MODEL_DIR)):
        path = os.path.join(MODEL_DIR, family, "manifest.json")
        if not os.path.exists(path):
            continue
        with open(path, "r", encoding="utf-8") as handle:
            for asset_id, info in json.load(handle).items():
                out[asset_id] = info
    return out


def check():
    built = manifests()
    problems = []
    seen = set()

    for rel in DOCS:
        path = os.path.join(REPO_ROOT, rel)
        with open(path, "r", encoding="utf-8") as handle:
            for number, line in enumerate(handle, 1):
                if not line.lstrip().startswith("|"):
                    continue
                match = TRIS_AND_SIZE.search(line)
                if not match:
                    continue
                asset_id = match.group("id")
                if asset_id not in built:
                    # An ID quoted with metrics that does not exist is worse
                    # than a wrong number: it is a row about nothing.
                    problems.append(
                        "%s:%d quotes metrics for `%s`, which no manifest "
                        "contains. Either the asset was renamed or the row "
                        "describes something that was never built."
                        % (rel, number, asset_id))
                    continue
                seen.add(asset_id)
                info = built[asset_id]
                tris = int(match.group("tris"))
                if tris != info["triangles"]:
                    problems.append(
                        "%s:%d says `%s` is %d triangles; the build says %d."
                        % (rel, number, asset_id, tris, info["triangles"]))
                doc_size = (float(match.group("w")), float(match.group("d")),
                            float(match.group("h")))
                real = tuple(round(v, 2) for v in info["size"])
                if doc_size != real:
                    problems.append(
                        "%s:%d says `%s` measures %.2f x %.2f x %.2f m; the "
                        "build says %.2f x %.2f x %.2f m."
                        % ((rel, number, asset_id) + doc_size + real))

    missing = sorted(set(built) - seen)
    if missing:
        problems.append(
            "%d built asset(s) carry metrics in no document row: %s. The "
            "owner's ledger is incomplete."
            % (len(missing), ", ".join(missing)))
    return problems, len(seen), len(built)


if __name__ == "__main__":
    found, checked, total = check()
    print("check-docs: %d of %d built assets have their metrics quoted and "
          "verified" % (checked, total))
    if found:
        print()
        print("check-docs: FAIL -- %d problem(s):" % len(found))
        for problem in found:
            print("  - %s" % problem)
        raise SystemExit(1)
    print("check-docs: PASS -- every number in the art documents matches the "
          "build.")
