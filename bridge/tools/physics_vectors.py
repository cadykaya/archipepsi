"""Generate the shared package-digest vectors.

    make physics-vectors        # or: cd bridge && python3 tools/physics_vectors.py

**Generated, never hand-edited.** Every vector's `canonical` and
`digest` come from the production path — `physics.canonical_bytes` and
`physics.package_digest` — so the file cannot drift from the serializer
it documents. A generator with its own copy of the recipe would be a
second implementation, which is the thing the file exists to prevent.

Each vector carries the structured `package` input as well as the
expected output. **Both lanes construct from `package` and run their own
production path**; comparing `canonical` as well as `digest` is what
says whether a mismatch is a construction difference or a hashing one.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Runnable straight from a checkout, installed or not: the script's own
# directory is what lands on sys.path, and that is `tools/`.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from archipepsi_bridge.schemas import physics as P  # noqa: E402

#: A GENERATOR, not a schema. It lives beside `mutate.py` rather than in
#: `archipepsi_bridge/schemas/` because the packet mirrors that directory
#: as the binding contract, and build tooling is not part of it.
OUT = (Path(__file__).resolve().parents[2] / "godot" / "tests"
       / "fixtures" / "physics_digest_vectors.json")

_BASE = {
    "package_id": "basin_bridge",
    "latch_conditions": [{"latch_id": "bridge_down",
                          "kind": "CONSTRAINT_STATE",
                          "detail": "hinge at rest below 5 degrees"}],
    "vector_latches": [0],
    "required_latches": ["bridge_down"],
    "on_mandatory_route": True,
    "setup": {"bodies": [{"body_id": "crate_a", "mass_kg": 80.0,
                          "constrained": False}],
              "solver": {"iterations": 8, "fixed_step_hz": 60.0,
                         "settle_timeout_s": 8.0},
              "scene_digest": "0123456789abcdef"},
    "reference_solution": {"steps": ["push_crate", "wait_for_settle"]},
}


#: A second base, whose whole job is to make the ORDERING rules in
#: `canonical_bytes` load-bearing. With one required latch and one
#: promoted index, `sorted(required_latches)` and `list(vector_latches)`
#: are interchangeable with each other and with doing nothing at all —
#: the vectors would pass with any of them, which is a vector set that
#: cannot see the serializer it is meant to pin.
_MULTI = {
    "package_id": "sluice_gate",
    "latch_conditions": [
        {"latch_id": "sluice_open", "kind": "CONSTRAINT_STATE",
         "detail": "gate above the waterline"},
        {"latch_id": "anchor_set", "kind": "ATTACH_SENSOR",
         "detail": "pin seated in the socket"},
        {"latch_id": "basin_full", "kind": "WEIGHT_THRESHOLD",
         "detail": "float arm over 40 kg"}],
    # Deliberately not ascending: promotion order is the STATE VECTOR's
    # bit order, so it is content, and sorting it here would silently
    # renumber the verifier's dimensions.
    "vector_latches": [2, 0, 1],
    # Deliberately not sorted: this is a set of names, so canonical form
    # orders it and two declarations of the same set must agree.
    "required_latches": ["sluice_open", "basin_full", "anchor_set"],
    "on_mandatory_route": True,
    "setup": None,
    "reference_solution": None,
}


def _derive(base: dict, **over) -> dict:
    out = json.loads(json.dumps(base))
    for path, value in over.items():
        node = out
        parts = path.split(".")
        for key in parts[:-1]:
            node = node[key]
        node[parts[-1]] = value
    return out


def _with(**over) -> dict:
    return _derive(_BASE, **over)


def vectors() -> list[dict]:
    """The cases, chosen so each isolates one way to diverge."""
    cases = [
        ("a fully specified load-bearing package", _BASE),
        ("the same package with a moved scene",
         _with(**{"setup.scene_digest": "fedcba9876543210"})),
        ("empty: no setup, no solution, no latches",
         {"package_id": "empty"}),
        ("unicode and punctuation in a detail",
         _with(**{"latch_conditions": [
             {"latch_id": "bridge_down", "kind": "CONSTRAINT_STATE",
              "detail": 'hinge ≤ 5°, "at rest"'}]})),
        # Float formatting is the classic cross-language divergence:
        # a language printing 80.0 as "80" produces a different string
        # for the same number.
        ("integral floats, which must not print as integers",
         _with(**{"setup.bodies": [{"body_id": "crate_a",
                                    "mass_kg": 80.0,
                                    "constrained": False}],
                  "setup.solver": {"iterations": 8, "fixed_step_hz": 60.0,
                                   "settle_timeout_s": 8.0}})),
        # Key order in the INPUT must not reach the output.
        ("declaration order that differs from canonical order",
         _with(**{"latch_conditions": [
             {"detail": "hinge at rest below 5 degrees",
              "kind": "CONSTRAINT_STATE", "latch_id": "bridge_down"}]})),
        # The ordering triple. Two of the three fields the canonical form
        # touches are sequences, and they are treated OPPOSITELY:
        # `required_latches` is a set and gets sorted, `vector_latches` is
        # the state vector's bit order and is preserved. One vector each
        # way pins both, and the multi base is what makes them differ.
        ("several requirements and promotions, declared out of order",
         _MULTI),
        ("the same requirements, declared already sorted",
         _derive(_MULTI, required_latches=["anchor_set", "basin_full",
                                           "sluice_open"])),
        ("the same latches promoted in a different bit order",
         _derive(_MULTI, vector_latches=[0, 1, 2])),
    ]
    out = []
    for name, payload in cases:
        pkg = P.PhysicsPackage.model_validate(payload)
        raw = P.canonical_bytes(pkg)
        out.append({
            "name": name,
            "package": payload,
            "canonical": raw.decode("utf-8"),
            "digest": P.package_digest(pkg),
        })
    return out


def main() -> None:
    body = {
        "_comment": (
            "GENERATED by archipepsi_bridge.schemas.physics_vectors; do "
            "not hand-edit. Both lanes CONSTRUCT from `package` and run "
            "their own production serializer, then compare `canonical` "
            "and `digest`. Hashing the stored `canonical` string proves "
            "the file is self-consistent and nothing about the code."),
        "recipe": [
            "construct the package from `package`",
            "build the canonical object: package_id, latch_conditions "
            "(latch_id, kind, detail), vector_latches, required_latches, "
            "setup (bodies as body_id/mass_kg/constrained, scene_digest, "
            "solver as iterations/fixed_step_hz/settle_timeout_s), "
            "reference_solution as a list of steps; absent setup and "
            "solution are null",
            "json with sorted keys and separators (',', ':')",
            "sha256 over utf-8, hex, first 16 characters",
        ],
        "vectors": vectors(),
    }
    OUT.write_text(json.dumps(body, indent=2, ensure_ascii=False) + "\n",
                   encoding="utf-8")
    print(f"wrote {OUT}")
    for v in body["vectors"]:
        print(f"  {v['digest']}  {v['name']}")


if __name__ == "__main__":
    main()
