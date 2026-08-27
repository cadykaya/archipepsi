# Archipepsi — build and test entry points.
#
# `make setup` obtains the pinned Archipelago checkout; everything else
# assumes it exists (or ARCHIPELAGO_ROOT points at one).

AP := $(or $(ARCHIPELAGO_ROOT),.archipelago)
PY := python3

# Mandatory for every AP entry point: importing CommonClient/Generate runs
# ModuleUpdate.update(), which drops into a bare input() without a TTY.
export SKIP_REQUIREMENTS_UPDATE = 1

.PHONY: setup test test-schemas test-bridge test-apworld world-install seed seed-multi host apworld export bridge smoke

setup:
	cd bridge && $(PY) bootstrap.py --root ../.archipelago

test: test-schemas test-bridge test-apworld

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

smoke:                         # headless full-loop smoke test, mock AP + fallback Epsilon
	cd bridge && $(PY) -m archipepsi_bridge.smoke
