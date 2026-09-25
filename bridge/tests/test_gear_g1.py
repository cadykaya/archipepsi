"""D16 G1 -- the Legs slice, under the owner's four rulings (2026-09-25).

1. "Pair speed, jump and landing Gear only with the corresponding runtime
   stats that already exist. Do not create a second or parallel
   Gear-stat system."
2. "Until a clause catalogue exists, a Gear piece should express one
   bounded, understandable stat effect."
3. "Gear comes only from Archipelago items' Echoes."
4. "At most one HIGH piece may be effective/equipped at once. Treat HIGH
   as a balance/classification rule, not as part of persistent item
   identity, so later balancing does not require save migration."

**The gate is closed, and stays closed until the StatStack applies a worn
piece** (note D-8, the lever's order). So the cases that need a piece to
exist open it with `open_gate`, exactly as the one commit that follows
Prod's half will; the closed gate has its own tests.
"""
from __future__ import annotations

import asyncio
import json

import pytest

from archipepsi_bridge.epsilon import capabilities as CAP
from archipepsi_bridge.epsilon.requests import allowed_for
from archipepsi_bridge.schemas import echo as E
from archipepsi_bridge.schemas import gear as G
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.inventory_view import inventory_view
from archipepsi_bridge.schemas.mechanics import FoldError, derive_mechanics
from archipepsi_bridge.server import _about

SPEED, JUMP = "gear_striders", "gear_springs"


@pytest.fixture
def open_gate(monkeypatch):
    monkeypatch.setattr(G, "SUPPORTED_GEAR_DOMAINS", G.PAIRED_DOMAINS)


def _piece(cid: str, domain: str, magnitude: str = "mag_profound") -> dict:
    return {"kind": "gear", "component_id": cid, "display_name": "Striders",
            "description": "They carry you.", "domains": [domain],
            "magnitudes": [magnitude]}


def _echo(loc: int, *ops) -> E.EchoInterpretation:
    return E.EchoInterpretation.model_validate({
        "echo_id": f"echo_{loc}", "interpretation_seq": 0,
        "source_location_id": loc, "source_item_name": "Pegasus Boots",
        "source_game": "A Link to the Past", "source_recipient_name": "Link",
        "display_name": "Pegasus Boots", "description": "Fast.",
        "operations": list(ops)})


def _create(component: dict) -> dict:
    return {"op": "create", "component": component}


def _save(*echoes) -> P.CampaignSave:
    save = P.CampaignSave(seed_name="Seed", team=0, slot_id=1,
                          slot_name="Skyiah")
    for echo in echoes:
        save = T.append_interpretation(save, echo)
    return save


def _two_pieces() -> P.CampaignSave:
    return _save(_echo(89100001, _create(_piece(SPEED, "dom_speed"))),
                 _echo(89100002, _create(_piece(JUMP, "dom_jump"))))


def _snapshot(save: P.CampaignSave) -> P.CampaignSnapshot:
    """The model's snapshot of this save. `campaign.snapshot()` passes
    `gear` once Prod adds that line (note D-8)."""
    return P.CampaignSnapshot(
        bridge_connected=True, ap_connected=True, ap_mode="mock",
        epsilon_provider="mock",
        hub=P.HubStatus(mode="NO_CAMPAIGN", headline="No campaign"),
        mechanics=save.derive(), slots=save.slots, gear=save.gear)


# --- ruling 1: the runtime stats that already exist ---------------------------

def test_each_paired_domain_moves_a_stat_the_runtime_already_has():
    pairs = {d: stat for d, (stat, _) in G.GEAR_EFFECTS.items()}
    assert pairs == {"dom_speed": "move_speed", "dom_jump": "jump_height",
                     "dom_landing": "air_control"}
    assert set(pairs.values()) <= set(CAP.IMPLEMENTED_TRAIT_STATS)
    # Design 1 §16.1's LARGE values, as multipliers.
    assert {d: f["mag_profound"] for d, (_, f) in G.GEAR_EFFECTS.items()} \
        == {"dom_speed": 1.18, "dom_jump": 1.30, "dom_landing": 1.90}


