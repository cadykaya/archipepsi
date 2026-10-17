"""The Integration gate's Godot shards cover every target, once.

The serial job that ran these had grown past its 30-minute cap and was
cancelled on every run (2026-10-17). Splitting it into shards
(`tools/ci/godot_shards.txt`) is only safe if nothing falls out on the
way: a target missing from every shard is a suite that silently stopped
being run, and the gate would stay green while meaning less.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHARDS = ROOT / "tools" / "ci" / "godot_shards.txt"
WORKFLOW = ROOT / ".github" / "workflows" / "integration.yml"
MAKEFILE = ROOT / "Makefile"

#: The targets the serial job ran, in its order, when it was split. A new
#: suite is added here AND to a shard; removing one is a decision, made here.
SERIAL_JOB_TARGETS = (
    "godot-boot",
    "godot-test",
    "godot-hud",
    "godot-rules",
    "godot-stats",
    "godot-lab",
    "godot-affordance",
    "godot-verbs",
    "godot-blink",
    "godot-content",
    "godot-activity",
    "godot-room",
    "godot-room-contract",
    "godot-graphs",
    "godot-movement",
    "godot-zone-audit",
    "godot-legible",
    "godot-physics",
    "godot-traverse",
    "godot-return-placement",
    "godot-build-failure",
    "godot-exit-reach",
    "godot-passenger-carry",
    "godot-rail-carrier",
    "godot-rail-junction",
    "godot-passing-platforms",
    "godot-counterfire",
    "godot-counterfire-hosted",
    "godot-mass-class",
    "godot-unweighted",
    "godot-target-facing",
    "godot-rail-zone",
    "godot-rail-gantry",
    "godot-rail-network",
    "godot-gantry-census",
    "godot-enemy-footing",
    "godot-machine-life",
    "godot-bombs",
    "godot-zone-state",
    "godot-roster",
    "godot-enemy-art",
    "godot-actuator",
    "godot-constraints",
    "godot-archive",
    "godot-consumable",
    "godot-encounter",
    "godot-signal-graph",
    "godot-signal-verbs",
    "godot-latched-route",
    "godot-theme-pack",
    "godot-carry",
    "godot-transport",
    "godot-held-route",
    "godot-reversible",
    "godot-verb-runtime",
    "godot-status-family",
    "godot-status-kinetic",
    "godot-combat-fairness",
    "godot-flyer-room",
    "godot-resume",
    "godot-minor-claim",
    "godot-menu-shell",
    "godot-equipment-face",
    "godot-minimap",
    "godot-map-face",
    "godot-journal-face",
    "godot-import",
    "godot-consumable-live",
    "godot-consumable-restart",
    "godot-latched-route-live",
    "godot-lever-route-live",
    "godot-transport-live",
    "godot-reversible-live",
    "godot-candidate-live",
    "godot-bombs-live",
    "godot-resume-live",
    "godot-ordinary-live",
    "godot-integration",
    "godot-integration-quiet",
    "godot-integration-variant-live",
    "godot-reload",
)


def _shards() -> dict[int, list[str]]:
    shards: dict[int, list[str]] = {}
    for line in SHARDS.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        number, _, targets = line.partition(":")
        shards[int(number)] = targets.split()
    return shards


def test_every_target_is_in_exactly_one_shard():
    listed = [t for targets in _shards().values() for t in targets]
    duplicated = sorted({t for t in listed if listed.count(t) > 1})
    missing = sorted(set(SERIAL_JOB_TARGETS) - set(listed))
    extra = sorted(set(listed) - set(SERIAL_JOB_TARGETS))
    assert not duplicated, f"in more than one shard: {duplicated}"
    assert not missing, f"no longer run by any shard: {missing}"
    assert not extra, (f"in a shard but not in SERIAL_JOB_TARGETS (add it "
                       f"there too): {extra}")


def test_every_target_exists_in_the_makefile():
    defined = set(re.findall(r"^([a-z0-9-]+):", MAKEFILE.read_text(), re.M))
    unknown = sorted(t for targets in _shards().values() for t in targets
                     if t not in defined)
    assert not unknown, f"not a Makefile target: {unknown}"


def test_the_workflow_runs_every_shard():
    shards = sorted(_shards())
    text = WORKFLOW.read_text()
    matrix = re.search(r"shard:\s*\[([0-9,\s]+)\]", text)
    assert matrix, "the godot job has no shard matrix"
    assert sorted(int(n) for n in matrix.group(1).split(",")) == shards
    assert "tools/ci/run_shard.sh ${{ matrix.shard }}" in text
