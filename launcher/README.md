# Archipepsi Development Launcher

A small Windows program that keeps a library of Archipepsi review builds,
installs them from the ZIPs they are delivered in, and starts the mode you
pick. It is separate from the game: it never changes a build's files or
the game's mechanics, and it has no accounts, telemetry, server or
downloads.

## Use it

1. Double-click `ArchipepsiLauncher.exe`. (Windows may warn about an
   unsigned program: More info, then Run anyway.)
2. **Install build from ZIP...** and choose the build's ZIP. For a
   two-part build, choosing either part is enough when both sit in the same
   folder; otherwise choose both. You can also drop ZIPs onto the
   launcher's icon.
3. Pick the build on the left, pick a mode under **Play**, press **Play**
   (or double-click the build). Tick *with a log window* to start the
   console version when something goes wrong.

What the install does:
- unpacks the ZIP(s) into the library;
- joins a two-part executable and checks it against the build's
  `SHA256SUMS.txt` and the size its own launchers expect, refusing a
  damaged or mismatched download;
- reads the play modes from the build's own `.bat` launchers (for example
  Crossing D's *NO ENEMIES* and *with enemies*), the "START HERE" one first.

What it refuses, leaving your library exactly as it was (each says what
to do in plain words, with the technical reason underneath):
- a ZIP that did not finish downloading, is damaged inside, is
  password-protected or uses a compression the launcher cannot open;
- a two-part build with a part missing, or parts from different builds
  (other builds chosen at the same time still install);
- a ZIP that would put files outside its folder or use names Windows
  cannot create, and a checksum list pointing outside the build;
- an install that would not fit on the disk (checked first, on the real
  unpacked size).

If the launcher is closed or the PC stops mid-install, the next start
discards the unfinished install; a build that was fully in place but not
yet listed is checked and listed again. Only one launcher window runs at a
time, so two cannot overwrite each other's list.

Updates and replacements:
- a new revision of a build is installed beside the earlier ones, which
  stay playable; the list marks the latest installed one;
- installing the same revision again changes nothing if it is identical;
  if its content differs, the new copy is kept beside the old one as
  "(2)";
- a copy whose game file went missing or was damaged (it is re-checked
  before playing whenever the file changed) is marked, cannot be started,
  and is repaired by installing its ZIP again;
- nothing is deleted unless you press **Remove this build...** (your
  original ZIPs are never touched); a build that is running cannot be
  removed or replaced, and nothing changes until you close it.

The library lives in `%LOCALAPPDATA%\ArchipepsiLauncher` (**Open library
folder**). Set `ARCHIPEPSI_LAUNCHER_HOME` to put it elsewhere.

## Package format it reads

The review-build format of `tools/crossing_d/package.sh` and
`tools/impact_lab/package.sh`: a ZIP holding one folder
`Archipepsi-<Name>-<revision>/` with the game `.exe` (+ `.console.exe`),
`.bat` launchers ending in `start "" "%~dp0<game>.exe" [args]`,
`README.txt` (title and revision on its first line) and `SHA256SUMS.txt`;
or the same folder in `...-partNofM.zip` parts with the executable cut
into `.exe.part1`, `.exe.part2`. A future build in that format needs no
launcher change.

## Develop

    python -m unittest discover -s tests -t .     # stdlib only, 43 tests
    python -m archipepsi_launcher                  # run from source

`tests/fixtures/` holds packages made by the review builds' own
`package.sh` scripts with a tiny fake game (`tests/make_fixtures.sh`).

Build the executable on Windows with `build_windows.bat`, or on Linux with
`build_with_wine.sh` (Windows Python under Wine; how the delivered
executable was made).