@pytest.mark.parametrize("domain", ["dom_mobility_recharge", "dom_crit",
                                    "dom_health", "dom_rail_control"])
def test_an_unpaired_domain_is_refused_by_the_pairing(domain):
    with pytest.raises(ValueError, match="pairs with no runtime stat"):
        E.GearComponent.model_validate(_piece("gear_x", domain))


def test_nothing_clamps_gear_alone(open_gate, monkeypatch):
    """The stack's one floor and envelope clamp the product (move_speed
    at `SPEED_MULT_MAX`); a Gear-only clamp would be the parallel system
    ruling 1 forbids. So the bridge passes the derived factor through."""
    monkeypatch.setitem(G.GEAR_EFFECTS, "dom_speed",
                        ("move_speed", {**G.GEAR_EFFECTS["dom_speed"][1],
                                        "mag_profound": 2.0}))
    save = T.gear_action(_two_pieces(), "LEGS", SPEED)
    assert _snapshot(save).gear_effects == {"move_speed": 2.0}


# --- ruling 2: one bounded stat effect ---------------------------------------

@pytest.mark.parametrize("magnitude", ["mag_slight", "mag_marked"])
def test_only_the_strongest_single_stat_piece_is_legal(magnitude):
    with pytest.raises(ValueError, match="strongest single-stat piece"):
        E.GearComponent.model_validate(_piece("gear_x", "dom_speed",
                                              magnitude))


def test_a_two_intrinsic_piece_waits_for_the_clause_catalogue():
    raw = {**_piece("gear_x", "dom_speed"),
           "domains": ["dom_speed", "dom_jump"],
           "magnitudes": ["mag_profound", "mag_profound"]}
    with pytest.raises(ValueError, match="one bounded stat effect"):
        E.GearComponent.model_validate(raw)


def test_every_legal_piece_is_whole_without_a_clause():
    costs = {d: G.composition_cost((d,), G.LEGAL_MAGNITUDES)
             for d in G.PAIRED_DOMAINS}
    assert costs == {"dom_speed": 96, "dom_jump": 90, "dom_landing": 88}
    assert all(G.USEFUL_BAND[0] <= c <= G.USEFUL_BAND[1]
               for c in costs.values())


def _with(save, *ops):
    return derive_mechanics(tuple(save.interpretations) + (
        _echo(89100009, *ops).model_copy(
            update={"interpretation_seq": save.next_interpretation_seq}),))


@pytest.mark.parametrize("op, says", [
    ({"op": "upgrade", "target": SPEED, "field": "multiplier",
      "delta": 0.1}, "not upgradable on a 'gear'"),
    ({"op": "modify", "target": SPEED,
      "add_modifier": {"type": "knockback_target", "force": 4.0}},
     "only be added to an action"),
    ({"op": "link", "link": "scales", "source": "res_battery",
      "target": SPEED}, "is Gear, which links to nothing"),
])
def test_a_piece_is_its_atoms_and_nothing_is_added_to_it(open_gate, op,
                                                         says):
    save = _save(_echo(89100001, _create(_piece(SPEED, "dom_speed")),
                       _create({"kind": "resource",
                                "component_id": "res_battery",
                                "display_name": "Battery",
                                "description": "Charge.",
                                "max_value": 100.0, "initial_fraction": 1.0,
                                "regen_per_second": 0.0, "regen_delay": 0.0,
                                "presentation": "bar",
                                "palette_color": "moss"})))
    with pytest.raises(FoldError, match=says):
        _with(save, op)


# --- ruling 3: only from an Echo ---------------------------------------------

