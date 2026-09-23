"""O05-06: an existing minor in a composed Zone, and its persistence.

The candidate profile's `minors` step builds EX50-033 Unweighted Switch
as a room of its own behind a dead-end arena, taking that arena's Check
(`minor_hosting.compose_minor`). These pin what that step may and may
not do to the Zone it is handed, and the `minor_<room>` latch path that
makes its bolt survive a reload.

Measured findings behind two of them:

* **P5-13.** Hosting by SUBSTITUTION -- the arena becomes the minor --
  failed every Zone of the frozen sample: the fallback fills a Zone to a
  few points over its content floor and `room_value` has no row for a
  minor, so the arena's enemies left the count. Adding the minor keeps
  every counted component; `test_the_zone_keeps_its_counted_content`.
* **P5-12.** The re-certification that catches a step breaking a rule
  was called without the Zone's content budget, so it judged a
  1000-point Zone against the prototype's 200.
  `test_certification_is_held_to_the_zone_budget` is its control.
"""
from __future__ import annotations

import pytest

from archipepsi_bridge import candidate as CP
from archipepsi_bridge import minor_hosting as MH
from archipepsi_bridge import shells
from archipepsi_bridge.content_value import room_value, zone_value
from archipepsi_bridge.schemas import physics as PH
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.minors import CONTRACTS, latch_package
from archipepsi_bridge.schemas.zone import Zone, validate_zone
from archipepsi_bridge.topology import reachability

SHELL = "minor_unweighted_switch"


@pytest.fixture(scope="module")
def played() -> Zone:
    from archipepsi_bridge.playtest import played_zone
    zone = played_zone()
    assert zone is not None
    return zone


@pytest.fixture(scope="module")
def hosted(played):
    out = MH.compose_minor(played)
    assert out.emitted, out.note
    return out


def _room(zone: Zone, room_id: str):
    return next(c for c in zone.chambers if c.id == room_id)


def _parent(zone: Zone, room_id: str):
    edge = next(e for e in zone.edges
                if e.edge_id == _room(zone, room_id).arrive_edge)
    return _room(zone, edge.room_a)


# --------------------------------------------------------------------------
# What the step builds
# --------------------------------------------------------------------------

def test_the_minor_is_its_own_room_built_from_its_shell(hosted):
    room = _room(hosted.zone, hosted.room_id)
    rule = shells.rule_of(shells.load_registry()[SHELL])
    assert room.shell_id == SHELL and room.type == "arena"
    # The shell's own size, never scaled to the room it stands behind.
    assert not shells.rule_errors(SHELL, rule, room)
    assert room.enemies == () and room.activities == ()
    assert room.features == () and room.elevation is None


def test_it_is_a_dead_end_behind_a_dead_end(hosted, played):
    room = _room(hosted.zone, hosted.room_id)
    parent = _parent(hosted.zone, hosted.room_id)
    doors = {d.socket_id: d.usage for d in room.doors}
    assert doors == {"entry": "USED", "exit": "SEALED"}
    before = _room(played, parent.id)
    # The parent was a dead end, and now leads to the minor and nowhere
    # else new.
    assert sum(d.usage != "SEALED" for d in before.doors) == 1
    opened = {d.edge_id for d in parent.doors if d.usage != "SEALED"}
    assert opened == {before.arrive_edge, room.arrive_edge}


def test_one_check_moves_one_room_deeper_and_none_is_lost(hosted, played):
    room = _room(hosted.zone, hosted.room_id)
    parent = _parent(hosted.zone, hosted.room_id)
    assert room.reward_ids == _room(played, parent.id).reward_ids
    assert parent.reward_ids == ()
    assert sorted(hosted.zone.reward_location_ids) \
        == sorted(played.reward_location_ids)


def test_the_parent_keeps_its_fight_and_its_objective(hosted, played):
    parent = _parent(hosted.zone, hosted.room_id)
    before = _room(played, parent.id)
    assert parent.enemies == before.enemies
    assert parent.activities == before.activities
    assert parent.objective == before.objective


