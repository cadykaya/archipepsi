#!/usr/bin/env python3
"""Check a diagnostic-build package against its own `archipepsi-build.json`.

Read by `test.sh` step 3. It asserts what a reader of the manifest -- the
Archipepsi Launcher among them -- is entitled to assume: the schema is the
one it knows, the ids and revision agree with the folder name, every mode
names a launcher that exists and starts the executable the manifest
names, the recommended mode is one of them, the integrity figures are the
executable's real size and digest, and the limitations say what this build
is not.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys


def main(argv: list[str]) -> int:
    pkg = pathlib.Path(argv[1]).resolve()
    m = json.loads((pkg / "archipepsi-build.json").read_text(encoding="utf-8"))
    bad: list[str] = []

    def want(cond: bool, why: str) -> None:
        if not cond:
            bad.append(why)

    want(m.get("schema") == "archipepsi-build/1",
         f"schema is {m.get('schema')!r}, not archipepsi-build/1")
    want(m.get("id") == pkg.name, f"id {m.get('id')!r} is not the folder name")
    want(m.get("platform") == "windows", "platform is not windows")
    want(isinstance(m.get("revision"), str)
         and pkg.name.endswith("-" + m.get("revision", "")),
         "revision does not end the folder name")
    want(m.get("product") and pkg.name == f"{m['product']}-{m['revision']}",
         "product + revision is not the folder name")
    commit = (m.get("source") or {}).get("commit") or ""
    want(re.fullmatch(r"[0-9a-f]{40}", commit) is not None,
         "source.commit is not a full commit id")
    want(commit.startswith(m.get("revision", "x")),
         "source.commit does not start with the revision")

    exe = pkg / (m.get("executable") or "")
    want(exe.is_file(), f"executable {m.get('executable')!r} is not in the folder")
    console = m.get("console_executable")
    want(console is None or (pkg / console).is_file(),
         f"console_executable {console!r} is not in the folder")

    ids = [mode.get("id") for mode in m.get("modes", [])]
    want(len(ids) >= 1, "no modes")
    want(len(ids) == len(set(ids)), "two modes share an id")
    for mode in m.get("modes", []):
        want(re.fullmatch(r"[a-z0-9-]+", mode.get("id") or "") is not None,
             f"mode id {mode.get('id')!r} is not a-z 0-9 -")
        want(isinstance(mode.get("args"), list), f"{mode.get('id')}: args is not a list")
        bat = mode.get("launcher")
        want(bat and (pkg / bat).is_file(),
             f"{mode.get('id')}: launcher {bat!r} is not in the folder")
        if bat and (pkg / bat).is_file():
            text = (pkg / bat).read_text(encoding="utf-8", errors="replace")
            # The launcher must start the executable the manifest names:
            # a .bat that started something else would make every other
            # field a description of the wrong program.
            want(m["executable"] in text or (console or "\0") in text,
                 f"{bat} does not start the manifest's executable")
    want(m.get("recommended_mode") in ids,
         f"recommended_mode {m.get('recommended_mode')!r} is not one of {ids}")

    integrity = m.get("integrity") or {}
    want(integrity.get("sums_file") == "SHA256SUMS.txt", "integrity.sums_file is wrong")
    rec = integrity.get("executable") or {}
    if exe.is_file():
        h = hashlib.sha256()
        with exe.open("rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        want(rec.get("size") == exe.stat().st_size,
             f"integrity size {rec.get('size')} is not the executable's "
             f"{exe.stat().st_size}")
        want(rec.get("sha256") == h.hexdigest(),
             "integrity sha256 is not the executable's digest")
    want("files" not in integrity,
         "integrity.files is present, so SHA256SUMS.txt misses something")

    readme = m.get("readme")
    want(readme and (pkg / readme).is_file(), "readme is not in the folder")
    limits = m.get("limitations") or []
    want(any("NOT a public release" in s or "not a release" in s.lower()
             for s in limits),
         "limitations do not say this is not a release")
    want(any("Archipelago" in s and "NOT included" in s for s in limits),
         "limitations do not say the real Archipelago path is not included")
    want(any("native Windows" in s for s in limits),
         "limitations do not say native Windows is untested")

    for why in bad:
        print("  manifest:", why, file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
