# The Windows diagnostic build

A private, self-contained Windows build of the **existing prototype-scale
campaign**, for Skyiah's hands-on review. It is not a release, not a
release candidate, and it changes nothing about how the game plays.

It answers §4 item 2 of `reports/release-readiness-audit.md` only as far
as a *diagnostic* build goes: a player (of one) can run the game without
installing Godot or Python, their save survives replacing the build, and
the whole thing is rebuilt by one script from a commit.

```sh
tools/diagnostic_build/build.sh out/              # build
tools/diagnostic_build/test.sh out/Archipepsi-Diagnostic-Campaign-<sha8>/ \
    /path/to/wine                                 # check what it claims
```

Nothing outside `tools/diagnostic_build/` is touched. The export preset
is written into a staged copy of `godot/`, never into the project: the
game line carries no `export_presets.cfg` and each review branch carries
its own, so a preset committed here would collide with all of them.

## What the build contains

```
Archipepsi-Diagnostic-Campaign-<sha8>/
  Archipepsi-Diagnostic.exe          the starter (windowed)
  Archipepsi-Diagnostic.console.exe  the starter, with a log window
  START HERE - Mock Campaign (Windows).bat
  With log window - Mock Campaign (Windows).bat
  game/Archipepsi.exe                the Godot 4.5.1 Windows export
  runtime/python/                    CPython 3.12.10 embeddable + pydantic,
                                     pydantic-core, websockets 13.1 and deps
  runtime/bridge/archipepsi_bridge/  the bridge, as committed
  runtime/godot/content/registry/    the room shells the bridge reads
  runtime/docs/baselines/            the baseline its banner reads
  README.txt  BUILD-INFO.txt  THIRD_PARTY_NOTICES.txt
  SHA256SUMS.txt  archipepsi-build.json
```

About 50 MB zipped, 136 MB unpacked.

### The starter is the whole of the new behaviour

`starter/archipepsi_starter.c` is plain Win32, built twice (windowed and
console). It does what a developer does by hand in a checkout:

1. refuses to start if something already listens on the bridge port, and
   says why — otherwise the game would quietly play against a checkout's
   bridge and *its* saves;
2. starts `runtime\python\python.exe -m archipepsi_bridge --ap=mock
   --epsilon=fallback --mock-scale=prototype --save-dir <per-user>` —
   the checkout's `Start Archipepsi (Windows).bat` arguments plus the
   save folder;
3. waits for the bridge to accept connections (and reports the bridge's
   log if it dies first);
4. starts the game, passing its own arguments through to it;
5. stops the bridge when the game exits.

Both processes go in one job object with `KILL_ON_JOB_CLOSE`, so neither
can outlive the starter as an orphan.

**No gameplay code, no bridge code and no CI file was changed to make
this work.** The bridge already takes `--save-dir`, already defaults to
the deterministic fallback Epsilon, and already prints where the save is.
That is why nothing here needed Prod.

### Saves, deliberately outside the installation

