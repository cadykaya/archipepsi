# Archipepsi — build and test entry points.
#
# `make setup` obtains the pinned Archipelago checkout; everything else
# assumes it exists (or ARCHIPELAGO_ROOT points at one).

AP := $(or $(ARCHIPELAGO_ROOT),.archipelago)
PY := python3

# Mandatory for every AP entry point: importing CommonClient/Generate runs
# ModuleUpdate.update(), which drops into a bare input() without a TTY.
export SKIP_REQUIREMENTS_UPDATE = 1

.PHONY: setup test test-schemas test-bridge test-apworld world-install seed seed-multi host apworld export bridge smoke godot-import godot-test godot-blink godot-integration

setup:
	cd bridge && $(PY) bootstrap.py --root ../.archipelago

test:                          # full suite (schemas + bridge + apworld)
	$(PY) -m pytest -q

test-schemas:
	$(PY) -m pytest bridge/archipepsi_bridge/schemas/test_schemas.py -q

test-bridge:
	$(PY) -m pytest bridge/tests -q

test-apworld:
	$(PY) -m pytest apworld/tests -q

export:
	cd bridge/archipepsi_bridge/schemas && $(PY) export.py generated
	cp bridge/archipepsi_bridge/schemas/generated/constants.gd godot/scripts/autoload/constants.gd

world-install:                 # symlink so edits are live, no copy step
	ln -sfn $(CURDIR)/apworld/archipepsi $(AP)/worlds/archipepsi

seed: world-install            # solo seed, writes to $(AP)/output/
	mkdir -p $(AP)/players_solo
	cp apworld/yaml/solo.yaml $(AP)/players_solo/
	cd $(AP) && $(PY) Generate.py --player_files_path players_solo --outputpath output

seed-multi: world-install      # two-slot multiworld seed (demo YAML + partner)
	mkdir -p $(AP)/players_multi
	cp apworld/yaml/demo.yaml apworld/yaml/partner.yaml $(AP)/players_multi/
	cd $(AP) && $(PY) Generate.py --player_files_path players_multi --outputpath output

host:                          # serves the newest generated seed on 38281
	cd $(AP) && $(PY) MultiServer.py --port 38281 \
	  $$(ls -t output/*.zip | head -1)

apworld: world-install         # official packaging; never hand-roll the zip
	cd $(AP) && $(PY) Launcher.py "Build APWorlds"

bridge:
	cd bridge && $(PY) -m archipepsi_bridge

bridge-mock:
	cd bridge && $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback

smoke:                         # headless full-loop smoke test, mock AP + fallback Epsilon
	cd bridge && $(PY) -m archipepsi_bridge.smoke

replay:                        # re-validate the generation archive (EPSILON_SPEC §14)
	cd bridge && $(PY) -m archipepsi_bridge.replay_archive \
	  $(or $(ARCHIVE),../generation_archive)

GODOT := godot-bin/godot

# A `--script` or `--headless` game run does NOT rescan for new class_name
# scripts, so adding one and going straight to a headless run fails with
# "Identifier not declared in the current scope" for a file that is plainly
# there. Only an import pass rewrites .godot/global_script_class_cache.cfg.
#
# The import is also the only step that compiles EVERY script rather than
# the ones a given entry point happens to reach. `godot-test` guards its own
# run, but its guard cannot see a file the suite does not depend on -- so a
# parse error in the action runner printed CHAMBER TESTS OK with the game
# itself refusing to load. Discard stdout, keep stderr, and fail on a parse
# error here, where the whole tree is in scope.
godot-import:                  # refresh the script class cache
	@err=$$($(GODOT) --headless --path godot --import 2>&1 >/dev/null); \
	if printf '%s\n' "$$err" | grep -qE "Parse Error|Compile Error|Failed to load script"; then \
	  printf '%s\n' "$$err"; \
	  echo "-- the project does not compile; every headless run below is meaningless"; \
	  exit 1; \
	fi

# A SceneTree script whose dependencies fail to compile still RUNS: the
# unresolved calls raise SCRIPT ERROR at runtime, the assertions they were
# supposed to make never execute, and the suite prints OK having tested
# nothing. So a script error fails the target regardless of the exit code.
godot-test: godot-import       # headless builder tests (no bridge needed)
	@out=$$($(GODOT) --headless --path godot --script tests/test_chambers.gd 2>&1); \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep -q "GODOT CHAMBER TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# Invariant I14 (ACCEPTANCE_TESTS 5.7). Boots the real project rather than
# using `--script`: a SceneTree script never instantiates the autoloads, so
# every script touching BridgeClient fails to compile and the suite reports
# zero attempts. Needs no bridge -- it builds its own zones.
godot-blink: godot-import      # blink never leaves the world
	@out=$$($(GODOT) --headless --path godot -- --blink-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT BLINK TESTS OK" || exit 1

# The integration run gets its own throwaway save directory. Sharing
# bridge/saves/ made the run resume the PREVIOUS run's campaign: the zone
# counter climbed forever, "coins were genuinely spent" passed on coins an
# earlier run had spent, and the shop assertion failed at random.
INTEGRATION_SAVES := $(CURDIR)/.integration-saves

godot-integration: godot-import   # full loop through a live mock bridge, fresh state
	rm -rf $(INTEGRATION_SAVES)
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(INTEGRATION_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start (port already serving? see the traceback above)"; \
	  exit 1; }; \
	$(GODOT) --headless --path godot -- --integration-test; \
	STATUS=$$?; kill $$BRIDGE_PID; exit $$STATUS
