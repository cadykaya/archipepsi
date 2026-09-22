# Archipepsi — build and test entry points.
#
# `make setup` obtains the pinned Archipelago checkout; everything else
# assumes it exists (or ARCHIPELAGO_ROOT points at one).

AP := $(or $(ARCHIPELAGO_ROOT),.archipelago)
PY := python3

# Mandatory for every AP entry point: importing CommonClient/Generate runs
# ModuleUpdate.update(), which drops into a bare input() without a TTY.
export SKIP_REQUIREMENTS_UPDATE = 1

.PHONY: apworld bridge doctor godot-graphs zone-fixtures zone-sample dual-real dual-real-soak export godot-activity godot-affordance godot-blink godot-boot godot-content godot-hud godot-import godot-integration godot-integration-quiet godot-integration-variant-live godot-return-journey godot-lab godot-legible godot-movement godot-physics godot-playtest3a godot-reload godot-room godot-room-contract godot-rules godot-stats godot-rail-carrier godot-rail-junction godot-passing-platforms godot-counterfire godot-mass-class godot-unweighted godot-target-facing godot-rail-zone godot-zone-state godot-test godot-traverse godot-verbs godot-zone-audit host mutate-bridge notices physics-vectors rules-fixture seed seed-multi setup smoke test test-apworld test-bridge test-schemas railway-shots verbs-fixture version world-install zone-shots

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

# The rule suite's snapshot is a real fold, and this is the fold that
# makes it. Regenerate rather than editing the JSON.
rules-fixture:
	$(PY) bridge/archipepsi_bridge/fixtures/make_rules_snapshot.py

verbs-fixture:
	$(PY) bridge/archipepsi_bridge/fixtures/make_verbs_snapshot.py

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
