"""The exported theme pack, against the set it came from and the contract.

    python3 tools/content/verify_theme_export.py

Production's `docs/art-requests/2026-09-12-theme-pack-binding-contract.md`
named a destination and six clauses. Three of them are load-time refusals
in their loader; the ones that are ART'S to keep true are checked here, and
one of them is the reason the descriptor is worth anything at all:

  * **Clause 4 — `sha256_16` is checked on load.** A texture whose digest
    does not match its row is not bound. That makes "the pack Arty built"
    and "the pack the game loaded" the same claim -- and it only holds if
    the digests in the EXPORTED descriptor match the EXPORTED pixels. A
    copy step that dropped a file, or a set rebuilt without re-exporting,
    breaks it silently and the first symptom is a room with no texture.

  * **Verbatim.** The descriptor is copied byte for byte and the `texture`
    field is not rewritten, because it is already relative in the shape
    `res://content/theme/...` needs.

  * **The sidecars are the engine's.** Every `.png` has a `.import` beside
    it, with mipmaps on and lossless compression. They are produced by
    running the real importer (`tools/import_godot_content.sh`); this only
    checks the two settings the contract names and that the sidecar points
    at the file it sits beside.

Filtering and repeat are NOT checked, and that is deliberate: in Godot 4
they are sampler state on the material (`BaseMaterial3D.texture_filter`,
`texture_repeat`), not importer parameters. There is nothing in a sidecar
to set, and asserting a key that cannot exist would be a check that always
fails or a check that lies. The binder sets them.
"""
import hashlib
import json
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(REPO, "assets", "textures", "theme")
DST = os.path.join(REPO, "godot", "content", "theme")
RES = "res://content/theme/"


def digest(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def main():
    problems = []
    if not os.path.isdir(DST):
        print("verify-theme-export: FAIL -- nothing at %s. Run "
              "tools/export_content_pack.py." % DST, file=sys.stderr)
        return 1

    want = sorted(n for n in os.listdir(SRC)
                  if n.endswith(".png") or n == "THEME_PACK.json")
    have = sorted(n for n in os.listdir(DST) if not n.endswith(".import"))

    for name in want:
        src, dst = os.path.join(SRC, name), os.path.join(DST, name)
        if not os.path.exists(dst):
            problems.append("%s was never exported" % name)
        elif digest(src) != digest(dst):
            problems.append("%s differs from the set it was copied from; "
                            "the export is stale" % name)
    for name in have:
        if name not in want:
            problems.append("%s is in the pack and not in the set. A file "
                            "nothing points at still loads." % name)

    # Clause 4, against the EXPORTED bytes.
    descriptor = os.path.join(DST, "THEME_PACK.json")
    if os.path.exists(descriptor):
        with open(descriptor, "r", encoding="utf-8") as handle:
            described = json.load(handle)
        for key, row in sorted(described.get("textures", {}).items()):
            rel = row["texture"]
            if not rel.startswith("theme/"):
                problems.append(
                    "%s names '%s'. The contract resolves it as "
                    "res://content/theme/..., so it has to stay relative "
                    "and unrewritten." % (key, rel))
                continue
            path = os.path.join(DST, os.path.basename(rel))
            if not os.path.exists(path):
                problems.append("%s names %s, which is not in the pack"
                                % (key, rel))
                continue
            if digest(path)[:16] != row["sha256_16"]:
                problems.append(
                    "%s: the exported texture's digest is %s and the "
                    "descriptor says %s. Clause 4 refuses it at load."
                    % (key, digest(path)[:16], row["sha256_16"]))

    # The sidecars, and only the settings the contract names.
    for name in want:
        if not name.endswith(".png"):
            continue
        sidecar = os.path.join(DST, name + ".import")
        if not os.path.exists(sidecar):
            problems.append("%s has no .import beside it; Godot will "
                            "reimport it and the pack is not reproducible"
                            % name)
            continue
        with open(sidecar, "r", encoding="utf-8") as handle:
            text = handle.read()
        if "mipmaps/generate=true" not in text:
            problems.append("%s imports without mipmaps; a 128 px tiling "
                            "texture on a 90 m deck shimmers" % name)
        if "compress/mode=0" not in text:
            problems.append("%s is not imported losslessly; the digest in "
                            "the descriptor is of the source pixels" % name)
        if ('source_file="%s%s"' % (RES, name)) not in text:
            problems.append("%s's sidecar points somewhere else" % name)

    for problem in problems:
        print("verify-theme-export: FAIL -- %s" % problem, file=sys.stderr)
    if problems:
        return 1
    pngs = [n for n in want if n.endswith(".png")]
    print("verify-theme-export: %d texture(s) and the descriptor, byte for "
          "byte, every digest matching and every sidecar the engine's."
          % len(pngs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
