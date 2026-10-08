# Review-build package standard (`archipepsi-build/1`)

How a review build tells a player, and the Archipepsi Launcher, what it is
and how to start it, without anyone writing launcher code for it.

Tooling: `tools/build_metadata/archipepsi_build.py` (Python 3.8+, standard
library only). Examples: `tools/build_metadata/examples/`.

## What a review build already is

The standard keeps the format `tools/crossing_d/package.sh` and
`tools/impact_lab/package.sh` already produce, unchanged:

- One folder, `Archipepsi-<Name>-<sha8>/`, where `<sha8>` is
  `git rev-parse --short=8 HEAD` of the packaged checkout.
- The game executable (`<exe>.exe`, or `<exe>.x86_64` on Linux) and, on
  Windows, its log-window twin `<exe>.console.exe`.
- One `.bat` launcher per play mode, each ending in
  `start "" "%~dp0<exe>.exe" [arguments]`. A launcher that joins a split
  executable compares the joined size in `if not "%JOINED%"=="<bytes>"`.
- `README.txt`, first line `ARCHIPEPSI - <TITLE>   (revision <sha8>)`.
- `SHA256SUMS.txt` (`sha256sum -- *` in the folder) covering every file,
  the whole executable included.
- Delivered as `<folder>-windows.zip`, `<folder>-linux.zip`, and the same
  Windows folder as `<folder>-windows-part1of2.zip` +
  `-part2of2.zip`, with the executable cut into `<exe>.exe.part1` (in part
  1, with everything else) and `<exe>.exe.part2` (alone in part 2).

## What the standard adds: `archipepsi-build.json`

One optional JSON file inside the package folder. Packages without it stay
valid; tools read them as before. With it, nothing needs guessing from
file names.

```json
{
  "schema": "archipepsi-build/1",
  "id": "Archipepsi-Impact-Lab-3337769d",
  "product": "Archipepsi-Impact-Lab",
  "title": "Impact Lab",
  "revision": "3337769d",
  "source": {"branch": "review/impact-lab-g0",
             "commit": "3337769d2394c9cf19a1385d67f6f25c23e67cbc"},
  "built_at": "2026-10-08T11:30:00Z",
  "platform": "windows",
  "executable": "Archipepsi-Impact-Lab.exe",
  "console_executable": "Archipepsi-Impact-Lab.console.exe",
  "modes": [
    {"id": "lab", "label": "Impact Lab", "args": [],
     "launcher": "START HERE - Impact Lab (Windows).bat",
     "description": "The one hall, no enemies."}
  ],
  "recommended_mode": "lab",
  "description": "A small technical fixture, not a designed room: ...",
  "limitations": ["Placeholder looks for the plate and the shutter; ..."],
  "readme": "README.txt",
  "integrity": {
    "sums_file": "SHA256SUMS.txt",
    "executable": {"size": 107544552, "sha256": "0e0066..."},
    "split": {
      "parts": [{"name": "Archipepsi-Impact-Lab.exe.part1", "size": 47319602, "sha256": "..."},
                {"name": "Archipepsi-Impact-Lab.exe.part2", "size": 60224950, "sha256": "..."}],
      "zips": ["Archipepsi-Impact-Lab-3337769d-windows-part1of2.zip",
               "Archipepsi-Impact-Lab-3337769d-windows-part2of2.zip"]
    }
  }
}
```

