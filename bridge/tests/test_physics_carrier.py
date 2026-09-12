"""A physics package, from the engine's proposal to persistent state.

`AMALGAM_BRIDGE.md` §5.6 put three carriers to the engine lane and
**option 2 was taken**: a package is a physical fact, like the layout,
so it arrives inside `layout_result`, is validated before anything is
committed, and travels afterwards inside the accepted manifest. Nothing
about it is on the Zone — the Zone is Epsilon's output surface, and
`LatchCondition.detail` and `ReferenceSolution.steps` are what the
engine must observe and the engine's own script.

**Every step here goes through a real handler.** `handle_layout_result`
and `handle_progress`, the same ones the socket calls. A test that
called `layout.validate` directly would prove the rule is decidable and
nothing about whether the path reaches it — which is the failure this
project keeps finding in its own measurements.
"""

from __future__ import annotations

import pytest
from pydantic import TypeAdapter, ValidationError

from archipepsi_bridge import store
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import physics as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.campaign import IntentError
from archipepsi_bridge.schemas.protocol import ClientMessage

from .conftest import connected_engine, drain, place_layout as _place, run
from .test_physics_contract import _package, _proved

_ADAPTER = TypeAdapter(ClientMessage)


def _placed(zone, room_id: str, content_ref: str, package) -> dict:
    return P.PlacedPackage(
        package_id=package.package_id, zone_id=zone.zone_id,
        room_id=room_id, content_ref=content_ref,
        package=package).model_dump()


async def _zone_with_a_shell(engine):
    """A generated Zone, and a room with content a package can realize.

    Ordinary generation, not a fixture: the point is that the identities
    a package binds to are ones a real Zone actually declares.
    """
    for _ in range(4):
        await engine.handle_request_next_zone(False)
        await drain()
        zid = engine.save.active_zone_id
        zone = engine.save.zone_by_id(zid).zone
        for ch in zone.chambers:
            if ch.shell_id:
                return zid, zone, ch.id, f"shell:{ch.shell_id}"
            if ch.features:
                return zid, zone, ch.id, f"feature:{ch.features[0].tag}"
        await engine.handle_enter_zone(zid)
        await engine.handle_abandon_zone(zid)
    pytest.skip("no Zone with authored or affordance content in four tries")


async def _committed(tmp_path, packages=None, *, config=C.DEFAULT_CONFIG):
    """Generate, offer a layout carrying `packages(zone, room, ref)`."""
    engine, _ = await connected_engine(tmp_path, config=config)
    zid, zone, room, ref = await _zone_with_a_shell(engine)
    layout = _place(zone)
    if packages is not None:
        layout["packages"] = packages(zone, room, ref)
    await engine.handle_layout_result(_ADAPTER.validate_python(
        {"type": "layout_result", "zone_id": zid, "layout": layout}))
    return engine, zid, zone, room, ref


# --- the accepted path ----------------------------------------------------

def test_an_accepted_package_is_persisted_with_the_manifest(tmp_path):
    """Where option 2 puts it: in the committed layout, under the same
    digest, so a package cannot be swapped under a Zone that was
    certified carrying a different one."""
    async def go():
        pkg = _proved(_package("counterweight"))
        engine, zid, zone, room, ref = await _committed(
            tmp_path, lambda z, r, c: [_placed(z, r, c, pkg)])
        rec = engine.save.zone_by_id(zid)
        assert rec.manifest is not None, "the layout was refused"
        carried = rec.manifest["packages"]
        assert [p["package_id"] for p in carried] == ["counterweight"]
        assert carried[0]["room_id"] == room
        assert carried[0]["content_ref"] == ref
        assert carried[0]["zone_id"] == zone.zone_id
        # And nothing about it reached the Zone, which is the whole
        # reason for this carrier.
        assert "packages" not in zone.model_dump()
    run(go())


def test_a_zone_with_no_packages_still_commits(tmp_path):
    """The control. Every Zone today has none, so a rule that refused an
    empty set would be refusing everything while looking strict."""
    async def go():
        engine, zid, _z, _r, _c = await _committed(tmp_path)
        rec = engine.save.zone_by_id(zid)
        assert rec.manifest is not None
        assert rec.manifest["packages"] == []
    run(go())


# --- unknown identities ---------------------------------------------------

