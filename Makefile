# Archipepsi — build and test entry points.
#
# `make setup` obtains the pinned Archipelago checkout; everything else
# assumes it exists (or ARCHIPELAGO_ROOT points at one).

AP := $(or $(ARCHIPELAGO_ROOT),.archipelago)
PY := python3

# Mandatory for every AP entry point: importing CommonClient/Generate runs
# ModuleUpdate.update(), which drops into a bare input() without a TTY.
export SKIP_REQUIREMENTS_UPDATE = 1

.PHONY: apworld bridge doctor godot-graphs zone-fixtures latched-route-fixture transport-fixture reversible-fixture candidate-fixture zone-sample dual-real dual-real-soak export godot-activity godot-affordance godot-blink godot-boot godot-content godot-hud godot-import godot-consumable-live godot-consumable-restart godot-encounter godot-signal-graph godot-signal-verbs godot-latched-route godot-latched-route-live godot-lever-route-live godot-held-route godot-counterfire-hosted godot-passing-hosted godot-menu-shell menu-shell-shots godot-equipment-face equipment-face-shots equipment-fixture godot-minimap minimap-shots map-fixture godot-map-face map-face-shots godot-journal-face journal-face-shots journal-fixture lever-route-fixture held-route-fixture latched-route-play godot-theme-pack theme-pack-shots godot-carry godot-transport godot-transport-live godot-reversible godot-reversible-live godot-candidate-live godot-resume-live candidate-shots godot-integration godot-integration-quiet godot-integration-variant-live godot-return-journey godot-lab godot-legible godot-movement godot-physics godot-playtest3a godot-reload godot-room godot-room-contract godot-rules godot-stats godot-rail-carrier godot-rail-junction godot-passing-platforms godot-counterfire godot-mass-class godot-unweighted godot-target-facing godot-rail-zone godot-rail-gantry godot-zone-state godot-roster godot-actuator godot-constraints godot-archive godot-test godot-traverse godot-verbs godot-verb-runtime godot-status-family godot-status-kinetic godot-combat-fairness godot-flyer-room godot-resume godot-zone-audit host mutate-bridge notices physics-vectors rules-fixture seed seed-multi setup smoke test test-apworld test-bridge test-schemas railway-shots verbs-fixture version world-install zone-shots

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

# EVERY COPY OF THE CONSTANTS, FROM THE ONE SOURCE. `constants.py` is
# the binding file; the GDScript is generated from it and the APWorld
# vendors it verbatim, because an APWorld ships to Archipelago without
# this repository around it. The vendored copy is HERE rather than left
# to be remembered: it drifted once already -- the enemy stat table
# landed in the source and not in the copy, and `make test` carried the
# failure for several commits while `make test-bridge`, which does not
# run the APWorld suite, stayed green.
export:
	cd bridge/archipepsi_bridge/schemas && $(PY) export.py generated
	cp bridge/archipepsi_bridge/schemas/generated/constants.gd godot/scripts/autoload/constants.gd
	cp bridge/archipepsi_bridge/schemas/constants.py apworld/archipepsi/constants.py

# The rule suite's snapshot is a real fold, and this is the fold that
# makes it. Regenerate rather than editing the JSON.
rules-fixture:
	$(PY) bridge/archipepsi_bridge/fixtures/make_rules_snapshot.py

verbs-fixture:
	$(PY) bridge/archipepsi_bridge/fixtures/make_verbs_snapshot.py

# H-INVENTORY's snapshots are real `CampaignSnapshot`s, so the face is
# tested against the inventory Dess's projection actually emits.
equipment-fixture:
	$(PY) bridge/archipepsi_bridge/fixtures/make_equipment_snapshot.py

# The maps' state is Dess's `map_view` of the candidate Zone after real
# transitions, so the minimap is tested against the map the bridge sends.
map-fixture:
	$(PY) bridge/archipepsi_bridge/fixtures/make_map_snapshot.py

# The journal's snapshots: the model's own CampaignSnapshot over the
# candidate Zone after real transitions (H-JOURNAL).
journal-fixture:
	$(PY) bridge/archipepsi_bridge/fixtures/make_journal_snapshot.py

# The PRE-ART playtest baseline. Regenerate DELIBERATELY and in its own
# commit: retaking it means the playtest before it and the playtest after
# it are no longer measuring the same game. See docs/PLAYTEST_BASELINE.md.
baseline:
	$(PY) bridge/archipepsi_bridge/fixtures/make_playtest_baseline.py

# The launcher's own guard and report, from a terminal. Same code the
# Windows launcher runs, so a green `playtest-check` here means the
# launcher will start.
playtest-check:
	cd bridge && $(PY) -m archipepsi_bridge.playtest check

playtest-report:
	cd bridge && $(PY) -m archipepsi_bridge.playtest report \
	  --save-dir $(or $(SAVES),../playtest-2.5)

# Two Archipepsi slots in ONE real multiworld: a real MultiServer, two
# bridges, two saves, checking each other's locations. Needs a generated
# seed (`make seed-multi`); the harness starts and stops its own server.
notices:                       # regenerate THIRD_PARTY_NOTICES from assets/LICENSES.json
	cd bridge && $(PY) -m archipepsi_bridge.notices

doctor:                        # what a fresh clone is missing, and what is optional
	cd bridge && $(PY) -m archipepsi_bridge.doctor

version:                       # what this build IS (CI attaches it to a run)
	cd bridge && $(PY) -m archipepsi_bridge.version

dual-real:
	bash bridge/archipepsi_bridge/dual_harness.sh

# The same, across freshly GENERATED multiworlds rather than one seed.
dual-real-soak:
	bash bridge/archipepsi_bridge/dual_soak.sh

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

# BRIDGE-ONLY, AND THE NAME NO LONGER OVERSELLS IT. A process with no
# client certifies no layout, and `claim_zone_check` refuses a Check
# against geometry the bridge has not validated -- so the claim/Echo/
# equip/reload half of this moved to `bridge/tests/test_full_loop.py`,
# which certifies through the real handler, and to `godot-integration`,
# which certifies against real geometry. What is left is the half that
# needs no client, plus an assertion that the guard refuses.
smoke:                         # bridge-only loop + the certification guard
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
	@out=$$($(GODOT) --headless --path godot -- --chamber-test 2>&1); \
	printf '%s\n' "$$out"; \
	printf '%s\n' "$$out" | grep -q "GODOT CHAMBER TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# The activity vocabulary, driven rather than grepped.