| Field | Meaning |
|---|---|
| `schema` | Always `archipepsi-build/1`. A reader that does not know the value treats the package as having no manifest. |
| `id` | The folder name. Unique per build. |
| `product` | The folder name without `-<revision>`. Builds of one product are versions of each other. |
| `title` | Human title, e.g. `Crossing D, Readability Review Build`. |
| `revision` | The `<sha8>` in the folder name and README. |
| `source.branch`, `source.commit` | Branch and full 40-character commit packaged, or `null` when unknown. The commit starts with `revision`. |
| `built_at` | UTC time of stamping (informational). |
| `platform` | `windows` or `linux`; each folder has its own manifest. |
| `executable` | The game, relative to the folder. |
| `console_executable` | The `.console.exe` twin, or `null`. |
| `modes[]` | Play modes in display order: `id` (a-z, 0-9, `-`, unique), `label`, `args` (exact arguments after the executable, `[]` for none; game arguments go after Godot's `--`, e.g. `["--", "--empty-yard"]`), `launcher` (the player-facing file that starts this mode in this folder, or `null`), optional `description`. |
| `recommended_mode` | The `id` to play first. Exactly one. |
| `description` | One or two sentences: what this build is. |
| `limitations` | Known limitations, one string each (may be empty). |
| `readme` | `README.txt`, or `null`. |
| `integrity.executable` | Size and sha256 of the whole executable, including when it arrives in parts. |
| `integrity.split` | Only in a split package: each part's name, size and sha256, and the zips it came in. Lets a reader tell a missing, damaged or wrong-build part apart before joining. |
| `integrity.files` | Only when the folder holds files `SHA256SUMS.txt` does not list (the old Crossing D split's join `.bat`): their sha256. |

The manifest is not listed in `SHA256SUMS.txt` (it is written after it)
and is carried only in the part-1 zip of a split set.

## For a new review build

1. Write a spec next to your package script, e.g.
   `tools/<build>/build-spec.json`. Copy one from
   `tools/build_metadata/examples/` and fill in title, executable base
   name, description, limitations, modes (with each mode's `.bat` under
   `launchers.windows`) and `recommended_mode`.
2. Package as today, then stamp the output folder, on the same checkout:

   ```sh
   tools/<build>/package.sh out/
   python3 tools/build_metadata/archipepsi_build.py stamp \
       --spec tools/<build>/build-spec.json out/
   ```

   Stamping writes the manifest into `out/windows/`, `out/windows-split/`
   and `out/linux/` folders and adds it to the matching zips. It records
   the branch and commit from the checkout when HEAD is the packaged
   revision (`--branch` / `--commit` override; a detached HEAD records the
   branch as `null` unless `--branch` is given). It refuses a zip already
   stamped: package again first.
3. Validate exactly what you will hand over:

   ```sh
   python3 tools/build_metadata/archipepsi_build.py validate --strict out/*.zip
   ```

   Every package must say `PASS`. Do not deliver a `FAIL`.

The `.bat` launchers stay the player's way in without the launcher, so a
mode's `args` must match what its `.bat` passes; `validate` checks that.

## What `validate` checks

On ZIPs (grouped into part sets by name) or on unpacked folders:

- Every part of a split set is present and claims the same part count.
- Each ZIP opens, passes its CRC check, holds exactly one top folder, no
  loose files, no absolute or `..` paths, and no file in two ZIPs.
- The manifest's shape (above). Without one: a warning, or an error with
  `--strict`.
- Folder name, README revision, manifest revision and source commit agree;
  no `@REVISION@` or `@SIZE@` left behind.
- The executable is present whole or in consecutive parts; each part's
  size and sha256; the joined size and sha256 (computed without writing
  the join).
- Every file in `SHA256SUMS.txt` exists and matches; every file in the
  folder is covered by it or by `integrity.files` (a warning for packages
  without a manifest).
- Each mode's `.bat` starts the manifest's executable with the mode's
  `args`, and each `.bat`'s joined-size check equals the real size.

Exit code 0 when all pass, 1 when any fails, 2 for a usage error.
`--json` prints the reports (and the manifest, given or inferred) for
tools. `infer` prints the manifest an older package implies.

## For the launcher (reading interface)

A reader should, per imported package folder:

1. If `archipepsi-build.json` exists and its `schema` is
   `archipepsi-build/1`, take title, revision, source, modes (with `args`,
   `label`, `description`), `recommended_mode`, description and
   limitations from it, and check the joined executable against
   `integrity.executable` (and the parts against `integrity.split` before
   joining, for a precise "part 2 is from another build" message).
   Ignore keys it does not know.
2. Otherwise, or if the file is unreadable or has another schema, fall back
   to today's reading: modes from the `.bat` `start` lines, START HERE
   first, title and revision from the README, sizes from the `.bat`, and
   `SHA256SUMS.txt`. `archipepsi_build.py infer` is that fallback written
   down, field for field.
3. `SHA256SUMS.txt` is verified either way.

`archipepsi_build.py validate --json` gives a reader the same answer as a
library call (`validate_package`, `infer_manifest`), if it prefers to
import rather than reimplement.

## Evidence it fits the existing builds

`tools/build_metadata/tests/compat.sh` runs Prod's own, unmodified
`package.sh` from `wip/crossing-d-review`, `review/crossing-d-readability`
and `review/impact-lab-g0` (with Godot's export replaced by random bytes),
validates the legacy output, stamps it with the matching example spec and
validates it again with `--strict`: all nine packages pass both times.

The real two-part `Archipepsi-Impact-Lab-3337769d-windows` download (the
one delivered for the G0 playtest, 107,544,552-byte executable) passes as a
legacy package, and passes `--strict` after a copy of it is stamped; the
`integrity` sizes in the example above are from it.
`python3 -m unittest discover -s tools/build_metadata/tests` covers the
failure cases.