def test_a_worn_piece_no_echo_made_is_refused_on_load(open_gate):
    """No transaction mints Gear, so a piece the log never created is a
    forged one -- refused on every path that builds a save."""
    raw = json.loads(_two_pieces().model_dump_json())
    raw["gear"]["LEGS"] = "gear_forged"
    with pytest.raises(ValueError, match="'gear_forged', which is not owned"):
        P.CampaignSave.model_validate(raw)


# --- ruling 4: HIGH is derived, never stored -----------------------------------

def test_a_piece_stores_its_atoms_and_nothing_derived(open_gate):
    assert set(E.GearComponent.model_fields) == {
        "kind", "component_id", "display_name", "description", "domains",
        "magnitudes"}
    owned = _two_pieces().derive().by_id(SPEED)
    item = next(i for i in inventory_view(_two_pieces()).items
                if i.component_id == SPEED)
    assert item.gear.tier == "USEFUL"
    assert "tier" not in json.dumps(owned.component.model_dump())


def test_a_rebalance_moves_a_saved_piece_without_migration(open_gate,
                                                            monkeypatch):
    wire = T.gear_action(_two_pieces(), "LEGS", SPEED).model_dump_json()
    monkeypatch.setitem(G.GEAR_EFFECTS, "dom_speed",
                        ("move_speed", {**G.GEAR_EFFECTS["dom_speed"][1],
                                        "mag_profound": 1.2}))
    reloaded = P.CampaignSave.model_validate_json(wire)
    assert _snapshot(reloaded).gear_effects == {"move_speed": 1.2}
    assert reloaded.model_dump_json() == wire


# --- the gate ---------------------------------------------------------------

def test_the_gate_is_closed_until_the_statstack_applies_a_worn_piece():
    assert G.SUPPORTED_GEAR_DOMAINS == ()
    with pytest.raises(ValueError, match="no runtime implements.*note D-8"):
        _echo(89100001, _create(_piece(SPEED, "dom_speed")))
    # Nothing invites a piece every validator would refuse.
    assert "gear" not in E.COMPONENT_KINDS
    allowed = allowed_for()
    assert "gear" not in allowed["component_kinds"]
    assert "gear_domains" not in allowed and "gear_magnitudes" not in allowed


def test_an_open_gate_offers_the_atoms_and_never_a_number(open_gate):
    allowed = allowed_for()
    assert allowed["gear_domains"] == list(G.PAIRED_DOMAINS)
    assert allowed["gear_magnitudes"] == ["mag_profound"]


# --- wearing -----------------------------------------------------------------

def test_a_piece_is_worn_in_its_own_territory_and_nowhere_else(open_gate):
    save = _two_pieces()
    worn = T.gear_action(save, "LEGS", SPEED)
    assert worn.gear.LEGS == SPEED
    assert T.gear_action(worn, "LEGS", JUMP).gear.LEGS == JUMP   # a swap
    assert T.gear_action(worn, "LEGS", None).gear.LEGS is None   # cleared
    with pytest.raises(ValueError, match="is LEGS Gear and cannot be worn "
                                         "on HEAD"):
        T.gear_action(save, "HEAD", SPEED)
    with pytest.raises(ValueError, match="unknown territory"):
        T.gear_action(save, "FEET", SPEED)
    with pytest.raises(ValueError, match="is not owned"):
        T.gear_action(save, "LEGS", "gear_missing")


def test_only_gear_is_worn_and_gear_is_never_slotted(open_gate):
    save = _save(_echo(89100001, _create(_piece(SPEED, "dom_speed")),
                       _create({"kind": "action", "component_id": "act_dash",
                                "display_name": "Dash",
                                "description": "Go.", "slot": "mobility",
                                "cooldown": 1.0, "modifiers": [],
                                "primitive": {"type": "dash",
                                              "force": 6.0}})))
    with pytest.raises(ValueError, match="only Gear is worn"):
        T.gear_action(save, "LEGS", "act_dash")
    with pytest.raises(ValueError, match="only actions occupy slots"):
        T.slot_action(save, "mobility", SPEED)