@pytest.mark.parametrize("what", ["zone", "room", "content"])
def test_a_package_bound_to_the_wrong_thing_is_refused(tmp_path, what):
    """Valid in itself, attached to something else.

    A package that parses and describes a real mechanism, filed under
    another Zone, a room this Zone does not have, or content that room
    never declared. Each would commit a manifest saying the engine
    measured something it did not.
    """
    async def go():
        pkg = _proved(_package("counterweight"))

        def build(zone, room, ref):
            entry = _placed(zone, room, ref, pkg)
            if what == "zone":
                entry["zone_id"] = "zone_999"
            elif what == "room":
                entry["room_id"] = "c999"
            else:
                entry["content_ref"] = "shell:not_a_shell"
            return [entry]

        engine, zid, *_ = await _committed(tmp_path, build)
        rec = engine.save.zone_by_id(zid)
        assert rec.manifest is None, (
            "a package bound to the wrong thing was committed anyway")
    run(go())


def test_a_placement_and_its_package_must_name_the_same_package(tmp_path):
    """Two spellings of one fact, caught where they are written."""
    with pytest.raises(ValidationError, match="two spellings of one fact"):
        P.PlacedPackage(package_id="a", zone_id="zone_001", room_id="c001",
                        content_ref="shell:x", package=_package("b"))


# --- evidence -------------------------------------------------------------

def test_a_load_bearing_package_without_evidence_refuses_the_layout(tmp_path):
    """**And is never dropped.** Committing the manifest without it
    would build the room and leave the mechanism inert: the content the
    engine asked for, quietly downgraded, with nothing saying so.

    This is also the accessibility guarantee, stated as a test rather
    than as a promise — while no engine produces evidence, no latch can
    become load-bearing, so the first playable chain cannot come to
    depend on one.
    """
    async def go():
        engine, zid, *_ = await _committed(
            tmp_path,
            lambda z, r, c: [_placed(z, r, c, _package("counterweight"))])
        rec = engine.save.zone_by_id(zid)
        assert rec.manifest is None
        assert rec.state != "ACTIVE", "a refusal has to change something"
    run(go())


def test_evidence_recorded_for_another_package_is_refused(tmp_path):
    """A replay proves something about the thing it replayed."""
    async def go():
        borrowed = _proved(_package("other")).evidence
        pkg = _package("counterweight").model_copy(
            update={"evidence": borrowed})
        engine, zid, *_ = await _committed(
            tmp_path, lambda z, r, c: [_placed(z, r, c, pkg)])
        assert engine.save.zone_by_id(zid).manifest is None
    run(go())


def test_evidence_for_another_revision_of_the_package_is_refused(tmp_path):
    """The package changed after it was measured. The digest is what
    notices, and it has to be reached through the acceptance path."""
    async def go():
        proved = _proved(_package("counterweight", detail="crate at rest"))
        edited = proved.model_copy(update={
            "latch_conditions": (P.LatchCondition(
                latch_id="l0", kind="CONSTRAINT_STATE",
                detail="crate two metres left"),)})
        assert P.package_digest(edited) != edited.evidence.content_digest
        engine, zid, *_ = await _committed(
            tmp_path, lambda z, r, c: [_placed(z, r, c, edited)])
        assert engine.save.zone_by_id(zid).manifest is None
    run(go())


@pytest.mark.parametrize("wrong", ["one_package", 3, {"counterweight": {}}])
def test_packages_that_are_not_a_list_are_refused(tmp_path, wrong):
    """The engine's payload is a `dict` off the wire, so this field can
    arrive as anything JSON can spell. Found by mutation: the refusal
    was there and nothing had ever sent it a non-list, so removing the
    check left the suite green."""
    async def go():
        engine, zid, *_ = await _committed(tmp_path, lambda z, r, c: wrong)
        assert engine.save.zone_by_id(zid).manifest is None
    run(go())


def test_a_malformed_package_entry_refuses_rather_than_skips(tmp_path):
    async def go():
        engine, zid, *_ = await _committed(
            tmp_path, lambda z, r, c: [{"package_id": "x"}])
        assert engine.save.zone_by_id(zid).manifest is None
    run(go())


# --- latch events ---------------------------------------------------------

async def _latched_zone(tmp_path):
    """A committed Zone carrying one accepted, non-load-bearing package.

    Non-load-bearing on purpose: a latch must not be load-bearing while
    nothing measures it, so what is being tested is the RECORDING of a
    consequence, not a route depending on one.
    """
    pkg = _package("counterweight", promote=(), required=())
    assert not pkg.load_bearing
    engine, zid, zone, room, ref = await _committed(
        tmp_path, lambda z, r, c: [_placed(z, r, c, pkg)])
    manifest = engine.save.zone_by_id(zid).manifest
    assert manifest is not None, "the layout was refused"
    # NOT MERELY COMMITTED: carrying the package. Without this the
    # refusal tests below pass on "this Zone accepted no packages at
    # all", which is a different sentence and a weaker claim.
    assert [p["package_id"] for p in manifest["packages"]] == [
        "counterweight"]
    await engine.handle_enter_zone(zid)
    return engine, zid


