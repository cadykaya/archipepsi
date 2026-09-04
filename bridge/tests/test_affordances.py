"""S9: affordances, local rewards and Info readouts.

Three invariants meet here, and each is enforced by a different layer, so
each is tested against the layer that actually enforces it:

* **I4** — a feature never lies on the mandatory path. The schema half is
  "not in a reward chamber, not on a gating objective"; the metre half is
  the client builder, pinned from `test_hud_contract`-style cross-language
  agreement below.
* **I12** — a feature only appears when the campaign owns the capability
  that makes it interactable. Derived from `owned_affordance_tags` over
  OWNED mechanics, never slotted ones.
* **I13** — what a feature holds is a local reward. There is no shape in
  the protocol that could make it an AP item, location or Check.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest
from pydantic import ValidationError

from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas import zone as Z
from pydantic import TypeAdapter
from .test_providers import zone_request

from archipepsi_bridge.schemas.constants import (
    FEATURE_MIN_WIDTH as C_MIN_WIDTH)

GODOT = Path(__file__).resolve().parents[2] / "godot"


def _tags() -> tuple[str, ...]:
    """Every tag in the schema's Literal, read from the model rather than
    retyped: a tag added to the contract must show up here on its own."""
    return tuple(Z.AffordanceTag.__args__)


# --- I12: capability pays for the feature ---------------------------------

def test_every_tag_declares_what_makes_it_interactable():
    """A tag with no entry in the registry would be silently ungated —
    `owned_affordance_tags` iterates the registry, so a missing entry is a
    tag that can never be offered rather than one offered freely. Either
    way it is drift, and this is what notices."""
    assert set(M.AFFORDANCE_REQUIREMENTS) == set(_tags())


def test_the_base_kit_tags_need_nothing_and_the_rest_need_something():
    """§13.1 marks exactly two tags base-kit usable. The distinction is
    load-bearing: it is why a campaign that has interpreted nothing still
    gets optional content, and why the other five cannot appear as set
    dressing."""
    empty = M.derive_mechanics([])
    assert M.owned_affordance_tags(empty) == ("bounce_pad", "moving_platform")
    for tag, requirement in M.AFFORDANCE_REQUIREMENTS.items():
        needs_nothing = not requirement.get("primitives") \
            and not requirement.get("stats")
        assert needs_nothing == (tag in ("bounce_pad", "moving_platform")), tag


def test_a_grapple_you_own_but_have_not_slotted_still_pays_for_the_anchor():
    """"Capability is evaluated over OWNED mechanics, never equipped ones"
    (§13.1). Slots change every time the player opens the loadout; a Zone
    whose geometry depended on them would be a Zone that stopped making
    sense the moment they did."""
    log = [_interpretation({"kind": "action", "component_id": "act_hook",
                   "display_name": "Hook", "description": "d",
                   "slot": "utility", "cooldown": 2.0,
                   "primitive": {"type": "grapple_to_surface",
                                 "range": 20.0, "pull_force": 18.0},
                   "modifiers": []})]
    live = M.derive_mechanics(log)
    assert "grapple_anchor" in M.owned_affordance_tags(live)


def test_an_owned_affordance_component_unlocks_its_own_tag():
    """An `AffordanceComponent` grants its tag outright.

    §13.1's table names the derived capability that makes each tag
    interactable, and this component kind IS that capability rather than a
    proxy for it. Without this, an Echo reading "you can grind rails now"
    would own a component that unlocked nothing, and the kind would be
    decorative.
    """
    empty = M.derive_mechanics([])
    assert "rail" not in M.owned_affordance_tags(empty)
    log = [_interpretation({
        "kind": "affordance", "component_id": "aff_rail",
        "display_name": "Rail Sense", "description": "d", "tag": "rail"})]
    assert "rail" in M.owned_affordance_tags(M.derive_mechanics(log))


def test_a_local_reward_reaches_the_client():
    """The save records it; the snapshot is how the player ever sees it.

    Without this the client cannot tell a note it already found from one
    it has not, and a pickup would respawn every time you re-entered the
    Zone — which is what makes `local_rewards` snapshot state rather than
    save-only state.
    """
    assert "local_rewards" in P.CampaignSnapshot.model_fields
    # ...and it is NOT folded: a local reward derives no mechanic, so it
    # must not appear as one.
    assert "local_rewards" not in M.Mechanics.model_fields


def test_a_zone_offering_an_unusable_feature_is_refused():
    """I12. The check is in `validate_zone`, so it fires on a Zone from any
    provider — the fallback's placement rule is a convenience, not the
    enforcement."""
    zone = _zone_with_features([{"tag": "water_volume", "at": (0.2, 0.4)}])
    errors = _validate(zone, owned=("bounce_pad",))
    assert any("water_volume" in e for e in errors), errors
    # ...and accepted once the campaign can use it, so this proves a gate
    # that opens rather than one that merely refuses.
    assert _validate(zone, owned=("bounce_pad", "water_volume")) == []


# --- I4: never on the mandatory path --------------------------------------

def test_a_narrow_chamber_still_cannot_hold_a_check_and_a_feature():
    """I4/§13.2, by the geometric proof rather than by separation.

    This chamber used to be refused for holding both at all. It is still
    refused, and for a better reason: a 6m corridor has no room for a
    bounce pad (7.1m) that is not across the walking lane, so the feature
    would sit between the player and the Check.

    A corridor deliberately, because it is the one chamber that can hold
    a Check without a gating objective -- what refuses this is the lane
    rule, with nothing else in the way to take the credit.
    """
    with pytest.raises(ValidationError, match="sit clear"):
        _zone(chambers=[
            {"id": "c1", "type": "corridor", "length": 12.0, "width": 6.0},
            {"id": "c2", "type": "corridor", "length": 14.0, "width": 6.0,
             "reward_location_id": 89100001,
             "features": [{"tag": "bounce_pad", "at": (0.5, 0.5)}]}])

    # ...and widened past the pad's footprint, the same room is fine.
    ok = _zone(chambers=[
        {"id": "c1", "type": "corridor", "length": 12.0, "width": 6.0},
        {"id": "c2", "type": "corridor", "length": 14.0, "width": 8.0,
         "reward_location_id": 89100001,
         "features": [{"tag": "bounce_pad", "at": (0.5, 0.5)}]}])
    assert ok.chambers[1].features and ok.chambers[1].reward_location_id


def test_a_feature_may_share_an_objective_room_but_only_where_it_fits():
    """The rule that used to be a blanket ban (CAMPAIGN_SCALE.md 7).

    An affordance may never be REQUIRED for an objective. That was
    enforced by forbidding the two from sharing a room at all, which was
    the cheapest possible proof and made every objective room sterile --
    no rails, no grapple, in exactly the rooms most worth having them.

    The invariant did not move; the proof did. `FEATURE_MIN_WIDTH` is
    `2 * (lane + 2 * reach + wall clearance)`, so a room wide enough for
    the tag is a room where the feature demonstrably sits clear of the
    walking lane. A room too narrow is still refused -- there is nowhere
    to put the feature except across the route.
    """
    # Wide enough for a rail (6.7m): legal now, and this is the point.
    zone = _zone(chambers=[
        {"id": "c1", "type": "corridor", "length": 12.0, "width": 6.0},
        {"id": "c2", "type": "arena", "width": 16.0, "depth": 14.0,
         "wall_height": 5.0, "objective": "kill_all",
         "enemies": [{"archetype": "melee", "count": 2}],
         "features": [{"tag": "rail", "at": (0.5, 0.5)}]}])
    assert zone.chambers[1].features, "the feature was silently dropped"

    # And the refusal half, on a CORRIDOR -- see the vacuity test below
    # for why an arena cannot demonstrate this. A 7m corridor has nowhere
    # to put a water volume (7.9m) that is not across the walking lane.
    with pytest.raises(ValidationError, match="sit clear"):
        _zone(chambers=[
            {"id": "c1", "type": "corridor", "length": 12.0, "width": 6.0},
            {"id": "c2", "type": "corridor", "length": 14.0, "width": 7.0,
             "features": [{"tag": "water_volume", "at": (0.5, 0.5)}]}])


def test_a_feature_may_share_a_reward_room_but_only_where_it_fits():
    """The same change for AP Checks, which is the one that matters.

    A reward room was the most sterile room in the game: it could hold a
    Check and nothing optional. Now it can hold both, and the ownership
    half of the guarantee -- that nothing optional is REQUIRED to reach
    the Check -- is still `validate_zone`'s, while the instantiated half
    is `godot-legible` walking the built room.
    """
    zone = _zone(chambers=[
        {"id": "c1", "type": "corridor", "length": 12.0, "width": 6.0},
        {"id": "c2", "type": "arena", "width": 20.0, "depth": 18.0,
         "wall_height": 6.0, "objective": "reach_reward",
         "reward_location_id": 89100001,
         "features": [{"tag": "grapple_anchor", "at": (0.5, 0.5)}]}])
    room = zone.chambers[1]
    assert room.reward_location_id == 89100001 and room.features


def test_the_width_rule_is_vacuous_for_arenas_and_says_so():
    """A limitation worth writing down rather than discovering later.

    An arena is `width >= 10` and the widest feature footprint is 7.9m,
    so EVERY legal arena is wide enough for every tag: the schema's lane
    rule cannot refuse an arena, ever. It is a real constraint on
    corridors, whose width starts at 4, and a tautology on rooms.

    That is not a hole as long as the arena guarantee is carried
    somewhere else, and it is: `godot-legible` walks the BUILT room and
    checks the reward is reachable with base movement while the feature
    is not in the way. This test exists so that nobody reads the width
    rule as the arena's protection, deletes the Godot half as redundant,
    and leaves reward rooms unguarded.
    """
    from archipepsi_bridge.schemas import zone as _Z
    arena_min = _Z.ArenaChamber.model_fields["width"].metadata
    lower = next(getattr(m, "ge") for m in arena_min if hasattr(m, "ge"))
    assert lower >= max(C_MIN_WIDTH.values()), (
        "an arena can now be narrower than its widest feature, so the "
        "schema rule has started to bite for rooms -- which is fine, but "
        "this test's premise no longer holds")


def test_the_client_builder_keeps_features_out_of_the_walking_lane():
    """The metre half of I4, pinned across languages.

    The schema can only say "not in this chamber"; the lane itself exists
    in `affordance_features.gd`, which owns metres. So the test reads that
    file and checks the rule it implements, the same way the HUD contract
    test pins the palette. A generator asking for dead centre must still
    produce a feature clear of the door lane.
    """
    source = (GODOT / "scripts/generation/affordance_features.gd").read_text()
    lane = _gd_const(
        GODOT / "scripts/generation/affordance_features.gd", "LANE_HALF_WIDTH")
    # Wider than the door it protects, or it is not protecting it.
    door = _gd_const(
        GODOT / "scripts/generation/chamber_builders.gd", "DOOR_WIDTH")
    assert lane > door / 2.0, (lane, door)
    # The clamp must push a feature's near EDGE out of the lane, not just
    # its origin — a pad 2 m across whose centre sat at the lane edge put
    # half its trigger inside the lane, and launched a player who was
    # only walking past. `inner` is that edge, and the clamp must use it.
    assert re.search(r"var inner := LANE_HALF_WIDTH \+ half_width", source)
    assert re.search(r"clampf\(absf\(x\), inner,", source), source


def test_every_tags_minimum_width_agrees_across_languages():
    """`FEATURE_MIN_WIDTH` and `AffordanceFeatures.FOOTPRINT` are the same
    rule in two languages, and they have to agree per tag.

    If Python allowed a chamber the builder refuses, the feature is
    silently dropped and the Zone reads richer than it plays — which is
    what the integration run caught the first time. If Python refused one
    the builder would happily build, content is lost for no reason.
    """
    from archipepsi_bridge.schemas import constants as C
    source = (GODOT / "scripts/generation/affordance_features.gd").read_text()
    lane = _gd_const(
        GODOT / "scripts/generation/affordance_features.gd", "LANE_HALF_WIDTH")
    margin = _gd_const(
        GODOT / "scripts/generation/affordance_features.gd", "WALL_MARGIN")
    footprints = dict(re.findall(
        r'"(\w+)": \{"half_width": ([0-9.]+)', source))
    assert set(footprints) == set(_tags()), set(footprints) ^ set(_tags())
    assert set(C.FEATURE_MIN_WIDTH) == set(_tags())
    for tag, half_width in footprints.items():
        expected = 2.0 * (lane + 2.0 * float(half_width) + margin)
        assert abs(C.FEATURE_MIN_WIDTH[tag] - expected) < 0.001, (
            tag, C.FEATURE_MIN_WIDTH[tag], expected)
    # ...and the rule itself, so a rewrite that changed the shape rather
    # than the numbers cannot slip past.
    assert re.search(
        r"return 2\.0 \* \(LANE_HALF_WIDTH \+ 2\.0 \* reach \+ WALL_MARGIN\)",
        source)


def test_a_corridor_that_cannot_hold_a_feature_still_holds_a_smaller_one():
    """Per-tag, not one conservative number: a rail fits a 5.9 m corridor
    that a wind column needs 8.3 m for, and refusing the rail there would
    lose content for no reason."""
    from archipepsi_bridge.schemas import constants as C
    assert C.FEATURE_MIN_WIDTH["rail"] < C.FEATURE_MIN_WIDTH["wind_volume"]
    narrow = 7.0
    assert C.FEATURE_MIN_WIDTH["rail"] <= narrow
    assert C.FEATURE_MIN_WIDTH["wind_volume"] > narrow
    _zone(chambers=[
        {"id": "c1", "type": "corridor", "length": 14.0, "width": narrow,
         "features": [{"tag": "rail", "at": (0.5, 0.5)}]}])
    with pytest.raises(ValidationError, match="wind_volume"):
        _zone(chambers=[
            {"id": "c1", "type": "corridor", "length": 14.0, "width": narrow,
             "features": [{"tag": "wind_volume", "at": (0.5, 0.5)}]}])


def test_a_corridor_too_narrow_for_a_feature_is_refused():
    """The Zone is refused rather than quietly stripped, so the repair
    loop gets a chance to widen the corridor."""
    with pytest.raises(ValidationError, match="to sit clear"):
        _zone(chambers=[
            {"id": "c1", "type": "corridor", "length": 12.0, "width": 4.5,
             "features": [{"tag": "bounce_pad", "at": (0.5, 0.5)}]},
            {"id": "c2", "type": "arena", "width": 16.0, "depth": 14.0,
             "wall_height": 5.0, "objective": "kill_all",
             "enemies": [{"archetype": "melee", "count": 2}],
             "reward_location_id": 89100001}])


def test_the_fallback_only_hangs_features_on_chambers_with_nothing_on_them():
    """The fallback is the provider the integration run uses, so if it
    placed a feature illegally the whole run would fail on a validator
    error rather than on anything a player would recognise."""
    from archipepsi_bridge.epsilon.fallback import fallback_zone
    request = _zone_request(("bounce_pad", "moving_platform", "rail"))
    zone = TypeAdapter(Z.Zone).validate_python(fallback_zone(request))
    placed = [(c.id, f.tag) for c in zone.chambers for f in c.features]
    assert placed, "a run with unlocked tags should offer something"
    # ...and it must be BUILDABLE, not just legal: the fallback widens a
    # corridor it is about to hang something on.
    for chamber in zone.chambers:
        for feature in chamber.features:
            assert chamber.width >= C_MIN_WIDTH[feature.tag], (
                chamber.id, chamber.width, feature.tag)
    for chamber in zone.chambers:
        if chamber.features:
            assert chamber.reward_location_id is None, chamber.id
            assert not getattr(chamber, "objective", None), chamber.id
    assert _validate(zone, owned=request.unlocked_affordances,
                     allocated=[loc.location_id for loc in request.locations]) == []


def test_every_shipping_provider_offers_affordances():
    """Not just the fallback.

    Mock Epsilon builds its own chambers rather than the fallback's, and
    it simply never placed a feature — so `--epsilon=mock`, the *richer*
    designer, shipped Zones with no optional content at all while the
    deliberately-boring fallback had some. Nothing caught it, because
    every affordance test named the fallback. A per-provider test is what
    notices the next provider that forgets.
    """
    import asyncio

    from archipepsi_bridge.epsilon.fallback import fallback_zone
    from archipepsi_bridge.epsilon.mock import MockEpsilonProvider

    request = _zone_request(("bounce_pad", "moving_platform", "rail"))
    produced = {
        "fallback": fallback_zone(request),
        "mock": asyncio.run(MockEpsilonProvider().generate_zone(request)),
    }
    for name, raw in produced.items():
        zone = TypeAdapter(Z.Zone).validate_python(raw)
        placed = [f.tag for c in zone.chambers for f in c.features]
        assert placed, f"{name} offered no affordance at all"
        assert set(placed) <= set(request.unlocked_affordances), (name, placed)
        assert _validate(
            zone, owned=request.unlocked_affordances,
            allocated=[loc.location_id for loc in request.locations]) == [], name


def test_the_fallback_offers_nothing_it_was_not_told_the_player_can_use():
    from archipepsi_bridge.epsilon.fallback import fallback_zone
    request = _zone_request(())
    zone = TypeAdapter(Z.Zone).validate_python(fallback_zone(request))
    assert [f for c in zone.chambers for f in c.features] == []


def test_every_unlocked_tag_reaches_a_zone_across_a_campaign():
    """A fully-unlocked campaign has 7 tags; a fallback Zone has 2 plain
    corridors capped at 3 features each. Six fit, one does not — and with
    a fixed tag order and a fixed corridor list the deal never rotated, so
    the SAME tag was dropped from every Zone in the campaign, forever.

    Rotating by zone index means each Zone drops a different one, so a
    player who owns a capability eventually sees something that uses it.
    """
    from archipepsi_bridge.epsilon.fallback import fallback_zone
    all_tags = _tags()
    seen: set[str] = set()
    for zone_index in range(len(all_tags)):
        request = _zone_request(all_tags).model_copy(update={
            "campaign": _zone_request(all_tags).campaign.model_copy(
                update={"zone_index": zone_index})})
        zone = TypeAdapter(Z.Zone).validate_python(fallback_zone(request))
        placed = {f.tag for c in zone.chambers for f in c.features}
        assert placed, zone_index
        seen |= placed
    assert seen == set(all_tags), sorted(set(all_tags) - seen)


def test_the_fallback_lays_out_the_same_zone_twice():
    """The fallback is the DETERMINISTIC provider. A feature set that
    wandered between two runs of the same campaign would make the
    integration run's assertions unreproducible for a reason nobody would
    look for."""
    from archipepsi_bridge.epsilon.fallback import fallback_zone
    request = _zone_request(("bounce_pad", "rail", "wind_volume"))
    assert fallback_zone(request) == fallback_zone(request)


# --- I13: the payoff is never Archipelago's -------------------------------

def test_the_local_reward_catalog_is_closed_and_shared():
    """The same six kinds on the wire and in the save. A kind that could
    be granted but not stored — or the reverse — is a reward that vanishes
    or one that cannot be earned."""
    assert set(P.GrantLocalReward.model_fields["kind"].annotation.__args__) \
        == set(P.EarnedLocalReward.model_fields["kind"].annotation.__args__)


def test_the_grant_intent_has_no_field_that_could_name_ap_truth():
    """§14.2, structurally. This is the test that would fail if somebody
    added a helpful `location_id` to the intent."""
    forbidden = ("location_id", "item", "item_name", "check", "coin",
                 "signal_key", "echo_id", "player", "slot_name")
    for field in P.GrantLocalReward.model_fields:
        assert field not in forbidden, field
    for field in P.EarnedLocalReward.model_fields:
        assert field not in forbidden, field


def test_a_local_reward_is_earned_once_however_often_it_is_reported():
    """The world may report the same pickup twice — a pull that lands on
    the same frame as a walk-over, a reconnect mid-Zone. Earning it twice
    would double a challenge marker's record.
    """
    reward = P.EarnedLocalReward(
        kind="epsilon_note", reward_id="c1_rail_0",
        display_name="Note", description="d", source_zone_id="zone_001")
    once = T.grant_local_reward(_save(), reward)
    twice = T.grant_local_reward(once, reward)
    assert len(twice.local_rewards) == 1


def test_a_challenge_record_only_moves_when_it_improves():
    marker = P.EarnedLocalReward(
        kind="challenge_marker", reward_id="c1_run", display_name="Sprint",
        source_zone_id="zone_001", best_seconds=12.5)
    save = T.grant_local_reward(_save(), marker)
    worse = T.grant_local_reward(
        save, marker.model_copy(update={"best_seconds": 20.0}))
    assert worse.local_rewards[0].best_seconds == 12.5
    better = T.grant_local_reward(
        worse, marker.model_copy(update={"best_seconds": 9.25}))
    assert better.local_rewards[0].best_seconds == 9.25


def test_earning_a_local_reward_moves_no_ap_truth():
    """The whole point of §14.2 in one assertion: a local reward is worth
    exactly zero to Archipelago."""
    before = _save()
    after = T.grant_local_reward(before, P.EarnedLocalReward(
        kind="cosmetic_grant", reward_id="skin_1", display_name="Skin",
        source_zone_id="zone_001"))
    # The save holds no copy of AP truth at all — that is the point — so
    # what a local reward must leave alone is everything the save DOES
    # own that AP cares about.
    assert after.pending_checks == before.pending_checks
    assert after.interpretations == before.interpretations
    assert after.coins_spent == before.coins_spent
    assert after.zones == before.zones
    assert after.generation_counter == before.generation_counter


# --- §14.1: readouts -------------------------------------------------------

def test_every_readout_in_the_contract_has_a_display():
    """A readout the fold can grant but the client cannot draw is an Echo
    that visibly does nothing. Read from the GDScript so the two lists
    cannot drift."""
    source = (GODOT / "scripts/ui/readouts.gd").read_text()
    match = re.search(r"const READOUTS := \[(.*?)\]", source, re.S)
    assert match
    drawn = set(re.findall(r'"([a-z_]+)"', match.group(1)))
    from archipepsi_bridge.schemas.echo import InfoComponent
    contract = set(InfoComponent.model_fields["readout"].annotation.__args__)
    assert drawn == contract, drawn ^ contract


def _interpretation(component: dict, seq: int = 0) -> object:
    """One CREATE, wrapped in a minimal valid interpretation."""
    from archipepsi_bridge.schemas.echo import EchoInterpretation
    return EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": "echo_89100001",
        "interpretation_seq": seq, "source_location_id": 89100001,
        "source_item_name": "Conference Call", "source_game": "Borderlands 2",
        "source_recipient_name": "BL2Player", "display_name": "Hook",
        "description": "A hook.",
        "operations": [{"op": "create", "component": component}]})


def _zone_request(unlocked: tuple[str, ...]):
    return zone_request().model_copy(
        update={"unlocked_affordances": unlocked})


def _save() -> P.CampaignSave:
    return P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah")


def _zone(chambers: list[dict]) -> Z.Zone:
    return TypeAdapter(Z.Zone).validate_python({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch", "chambers": chambers})


def _validate(zone, *, owned=(), allocated=None) -> list[str]:
    return Z.validate_zone(
        zone, expected_zone_id="zone_001",
        allocated_location_ids=(allocated if allocated is not None
                                else list(zone.reward_location_ids)),
        owned_echo_ids=[], owned_affordance_tags=owned)


def _gd_const(path: Path, name: str) -> float:
    match = re.search(rf"const {name} := ([0-9.]+)", path.read_text())
    assert match, f"{name} not found in {path.name}"
    return float(match.group(1))


def _zone_with_features(features: list[dict]) -> Z.Zone:
    return TypeAdapter(Z.Zone).validate_python({
        "schema_version": 7, "zone_id": "zone_001",
        "display_name": "Relay", "target_game": "Game", "theme": "void_glitch",
        "chambers": [
            {"id": "c1", "type": "corridor", "length": 12.0, "width": 9.5,
             "features": features},
            {"id": "c2", "type": "arena", "width": 16.0, "depth": 14.0,
             "wall_height": 5.0, "objective": "kill_all",
             "enemies": [{"archetype": "melee", "count": 2}],
             "reward_location_id": 89100001},
        ],
    })