def test_the_worn_piece_reaches_the_snapshot_as_one_factor(open_gate):
    save = T.gear_action(_two_pieces(), "LEGS", SPEED)
    assert _snapshot(save).gear_effects == {"move_speed": 1.18}
    save = T.gear_action(save, "LEGS", JUMP)
    assert _snapshot(save).gear_effects == {"jump_height": 1.30}
    assert _snapshot(T.gear_action(save, "LEGS", None)).gear_effects == {}
    wire = json.loads(_snapshot(save).model_dump_json())
    assert wire["gear"]["LEGS"] == JUMP
    assert wire["gear_effects"] == {"jump_height": 1.3}


def test_a_worn_piece_survives_a_reload(open_gate):
    save = T.gear_action(_two_pieces(), "LEGS", SPEED)
    assert P.CampaignSave.model_validate_json(
        save.model_dump_json()).gear.LEGS == SPEED


def test_a_save_from_before_gear_wears_nothing():
    raw = json.loads(_save().model_dump_json())
    del raw["gear"]
    assert P.CampaignSave.model_validate(raw).gear == P.GearSlots()


def test_the_inventory_shows_gear_as_worn_in_a_territory(open_gate):
    view = inventory_view(T.gear_action(_two_pieces(), "LEGS", SPEED))
    by_id = {i.component_id: i for i in view.items}
    speed = by_id[SPEED]
    assert speed.activation == "worn" and speed.compatible_slots == ()
    assert speed.gear.model_dump() == {
        "territory": "LEGS", "effects": {"move_speed": 1.18},
        "tier": "USEFUL", "worn": True}
    assert by_id[JUMP].gear.worn is False
    territories = {t.territory: t for t in view.territories}
    assert territories["LEGS"].holds == SPEED
    assert territories["LEGS"].accepts == (SPEED, JUMP)
    assert all(not territories[t].accepts for t in ("HEAD", "TORSO",
                                                    "ARMS"))
    assert all(SPEED not in s.accepts for s in view.slots)


# --- the intent, and the refusal that names it (with Prod's N-11) -------------

@pytest.mark.parametrize("message, key", [
    ({"type": "gear_action", "territory": "LEGS",
      "component_id": "gear_x"}, "gear_action:LEGS:gear_x"),
    ({"type": "gear_action", "territory": "LEGS"}, "gear_action:LEGS:"),
    ({"type": "slot_action", "slot": "mobility",
      "component_id": "act_x"}, "slot_action:mobility:act_x"),
    ({"type": "slot_action", "slot": "mobility"}, "slot_action:mobility:"),
])
def test_an_equip_request_is_named_by_its_domain_key(message, key):
    from pydantic import TypeAdapter
    parsed = TypeAdapter(P.ClientMessage).validate_python(message)
    assert _about(parsed) == key


@pytest.mark.parametrize("message, key", [
    ({"type": "slot_action", "slot": "mobility",
      "component_id": "act_missing"}, "slot_action:mobility:act_missing"),
    ({"type": "gear_action", "territory": "LEGS",
      "component_id": "gear_missing"}, "gear_action:LEGS:gear_missing"),
])
def test_a_refused_equip_answers_with_its_key(tmp_path, message, key):
    """N-11: the whole path -- parse, route, refuse -- and the error frame
    names the request, so the Equipment wall can attribute it."""
    from archipepsi_bridge.server import BridgeServer

    from .conftest import connected_engine, run

    class FakeWS:
        def __init__(self):
            self.sent = []

        async def send(self, payload):
            self.sent.append(payload)

    async def go():
        engine, _ = await connected_engine(tmp_path)
        ws = FakeWS()
        await BridgeServer(engine).dispatch(ws, json.dumps(message))
        errors = [json.loads(p) for p in ws.sent
                  if json.loads(p).get("type") == "error"]
        assert [e["about"] for e in errors] == [key], ws.sent
        assert "not owned" in errors[0]["message"]
    run(go())