def _fire(zone_id, package_id="counterweight", latch_id="l0"):
    return _ADAPTER.validate_python(
        {"type": "latch_fired", "zone_id": zone_id,
         "package_id": package_id, "latch_id": latch_id})


def test_a_latch_is_recorded_under_its_global_identity(tmp_path):
    """`package_id/latch_id`, never a bare latch id: two packages may
    both call a latch `bridge_down`."""
    async def go():
        engine, zid = await _latched_zone(tmp_path)
        await engine.handle_progress(_fire(zid))
        assert engine.save.zone_by_id(zid).progress.latched == (
            "counterweight/l0",)
    run(go())


@pytest.mark.parametrize("package_id,latch_id,says", [
    ("no_such_package", "l0", "accepted no physics package"),
    ("counterweight", "no_such_latch", "declares no latch"),
])
def test_a_latch_no_accepted_package_declares_is_refused(
        tmp_path, package_id, latch_id, says):
    """The `record_key`-accepts-anything defect, not repeated.

    Checked against the packages the COMMITTED MANIFEST accepted, not
    against the message. A latch nobody placed would otherwise become
    permanent save data describing nothing, and monotone sets never give
    anything back.
    """
    async def go():
        engine, zid = await _latched_zone(tmp_path)
        with pytest.raises(IntentError, match=says):
            await engine.handle_progress(_fire(zid, package_id, latch_id))
        assert engine.save.zone_by_id(zid).progress.latched == ()
    run(go())


def test_a_latch_before_any_layout_is_committed_is_refused(tmp_path):
    """No manifest, no accepted packages, nothing measured — so nothing
    can have latched."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, _zone, _room, _ref = await _zone_with_a_shell(engine)
        await engine.handle_enter_zone(zid)
        assert engine.save.zone_by_id(zid).manifest is None
        with pytest.raises(IntentError, match="holds none"):
            await engine.handle_progress(_fire(zid))
    run(go())


def test_the_same_latch_twice_is_one_latch(tmp_path):
    """Monotone by construction (Design 2 §5.7), so a resend after a
    dropped connection is the normal case and never an error."""
    async def go():
        engine, zid = await _latched_zone(tmp_path)
        await engine.handle_progress(_fire(zid))
        before = store.load_save(engine._save_path)
        await engine.handle_progress(_fire(zid))
        await engine.handle_progress(_fire(zid))
        after = engine.save.zone_by_id(zid).progress
        assert after.latched == ("counterweight/l0",)
        assert before.zone_by_id(zid).progress == after, (
            "a duplicate event rewrote the save")
    run(go())


def test_a_latched_consequence_survives_a_reload(tmp_path):
    """Quitting is a reset, and §5.7 says a latch is never cleared by
    one. The live signal is not the state; the approved consequence is,
    and it is read back off disk by a new process."""
    async def go():
        engine, zid = await _latched_zone(tmp_path)
        await engine.handle_progress(_fire(zid))
        await engine.handle_exit_zone(zid)
        await drain()

        engine.save = store.load_save(engine._save_path)
        rec = engine.save.zone_by_id(zid)
        assert rec.progress.latched == ("counterweight/l0",)
        # And the packages it was validated against came back with it,
        # so the next latch is checked against the same set.
        assert [p["package_id"] for p in rec.manifest["packages"]] == [
            "counterweight"]
        await engine.handle_enter_zone(zid)
        await engine.handle_progress(_fire(zid, "counterweight", "l0"))
        assert engine.save.zone_by_id(zid).progress.latched == (
            "counterweight/l0",)
    run(go())


def test_the_snapshot_carries_the_latches_and_adds_no_second_carrier(tmp_path):
    """One carrier: the `ZoneRecord` the game already reads.

    `main.gd::_to_zone` is driven by `_on_snapshot` and takes progress
    from `BridgeClient.active_zone()`. A field on `zone_ready` would be
    a second copy of one fact on a different message — which this lane
    committed once already, for `progress`, and reverted.
    """
    import json

    async def go():
        engine, zid = await _latched_zone(tmp_path)
        await engine.handle_progress(_fire(zid))
        snap = json.loads(engine.snapshot().model_dump_json())
        assert snap["active_zone"]["progress"]["latched"] == [
            "counterweight/l0"]
        assert "latched" not in json.dumps(snap["hub"])
    run(go())
