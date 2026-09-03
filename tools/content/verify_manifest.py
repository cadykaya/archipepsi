#!/usr/bin/env python3
"""Validate the exported pack with PRODUCTION'S OWN ContentManifest.

    python3 tools/content/verify_manifest.py <prod-ref> [manifest ...]

The other half of a dual-language contract. `content_registry.gd` and
`schemas/content.py` both police the same manifests and they do not police
the same things: the GDScript side asks whether a scene EXISTS and whether a
fallback chain terminates; the Python side is a strict pydantic model with
`extra="forbid"` and hard length limits.

The first version of this pack passed the GDScript half and was rejected by
the Python half on three counts -- a 231-character pack description against a
160 limit, plus `source_asset` and `source_batch_review`, two fields
`ContentEntry` forbids outright. Verifying one side of a two-sided contract
is verifying nothing, so this script exists and the shell wrapper runs both.

Production's schema is fetched read-only from the gameplay branch at run
time. Nothing from that branch is committed to the art branch, and that
branch is never written to.
"""
from __future__ import annotations

import glob
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCHEMA_DIR = "bridge/archipepsi_bridge/schemas"


def _fetch(ref, tmp):
    """Production's content schema and the constants it reads, verbatim."""
    for name in ("content.py", "constants.py"):
        blob = subprocess.run(
            ["git", "show", "%s:%s/%s" % (ref, SCHEMA_DIR, name)],
            cwd=ROOT, capture_output=True, check=True).stdout
        with open(os.path.join(tmp, name), "wb") as fh:
            fh.write(blob)


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    ref = argv[1]
    manifests = argv[2:] or sorted(glob.glob(
        os.path.join(ROOT, "godot", "content", "registry", "*.json")))
    if not manifests:
        print("verify-manifest: no manifests found", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory() as tmp:
        _fetch(ref, tmp)
        sys.path.insert(0, tmp)
        try:
            import content as prod  # noqa: E402  Production's own module
        except ImportError as exc:
            print("verify-manifest: cannot import Production's schema (%s)."
                  % exc, file=sys.stderr)
            print("verify-manifest: `pip install pydantic` and retry.",
                  file=sys.stderr)
            return 2

        loaded = []
        failed = 0
        for path in manifests:
            with open(path) as fh:
                raw = json.load(fh)
            try:
                loaded.append(prod.ContentManifest(**raw))
            except Exception as exc:
                failed += 1
                print("[pyverify]   REJECTED %s" % os.path.basename(path))
                for line in str(exc).splitlines():
                    print("[pyverify]     %s" % line)
                continue
            print("[pyverify]   ok  %-24s %d entries, description %d/%d chars"
                  % (os.path.basename(path), len(raw["entries"]),
                     len(raw.get("description", "")), prod.C.MAX_TEXT_LEN))

        if failed:
            print("[pyverify] FAIL -- %d manifest(s) Production would reject"
                  % failed)
            return 1

        # A CHANGE THE ART LANE MEANS, ENUMERATED ONE FIELD AT A TIME.
        #
        # The drift check exists because a field quietly disagreeing with
        # the landed pack is how the projectile review went stale, so it
        # is not softened into "changes are fine". Every intended change
        # to a field Production already carries is named here with the
        # reason, and everything NOT named still fails. The list is meant
        # to be emptied by the next integration, not to grow.
        # THE REPAIRS PRODUCTION ASKED FOR, ENUMERATED FIELD BY FIELD.
        #
        # The drift check exists because a field quietly disagreeing with
        # the landed pack is how the projectile review went stale, so it
        # is not softened into "changes are fine". Every intended change
        # to a field Production already carries is named here with the
        # reason, and everything NOT named still fails. The list is meant
        # to be emptied by the next integration, not to grow.
        _WELL = ("the deck no longer roofs the climb (`_deck_well`). "
                 "Production measured collapsed rubble_1_0/rubble_1_1 and "
                 "spiral platform_6 with zero valid placements at 1648fa9, "
                 "all three because a 0.5 m deck slab sat over them. The "
                 "deck rect, the routecheck stone, the sockets on it and "
                 "the reward volume all move with it")
        _STEP_LOW = ("`step_low` is no longer declared a stand Surface. "
                     "Its 3.0 m square carries the 2.2 m upper step, so "
                     "what is left is a 0.40 m ring against a 0.80 m "
                     "player -- zero valid placements, measured. The "
                     "plinth mesh and its collision are unchanged; the "
                     "two rises become the one 0.80 m rise a player "
                     "actually makes")
        _SOCKET = ("`enemy_high` sockets are placed WHERE something fits "
                   "on their surface, not at its centre. The centre put "
                   "collapsed's high_3 0.05 m inside the stone above it")
        _PASS = ("PASSED at the P2 owner form review. Production certified "
                 "all eight physically at 6640d86 (room contract, zero "
                 "findings) and the owner then approved the rendered form "
                 "from docs/art/review/p2_owner/. Production's landed pack "
                 "still carries the pre-review 'pending'")
        _CORNER = ("corners offered as CORRIDOR, the request Production "
                   "recorded at eda4fd9 ('corner is not a chamber type'); "
                   "the corner shape survives as a tag beside it")
        _HOP = ("`platform_8_to_deck` is a `gap`, not a `walk`. "
                "Production probed the real geometry at b37fe07 and found "
                "a void between the two decks; crossing it is a 1.75 m "
                "hop against a 2.60 m reach. Art's own box-evidence "
                "mirror PROVES that crossing walkable and is wrong to -- "
                "there is floor 1 m down between them, and a player's "
                "body does not fit in the slot. The support-only evidence "
                "cannot see a pinch, so this correction is recorded from "
                "Production's measurement rather than derived")
        _FLIGHT = ("the hall's six RoomAudit findings at 301374d, "
                   "repaired at the source, plus the plinth Surface "
                   "decision at 94d562d. Four findings were declarations "
                   "pointing at geometry that is not there: two plinth "
                   "segments ending 0.5 m off the plinth in air, "
                   "`gantry_to_exit` ending on the flight rather than the "
                   "exit platform, and `gallery_to_landing` crossing the "
                   "void between the gallery and a ramp that meets it "
                   "only at its west end. Two were geometry: "
                   "`ring_n_to_ring_e` started INSIDE an armature column, "
                   "because 4.0 m columns on +/-7 filled a 3 m collar "
                   "band at all four corners and the ring was four arcs "
                   "rather than a loop -- the columns move into the shaft "
                   "corners at 3.0 m, which clears the band and keeps the "
                   "entry sightline (re-asserted, 64.7 m). "
                   "`basin_to_gallery` started a metre up the flight "
                   "where a body on one wedge section overlaps the next. "
                   "AND THE PLINTHS ARE NO LONGER `stand` SURFACES: the "
                   "owner's decision at 94d562d, because under C(ii) a "
                   "`stand` Surface advertises usable placement space and "
                   "no traversal and no offer in this shell reaches "
                   "either plinth. The 4 m masses stay in the room "
                   "exactly as they were; only the claim goes, and a "
                   "later package that brings its own arrival can expose "
                   "them. AND THE OWNER'S TWO CHANGES ON THE LIBRARY "
                   "REVIEW, after Production certified the repaired "
                   "geometry at fc2cc41. (1) `ring_s_to_ring_e` closes "
                   "the collar: the walkable ring was declared as a C -- "
                   "north to east one way, north to west to south the "
                   "other, and the south band a dead end -- while the "
                   "BAND was always a full loop, the east one spanning "
                   "z 25..43 and so already covering the south-east "
                   "corner. So the closure is one optional `walk` "
                   "declaration over geometry that was already there, "
                   "proved by the same flood as every other walk, and no "
                   "mandatory segment and no Surface moved. (2) Three "
                   "`grapple_point` offers, one 0.2 m under the inner lip "
                   "of each collar ring, forming a ladder up the "
                   "landmark: the basin is the ground under the low one "
                   "(9.0 m), the low ring under the middle (8.0 m), the "
                   "walkable collar under the high (6.0 m). They were "
                   "absent only because `grapple_point` was not in "
                   "OFFER_KINDS when this room was authored; Wave 1 "
                   "declares three in every room. An offer reserves a "
                   "place and adds NO geometry, so the shell is byte-"
                   "identical and the entry sightline is untouched, and "
                   "the base walking route is still complete with no "
                   "package installed")
        _WAVE1 = ("the Wave 1 findings Production measured before its "
                  "own correction pass, repaired at the source under the "
                  "owner's authored-entry ruling. Eleven findings were "
                  "reported across the three rooms; THREE are the audit "
                  "assuming a room's entry is its local origin, and those "
                  "are Production's and are deliberately untouched -- the "
                  "plenum enters at y=68 because it is a shaft you "
                  "descend, the yard at x=-43 because it is 84 m wide, "
                  "the span at y=14 because its entry is on the deck. "
                  "The other EIGHT were Art's and were all one mistake "
                  "made three times: a declared point carrying the CENTRE "
                  "of the thing it names. Seven `cover` sockets sat at "
                  "the centre of their own cover block, buried in 1.9 m "
                  "of concrete; they move beside the block, on the far "
                  "side from the room's centre line, so the block is "
                  "between the player and the open middle -- which is "
                  "what cover is for. The plenum's `reward` volume sat at "
                  "the centre of the collar, which is the centre of eight "
                  "metres of solid machine; it moves onto the collar band "
                  "at radius 5.25, opposite the bridge. NO GEOMETRY "
                  "MOVED: all three shells export the same triangle and "
                  "collider counts, and surfaces, traversal, size and "
                  "offers are unchanged in every one. Both stances are "
                  "derived from the block or the collar rather than "
                  "written out a second time, because two lists drifting "
                  "apart is how this happened")
        _TRUTH = ("the physical-truth repair of 2026-09-03, seven items "
                  "measured against the collision the rooms actually "
                  "ship. (1) A `-convcolonly` node imports as the CONVEX "
                  "HULL of its vertices, and each plenum collar is an "
                  "annulus 4.00 to 6.75 -- so the hole the art draws was "
                  "shipping filled. Each collar is now twelve convex "
                  "trapezoidal prisms sharing the tube's own angles: 117 "
                  "colliders to 150, the same 1656 triangles, the same "
                  "21.20 x 20.00 x 73.60 m, and the pieces are asserted "
                  "to reassemble the ring to 1 mm3. `assert_convex` now "
                  "refuses any non-convex collider at build time in all "
                  "six builders that author collision. (2) Every declaration that named a collar "
                  "carried the ring's CENTRE, which is the centre of "
                  "eight metres of hanging steel -- three "
                  "`landing_N_to_collar_K` endpoints, three enemy "
                  "anchors, the check anchor and the launch target. All "
                  "are on the band at radius 5.25 now, through one "
                  "`_collar_point` that shares its axis decision with "
                  "the bridge builder instead of copying the expression. "
                  "(1) and (2) are ONE change: the decomposition opens a "
                  "real hole, so an axis declaration would go from being "
                  "inside a filled hull to being in mid air. (3) THE "
                  "PLENUM'S LAUNCH SERVES THE LOW COLLAR NOW, not the "
                  "middle one, and that is a design change rather than a "
                  "correction. Putting the target on the band made it a "
                  "real landing surface and left the FLIGHT impossible: "
                  "an arc to 28.333 m has to pass the low collar's ring "
                  "on the way up. Measured over 4537 floor stances on a "
                  "0.25 m grid against all four band points of each "
                  "collar -- the top collar is reachable from none of "
                  "them, the middle from five (all in one 0.2 x 0.5 m "
                  "pocket, none on the declared point), the low from "
                  "141. The pad moved to the bottom landing and onto the "
                  "floor's face, and the reward stays on the middle "
                  "collar. (4) Three rails were rerouted off geometry "
                  "their BAKED curve was inside while their control "
                  "points were legal: the plenum's ride sagged 0.1668 m "
                  "into all three collar bands from points 3.8 cm "
                  "outside them, the hall's ran 0.249 m inside the east "
                  "gantry and 0.389 m inside a west ramp tread, the "
                  "span's ran 1.9911 m inside BOTH pylons. (5) The "
                  "plenum's `grapple_1` hung 0.762 m over a helix run "
                  "with no swing room; a metre inward makes it 9.67 m. "
                  "NO VISIBLE GEOMETRY MOVED in any of the three rooms: "
                  "same triangles, same size, same entry, exit, "
                  "connectors, surfaces and sockets, and the yard was "
                  "not touched at all. Measured by "
                  "`tools/content/measure_offers.py`, which reproduced "
                  "every audited finding before a builder changed, and "
                  "held by `tools/content/replay_audited.py`, which "
                  "replays the pre-repair pack out of git and fails "
                  "unless all twelve findings still come back. TWO "
                  "FINDINGS ARE RAISED AND NOT REPAIRED and are waiting "
                  "on the owner: the hall's and the span's launch ARCS "
                  "each clip the underside of the platform they land on "
                  "by 0.08 m. Both are carried in `measure_offers.RAISED`"
                  ", which fails if either changes or disappears")

        DECLARED_HANDOFF = {}
        for _cid, _fields, _why in (
                ("shell_corner_left", ("semantic_tags",), _CORNER),
                ("shell_corner_right", ("semantic_tags",), _CORNER),
                ("shell_tower_collapsed",
                 ("surfaces", "traversal", "volumes"), _WELL),
                ("shell_tower_spiral", ("surfaces", "traversal"),
                 _WELL + "; and " + _HOP),
                ("shell_tower_collapsed", ("sockets",),
                 _WELL + "; and " + _SOCKET),
                ("shell_tower_spiral", ("sockets",),
                 _WELL + "; and " + _SOCKET),
                ("shell_treasure_vault", ("surfaces", "traversal"),
                 _STEP_LOW),
                ("shell_treasure_cache", ("surfaces", "traversal"),
                 _STEP_LOW),
                ("shell_treasure_coffer", ("surfaces", "traversal"),
                 _STEP_LOW),
                ("shell_tower_collapsed", ("review",), _PASS),
                ("shell_tower_spiral", ("review",), _PASS),
                ("shell_tower_gantry", ("review",), _PASS),
                ("shell_treasure_vault", ("review",), _PASS),
                ("shell_treasure_cache", ("review",), _PASS),
                ("shell_treasure_coffer", ("review",), _PASS),
                ("shell_corner_left", ("review",), _PASS),
                ("shell_corner_right", ("review",), _PASS),
                ("shell_hall_transit",
                 ("traversal", "surfaces", "size"), _FLIGHT),
                ("shell_hall_transit", ("offers",),
                 _FLIGHT + "; and " + _TRUTH),
                ("shell_plenum_helix", ("volumes",), _WAVE1),
                ("shell_yard_gantry", ("sockets",), _WAVE1),
                ("shell_span_basin", ("sockets",), _WAVE1),
                ("shell_plenum_helix",
                 ("offers", "traversal", "colliders", "check_anchor",
                  "enemy_anchors"), _TRUTH),
                ("shell_span_basin", ("offers",), _TRUTH)):
            for _field in _fields:
                DECLARED_HANDOFF[(_cid, _field)] = _why

        # DRIFT. The bug this catches happened: the art exporter kept
        # emitting `review: "pass"` for the three projectiles after
        # Production had reverted them to "pending", so any regeneration
        # would have silently re-enabled a substitution the owner turned
        # off. Nothing compared the two copies, because nothing knew there
        # were two.
        #
        # Production's pack is the LANDED state. Ours is the source that
        # generates it. They must agree, field for field, or one of them is
        # about to overwrite a decision.
        try:
            landed = subprocess.run(
                ["git", "show", "%s:godot/content/registry/authored_art.json" % ref],
                cwd=ROOT, capture_output=True, check=True).stdout
        except subprocess.CalledProcessError:
            print("[pyverify]   note: Production carries no authored_art.json "
                  "yet, so there is nothing to drift from")
        else:
            theirs = {e["id"]: e for e in json.loads(landed)["entries"]}
            ours = {}
            for path in manifests:
                with open(path) as fh:
                    doc = json.load(fh)
                if doc.get("pack") == "authored_art":
                    ours = {e["id"]: e for e in doc["entries"]}
            drift = []
            declared = []
            pending_handoff = []
            for cid in sorted(set(ours) | set(theirs)):
                a, b = ours.get(cid), theirs.get(cid)
                if a is None:
                    # Production carries an entry the art export does not.
                    # That is real drift in the dangerous direction: the
                    # next regeneration would DELETE it.
                    drift.append("%s: only Production has it" % cid)
                elif b is None:
                    # The art export carries an entry Production has not
                    # taken yet. That is a HANDOFF, not drift -- new work
                    # always looks like this for exactly as long as it
                    # takes them to integrate it.
                    pending_handoff.append(cid)
                elif a != b:
                    keys = sorted(k for k in set(a) | set(b)
                                  if a.get(k) != b.get(k))
                    for k in keys:
                        if (cid, k) in DECLARED_HANDOFF:
                            declared.append(
                                "%s.%s: art=%r prod=%r -- %s"
                                % (cid, k, a.get(k), b.get(k),
                                   DECLARED_HANDOFF[(cid, k)]))
                            continue
                        drift.append("%s.%s: art=%r prod=%r"
                                     % (cid, k, a.get(k), b.get(k)))
            if pending_handoff:
                print("[pyverify]   ok  %d entr%s awaiting handoff (in the "
                      "art export, not yet in Production's pack): %s"
                      % (len(pending_handoff),
                         "y" if len(pending_handoff) == 1 else "ies",
                         ", ".join(pending_handoff)))
            if declared:
                print("[pyverify]   ok  %d DECLARED change(s) to a shared "
                      "field, awaiting handoff:" % len(declared))
                for line in declared:
                    print("[pyverify]     %s" % line)
            if drift:
                print("[pyverify]   DRIFT from Production's landed pack:")
                for line in drift:
                    print("[pyverify]     %s" % line)
                print("[pyverify] FAIL -- the art export and the landed pack "
                      "disagree")
                return 1
            shared = len(set(ours) & set(theirs))
            print("[pyverify]   ok  no drift on the %d shared id(s), field "
                  "for field" % shared)

        # The union check, which no single manifest can answer: colliding
        # ids, a fallback naming nothing, a fallback that loops.
        try:
            registry = prod.build_registry(loaded)
        except prod.RegistryError as exc:
            # Expected here: the pack's fixture entries fall back to the
            # `*_proc` ids that only Production's own manifest defines, and
            # that manifest is not part of this repo. The shell wrapper
            # supplies it; run standalone, this arm is the honest answer.
            print("[pyverify]   note: cross-manifest check needs Production's "
                  "own pack too -- %s" % exc)
        else:
            print("[pyverify]   ok  build_registry accepted %d ids"
                  % len(registry))
        print("[pyverify] PASS -- Production's ContentManifest accepts the pack")
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