def test_the_zone_keeps_its_counted_content(hosted, played):
    """P5-13: nothing the budget counts is removed.

    The parent scores exactly what it did (a Check is worth nothing), and
    the Zone gains only what the minor's room scores through the table's
    EXISTING rows -- its `reach_reward` objective and the space that
    bounds -- because the table has no row for a minor and none is added.
    """
    parent = _parent(hosted.zone, hosted.room_id)
    assert room_value(parent) == room_value(_room(played, parent.id))
    minor = room_value(_room(hosted.zone, hosted.room_id))
    assert zone_value(hosted.zone) == zone_value(played) + minor


def test_the_hosted_zone_is_reachable_with_the_base_kit(hosted):
    assert reachability(hosted.zone).ok


def test_the_minor_is_never_offered_to_a_provider():
    catalog = shells.shell_catalog()
    assert SHELL not in {i for ids in catalog.values() for i in ids}
    assert SHELL not in shells.shell_rules()


# --------------------------------------------------------------------------
# What the step declines, by name
# --------------------------------------------------------------------------

def test_a_second_pass_does_not_host_it_twice(hosted):
    again = MH.compose_minor(hosted.zone)
    assert not again.emitted and "already hosted" in again.note


def test_a_room_holding_another_relationship_is_not_a_parent(played):
    out = CP.apply(played, CP.STEPS)
    parent = _parent(out.zone, next(iter(MH.hosted(out.zone))))
    occupied = MH._occupied(out.zone)
    assert parent.id not in occupied


def test_a_zone_with_no_dead_end_arena_declines_with_the_reasons(played):
    raw = played.model_dump()
    for c in raw["chambers"]:
        if c["type"] == "arena":
            # Every arena's Check gone: nothing left to hand the minor.
            c["reward_location_id"] = None
    zone = Zone.model_validate(raw)
    out = MH.compose_minor(zone)
    assert not out.emitted and out.zone is zone
    assert "declined" in out.note and "carries no Check" in out.note


def test_a_gated_doorway_is_not_a_way_in(played):
    target = next(c for c in played.chambers
                  if MH.parent_problem(played, c, played.chambers[0].id,
                                       {}, shells.load_registry()) is None)
    raw = played.model_dump()
    for e in raw["edges"]:
        if e["edge_id"] == target.arrive_edge:
            e["capability"] = "blink"
    zone = Zone.model_validate(raw)
    why = MH.parent_problem(zone, _room(zone, target.id), zone.chambers[0].id,
                            {}, shells.load_registry())
    assert why and "gated doorway" in why


# --------------------------------------------------------------------------
# Reversible, and re-certified
# --------------------------------------------------------------------------

def test_unhost_hands_the_check_back_exactly(hosted, played):
    back = MH.unhost(hosted.zone)
    assert [c.id for c in back.chambers] == [c.id for c in played.chambers]
    for a, b in zip(back.chambers, played.chambers):
        assert a.reward_ids == b.reward_ids


def test_strip_takes_the_minor_out_before_a_graph_is_recomposed(played):
    out = CP.apply(played, CP.STEPS)
    assert "minors" in out.emitted
    stripped = CP.strip(out.zone)
    assert not MH.hosted(stripped)
    assert sorted(stripped.reward_location_ids) \
        == sorted(played.reward_location_ids)


def _certify(zone, played, offer, budget=1000):
    return validate_zone(
        zone, expected_zone_id=played.zone_id,
        allocated_location_ids=list(played.reward_location_ids),
        owned_echo_ids=[], zone_budget=budget, **offer)


def _offer():
    catalog = shells.shell_catalog()
    return {"legal_shell_ids": shells.all_legal_shell_ids(catalog),
            "shell_catalog": catalog, "shell_rules": shells.shell_rules()}


def test_certification_accepts_the_minor_only_with_its_own_rule(hosted,
                                                                played):
    without = _certify(hosted.zone, played, _offer())
    assert any(SHELL in e for e in without), without
    new = set(without) - set(_certify(played, played, _offer()))
    assert new and all(SHELL in e for e in new)
    offer = MH.certify_offer(_offer())
    assert not (set(_certify(hosted.zone, played, offer))
                - set(_certify(played, played, offer)))