#
# `test_runner_coverage.py` proves each schema kind has a MATCH BRANCH in
# activities.gd. It cannot see that a branch builds an inert box, which is
# what four of them did. This target drives each family to completion, and
# each family to failure, through the real physics and the real damage
# path -- so the two guards together mean "exists AND behaves".
godot-activity: godot-import
	@out=$$($(GODOT) --headless --path godot -- --activity-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT ACTIVITY TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# ROOM GRAMMAR v0: elevation bands, sockets and environmental objects.
#
# Every test goes through `ZoneBuilder.build` or
# `ContentInstantiator.build_chamber`, and none constructs its own room.
# This project has been burned three times by a subsystem passing its own
# tests while the real composition path never reached it.
godot-room: godot-import
	@out=$$($(GODOT) --headless --path godot -- --room-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[|WARNING)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT ROOM TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# THE ROOM CONTRACT, over both producers (P1).
#
# One suite keyed to `room_contract.gd` and `room_audit.gd`, run over
# procedural rooms AND authored fixtures. A per-producer suite proves
# that producer is self-consistent; this asks whether "a valid room"
# means the same thing whoever built it.
godot-room-contract: godot-import
	@out=$$($(GODOT) --headless --path godot -- --room-contract 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[|WARNING)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT ROOM CONTRACT TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# The REAL Zone 1, audited through the real builder.
#
# `godot-activity` drives activities it builds itself. That is what let a
# whole batch ship with the game building none: the suite proved the
# runtime works and nothing about whether anything reaches it. This target
# loads the JSON of the Zone a baseline playtest actually walks, hands it
# to `ZoneBuilder.build`, and measures the assembled scene with physics.
#
# It fails on STRUCTURE -- a declared activity with no runtime, a wrong
# element count, a kind that cannot be completed in the assembled Zone.
# Placement findings print as NOTEs and do not fail: they are written down
# in `docs/ZONE_ACTIVITY_AUDIT.md` and a target that goes red on a known
# open defect is a target people learn to ignore.
# SEVERAL ordinary generated Zones, composed and walked.
#
# `godot-room-contract` proves a great deal about ONE Zone, which is one
# shape the composer happened to make. This walks a run of consecutive
# Zones from a real campaign: does each compose, what shape is it, which
# branches were physically placed, and can the real `Player` reach a side
# destination and get back. No topology is preferred -- what is measured
# is whether the shape the composer chose can be built and walked.
godot-graphs: godot-import
	@out=$$($(GODOT) --headless --path godot -- --graphs 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[|WARNING)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT GRAPH TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# The generated Zones `godot-graphs` walks, regenerated from the engine
# rather than edited. Five consecutive Zones of a real campaign.
zone-fixtures:
	cd bridge && $(PY) tools/dump_zones.py --count 5

# THE DECLARED SAMPLE, wider than the five preserved controls: the first
# twenty consecutive ordinary Zones of a real campaign at DEFAULT_CONFIG,
# of which those five are exactly the prefix. Composed, and then the
# manifests judged by the bridge's own validator -- LAYOUT_OK from the
# router is not acceptance, and only one of the two is measured in the
# engine. Every result is printed, refusals included.
zone-sample: godot-import
	cd bridge && $(PY) tools/dump_zones.py --count 20 \
	  --out ../godot/tests/fixtures/sample
	@out=$$($(GODOT) --headless --path godot -- --graphs --sample 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[|WARNING)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT GRAPH TESTS OK" || exit 1
	@echo "-- and the bridge's own verdict on each emitted manifest --"
	@echo "   REPORT ONLY: an unplayed Zone's doorways are probed without"
	@echo "   the setup a played Zone gets, so door-polarity refusals here"
	@echo "   are about this harness. Acceptance is gated live, by"
	@echo "   godot-integration. The manifest-only class this once caught"
	@echo "   -- room overlap -- the router now refuses itself."
	-cd bridge && $(PY) tools/check_sample_layouts.py \
	  --json ../docs/evidence/overnight-0-3/sample-census.json

# THE SAME LOOP, WITH THE OPT-IN VARIANT TURNED ON. The owner's ask is
# that BOTH modes are exercised through real build and acceptance, not
# just the one that ships -- so this is `godot-integration` with the one
# flag added and its own save folder. A variant that generates Zones the
# engine refuses fails here rather than in a review session.
#
# PROTOTYPE SCALE, exactly like the baseline target, because that is
# what this harness is written for: `--mock-scale=default` fails here
# for the BASELINE too ("30 locations scouted", then a layout verdict
# that never arrives), so running the variant at default scale would
# compare it against a harness rather than against the baseline.
#
# The consequence is worth stating rather than burying: at prototype
# scale a Zone's budget is already ZONE_BUDGET_MIN, so the variant's
# band is clamped to the floor and what this exercises is the FAMILY
# NARROWING, not the lower band. The bridge logs that per Zone. Default
# scale is covered in Python instead -- `test_quiet_integration.py`
# generates and accepts a default-scale variant Zone through the same
# provider and the same validate_zone -- and in the engine by the
# station census in `godot-room-contract`, which builds five real
# manifests of each variant.
godot-integration-quiet: godot-import
	rm -rf $(QUIET_SAVES)
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(QUIET_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --quiet-generation & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start (port already serving? see the traceback above)"; \
	  exit 1; }; \
	$(GODOT) --headless --path godot -- --integration-test \
	  > /tmp/archipepsi-integration-quiet.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID; \
	cat /tmp/archipepsi-integration-quiet.log; \
	if [ $$STATUS -ne 0 ]; then exit $$STATUS; fi; \
	if grep -q "SCRIPT ERROR" /tmp/archipepsi-integration-quiet.log; then \
	  echo "-- a script error was raised: a run that crashed and still"; \
	  echo "-- printed OK is not a pass."; \
	  grep "SCRIPT ERROR" /tmp/archipepsi-integration-quiet.log | sort -u; \
	  exit 1; \
	fi

# THE VARIANT AT THE SCALE IT IS FOR, live and bounded.
#
# One Zone, default scale, variant on -- the only combination where the
# band is genuinely lower rather than clamped to the contract floor. The
# campaign starts fresh and takes what it is given, so the router
# refusal the offline census measured arrives on its own; ordinary
# bounded recovery then does whatever it does and the driver writes down
# the refusals, the outcome, and the leave/resume.
#
# THE BRIDGE LOG IS CHECKED TOO, and that is the half the client cannot
# answer: only the bridge knows what band it asked for. A run whose log
# shows the clamp warning is a run that measured the family narrowing
# and not the variant, so it fails here rather than being reported as
# one.
godot-integration-variant-live: godot-import
	rm -rf $(VARIANT_SAVES)
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(VARIANT_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default --quiet-generation \
	  > /tmp/archipepsi-variant-bridge.log 2>&1 & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start (port already serving?)"; \
	  cat /tmp/archipepsi-variant-bridge.log; exit 1; }; \
	$(GODOT) --headless --path godot -- --integration-test \
	  --variant-live > /tmp/archipepsi-variant-live.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID; \
	grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" \
	  /tmp/archipepsi-variant-live.log; \
	echo "-- what the bridge asked for --"; \
	grep "QUIET GENERATION" /tmp/archipepsi-variant-bridge.log \
	  | sed 's/^.*archipepsi.campaign //' | head -6; \
	if grep -q "below the contract floor" \
	    /tmp/archipepsi-variant-bridge.log; then \
	  echo "-- the band was CLAMPED, so this run measured the family"; \
	  echo "-- narrowing and not the lower-budget variant."; \
	  exit 1; \
	fi; \
	grep -q "QUIET GENERATION" /tmp/archipepsi-variant-bridge.log || { \
	  echo "-- the bridge never narrowed anything: the flag did not"; \
	  echo "-- reach generation, so nothing here is about the variant."; \
	  exit 1; }; \
	if [ $$STATUS -ne 0 ]; then exit $$STATUS; fi

godot-movement: godot-import   # P3.0 rails, launch pads, and the offer seam
	@out=$$($(GODOT) --headless --path godot -- --movement-test 2>&1); \
	status=$$?; echo "$$out" | grep -v "^$$"; \
	exit $$status

godot-playtest3a: godot-import  # 3A: a real player rides an authored rail
	@out=$$($(GODOT) --headless --path godot -- --playtest3a-test 2>&1); \
	status=$$?; echo "$$out" | grep -v "^$$"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: a test that crashed is not a test that passed"; \
	  exit 1; \
	fi; \
	exit $$status

# Also the producer of `godot/tests/fixtures/placement/*.json` -- the
# engine payloads `bridge/tests/test_placement_contract.py` runs through
# the real validator. `ARCHIPEPSI_CAPTURE_COMMIT` is what lets each
# capture record the tree it was measured from; the driver says
# "unknown" rather than inventing one when it is not set.
godot-zone-audit: godot-import
	@out=$$(ARCHIPEPSI_CAPTURE_COMMIT=$$(git rev-parse --short=12 HEAD 2>/dev/null) \
	  $(GODOT) --headless --path godot -- --zone-audit 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[|WARNING)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT ZONE AUDIT OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: the audit cannot vouch for itself"; \
	  exit 1; \
	fi

# The first deterministic screenshots of a REAL generated Zone.
#
# NOT `--headless`: that selects the dummy renderer and an awaited capture
# hangs forever with no output (`docs/art/CAMERA_BENCH.md`, gotcha 1, on
# the art branch). Xvfb plus the GL driver, and the screen must be at
# least as large as the viewport or the frame comes back part black with
# no error anywhere.
#
# Diagnostic, and not in CI: it asserts nothing, it needs a display, and
# `godot-zone-audit` is what makes the claims. Output is gitignored --
# these are for looking at, not for diffing.
zone-shots: godot-import
	@xvfb-run -a -s "-screen 0 1600x1000x24" $(GODOT) --path godot \
	  --rendering-driver opengl3 -- --zone-shots 2>&1 \
	  | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)"

# Five pictures of the `--railway` development scenario. Diagnostic and
# not in CI: it asserts nothing, it needs a display, and
# `godot-rail-junction` is what makes the claims. Output is
# `user://railway_shots`, outside the repository.
railway-shots: godot-import
	@xvfb-run -a -s "-screen 0 1600x1000x24" $(GODOT) --path godot \
	  --rendering-driver opengl3 -- --railway-shots 2>&1 \
	  | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)"

# Which refusals has anything ever triggered? Mutes one at a time and
# reports the survivors. See bridge/tools/mutate.py for what a survivor
# means -- it is not automatically a missing test.
mutate-bridge:
	cd bridge && $(PY) tools/mutate.py archipepsi_bridge/layout.py \
	  "c.fail(" tests/test_layout.py tests/test_physics_carrier.py
	cd bridge && $(PY) tools/mutate.py archipepsi_bridge/topology.py \
	  "errors.append(" tests/test_topology.py
	cd bridge && $(PY) tools/mutate.py archipepsi_bridge/schemas/physics.py \
	  "errors.append(" tests/test_physics_contract.py || \
	  { echo "(the empty-latch backstop is an expected survivor -- see"; \
	    echo " AMALGAM_BRIDGE.md 4.1a case 2)"; }

# The shared package-digest vectors, generated from the production
# serializer rather than edited. Regenerating is a CONTRACT CHANGE: the
# engine lane must re-run its side against the new file. See
# docs/AMALGAM_BRIDGE.md 6.2a.
physics-vectors:
	cd bridge && $(PY) tools/physics_vectors.py

# The audit's fixture, regenerated from the engine rather than edited.
zone-fixture:
	cd bridge && $(PY) -m archipepsi_bridge.playtest dump \
	  --out ../godot/tests/fixtures/played_zone.json

# P14, now M-1's legacy input: the played Zone with the retired
# step-once plate route (D-07) that a saved Zone may still hold, replayed
# by `godot-latched-route-live`'s legacy form (step on, step off, walk
# through, reload). Regenerated from source, never edited.
latched-route-fixture:
	cd bridge && $(PY) -m archipepsi_bridge.playtest dump-latched \
	  --out ../godot/tests/fixtures/latched_route_zone.json

# D13 1c: the played Zone with the production composer's lever route
# (the lever in c002, the shutter across e:c002:c003), played by
# `godot-lever-route-live`. Regenerated from source, never edited.
lever-route-fixture:
	cd bridge && $(PY) -m archipepsi_bridge.playtest dump-lever \
	  --out ../godot/tests/fixtures/lever_route_zone.json

# D13 1d: the played Zone with a doorway held by a declared weight on an
# object-only plate. Regenerated from source, never edited.
held-route-fixture:
	cd bridge && $(PY) -m archipepsi_bridge.playtest dump-held \
	  --out ../godot/tests/fixtures/held_route_zone.json

# O05-02 / O05-04: the played Zone with one CANDIDATE profile step applied
# (`candidate.py`, the same code the opt-in generation profile runs).
# Generated, never hand-edited.
transport-fixture:
	cd bridge && $(PY) -m archipepsi_bridge.playtest dump-candidate \
	  transport --out ../godot/tests/fixtures/transport_zone.json
reversible-fixture:
	cd bridge && $(PY) -m archipepsi_bridge.playtest dump-candidate \
	  zone_state --out ../godot/tests/fixtures/reversible_zone.json
candidate-fixture:
	cd bridge && $(PY) -m archipepsi_bridge.playtest dump-candidate \
	  all --out ../godot/tests/fixtures/candidate_zone.json

# Invariant I14 (ACCEPTANCE_TESTS 5.7). Boots the real project rather than
# using `--script`: a SceneTree script never instantiates the autoloads, so
# every script touching BridgeClient fails to compile and the suite reports
# zero attempts. Needs no bridge -- it builds its own zones.
godot-blink: godot-import      # blink never leaves the world
	@out=$$($(GODOT) --headless --path godot -- --blink-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT BLINK TESTS OK" || exit 1

# The S3 HUD suite: safe palette, glyph rule, the §7 pressure valve, and
# the archive's provenance chains. Boots the real project (the meters, the
# pool and the archive read the autoloads); needs no bridge -- the
# snapshot is a fold-derived fixture.
godot-hud: godot-import        # resource channels and the Echo archive
	@out=$$($(GODOT) --headless --path godot -- --hud-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT HUD TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# The S4 rule-engine suite: invariant I5 (edge derivation, deferral,
# cooldown-bounded oscillation, the per-tick cap) plus cost atomicity,
# condition conjunction and alias resolution, ticked by hand.
godot-rules: godot-import      # the ECHOES 5 interpreter, deterministically
	@out=$$($(GODOT) --headless --path godot -- --rules-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT RULES TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# The S5 stat-stack suite: invariant I3 over a seeded random sweep of
# legal trait stacks, plus scaled_by, scales links, requires_equipped,
# trait pulses and the status container's rules.
godot-stats: godot-import      # the derived stat stack holds its floors
	@out=$$($(GODOT) --headless --path godot -- --stats-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT STATS TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# The S8 Echo Lab suite: the fixtures exercise production interfaces, and
# a visit leaves campaign truth untouched.
godot-lab: godot-import        # the Hub test chamber, and what it must not do
	@out=$$($(GODOT) --headless --path godot -- --lab-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT LAB TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# The S9 affordance suite: features off the mandatory path (I4), a
# capability paying for each one (I12), local rewards that are never AP's
# (I13), and readouts that only ever read.
godot-affordance: godot-import # world affordances, local rewards, readouts
	@out=$$($(GODOT) --headless --path godot -- --affordance-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT AFFORDANCE TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# The integration run gets its own throwaway save directory. Sharing
# bridge/saves/ made the run resume the PREVIOUS run's campaign: the zone
# counter climbed forever, "coins were genuinely spent" passed on coins an
# earlier run had spent, and the shop assertion failed at random.
INTEGRATION_SAVES := $(CURDIR)/.integration-saves
# The lower-budget variant's own folder. A SEPARATE one, because the
# two modes compose different Zones and a single campaign holding
# both would make the comparison unreadable.
QUIET_SAVES := $(CURDIR)/.integration-saves-quiet
# And the default-scale live check's own folder, kept apart again so
# a bounded one-Zone probe never lands in a campaign anyone is
# reading.
VARIANT_SAVES := $(CURDIR)/.integration-saves-variant
JOURNEY_SAVES := $(CURDIR)/.journey-saves
# And the consumable sequence's own folder. It is SEEDED between two
# bridge runs, so it must never be a directory anyone else is using.
CONSUMABLE_SAVES := $(CURDIR)/.consumable-saves
# And the process-boundary run's own, because it deliberately leaves a
# campaign mid-expenditure and the socket sequence must not inherit it.
RESTART_SAVES := $(CURDIR)/.consumable-restart-saves

# The S2/S5 action-runner suite: press, release, cancel and death, with a
# real player over a real floor.
godot-verbs: godot-import      # the press and release lifecycle
	@out=$$($(GODOT) --headless --path godot -- --verbs-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT VERBS TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# Does the game START? The suite that should have existed: every other
# Godot target boots a DRIVER, and a driver returns from `_ready` before
# the real setup runs. That is how the world node went missing for a day
# with nine suites and two CI tiers green.
godot-boot: godot-import       # the real startup path, and the transition that crashed
	@out=$$($(GODOT) --headless --path godot -- --boot-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT BOOT TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# O05-08.1-.4: PUSH, PULL, HOLD, ALIGN, SETTLE, PIN, TETHER, ROTATE,
# ATTACH, DETACH, LIGHTEN_FIELD and ANCHOR_FIELD, and the relations
# ledger, runtime only (Design 2 §14.2-14.4, §31.2), by direct
# invocation. No Echo Action reaches them; see PROD_OV05.md, O05-08.
godot-verb-runtime: godot-import  # twelve verbs' runtime, not their delivery
	@out=$$($(GODOT) --headless --path godot -- --verb-runtime-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT VERB RUNTIME OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# O05-09.1: `rooted` and `anchored` on an enemy (Design 5 §15.2) -- no
# step of its own, attacks kept; a knock moves a rooted enemy and not an
# anchored one -- per role, and once through a real on-hit in a declared
# arena. See PROD_OV05.md, O05-09.1.
godot-status-family: godot-import  # the effective Statuses on their real consumers
	@out=$$($(GODOT) --headless --path godot -- --status-family-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT STATUS FAMILY OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

godot-status-kinetic: godot-import  # H-STATUS: anchored and lightened on every modelled target
	@out=$$($(GODOT) --headless --path godot -- --status-kinetic 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT STATUS KINETIC OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# CP1 (post-playtest): fair combat, counted in cumulative events --
# artillery knowledge, shell path and blast cover, with a low-cover
# positive control. See PROD_POST_PLAYTEST.md, H-ARTILLERY.
godot-combat-fairness: godot-import  # no shell through walls, roofs or cover
	@out=$$($(GODOT) --headless --path godot -- --combat-fairness-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT COMBAT FAIRNESS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# CP1 (post-playtest) H-FLYER-AI: the five divers of the played Zone's
# c011, in the real ZoneController -- the real player walks the spine to
# them, stands, jumps and clears the room, and every number is counted
# from an event (V-05).
godot-flyer-room: godot-import  # the played room's flyers wait, dive and die
	@out=$$($(GODOT) --headless --path godot -- --flyer-room 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT FLYER ROOM OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

godot-minor-claim: godot-import  # V-09: no minor's Check before its room is solved
	@out=$$($(GODOT) --headless --path godot -- --minor-claim 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT MINOR CLAIM TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# CP1 (post-playtest) H-RESUME-R, offline: what the Zone builds from a
# saved encounter record, read before the first physics step. The
# two-process proof is `godot-resume-live`.
godot-resume: godot-import  # the fallen stay fallen; the player never among the living
	@out=$$($(GODOT) --headless --path godot -- --resume-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT RESUME TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# Can the player READ the walls? Playtest 1 found every Hub sign
# mirrored while nine suites stayed green: they all assert state,
# geometry or protocol, and a backwards sign is correct in all three.
godot-legible: godot-import    # which way the writing on the wall faces
	@out=$$($(GODOT) --headless --path godot -- --legibility-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT LEGIBILITY TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# The S12 authored-content suite. Godot is the physical authority for the
# registry: it is the only half that can ask whether a scene a manifest
# claims actually loads, and it owns the S13 selection rule. The Python
# half validates manifest SHAPE and pins the two together.
godot-content: godot-import    # the authored-content registry and its fallbacks
	@out=$$($(GODOT) --headless --path godot -- --content-test 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT CONTENT TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

RELOAD_SAVES := $(CURDIR)/.reload-saves

# TWO PROCESSES, ONE SAVE. The only thing that crosses between them is
# the campaign on disk, which is what makes this the one suite that can
# see a resume read from memory instead of from the bridge.
#
# `--mock-scale default` because a locked branch needs a Zone big enough
# to spare a room, and the prototype's thirty locations do not make one.
# BOTH SIDES RESTART. The bridge used to stay up across the two Godot
# processes, so "the campaign loads from disk" was the CLIENT loading
# from a bridge that still had everything in memory. It is stopped and
# started again between the phases now, against the same save directory,
# so the only thing that crosses the restart is the file on disk.
# THE PHYSICS SUBSTRATE (`docs/AMALGAM_BRIDGE.md` §6.3): a rigid body
# that rests and can be pushed, and one verb resolving to force, range
# and mass. Its own target because it is the only suite that steps
# physics for hundreds of frames, and folding it into `godot-content`
# would make a fast contract suite slow for everybody.
godot-physics: godot-import
	@out=$$($(GODOT) --headless --path godot -- --physics-test 2>&1); \
	status=$$?; printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[|WARNING)"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: a test that crashed is not a test that passed"; \
	  exit 1; \
	fi; \
	exit $$status

godot-traverse: godot-import   # walking to things, with the real controller
	@out=$$($(GODOT) --headless --path godot -- --traverse-test 2>&1); \
	status=$$?; printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[|WARNING)"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: a test that crashed is not a test that passed"; \
	  exit 1; \
	fi; \
	exit $$status

godot-exit-reach: godot-import  # can the player actually reach the exit
	@out=$$($(GODOT) --headless --path godot -- --exit-reach 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-passenger-carry: godot-import  # is a body carried on a moving deck
	@out=$$($(GODOT) --headless --path godot -- --passenger-carry 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-rail-carrier: godot-import  # does the railway travel, stop and refuse
	@out=$$($(GODOT) --headless --path godot -- --rail-carrier 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-rail-junction: godot-import  # lever, span, latch, and coming back
	@out=$$($(GODOT) --headless --path godot -- --rail-junction 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-passing-platforms: godot-import  # EX50-011: two carriers, one meeting
	@out=$$($(GODOT) --headless --path godot -- --passing-platforms-test 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-counterfire: godot-import  # EX50-021: a hostile shot as an input
	@out=$$($(GODOT) --headless --path godot -- --counterfire-test 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-roster: godot-import  # OV04 P06: the seven additional enemy roles
	@out=$$($(GODOT) --headless --path godot -- --roster 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-actuator: godot-import  # OV04 P15: §21's actuator contract
	@out=$$($(GODOT) --headless --path godot -- --actuator 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-constraints: godot-import  # OV04 P13: §14.8's eight kinds
	@out=$$($(GODOT) --headless --path godot -- --constraints 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-archive: godot-import  # the Echo archive: search, sort, the split
	@out=$$($(GODOT) --headless --path godot -- --archive 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

# THE GENERATED ENCOUNTER, PLAYED. Declared cases, not all ten roles in
# one room: the roles are built by the same composer a campaign uses,
# the player is the controller's own, the input is the real input path,
# and the fight ends in `kill_all` or it does not end.
#
# It ran about one in five red before it was a target, always on the
# three-scuttler case, and the cause was the harness: the fight held
# the trigger from a fixed spot, so a body placed outside the 18 m
# aggro radius never woke and eighty-two shots went into the reward
# pedestal in front of it. It walks now. Ten consecutive green runs
# bought this line.
# P14: A ZONE ASKS FOR A SIGNAL CHAIN AND GETS ONE. The plate, the NOT
# and the shutter `unweighted_switch` hard-wires, built instead from
# `Zone.room_graphs` -- and every other node and sensor §19.2 and §20
# name refused, with a typo told apart from a gap.
godot-signal-graph: godot-import  # the declared room graph, built and run
	@out=$$($(GODOT) --headless --path godot -- --signal-graph 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT SIGNAL GRAPH TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# H-GRAPHS: Design 3 §14's five signal verbs on the graphs real rooms run
# (the held and latched routes, EX50-033, EX50-021). Runtime-only until
# an Echo delivers them (N-15).
godot-signal-verbs: godot-import  # the five signal verbs, on real graphs
	@out=$$($(GODOT) --headless --path godot -- --signal-verbs 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT SIGNAL VERBS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# P14: THE DECLARED ROUTE, PLAYED. Dess's `latched_route_zone.json`
# (`make latched-route-fixture`) entered from its own arrival with the
# real body on `move_forward` through real collision: the arena cleared
# with the base kit, the doorway shown shut by pressing at it, the
# player-enabled plate stepped on (one real `latch_fired`), stepped off,
# and the actual doorway walked into c003 and back. The control takes
# the LATCH out and the same walk is stopped at the door.
godot-latched-route: godot-import  # the latch route, played end to end
	@out=$$($(GODOT) --headless --path godot -- --latched-route 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT LATCHED ROUTE TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# P14: THE SAME ROUTE THROUGH A REAL BRIDGE, AND BACK AFTER A RESTART.
# A disposable default-scale mock campaign (the scale Dess's fixture was
# composed at). The real path generates zone_001; `compose_latched_route.py`
# takes D-10's explicit step on it and checks the result IS
# `latched_route_zone.json` (no re-keying); the real `Main` enters it
# through the portal, the bridge certifies the layout, and the plate is
# stepped on -- the real `latch_fired` accepted and read back off the save
# file, forged latches refused. Then BOTH processes restart from the save
# alone, and the route is open before anyone reaches the plate.
#
# To play the same candidate by hand, seed a save the same way and point
# the ordinary client at it: see docs/P14_LATCHED_ROUTE_REPLAY.md.
#
# LATCH_FORM picks the route (D-07, D13 1c): `legacy`, the default, is
# M-1's step-once plate; `lever` is what the composer now writes, pulled
# once and thrown for good (`godot-lever-route-live`). The seed tool and
# the driver both take it, and the driver fails if the served Zone
# declares the other form's control.
LATCH_SAVES := $(CURDIR)/.latched-route-saves
LATCH_FORM ?= legacy
LATCH_EXPECT = $(if $(filter lever,$(LATCH_FORM)),lever_route_zone.json,latched_route_zone.json)
godot-latched-route-live: godot-import
	rm -rf $(LATCH_SAVES)
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(LATCH_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start (port already serving?)"; exit 1; }; \
	$(GODOT) --headless --path godot -- --latched-live=seed \
	  > /tmp/archipepsi-latched-seed.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; wait $$BRIDGE_PID 2>/dev/null; \
	grep -E "^(  ok|FAIL|seeded|GODOT LATCHED)" /tmp/archipepsi-latched-seed.log; \
	if [ $$STATUS -ne 0 ]; then tail -20 /tmp/archipepsi-latched-seed.log; \
	  echo "-- no campaign was seeded"; exit $$STATUS; fi
	cd bridge && PYTHONPATH=. $(PY) tools/compose_latched_route.py \
	  $(LATCH_SAVES) --form $(LATCH_FORM) \
	  --expect ../godot/tests/fixtures/$(LATCH_EXPECT)
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(LATCH_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "the bridge did not load the composed save"; exit 1; }; \
	$(GODOT) --headless --path godot -- --latched-live=play \
	  --latched-form=$(LATCH_FORM) \
	  --latched-save-dir=$(LATCH_SAVES) > /tmp/archipepsi-latched-play.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; wait $$BRIDGE_PID 2>/dev/null; \
	grep -E "^(  ok|  NOTE|FAIL|played|GODOT LATCHED)" /tmp/archipepsi-latched-play.log; \
	if [ $$STATUS -ne 0 ]; then exit $$STATUS; fi; \
	grep -qE "GODOT LATCHED LIVE (LEVER )?PLAY OK" /tmp/archipepsi-latched-play.log || exit 1
	@echo "-- both processes restart: the bridge too, from its own save --"
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(LATCH_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "the restarted bridge did not come back"; exit 1; }; \
	$(GODOT) --headless --path godot -- --latched-live=restore \
	  --latched-form=$(LATCH_FORM) \
	  --latched-save-dir=$(LATCH_SAVES) > /tmp/archipepsi-latched-restore.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; wait $$BRIDGE_PID 2>/dev/null; \
	grep -E "^(  ok|  NOTE|FAIL|GODOT LATCHED)" /tmp/archipepsi-latched-restore.log; \
	if [ $$STATUS -ne 0 ]; then exit $$STATUS; fi; \
	grep -qE "GODOT LATCHED LIVE (LEVER )?RESTORE OK" /tmp/archipepsi-latched-restore.log \
	  || exit 1

# D13 1c's lever route, through the same real bridge and restart: the
# bolt pulled once with the real interact, accepted and saved, thrown for
# good, and restored thrown with the way open.
godot-lever-route-live:
	$(MAKE) godot-latched-route-live LATCH_FORM=lever \
	  LATCH_SAVES=$(CURDIR)/.lever-route-saves

# O05-03: THE TRANSPORT JOURNEY THROUGH A REAL BRIDGE, ACROSS TWO REAL
# RESTARTS. A disposable default-scale mock campaign whose bridge runs the
# opt-in CANDIDATE profile (`--candidate=transport`): the real generation
# path composes zone_001 and the profile adds the journey before the Zone
# is accepted -- no save is edited. SEED checks it is `transport_zone.json`
# exactly. Then three more process pairs, each a new bridge beside a new
# client with only the save crossing: PLACE (carry the cell partway and put
# it down), INSTALL (restart 1: it is where it was put down; carry on and
# install), RESTORE (restart 2: installed at load, the doorway open, and
# the player walks through).
TRANSPORT_SAVES := $(CURDIR)/.transport-saves
TRANSPORT_BRIDGE = cd bridge && ARCHIPEPSI_SAVE_DIR=$(TRANSPORT_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default --candidate=transport
define transport_phase
	$(TRANSPORT_BRIDGE) & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start for $(1) (port already serving?)"; exit 1; }; \
	$(GODOT) --headless --path godot -- --transport-live=$(1) \
	  --transport-save-dir=$(TRANSPORT_SAVES) \
	  > /tmp/archipepsi-transport-$(1).log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; wait $$BRIDGE_PID 2>/dev/null; \
	grep -E "^(  ok|  NOTE|FAIL|seeded|placed|installed|GODOT TRANSPORT)" \
	  /tmp/archipepsi-transport-$(1).log; \
	if [ $$STATUS -ne 0 ]; then tail -20 /tmp/archipepsi-transport-$(1).log; \
	  exit $$STATUS; fi
endef
godot-transport-live: godot-import
	rm -rf $(TRANSPORT_SAVES)
	$(call transport_phase,seed)
	$(call transport_phase,place)
	@echo "-- restart 1: both processes new, only the save crosses --"
	$(call transport_phase,install)
	@echo "-- restart 2: both processes new again --"
	$(call transport_phase,restore)

# O05-04.5: THE REVERSIBLE LEVER THROUGH A REAL BRIDGE AND A RESTART. The
# bridge runs the CANDIDATE profile's `zone_state` step, so the real
# generation path composes the lever (SEED checks it is
# `reversible_zone.json`). SELECT pulls it -- PENDING, then ACCEPTED off
# the snapshot, and on disk -- refuses a forged selection by its own key,
# walks through and leaves it LOWERED. RESTORE: both processes new, the
# doorway open at load, walked through without touching the lever.
REVERSIBLE_SAVES := $(CURDIR)/.reversible-saves
define reversible_phase
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(REVERSIBLE_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default --candidate=zone_state & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start for $(1) (port already serving?)"; exit 1; }; \
	$(GODOT) --headless --path godot -- --reversible-live=$(1) \
	  --reversible-save-dir=$(REVERSIBLE_SAVES) \
	  > /tmp/archipepsi-reversible-$(1).log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; wait $$BRIDGE_PID 2>/dev/null; \
	grep -E "^(  ok|  NOTE|FAIL|seeded|selected|GODOT REVERSIBLE)" \
	  /tmp/archipepsi-reversible-$(1).log; \
	if [ $$STATUS -ne 0 ]; then tail -20 /tmp/archipepsi-reversible-$(1).log; \
	  exit $$STATUS; fi
endef
godot-reversible-live: godot-import
	rm -rf $(REVERSIBLE_SAVES)
	$(call reversible_phase,seed)
	$(call reversible_phase,select)
	@echo "-- restart: both processes new, only the save crosses --"
	$(call reversible_phase,restore)

# O05-13/15: THE WHOLE CANDIDATE PROFILE IN ONE ZONE, the combination the
# candidate launcher (`archipepsi_bridge.diagnostic --candidate`) plays.
# SEED checks the served Zone is `candidate_zone.json` and that the bridge
# recorded every step EMITTED; PLAY builds all three, pulls the lever,
# carries and installs the cell and walks through; RESTORE (both processes
# new) finds lever, cell and P14's shutter as they were left.
CANDIDATE_SAVES := $(CURDIR)/.candidate-saves
define candidate_phase
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(CANDIDATE_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default --candidate=all & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start for $(1) (port already serving?)"; exit 1; }; \
	$(GODOT) --headless --path godot -- --candidate-live=$(1) \
	  --candidate-save-dir=$(CANDIDATE_SAVES) \
	  $(if $(CANDIDATE_DUMP),--candidate-dump-zone=$(CANDIDATE_DUMP)) \
	  > /tmp/archipepsi-candidate-$(1).log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; wait $$BRIDGE_PID 2>/dev/null; \
	grep -E "^(  ok|  NOTE|FAIL|seeded|played|GODOT CANDIDATE)" \
	  /tmp/archipepsi-candidate-$(1).log; \
	if [ $$STATUS -ne 0 ]; then tail -20 /tmp/archipepsi-candidate-$(1).log; \
	  exit $$STATUS; fi; \
	if grep -qE "SCRIPT ERROR|String formatting error" \
	  /tmp/archipepsi-candidate-$(1).log; then \
	  echo "candidate phase $(1): runtime errors in the run"; exit 1; fi
endef
godot-candidate-live: godot-import
	rm -rf $(CANDIDATE_SAVES)
	$(call candidate_phase,seed)
	$(call candidate_phase,play)
	@echo "-- restart: both processes new, only the save crosses --"
	$(call candidate_phase,restore)
	$(call candidate_phase,minor)
	@echo "-- restart: both processes new, only the save crosses --"
	$(call candidate_phase,minor_restore)
	$(call candidate_phase,next)
	@echo "-- restart: both processes new, only the save crosses --"
	$(call candidate_phase,next_restore)
	@echo "-- restart: both processes new, only the save crosses --"
	$(call candidate_phase,next_final)

# H-RESUME-R (post-playtest CP1): AN ENCOUNTER RESUMES AS IT WAS LEFT
# (D-06). The candidate profile's c005 -- two bulwarks and the station a
# resume returns to. Each phase is a new client beside a new bridge; only
# the save crosses. `legacy` runs on a COPY made after `partial`, with the
# per-enemy record stripped by `tools/strip_encounter_record.py`, which
# refuses any directory but such a copy.
RESUME_SAVES := $(CURDIR)/.resume-saves
RESUME_LEGACY := $(CURDIR)/.resume-saves-legacy
define resume_phase
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(2) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default --candidate=all & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start for $(1) (port already serving?)"; exit 1; }; \
	$(GODOT) --headless --path godot -- --resume-live=$(1) \
	  --resume-save-dir=$(2) \
	  > /tmp/archipepsi-resume-$(1).log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; wait $$BRIDGE_PID 2>/dev/null; \
	grep -E "^(  ok|  NOTE|FAIL|seeded|played|restored|legacy|GODOT RESUME)" \
	  /tmp/archipepsi-resume-$(1).log; \
	if grep -qE "SCRIPT ERROR|String formatting error" \
	  /tmp/archipepsi-resume-$(1).log; then \
	  echo "-- a runtime error was raised in $(1)"; exit 1; fi; \
	if [ $$STATUS -ne 0 ]; then tail -20 /tmp/archipepsi-resume-$(1).log; \
	  exit $$STATUS; fi
endef
godot-resume-live: godot-import
	rm -rf $(RESUME_SAVES) $(RESUME_LEGACY)
	$(call resume_phase,seed,$(RESUME_SAVES))
	$(call resume_phase,partial,$(RESUME_SAVES))
	cp -r $(RESUME_SAVES) $(RESUME_LEGACY)
	$(PY) tools/strip_encounter_record.py $(RESUME_LEGACY)
	@echo "-- restart: both processes new, only the save crosses --"
	$(call resume_phase,partial_restore,$(RESUME_SAVES))
	@echo "-- restart: both processes new, only the save crosses --"
	$(call resume_phase,clear_restore,$(RESUME_SAVES))
	@echo "-- the legacy copy: both processes new, a save without the record --"
	$(call resume_phase,legacy,$(RESUME_LEGACY))

# P14: THE LATCH-ROUTE CANDIDATE, BY HAND. Opt-in and disposable: its own
# save directory, a default-scale mock campaign whose zone_001 is Dess's
# `latched_route_zone.json` -- the same seed and explicit compose step
# `godot-latched-route-live` takes, identity checked. Nothing else is read
# or written, and the ordinary campaign never composes a latch.
#   make latched-route-play           seed once, then the bridge + the game
#   make latched-route-play FRESH=1   discard that save and seed again
# In the game: MOCK CAMPAIGN, then the portal. Quit and run it again (no
# FRESH) to come back to the same save. docs/P14_LATCHED_ROUTE_REPLAY.md.
LATCH_PLAY_SAVES := $(CURDIR)/.latched-route-play
latched-route-play: godot-import
	$(if $(FRESH),rm -rf $(LATCH_PLAY_SAVES))
	@if ls $(LATCH_PLAY_SAVES)/*.json >/dev/null 2>&1; then \
	  echo "-- reusing $(LATCH_PLAY_SAVES) (FRESH=1 seeds it again)"; \
	else \
	  cd bridge && ARCHIPEPSI_SAVE_DIR=$(LATCH_PLAY_SAVES) \
	    $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	    --mock-scale=default > /tmp/archipepsi-latched-play-seed.log 2>&1 & \
	  BRIDGE_PID=$$!; sleep 2; \
	  $(GODOT) --headless --path godot -- --latched-live=seed \
	    > /tmp/archipepsi-latched-play-seed-client.log 2>&1; \
	  STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; wait $$BRIDGE_PID 2>/dev/null; \
	  if [ $$STATUS -ne 0 ]; then \
	    tail -20 /tmp/archipepsi-latched-play-seed-client.log; exit $$STATUS; fi; \
	  (cd bridge && PYTHONPATH=. $(PY) tools/compose_latched_route.py \
	    $(LATCH_PLAY_SAVES) \
	    --expect ../godot/tests/fixtures/latched_route_zone.json) || exit 1; \
	fi
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(LATCH_PLAY_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start (port already serving?)"; exit 1; }; \
	$(GODOT) --path godot; \
	kill $$BRIDGE_PID 2>/dev/null; wait $$BRIDGE_PID 2>/dev/null; true

# D-11: A ZONE'S GAME PACK, THROUGH THE REAL MATERIAL PATH. Real Zones
# and the real Hub are built and the meshes the builders made are read:
# no pack is unchanged; a selectable pack's exact row wins; a missing role
# is the family's (and a pack takes no hop); two packs over one family
# share nothing; no pack again is the family again; the Hub is no Zone's;
# a pack's hazard row is refused; a candidate or unlisted pack binds
# nothing. The packs are in-memory and test-scoped: THEME_PACK.json and
# the production THEME_PACK_STATUS ({}) are untouched.
godot-theme-pack: godot-import  # Zone.theme_pack, on the geometry
	@out=$$($(GODOT) --headless --path godot -- --theme-pack 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT THEME PACK TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# The same arena wall rendered under no pack, test pack A and test pack
# B, for a reviewer. Diagnostic and not in CI: it asserts nothing and it
# needs a display; `godot-theme-pack` makes the claims. Output is
# `user://theme_pack_shots`, outside the repository.
# O05-15.4: review frames of the candidate Zone (`candidate_zone.json`),
# each relationship before and after. Diagnostic and not in CI: it asserts
# nothing and needs a display. Output is `user://candidate_shots`.
candidate-shots: godot-import
	@xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --path godot \
	  --rendering-driver opengl3 -- --candidate-shots 2>&1 \
	  | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)"

theme-pack-shots: godot-import
	@xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --path godot \
	  --rendering-driver opengl3 -- --theme-pack --shots 2>&1 \
	  | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)"

# O05-01: ORDINARY HAND CARRY, OPERATED. A real Player, driven through
# `interact`, `move_forward`, `fire_pulse` and the mobility slot: pick up,
# follow the view, walk into a wall (never inside it), put down at rest,
# pick up again; the refusals (not carriable at the same mass; 60.00 kg
# yes, 60.01 kg no; LIGHTENED changes class, not kilograms); the 0.85
# walking factor for MEDIUM; the Archive's hold; dying while carrying.
godot-carry: godot-import  # Design 2 §10.3-10.4 hand carry, played
	@out=$$($(GODOT) --headless --path godot -- --carry 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT CARRY TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

# O05-02/03: A REQUIRED OBJECT, CARRIED BETWEEN ROOMS AND INSTALLED, on
# `transport_zone.json` (`make transport-fixture`). The real player clears
# the rooms, fetches the 40 kg cell with `interact`, carries it through two
# connectors, installs it in the socket with the interact ray and walks
# through the doorway it opens. Then: restore installed (one copy, gate
# open at load), restore at a settled mid-branch pose, the wrong object
# refused, out-of-volume recovery after 1.0 s, death while carrying,
# destruction (2.0 s), interruption beside the socket, and LIGHTENED
# crossing the threshold on the same body.
godot-transport: godot-import  # P16 carry + install, played
	@out=$$($(GODOT) --headless --path godot -- --transport 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT TRANSPORT TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "godot-transport: script errors in the run"; exit 1; fi

# H-COUNTERFIRE (PT-04, D12, V-11): EX50-021 AS THE PLAYED ZONE HOSTS IT
# (`candidate_zone.json`, zone_001/c025). What the room says as built and
# while the window runs; the Zone's gunner killed with the base kit and
# the receiver shot by hand from the lane (the owner's route, and the
# kill-first fallback); no step off anywhere reached drops out of the
# world; the hood as a census; V-10 at the schema maxima; and the way
# back, without the release and with it.
godot-counterfire-hosted: godot-import  # EX50-021 hosted, played
	@out=$$($(GODOT) --headless --path godot -- --counterfire-hosted 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT COUNTERFIRE HOSTED OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "godot-counterfire-hosted: script errors in the run"; exit 1; fi

# H-PASSING (PT-06, PT-07, D12): EX50-011 AS THE CANDIDATE'S SECOND ZONE
# HOSTS IT (zone_002/c025). The census as built and with the shuttle
# docked; what the room says; the shuttle opening G's glass gate from A's
# board and shutting it when called away; V-10 at the schema maxima; an
# arrival anywhere on G releasing the stair, walked back down; and the
# gate held open over a player standing in it. Until Dess's fixture lands
# (N-10) the Zone is a capture of the one the bridge serves --
# `make godot-candidate-live CANDIDATE_DUMP=<path>` writes it -- passed
# as PASSING_ZONE=<path>, and the target is not in CI.
PASSING_ZONE ?= res://tests/fixtures/passing_zone.json
godot-passing-hosted: godot-import  # EX50-011 hosted, played
	@out=$$($(GODOT) --headless --path godot -- --passing-hosted \
	  --passing-zone=$(PASSING_ZONE) 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT PASSING HOSTED OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "godot-passing-hosted: script errors in the run"; exit 1; fi

# H-3D-SHELL (CP3, V-18): THE PAUSE INTERFACE IN REAL 3D. Four walls of a
# box in its own World3D, the camera turning between them (left: Settings,
# Equipment, Map, Journal), the pointer carried to the front page by
# geometry, the keys, and reduced motion as a cut. `menu-shell-shots`
# renders it for real under xvfb and writes the frames to SHOTS_DIR.
godot-menu-shell: godot-import  # the 3D shell: box, order, turn, input
	@out=$$($(GODOT) --headless --path godot -- --menu-shell 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT MENU SHELL OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "godot-menu-shell: script errors in the run"; exit 1; fi

SHOTS_DIR ?= /tmp/archipepsi-menu-shell
menu-shell-shots: godot-import
	@xvfb-run -a -s "-screen 0 1280x720x24" $(GODOT) --path godot \
	  --rendering-driver opengl3 -- --menu-shell --shots=$(SHOTS_DIR) 2>&1 \
	  | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)"

# H-INVENTORY (CP3): THE EQUIPMENT WALL, three regions on Dess's
# `CampaignSnapshot.inventory`: the keys, a grid of owned items (items,
# never Echo events), and the selected item's detail and comparison. An
# equip is a request until a snapshot carries it; a refusal is shown on
# the exact `about` key only; the consumable key names its five states;
# mouse, keyboard and controller all reach it through the 3D shell.
# `equipment-face-shots` renders it under xvfb at 1280x720 and 1920x1080.
godot-equipment-face: godot-import  # the equipment wall: regions, requests, input
	@out=$$($(GODOT) --headless --path godot -- --equipment-face 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT EQUIPMENT FACE OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "godot-equipment-face: script errors in the run"; exit 1; fi

# H-MINIMAP (CP4, V-20): THE MAP THAT STAYS ON SCREEN, on the real
# candidate Zone: rooms as their built envelopes, connectors along their
# built chains (a turning corridor drawn turning), the room you are in by
# the bridge's name, `room_entered` sent and resent until the bridge's map
# shows it (D-2), and blockers in their circuit's colour with a reason
# symbol -- the green circuit blocked while the cell is carried and open
# once it is installed, the reversible span closing again.
godot-minimap: godot-import  # the minimap: real shapes, the bridge's states
	@out=$$($(GODOT) --headless --path godot -- --minimap 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT MINIMAP OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "godot-minimap: script errors in the run"; exit 1; fi

# The window the minimap, map-wall and journal shots are taken at.
SHOTS_SIZE ?= 1280x720
MINIMAP_SHOTS_DIR ?= /tmp/archipepsi-minimap
minimap-shots: godot-import
	@xvfb-run -a -s "-screen 0 1920x1080x24" $(GODOT) --path godot \
	  --rendering-driver opengl3 -- --minimap --shots=$(MINIMAP_SHOTS_DIR) \
	  --shots-size=$(SHOTS_SIZE) 2>&1 \
	  | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)"

# H-3D-MAP (CP4, V-21): THE MAP WALL, on the real shell and the real
# candidate Zone: a render-only miniature (meshes and labels in its own
# World3D, nothing of the Zone's), the same projection as the minimap,
# cutaway rooms and one floor at a time, and its own keys, pad and
# pointer -- none of which turns the page.
godot-map-face: godot-import  # the map wall: render-only, one projection
	@out=$$($(GODOT) --headless --path godot -- --map-face 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT MAP FACE OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "godot-map-face: script errors in the run"; exit 1; fi

MAP_FACE_SHOTS_DIR ?= /tmp/archipepsi-map-face
map-face-shots: godot-import
	@xvfb-run -a -s "-screen 0 1920x1080x24" $(GODOT) --path godot \
	  --rendering-driver opengl3 -- --map-face --shots=$(MAP_FACE_SHOTS_DIR) \
	  --shots-size=$(SHOTS_SIZE) 2>&1 \
	  | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)"

# H-JOURNAL (CP4, §8): THE JOURNAL WALL AND THE SETTINGS WALL, on the
# real shell: objectives in the Hub's own words, what was done in the
# Zone and what it opened, what is still shut and why, the places found,
# the earned notes -- and nothing unfound named; the campaign beside the
# pause menu's unchanged actions, and the options that are applied.
godot-journal-face: godot-import  # the journal and settings walls
	@out=$$($(GODOT) --headless --path godot -- --journal-face 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT JOURNAL FACE OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "godot-journal-face: script errors in the run"; exit 1; fi

JOURNAL_SHOTS_DIR ?= /tmp/archipepsi-journal-face
journal-face-shots: godot-import
	@xvfb-run -a -s "-screen 0 1920x1080x24" $(GODOT) --path godot \
	  --rendering-driver opengl3 -- --journal-face --shots=$(JOURNAL_SHOTS_DIR) \
	  --shots-size=$(SHOTS_SIZE) 2>&1 \
	  | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)"

EQUIPMENT_SHOTS_DIR ?= /tmp/archipepsi-equipment-face
equipment-face-shots: godot-import
	@xvfb-run -a -s "-screen 0 1920x1080x24" $(GODOT) --path godot \
	  --rendering-driver opengl3 -- --equipment-face \
	  --shots=$(EQUIPMENT_SHOTS_DIR) 2>&1 \
	  | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|GDScript backtrace|       \[)"

# D13 1d / Dess's D-4: A DOORWAY HELD OPEN BY A DECLARED WEIGHT, on
# `held_route_zone.json` (`make held-route-fixture`). The real player
# clears the way, finds the object-only plate ignores them, carries the
# 40 kg counterweight onto it, and the doorway opens and stays open only
# while it rests there; lifted, it shuts; put back, it opens. A rebuild
# from the reported pose opens it again with no plate state saved, and the
# panel holds off a player standing in the doorway when the weight goes.
godot-held-route: godot-import  # D-07's held plate, played
	@out=$$($(GODOT) --headless --path godot -- --held-route 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT HELD ROUTE OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "godot-held-route: script errors in the run"; exit 1; fi

# O05-04: A REVERSIBLE BRANCH ACTION CHANGES ACCESS ELSEWHERE, on
# `reversible_zone.json` (`make reversible-fixture`). The real player clears
# c002, finds the doorway shut, operates the lever (PENDING until a bridge
# answers), walks through the doorway it opened, comes back and reverses
# it. Then a required crate carried into the opening holds the closure
# QUEUED until it is carried back out, and the way in stays open. Restored
# lowered and stowed; and (synthetic) a refusal naming the selection puts
# it back.
godot-reversible: godot-import  # D-8 reversible lever, played
	@out=$$($(GODOT) --headless --path godot -- --reversible 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT REVERSIBLE TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "godot-reversible: script errors in the run"; exit 1; fi

godot-encounter: godot-import  # generated rooms, fought with the base kit
	@out=$$($(GODOT) --headless --path godot -- --encounter 2>&1); \
	printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" ; \
	printf '%s\n' "$$out" | grep -q "GODOT ENCOUNTER TESTS OK" || exit 1; \
	if printf '%s\n' "$$out" | grep -qE "SCRIPT ERROR|String formatting error"; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

godot-consumable: godot-import  # the fifth slot at runtime: charges, races, refusals
	@out=$$($(GODOT) --headless --path godot -- --consumable 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-zone-state: godot-import  # D-8: a puzzle that crosses rooms
	@out=$$($(GODOT) --headless --path godot -- --zone-state 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-rail-zone: godot-import  # D-4: a Zone that asks for a railway
	@out=$$($(GODOT) --headless --path godot -- --rail-zone 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-rail-gantry: godot-import  # D-9: a span's control on a gantry
	@out=$$($(GODOT) --headless --path godot -- --rail-gantry 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-unweighted: godot-import  # EX50-033: the room the class change opens
	@out=$$($(GODOT) --headless --path godot -- --unweighted-test 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-mass-class: godot-import  # class vs kilograms: two sensors, one crate
	@out=$$($(GODOT) --headless --path godot -- --mass-class 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised"; exit 1; \
	fi; \
	exit $$status

godot-target-facing: godot-import  # which way a shot target points
	@out=$$($(GODOT) --headless --path godot -- --target-facing 2>&1); \
	status=$$?; printf '%s\n' "$$out" \
	  | grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: a test that crashed is not a test that passed"; \
	  exit 1; \
	fi; \
	exit $$status

godot-return-placement: godot-import  # a convenience return is never on the way
	@out=$$($(GODOT) --headless --path godot -- --return-placement 2>&1); \
	status=$$?; printf '%s\n' "$$out" | grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[|WARNING)"; \
	if printf '%s\n' "$$out" | grep -q "SCRIPT ERROR"; then \
	  echo "-- a script error was raised: a test that crashed is not a test that passed"; \
	  exit 1; \
	fi; \
	exit $$status

godot-reload: godot-import
	rm -rf $(RELOAD_SAVES) $(HOME)/.local/share/godot/app_userdata/Archipepsi/reload_notes.json
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(RELOAD_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start (port already serving?)"; exit 1; }; \
	$(GODOT) --headless --path godot -- --reload-phase=record > /tmp/reload-record.log 2>&1; \
	RECORD=$$?; \
	grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[|WARNING)" /tmp/reload-record.log | tail -25; \
	if [ $$RECORD -ne 0 ]; then kill $$BRIDGE_PID; exit $$RECORD; fi; \
	echo "-- both processes restart: the bridge too, from its own save --"; \
	kill $$BRIDGE_PID; wait $$BRIDGE_PID 2>/dev/null || true; \
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(RELOAD_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "the restarted bridge did not come back"; exit 1; }; \
	$(GODOT) --headless --path godot -- --reload-phase=resume > /tmp/reload-resume.log 2>&1; \
	RESUME=$$?; \
	grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[|WARNING)" /tmp/reload-resume.log | tail -30; \
	kill $$BRIDGE_PID; exit $$RESUME

# ONE NAMED SAMPLE PROPOSAL, THROUGH A REAL CLIENT AND A REAL BRIDGE.
#
#   make godot-named-case CASE=zone_05
#
# `make zone-sample` judges a manifest offline. This puts the SAME
# proposal in front of the live path: a disposable campaign at the scale
# the sample was dumped at, the proposal re-keyed to that campaign's own
# identity and allocation, and the client building, certifying and
# submitting it for a real verdict. Nothing is fabricated and no
# acceptance is skipped -- only WHICH proposal the campaign is asked to
# lay out.
#
# Reports the same five things whether the Zone is accepted or refused,
# so a bounded recovery can never be read as a first-attempt success.
# ONE ORDINARY ZONE, AT DEFAULT SCALE, THROUGH THE REAL APPLICATION.
#
#   make godot-ordinary-live
#
# Everything else that runs live serves a NAMED proposal. This asks the
# campaign for whatever it would ordinarily compose, at the scale the
# diagnostic actually runs at, and then does what a player does in the
# order a player does it: enter, walk the last leg to a Check and press
# E on it, bring a station online and open its panel, return to the Hub
# without abandoning, and go back in.
#
# The walk is the LAST LEG only and says so. Whether a route across the
# Zone reaches every Check is `godot-traverse`'s measurement, with its
# own BLOCKED and UNRESOLVED outcomes.
ORDINARY_SAVES := $(CURDIR)/.ordinary-live-saves
godot-ordinary-live: godot-import
	rm -rf $(ORDINARY_SAVES)
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(ORDINARY_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default & \
	BRIDGE_PID=$$!; sleep 3; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start (port already serving?)"; exit 1; }; \
	$(GODOT) --headless --path godot -- --reload-phase=ordinary \
	  > /tmp/archipepsi-ordinary-live.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID; \
	grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )" \
	  /tmp/archipepsi-ordinary-live.log | tail -40; \
	if [ $$STATUS -ne 0 ]; then exit $$STATUS; fi; \
	if grep -q "SCRIPT ERROR" /tmp/archipepsi-ordinary-live.log; then \
	  echo "-- a script error was raised: a run that printed its report"; \
	  echo "-- and then died is not a pass."; \
	  grep -m5 "SCRIPT ERROR" /tmp/archipepsi-ordinary-live.log; \
	  exit 1; \
	fi

# THE HANDOFF AFTER A BUILD THAT COULD NOT HAPPEN. No bridge needed.
#
#   make godot-build-failure
#
# `ZoneController.setup` returns without creating a player when
# `ZoneBuilder` cannot route the rooms, and `Main._to_zone` used to carry
# on into `hud.bind_player(zone.player)` -- a null. This hands the real
# `Main` a Zone the router genuinely cannot place (`zone_08` of the
# declared sample, under the id it was dumped as) and checks what the
# player is left with: no crash, no half-built level in the tree, a Hub
# with a live player in it, and the failure reported to the bridge.
#
# The live half -- a real bridge, the bounded recovery and the parked
# Zone -- is `make godot-named-case CASE=zone_08 AT=8`.
godot-build-failure: godot-import
	$(GODOT) --headless --path godot -- --reload-phase=build-failure \
	  > /tmp/archipepsi-build-failure.log 2>&1; \
	STATUS=$$?; \
	grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )" \
	  /tmp/archipepsi-build-failure.log | tail -20; \
	if [ $$STATUS -ne 0 ]; then exit $$STATUS; fi; \
	if grep -q "SCRIPT ERROR" /tmp/archipepsi-build-failure.log; then \
	  echo "-- a script error was raised: the crash this gate exists"; \
	  echo "-- for prints its report and then dies."; \
	  grep -m5 "SCRIPT ERROR" /tmp/archipepsi-build-failure.log; \
	  exit 1; \
	fi

# `AT=N` SERVES THE PROPOSAL AS THE CAMPAIGN'S Nth ZONE, which is how a
# case that fails OFFLINE is reproduced live. Placement is seeded by
# `hash("<zone_id>|<theme>|layout")` and a campaign names its first Zone
# `zone_001`, so serving `zone_08`'s content as Zone 1 lays it out under
# a pose sequence it was never measured with -- and it routes. `AT=8`
# gives it back the id it was dumped under, and its placement seed with
# it: the campaign really does generate and abandon seven Zones first.
#
# `THEN=<case>` SERVES A SECOND PROPOSAL from the Zone's second request
# onward. Without it a Zone whose sample the engine cannot build fails
# identically on every retry -- which shows the budget and the
# exhaustion honestly and cannot show the other half: a failure followed
# by a replacement that really is built, certified and accepted. The
# ORDINARY provider cannot supply that half either: the fallback seeds
# composition on zone index and budget alone, so the recompose after a
# refusal returns byte-identical content. Measured, not assumed.
CASE ?= zone_05
AT ?= 1
THEN ?=
NAMED_CASE_SAVES := $(CURDIR)/.named-case-saves
godot-named-case: godot-import
	rm -rf $(NAMED_CASE_SAVES)
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(NAMED_CASE_SAVES) \
	  $(if $(THEN),ARCHIPEPSI_SAMPLE_THEN=$(if $(findstring /,$(THEN)),$(THEN),$(CURDIR)/godot/tests/fixtures/sample/$(THEN).json),) \
	  ARCHIPEPSI_SAMPLE_ZONE=$(if $(findstring /,$(CASE)),$(CASE),$(CURDIR)/godot/tests/fixtures/sample/$(CASE).json) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=sample \
	  --mock-scale=default & \
	BRIDGE_PID=$$!; sleep 3; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start (port already serving? bad CASE?)"; \
	  exit 1; }; \
	$(GODOT) --headless --path godot -- --reload-phase=named-case \
	  --named-case-at=$(AT) \
	  --named-case-source=$(if $(findstring /,$(CASE)),$(CASE),$(CURDIR)/godot/tests/fixtures/sample/$(CASE).json) \
	  > /tmp/archipepsi-named-case.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID; \
	grep -vE "^(ERROR|USER ERROR|WARNING)|^ *(at:|GDScript backtrace|\[[0-9]+\] )" \
	  /tmp/archipepsi-named-case.log | tail -70; \
	if [ $$STATUS -ne 0 ]; then exit $$STATUS; fi; \
	if grep -q "SCRIPT ERROR" /tmp/archipepsi-named-case.log; then \
	  echo "-- a script error was raised. A run that crashed and still"; \
	  echo "-- printed its report is not a pass: the missing-player"; \
	  echo "-- crash after a failed build printed one."; \
	  grep -m5 "SCRIPT ERROR" /tmp/archipepsi-named-case.log; \
	  exit 1; \
	fi

# THE CONSUMABLE SPEND, END TO END. Three phases, and the middle one is
# why this is not a single command:
#
#   1. A bridge makes a real campaign, through the real `on_ap_ready`.
#      The driver connects, asks for it and stops.
#   2. `tools/give_consumable.py` appends one interpretation to that
#      save. The fallback provider does not emit a `consumable`-slot
#      Action -- the slot is staged -- and this target is about the
#      expenditure rather than about generation.
#   3. A bridge is started again on the seeded save, and the driver
#      plays the sequence: an accepted use, a deduction held across a
#      round trip, a refusal that names what it refused, presses made
#      with the socket down and resent on reconnect, and the empty
#      supply. The measure is EFFECTS RUN against CHARGES AUTHORISED.
#
# The bridge is stopped between phases on purpose: a live engine holds
# the campaign in memory and would write it back over the seed.
# THE PROCESS BOUNDARY, which is a DIFFERENT boundary from a dropped
# socket and the one `_in_flight` cannot close by itself.
#
# Phase 3 authorises a charge, lets the effect happen with the settle
# report dropped, and kills its own process with a signal. Phase 4 is a
# genuinely fresh Godot against the same bridge and the same unrefilled
# deployment: it holds no list, no reservation and no memory, and
# everything it knows comes off the save. If the supply could be reused,
# phase 4's press would mint index 1 again and buy a second effect from
# the charge phase 3 already paid for.
#
# Phase 3 is EXPECTED to die, so its exit status proves nothing and is
# not read; the marker line it prints before the signal is.
godot-consumable-restart: godot-import
	rm -rf $(RESTART_SAVES)
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(RESTART_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback & \
	BRIDGE_PID=$$!; sleep 2; \
	$(GODOT) --headless --path godot -- --consumable-live --seed-only \
	  > /tmp/archipepsi-restart-seed.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; wait $$BRIDGE_PID 2>/dev/null; \
	if [ $$STATUS -ne 0 ]; then tail -20 /tmp/archipepsi-restart-seed.log; \
	  echo "-- no campaign was created"; exit $$STATUS; fi
	cd bridge && PYTHONPATH=. $(PY) tools/give_consumable.py \
	  $(RESTART_SAVES) --charges 3
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(RESTART_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback & \
	BRIDGE_PID=$$!; sleep 2; \
	$(GODOT) --headless --path godot -- --consumable-live \
	  --kill-after-launch > /tmp/archipepsi-restart-die.log 2>&1; \
	grep -q "KILLED AFTER AUTHORISING" /tmp/archipepsi-restart-die.log || { \
	  kill $$BRIDGE_PID 2>/dev/null; \
	  tail -25 /tmp/archipepsi-restart-die.log; \
	  echo "-- the first process never authorised anything, so there is"; \
	  echo "-- no expenditure for the second one to fail to reuse"; \
	  exit 1; }; \
	grep "KILLED AFTER AUTHORISING" /tmp/archipepsi-restart-die.log; \
	$(GODOT) --headless --path godot -- --consumable-live \
	  --after-kill > /tmp/archipepsi-restart-back.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; \
	grep -vE "^(ERROR|USER ERROR|WARNING|   at:|     at:|GDScript backtrace|       \[|         \[)" \
	  /tmp/archipepsi-restart-back.log; \
	if [ $$STATUS -ne 0 ]; then exit $$STATUS; fi; \
	grep -q "GODOT CONSUMABLE LIVE TESTS OK" \
	  /tmp/archipepsi-restart-back.log || exit 1

godot-consumable-live: godot-import
	rm -rf $(CONSUMABLE_SAVES)
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(CONSUMABLE_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start (port already serving?)"; exit 1; }; \
	$(GODOT) --headless --path godot -- --consumable-live --seed-only \
	  > /tmp/archipepsi-consumable-seed.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; wait $$BRIDGE_PID 2>/dev/null; \
	if [ $$STATUS -ne 0 ]; then \
	  tail -20 /tmp/archipepsi-consumable-seed.log; \
	  echo "-- no campaign was created; there is nothing to seed"; \
	  exit $$STATUS; \
	fi
	cd bridge && PYTHONPATH=. $(PY) tools/give_consumable.py \
	  $(CONSUMABLE_SAVES) --charges 5
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(CONSUMABLE_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not restart"; exit 1; }; \
	$(GODOT) --headless --path godot -- --consumable-live \
	  > /tmp/archipepsi-consumable-live.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID 2>/dev/null; \
	grep -vE "^(ERROR|USER ERROR|   at:|GDScript backtrace|       \[)" \
	  /tmp/archipepsi-consumable-live.log; \
	if [ $$STATUS -ne 0 ]; then exit $$STATUS; fi; \
	grep -q "GODOT CONSUMABLE LIVE TESTS OK" \
	  /tmp/archipepsi-consumable-live.log || exit 1; \
	if grep -qE "SCRIPT ERROR" /tmp/archipepsi-consumable-live.log; then \
	  echo "-- a runtime error was raised: the suite cannot vouch for itself"; \
	  exit 1; \
	fi

godot-integration: godot-import   # full loop through a live mock bridge, fresh state
	rm -rf $(INTEGRATION_SAVES)
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(INTEGRATION_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start (port already serving? see the traceback above)"; \
	  exit 1; }; \
	$(GODOT) --headless --path godot -- --integration-test \
	  > /tmp/archipepsi-integration.log 2>&1; \
	STATUS=$$?; kill $$BRIDGE_PID; \
	cat /tmp/archipepsi-integration.log; \
	if [ $$STATUS -ne 0 ]; then exit $$STATUS; fi; \
	if grep -q "SCRIPT ERROR" /tmp/archipepsi-integration.log; then \
	  echo "-- a script error was raised: a run that crashed and still"; \
	  echo "-- printed OK is not a pass. The exit-portal crash reached"; \
	  echo "-- ALL_CHECKS_CLEARED and reported OK before this guard."; \
	  grep "SCRIPT ERROR" /tmp/archipepsi-integration.log | sort -u; \
	  exit 1; \
	fi

# THE RE-SELECTION JOURNEY, at the scale its subject needs.
#
# Same driver, same live bridge, one control: an unhostable host
# measured by the engine, barred, re-selected, a late result from the
# proposal that was replaced, acceptance, a walk onto the return device
# and a restart that replays it. `godot-integration` runs at PROTOTYPE
# scale, where a Zone is three rooms -- and three rooms carry no branch,
# so they carry no return device and there is no host to bar. Measured:
# four consecutive Zones with no plug at all. So the bridge here is
# started at `--mock-scale=default`, which is the size the composer
# actually branches at.
godot-return-journey: godot-import
	rm -rf $(JOURNEY_SAVES)
	cd bridge && ARCHIPEPSI_SAVE_DIR=$(JOURNEY_SAVES) \
	  $(PY) -m archipepsi_bridge --ap=mock --epsilon=fallback \
	  --mock-scale=default & \
	BRIDGE_PID=$$!; sleep 2; \
	kill -0 $$BRIDGE_PID 2>/dev/null || { \
	  echo "bridge did not start (port already serving?)"; \
	  exit 1; }; \
	$(GODOT) --headless --path godot -- --integration-test \
	  --return-journey; \
	STATUS=$$?; kill $$BRIDGE_PID; exit $$STATUS