| What | Where |
|---|---|
| The campaign | `%LOCALAPPDATA%\Archipepsi\Diagnostic Campaign\saves` |
| Bridge and starter logs | `…\Diagnostic Campaign\logs` |
| Settings, loadout, "seen" flags | `%APPDATA%\Godot\app_userdata\Archipepsi` (Godot's `user://`) |

`ARCHIPEPSI_DIAGNOSTIC_HOME` moves the first two; `test.sh` uses it so a
test run cannot touch a real campaign. The second row is Godot's own
`user://` and is *shared with a checkout's runs* — three small config
files (`settings.cfg`, `loadout.cfg`, `equipment_seen.cfg`), no campaign
state. Step 5 of `test.sh` proves the package folder is byte-identical
after a full campaign, so replacing the build never costs a save.

### The real Archipelago path is deliberately absent

The bundled bridge runs `--ap=mock`, so `_connect_ap` routes a connect
intent to the mock backend whatever address the game sends: a server
address typed in the game reaches the offline fixture campaign, not a
server. That is stated in `README.txt`, in `archipepsi-build.json`'s
`limitations`, and checked by `check_manifest.py`.

Bundling the real path is a bigger job than this build, and it is not
only packaging: `ap_client.ensure_ap_importable` imports `CommonClient`
from an Archipelago **source checkout** (`.archipelago/`), and
Archipelago's own requirements come with it. Shipping that means either
bundling an Archipelago checkout inside the build or asking the player to
install Archipelago and pointing `ARCHIPELAGO_ROOT` at it. It is
untested in this form and is out of this build's scope.

## Reproducibility

- The build packages `git archive HEAD`, never the working tree, and says
  so when the tree is dirty. The `<sha8>` in the folder name is the
  commit inside it.
- Every download is pinned by URL and digest in `toolchain.lock`, and the
  wheels by hash in `requirements-windows.txt` (`pip --require-hashes`).
  A digest that does not match stops the build.
- The pinned Godot build is asserted (`4.5.1.stable.official.f62fdbde1`,
  the build `project.godot` names) before anything is exported.
- The bridge port is read out of `schemas/constants.py` and compared with
  GDScript's `BRIDGE_PORT`; the starter is compiled with that number.
- Every file is stamped with the packaged commit's own date (after the
  last of them is written: writing a file also changes its directory's
  mtime, and the top folder's zip entry is what made two builds differ
  by two bytes before this was fixed), the starter links with
  `--no-insert-timestamp`, and each zip is built from a sorted file
  list. Two independent builds of one commit on one toolchain produce
  byte-identical zips, which is checked by building twice and comparing
  digests.
- `BUILD-INFO.txt` records the commit, the Godot build, the wheels, the
  compiler and the lock digests.

## What the launcher sees

The package carries `archipepsi-build.json` to the `archipepsi-build/1`
standard (draft PR #25), so the Archipepsi Launcher (draft PR #24) reads
it with no launcher change — and the `.bat` files, `README.txt` title line
and `SHA256SUMS.txt` the launcher falls back to are present and agree
with it. The launcher's own "log window" toggle starts
`Archipepsi-Diagnostic.console.exe`, so it shows one mode rather than
two; a double-clicker gets the second `.bat`.

## Known limitations

- **Built on Linux; exercised under Wine 11, never on native Windows.**
  Wine is not Windows. The first native run is Skyiah's.
  (Wine 9, which Ubuntu 24.04 ships, does not implement
  `KERNEL32.CopyFile2`, which Python 3.12's `shutil.copy2` calls — and
  `store.py` copies the save to `.bak` through it. So the bridge aborts
  on its first save under Wine 9 and the campaign cannot be tested there.
  Wine 10 or newer is needed. `CopyFile2` exists on Windows 8 and later,
  so this is a Wine gap, not a build defect.)
- Not code-signed: SmartScreen may warn on first run.
- The prototype-scale campaign exactly as it is: no `--candidate`
  profile, no review rooms, no music, no schema or gameplay change.
- The bridge banner reports its commit as `unknown`, because a packaged
  bridge has no `.git`. `BUILD-INFO.txt` and `README.txt` carry it.
- Windows only. A Linux build would be a second preset and is not needed
  for this review.

## The two-part delivery

`build.sh` also writes `-windows-part1of2.zip` and `-part2of2.zip`, the
same folder with `game/Archipepsi.exe` cut in two (at a fifth, so both
zips land near 26 MB rather than 37 and 16). The starter joins the parts
on its first run, checks the result against `game/Archipepsi.exe.size`,
and deletes them; `archipepsi-build.json` records each part's size and
digest and the whole file's, under `integrity.game`. This exists because
not every channel the build travels carries a 50 MB file — the review
builds split for the same reason — and because the project's file
transfer allows 30 MB per file.

Note that `Archipepsi.console.exe` is a 184 kB wrapper that launches
`Archipepsi.exe`, so the console starter needs the joined file too. The
first version of the join keyed on "the executable I am about to start",
which the console build already had, so it skipped the join and started a
wrapper with nothing behind it. `test.sh` step 10 is there because that
happened.