def test_certification_is_held_to_the_zone_budget(hosted, played):
    """P5-12's control: the prototype's budget refuses a real Zone."""
    offer = MH.certify_offer(_offer())
    assert any("enemies, limit is" in e
               for e in _certify(played, played, offer, budget=200))
    assert not any("enemies, limit is" in e
                   for e in _certify(played, played, offer, budget=1000))


# --------------------------------------------------------------------------
# The bolt, persisted: `minor_<room>/bolt`
# --------------------------------------------------------------------------

def _save(zone: Zone, *, committed: bool = True,
          placed: tuple[str, ...] | None = None) -> P.CampaignSave:
    top = max(zone.reward_location_ids) - 89100000
    save = P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        scale=P.CampaignScale(location_count=max(top + 1, 30),
                              zone_target_checks=15, zone_budget=1000))
    save = T.start_generation(
        save, zone_id=zone.zone_id,
        allocated_location_ids=tuple(zone.reward_location_ids),
        target_game=zone.target_game)
    save = T.enter_zone(T.accept_zone(save, zone), zone.zone_id)
    if committed:
        rooms = [c.id for c in zone.chambers] if placed is None else placed
        save = T.commit_layout(save, zone.zone_id, {
            "zone_id": zone.zone_id, "manifest_digest": "d" * 16,
            "rooms": {r: {} for r in rooms}, "packages": []})
    return save


def test_the_bolt_is_recorded_under_its_room(hosted):
    zone = hosted.zone
    package = latch_package(hosted.room_id)
    save = T.record_latch(_save(zone), zone.zone_id, package, "bolt")
    rec = save.zone_by_id(zone.zone_id)
    assert f"{package}/bolt" in rec.progress.latched
    # Idempotent, like every latch.
    again = T.record_latch(save, zone.zone_id, package, "bolt")
    assert again.zone_by_id(zone.zone_id).progress.latched \
        == rec.progress.latched


def test_a_latch_the_contract_does_not_declare_is_refused(hosted):
    zone = hosted.zone
    with pytest.raises(ValueError, match="declares no latch 'lever'"):
        T.record_latch(_save(zone), zone.zone_id,
                       latch_package(hosted.room_id), "lever")


def test_a_room_that_is_not_a_minor_records_nothing(hosted):
    zone = hosted.zone
    parent = _parent(zone, hosted.room_id)
    with pytest.raises(ValueError, match="hosts no minor"):
        T.record_latch(_save(zone), zone.zone_id, latch_package(parent.id),
                       "bolt")


def test_no_committed_layout_means_nothing_has_latched(hosted):
    zone = hosted.zone
    with pytest.raises(ValueError, match="no committed layout"):
        T.record_latch(_save(zone, committed=False), zone.zone_id,
                       latch_package(hosted.room_id), "bolt")


def test_a_minor_the_layout_never_placed_records_nothing(hosted):
    zone = hosted.zone
    placed = tuple(c.id for c in zone.chambers if c.id != hosted.room_id)
    with pytest.raises(ValueError, match="placed no room"):
        T.record_latch(_save(zone, placed=placed), zone.zone_id,
                       latch_package(hosted.room_id), "bolt")


def test_no_physics_package_may_take_the_minor_namespace():
    with pytest.raises(ValueError, match="reserved for hosted minors"):
        PH.refuse_reserved_package_id("minor_c024")


def test_every_contract_names_a_registry_shell_tagged_minor():
    reg = shells.load_registry()
    for shell_id, contract in CONTRACTS.items():
        assert contract.shell_id == shell_id
        entry = reg[shell_id]
        assert shells.MINOR_TAG in entry.semantic_tags
        assert contract.chamber_type in entry.semantic_tags
        assert contract.entry_socket in shells.joinable_sockets(entry)
        assert set(contract.sealed_sockets) \
            <= set(shells.joinable_sockets(entry))
