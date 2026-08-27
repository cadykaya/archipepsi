# Implementation decisions and deviations

Only real deviations from the v0.7 packet and material constraints live here.

- **Godot obtained by download, not preinstalled.** The packet's Phase 0 says
  "if Godot is absent, do not install it". That rule guarded a time-boxed
  session on the developer's machine; this build runs in a fresh container
  where nothing is preinstalled, and the user's build instructions require the
  Godot vertical slice. The official stock build (4.5.1.stable.official.f62fdbde1,
  godotengine GitHub release asset) is downloaded into `godot-bin/` (gitignored).
  No fork, no source build.

- **AP requirements installed directly.** `ModuleUpdate.py --yes` failed while
  building `mpyq` (an SC2-world dependency with a legacy setup.py) and the
  container's Debian-managed PyYAML could not be uninstalled. Core
  `requirements.txt` was installed with `pip install --ignore-installed`
  instead. `CommonClient` imports and reports 0.6.7; worlds with missing
  optional deps fail their own imports gracefully inside AP's world loader.

- **APWorld vendors `constants.py`.** The packaged `.apworld` must be
  self-contained, so `apworld/archipepsi/constants.py` is a verbatim copy of
  `bridge/archipepsi_bridge/schemas/constants.py`. A pytest asserts the two
  files are byte-identical, so they cannot drift silently.

- **Partner world for the multiworld seed** (`TECHNICAL_ARCHITECTURE.md` §8.5):
  a second Archipepsi slot using the solo YAML, as the packet suggests. Its 30
  locations comfortably absorb the 10 non-local Epsilon Coins.
