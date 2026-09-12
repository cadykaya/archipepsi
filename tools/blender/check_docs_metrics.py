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
MODEL_DIR = os.path.join(REPO_ROOT, "assets", "models")
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

#: The prose form ART_REVIEW.md uses in its per-concept rows:
#:     | Metrics | 284 tris · 1.40 × 1.28 × 2.63 m · 249 px at 6 m |
#:
#: Added after a sabotage run found that changing the review document's
#: table shape had quietly taken it out of this checker's scope entirely --
#: the checker still reported "29 of 29 verified" because it was finding all
#: 29 in the inventory and none at all in the ledger the owner actually
#: reads. A checker whose coverage can silently shrink to zero while its
#: pass line stays true is the same failure as a filter that cannot express
#: failure.
INLINE = re.compile(
    r"(?P<tris>\d{1,5})\s*tris\s*·\s*"
    r"(?P<w>\d+\.\d\d)\s*×\s*(?P<d>\d+\.\d\d)\s*×\s*(?P<h>\d+\.\d\d)\s*m")
#: ART_REVIEW's headings carry no bare ID -- they reference sheets like
#: `A_epsilon_b_core.png`, which CONTAINS the asset id rather than being it.
#: So the association is by substring against the real manifest keys, and
#: the nearest preceding match owns the metrics row beneath it.
def _id_in(line, built):
    hit, at = None, -1
    for asset_id in built:
        found = line.find(asset_id)
        if found > at:
            hit, at = asset_id, found
    return hit


def manifests():
    """Every manifest in every batch.

    This walked `batch001` only, and the first batch002 asset it met was
    reported as "quotes metrics for an asset no manifest contains" -- the
    checker saying the document was wrong when the checker was the thing
    that had not moved. A verifier that has to be edited whenever the work
    grows is a verifier that will one day be edited into agreeing.
    """
    out = {}
    for batch in sorted(os.listdir(MODEL_DIR)):
        batch_dir = os.path.join(MODEL_DIR, batch)
        if not os.path.isdir(batch_dir):
            continue
        for family in sorted(os.listdir(batch_dir)):
            path = os.path.join(batch_dir, family, "manifest.json")
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
    inline_hits = {}
    table_hits = {}

    for rel in DOCS:
        path = os.path.join(REPO_ROOT, rel)
        with open(path, "r", encoding="utf-8") as handle:
            lines = handle.readlines()
        recent = None
        for number, line in enumerate(lines, 1):
            named = _id_in(line, built)
            if named:
                recent = named
            if not line.lstrip().startswith("|"):
                continue
            inline = INLINE.search(line)
            if inline and recent:
                info = built[recent]
                tris = int(inline.group("tris"))
                if tris != info["triangles"]:
                    problems.append(
                        "%s:%d says `%s` is %d triangles; the build says %d."
                        % (rel, number, recent, tris, info["triangles"]))
                doc_size = (float(inline.group("w")), float(inline.group("d")),
                            float(inline.group("h")))
                real = tuple(round(v, 2) for v in info["size"])
                if doc_size != real:
                    problems.append(
                        "%s:%d says `%s` measures %.2f x %.2f x %.2f m; the "
                        "build says %.2f x %.2f x %.2f m."
                        % ((rel, number, recent) + doc_size + real))
                seen.add(recent)
                inline_hits[rel] = inline_hits.get(rel, 0) + 1
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
            table_hits[rel] = table_hits.get(rel, 0) + 1
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

    # Every document this checks must actually contribute rows. A document
    # whose table shape changed can silently leave this checker's scope
    # while the pass line stays true, which is how ART_REVIEW.md spent a
    # revision unchecked.
    for rel in DOCS:
        if not inline_hits.get(rel) and not table_hits.get(rel):
            problems.append(
                "%s contributed NO checkable metrics. Either its format "
                "changed or it stopped quoting any -- and a checker that "
                "silently covers one document less still prints PASS."
                % rel)

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
