# Launcher hardening, 0.2.0: audit and evidence

Launcher 0.1.0 (the MVP, `d48a51b2`) was run against 14 scripted failure
cases before any change. 11 of them failed: a crash, a silent wrong
result, or lost data. Reading the code turned up five more problems,
marked † below. 0.2.0 fixes all of them, and every fix has a test in
`tests/test_hardening.py` except the pane divider, which is checked by
eye.

**Not verified on native Windows.** The tests were run under Linux Python
and under Windows Python 3.12 inside Wine, and the executable was run under
Wine. Native Windows behaviour has not been checked for any of these 0.2.0
changes. Two Windows-specific behaviours are simulated rather than
observed: renaming a folder while the game inside it is running, and the
lock that keeps a second launcher window from opening.

## Before and after

| Case | 0.1.0 (MVP) | 0.2.0 |
|---|---|---|
| ZIP cut short by an unfinished download | refused | refused, in plain words |
| ZIP with a damaged file inside (bad CRC) | refused, technical wording | refused: "is damaged ... download it again" |
| Password-protected ZIP | crash: unhandled `RuntimeError` | refused |
| ZIP using a compression it cannot read (e.g. Deflate64) | crash: unhandled `NotImplementedError` | refused |
| Two-part build with a part missing, chosen together with a good ZIP | the whole selection was rejected | the good build installs, the missing part is named |
| Parts from two different builds | the whole selection was rejected | each one is reported as missing its partner |
| A part from another download under the same name | refused by checksum | refused by checksum, in plain words |
| Entry named `CON`, `a:b`, ending in a dot, etc. | installed (Windows cannot create these) | refused, nothing installed |
| `SHA256SUMS.txt` naming `../../outside.txt` | **read a file outside the build** and installed | refused |
| Free-space check | compressed size × 3 (a highly compressed ZIP could pass and then fill the disk) | real unpacked size × 2 + 64 MB |
| Disk full while joining the parts | crash: unhandled `OSError` | refused, "the disk ran out of space", library unchanged |
| Writing `library.json` fails mid-install † | build folder left behind, not listed | install rolled back, library unchanged |
| Launcher killed after the build was moved in, before it was listed † | build invisible, its disk space lost | re-checked and re-listed at the next start |
| `library.json` corrupted | every build disappeared from the list | restored from `library.json.bak`, or rebuilt from the build folders |
| Leftover `staging/` after a crash | never cleaned (here, 117 MB) | cleared at the next start |
| Installed game damaged, same size | reported as fine; reinstalling said "identical, nothing changed" | re-hashed whenever the file has changed: shown as damaged, cannot be played, reinstalling repairs it |
| A folder in `builds/` that the list does not know about | **deleted** when a build of the same name was installed | moved to `unrecognised/`, never deleted |
| Removing or replacing a build while it is running † | index entry dropped, folder half-deleted | refused, "close the game", nothing changed |
| Two launcher windows open at once † | each could overwrite the other's list | the second one says the launcher is already open |
| GUI pane divider † | snapped back every 100 ms, so it could not be moved | moves freely |

The scenario script printed the 0.1.0 and 0.2.0 columns against the real
fixtures. Its output is in the PR description.

## How an install stays safe now

1. The real unpacked size is checked against free space first.
2. The ZIP(s) are unpacked into `staging/`. Each entry is checked first:
   no absolute paths, no `..`, no names Windows cannot create, no
   encryption, only supported compression. Any failure stops the install
   before a byte is written.
3. Parts are joined and checked against `SHA256SUMS.txt` and the size the
   build's own launchers expect. Every name in the checksum list must
   stay inside the build.
4. The verified folder is renamed into `builds/` (one rename, on one
   drive), and only then recorded. If recording fails, the rename is
   undone.
5. When a damaged copy is being replaced, it is renamed aside first. On
   Windows that rename fails while the game is running, which leaves
   everything unchanged. The old copy is deleted last.
6. At start-up the launcher takes its lock, then clears `staging/` and
   any half-renamed leftovers, and re-adopts any verified, unlisted build.

## Evidence

- `python -m unittest discover -s tests -t .` passes all 43 tests (15 from
  the MVP, 28 new) under Linux Python 3.13 and Windows Python 3.12.10
  under Wine.
- The executable under Wine:
  - Given a good two-part build and a truncated ZIP together, it
    installed the good one and named the truncated one, with a plain
    message and its details.
  - A second copy said the launcher is already open.
  - With a 400 MB two-part build, the launcher was killed 4 s into the
    install, leaving 117 MB in `staging/`. The next start cleared it, and
    the library was unchanged.
  - A byte flipped in an installed game was shown as "damaged: reinstall"
    and Play was disabled.

## Compatibility with the packaging standard (PR #25)

Nothing here conflicts with the optional `archipepsi-build.json`
(`archipepsi-build/1`). Its file is unpacked and kept like any other.
`SHA256SUMS.txt` is still checked. Reading it later would mean:

- in `describe()`, preferring its title, revision, modes and recommended
  mode over the `.bat`/README reading;
- checking its per-part checksums before joining, so a bad part can be
  named ("part 2 is damaged") rather than only the joined game;
- running its names through `_unsafe_name` like the checksum list.

That is left for when the standard is agreed.

## 0.2.0-rc1

- **Upgrade from 0.1.0:** at first start, every build recorded by 0.1.0
  is checked in full once. The launcher then says whether they are all
  intact. A damaged one is reported and kept, never dropped.
  `tests/test_release.py` runs this against `fixtures/library-0.1.0.zip`,
  a real library written by 0.1.0.
- **Newer formats:** Impact Relay G1 and its art candidate (two launchers,
  heavy-hit mode) install with the right modes.
- **Layout:** the build list could be squeezed to nothing when the window
  opened slowly (seen under Wine when opening with a ZIP). The divider is
  now placed once the window is laid out.
- **Real build (under Wine):** Skyiah's Impact Lab `3337769d` two-part
  download installed from part 1 alone in 2–3 s and joined to `0e006640…`.
  With the other part missing it was refused, and with an altered part 2
  it was refused by checksum. Play started the real game. It stopped at
  Godot's video-driver warning, because the container has no GPU.
- 50 tests pass under Linux Python and Windows Python (Wine).
