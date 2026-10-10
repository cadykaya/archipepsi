"""Mock Epsilon: deterministic like the fallback, with real flair.

Used only when Mock Campaign is explicitly chosen. Distinct from the
fallback so the two axes stay observable: a mock Zone is recognisably
*designed* — varied chamber shapes, themed enemies and named rooms, all
seeded from the campaign key — while the fallback is deliberately the same
boring shape every time (`EPSILON_SPEC` §12.1 pins that shape, so it is
not this module's to improve).

Everything here still goes through the same validators as live model
output. Mock Epsilon can be interesting; it cannot be unsafe.
"""

from __future__ import annotations

import random

from ..schemas import constants as C
from ..schemas import migration as MG
from .concepts import mode_for_operations, read_concepts
from .fallback import (
    _add_features, _clamp, _common, _create_ops, _theme_for, as_disposition,
    fallback_echo, fallback_zone)
from .requests import EchoGenerationRequest, ZoneGenerationRequest

_ADJECTIVES = ("Humming", "Sunken", "Borrowed", "Restless", "Overgrown",
               "Backwards", "Polite", "Leaking", "Forgotten", "Enthusiastic")
_NOUNS = ("Concourse", "Substation", "Vault", "Undercroft", "Gallery",
          "Loading Bay", "Cistern", "Archive", "Switchyard", "Atrium")

_NOTES = (
    "I gave this one a bigger room because you seemed to enjoy the last one.",
    "Structurally sound. Emotionally unclear.",
    "The brute is optional. The brute does not know this.",
    "I tried a shape I have not tried before. Please be gentle with it.",
    "Built around the shotgun you never equip.",
    "Two rooms and a regret.",
    "This one is mostly corridor. Corridors are underrated.",
    "I have been thinking about verticality.",
)

#: Reward-chamber shapes the mock designer picks between. Each is a factory
#: taking (rng, index) and returning a chamber dict without its reward id;
#: every one is inside the schema bounds by construction.
def _arena_brawl(rng: random.Random, index: int) -> dict:
    return {"type": "arena",
            "width": float(rng.randrange(14, 25)),
            "depth": float(rng.randrange(12, 23)),
            "wall_height": float(rng.randrange(5, 8)),
            "objective": "kill_all",
            "enemies": [{"archetype": "melee", "count": rng.randint(2, 4)}]}


def _arena_snipers(rng: random.Random, index: int) -> dict:
    return {"type": "arena",
            "width": float(rng.randrange(16, 27)),
            "depth": float(rng.randrange(14, 25)),
            "wall_height": float(rng.randrange(6, 9)),
            "objective": "kill_all",
            "enemies": [{"archetype": "ranged", "count": rng.randint(2, 3)},
                        {"archetype": "melee", "count": rng.randint(1, 2)}]}


def _tower_climb(rng: random.Random, index: int) -> dict:
    return {"type": "tower",
            "floors": rng.randint(2, 5),
            "objective": "reach_reward",
            "enemies": [{"archetype": "ranged", "count": rng.randint(1, 2)}]}


def _tower_fight(rng: random.Random, index: int) -> dict:
    return {"type": "tower",
            "floors": rng.randint(2, 4),
            "objective": "kill_all",
            "enemies": [{"archetype": "melee", "count": rng.randint(2, 3)}]}


def _platforms(rng: random.Random, index: int) -> dict:
    step = round(rng.uniform(0.0, C.MAX_VERTICAL_STEP), 1)
    gap = round(min(rng.uniform(1.2, 2.4), C.max_safe_gap(step)), 1)
    return {"type": "platform_path",
            "segment_count": rng.randint(3, 8),
            "gap_size": gap,
            "vertical_step": step,
            "objective": "platform_to_goal"}


def _vault(rng: random.Random, index: int) -> dict:
    return {"type": "treasure_room"}


_REWARD_SHAPES = (_arena_brawl, _arena_snipers, _tower_climb, _tower_fight,
                  _platforms, _vault)

#: How the mock designer announces each §15 mode. The mode is derived from
#: the operations, so these phrases are always true of the Echo they
#: describe — which is the point of announcing them at all.
_MODE_PHRASING = {
    "literal": "Read",
    "mechanical": "Took the working parts of",
    "conceptual": "Read, loosely,",
    "systemic": "Wired",
}


def _join(concepts) -> str:
    """`a / b / c`, the archive's own separator (§15)."""
    return " / ".join(concepts) if concepts else "nothing in particular"


def _connector(rng: random.Random) -> dict:
    return {"type": "corridor",
            "length": float(rng.randrange(8, 20)),
            "width": float(rng.randrange(4, 8))}




# ---------------------------------------------------------------------------
# The wider action catalog (EPSILON_SPEC §12.2)
# ---------------------------------------------------------------------------
#
# §12.2 names this as mock's job and schedules it for S10: "`--epsilon=mock`
# has to exercise resources, rules, links, merges and the wider action
# catalog, or the headless integration run stops proving anything about the
# systems S2-S6 add." It was not done — mock delegated its whole echo to
# `fallback_echo` and added narration — and the cost was measurable: across
# ten full campaigns the fallback's heuristics reached 8 of the 28
# primitives, one of the four link kinds, and no Info readout at all. The
# blink suite fires 23,000 attempts at a verb no campaign grants; the hover
# and beam tests in `make godot-verbs` cover holds no player can perform.
#
# Each shape below is self-contained: it creates every component it names,
# so a link can never dangle and the fold's `_require_power_links` /
# `_require_fill_links` are satisfied from inside the interpretation. Every
# value sits inside its own field's declared bounds, and everything still
# goes through the same validators as live model output. Mock Epsilon can
# be interesting; it cannot be unsafe.


def _action(request, primitive: dict, *, slot: str, cooldown: float,
            suffix: str = "") -> dict:
    src = request.source
    return {
        "kind": "action",
        "component_id": MG.component_id_for("act", src.location_id) + suffix,
        "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
        "description": _clamp(f"{src.item_name}, read as a verb.",
                              C.MAX_TEXT_LEN),
        "slot": slot,
        "cooldown": cooldown,
        "primitive": primitive,
        "modifiers": [],
    }


def _bar(request, *, name: str, maximum: float, regen: float,
         delay: float, colour: str) -> dict:
    return {
        "kind": "resource",
        "component_id": MG.component_id_for("res", request.source.location_id),
        "display_name": _clamp(name, C.MAX_TEXT_LEN),
        "description": _clamp("What it spends.", C.MAX_TEXT_LEN),
        "max_value": maximum,
        "initial_fraction": 1.0,
        "regen_per_second": regen,
        "regen_delay": delay,
        "presentation": "bar",
        "palette_color": colour,
    }


def _powers(request, strength: float) -> dict:
    src = request.source
    return {"op": "link", "link": "powers",
            "source": MG.component_id_for("res", src.location_id),
            "target": MG.component_id_for("act", src.location_id),
            "strength": strength}


def _drained(request, primitive: dict, *, slot: str, cooldown: float,
             bar: str, maximum: float, regen: float, colour: str) -> list:
    """A held verb and the bar it burns.

    `beam_sustained`, `hover` and `block` are `POWERED_PRIMITIVES`: the
    fold REFUSES one with no `powers` link, because a drain verb with
    nothing to spend is a movement contract rather than an ability. So
    these three can only ever arrive as a three-operation shape, which is
    why the fallback — pinned to one CREATE — could never reach them.
    """
    return [
        _action(request, primitive, slot=slot, cooldown=cooldown),
        _bar(request, name=bar, maximum=maximum, regen=regen, delay=1.5,
             colour=colour),
        _powers(request, 1.0),
    ]


def _refilled(request, primitive: dict, *, slot: str, cooldown: float,
              bar: str, maximum: float, colour: str) -> list:
    """`restore_resource` is the mirror: the fold refuses it without a
    `fills` link, because the link says WHERE and the primitive says how
    much. The only shape that satisfies both is this one."""
    src = request.source
    return [
        _action(request, primitive, slot=slot, cooldown=cooldown),
        _bar(request, name=bar, maximum=maximum, regen=0.0, delay=0.0,
             colour=colour),
        {"op": "link", "link": "fills",
         "source": MG.component_id_for("act", src.location_id),
         "target": MG.component_id_for("res", src.location_id),
         "strength": 1.0},
    ]


def _gated(request, primitive: dict, *, slot: str, cooldown: float,
           bar: str, maximum: float, colour: str, threshold: float) -> list:
    """A verb behind a threshold. `gates` is the one link kind with no
    other route into a campaign: nothing in the fallback emits it, so
    without this the client's `_gates_open` is dead code in play."""
    src = request.source
    return [
        _action(request, primitive, slot=slot, cooldown=cooldown),
        _bar(request, name=bar, maximum=maximum, regen=6.0, delay=1.0,
             colour=colour),
        {"op": "link", "link": "gates",
         "source": MG.component_id_for("res", src.location_id),
         "target": MG.component_id_for("act", src.location_id),
         "strength": threshold},
    ]


def _scaled(request, *, stat: str, multiplier: float, bar: str,
            maximum: float, colour: str) -> list:
    """A trait that interpolates with a bar's fraction, via the LINK.

    `scaled_by` is a field on the trait and `scales` is an edge in the
    graph, and they are not the same mechanism: `stat_stack.gd` reads
    both, and only the field had any producer. The edge is what ECHOES §4
    draws (`Momentum --scales--> recoil`), so this emits the edge and
    leaves `scaled_by` unset -- the fourth link kind, finally reachable.
    """
    src = request.source
    return [
        _bar(request, name=bar, maximum=maximum, regen=4.0, delay=0.5,
             colour=colour),
        {
            "kind": "trait",
            "component_id": MG.component_id_for("trait", src.location_id),
            "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
            "description": _clamp("Stronger while the bar is full.",
                                  C.MAX_TEXT_LEN),
            "stat": stat,
            "multiplier": multiplier,
            "scaled_by": None,
            "requires_equipped": None,
        },
        {"op": "link", "link": "scales",
         "source": MG.component_id_for("res", src.location_id),
         "target": MG.component_id_for("trait", src.location_id),
         "strength": 1.0},
    ]


def _readout(request, readout: str) -> list:
    """An Info component, which is the ONLY thing that turns a §14.1
    readout on — `readouts.gd` reads `owned_components("info")` and
    nothing else. Nothing in the tree emitted one, so all ten readouts
    were built, tested by `make godot-affordance`, and unreachable by
    every player without an API key."""
    return [{
        "kind": "info",
        "component_id": MG.component_id_for("info", request.source.location_id),
        "display_name": _clamp(request.source.item_name, C.MAX_TEXT_LEN),
        "description": _clamp("It tells you something.", C.MAX_TEXT_LEN),
        "readout": readout,
    }]


#: concept -> the shape mock builds for it, most specific first. Keyed on
#: the §15 reading rather than on the item name, for the same reason the
#: fallback's enhancement is: the machinery that decides how Epsilon READ
#: an item is what should decide what the item does.
_MOCK_SHAPES = (
    ("beam", lambda r: (_drained(
        r, {"type": "beam_sustained", "damage_per_second": 14.0,
            "range": 24.0, "drain_per_second": 12.0},
        slot="echo_a", cooldown=0.6, bar="Charge", maximum=100.0,
        regen=8.0, colour="signal"), "a beam and the charge it burns")),
    ("flight", lambda r: (_drained(
        r, {"type": "hover", "gravity_multiplier": 0.25,
            "drain_per_second": 8.0, "max_duration": 4.0},
        slot="mobility", cooldown=1.2, bar="Lift", maximum=80.0,
        regen=10.0, colour="tide"), "a hover and the lift it spends")),
    ("buoyancy", lambda r: (_drained(
        r, {"type": "hover", "gravity_multiplier": 0.3,
            "drain_per_second": 6.0, "max_duration": 5.0},
        slot="mobility", cooldown=1.0, bar="Lift", maximum=90.0,
        regen=9.0, colour="tide"), "a hover and the lift it spends")),
    ("interposition", lambda r: (_drained(
        r, {"type": "block", "reduction": 0.6, "drain_per_second": 10.0},
        slot="utility", cooldown=0.4, bar="Guard", maximum=70.0,
        regen=7.0, colour="rust"), "a held block and its guard meter")),
    ("restoration", lambda r: (_refilled(
        r, {"type": "restore_resource", "amount": 40.0},
        slot="utility", cooldown=6.0, bar="Reserve", maximum=120.0,
        colour="moss"), "a reserve and the draught that refills it")),
    ("descent", lambda r: (_create(
        r, {"type": "glide", "fall_speed": 2.0, "forward_speed": 9.0},
        slot="mobility", cooldown=0.5), "a glide")),
    ("glide", lambda r: (_create(
        r, {"type": "glide", "fall_speed": 1.6, "forward_speed": 11.0},
        slot="mobility", cooldown=0.5), "a glide")),
    ("elsewhere", lambda r: (_create(
        r, {"type": "blink", "range": 12.0, "clearance": 0.5},
        slot="mobility", cooldown=4.0), "a blink")),
    ("displacement", lambda r: (_create(
        r, {"type": "blink", "range": 9.0, "clearance": 0.5},
        slot="mobility", cooldown=3.5), "a blink")),
    ("elevation", lambda r: (_create(
        r, {"type": "double_jump", "force": 8.0, "extra_jumps": 1},
        slot="mobility", cooldown=0.2), "a second jump")),
    ("footing", lambda r: (_create(
        r, {"type": "wall_kick", "force": 11.0, "outward_fraction": 0.4},
        slot="mobility", cooldown=0.3), "a kick off the wall")),
    ("propulsion", lambda r: (_create(
        r, {"type": "air_dash", "force": 14.0, "uses_per_airtime": 1},
        slot="mobility", cooldown=1.0), "a dash in mid-air")),
    ("weight", lambda r: (_create(
        r, {"type": "slam_ground", "damage": 22.0, "radius": 4.0,
            "descent_force": 18.0},
        slot="echo_b", cooldown=2.5), "a ground slam")),
    ("impact", lambda r: (_create(
        r, {"type": "slam_ground", "damage": 26.0, "radius": 3.5,
            "descent_force": 20.0},
        slot="echo_b", cooldown=2.8), "a ground slam")),
    ("thrust", lambda r: (_create(
        r, {"type": "melee_thrust", "damage": 30.0, "reach": 3.2},
        slot="echo_a", cooldown=0.7), "a thrust")),
    ("puncture", lambda r: (_create(
        r, {"type": "melee_thrust", "damage": 34.0, "reach": 2.8},
        slot="echo_a", cooldown=0.8), "a thrust")),
    ("tension", lambda r: (_create(
        r, {"type": "grapple_swing", "range": 22.0, "tether_force": 14.0,
            "max_duration": 3.0},
        slot="mobility", cooldown=1.5), "a swing")),
    ("pursuit", lambda r: (_create(
        r, {"type": "grapple_pull_target", "range": 20.0,
            "pull_force": 15.0, "max_target_hp": 40.0},
        slot="utility", cooldown=2.0), "a hook that pulls back")),
    ("restraint", lambda r: (_create(
        r, {"type": "parry", "window": 0.25},
        slot="utility", cooldown=1.2), "a parry")),
    ("triage", lambda r: (_create(
        r, {"type": "cleanse", "count": 2},
        slot="utility", cooldown=8.0), "a cleanse")),
    ("repair", lambda r: (_create(
        r, {"type": "cleanse", "count": 1},
        slot="utility", cooldown=6.0), "a cleanse")),
    ("proximity", lambda r: (_create(
        r, {"type": "pull_pickup", "radius": 9.0},
        slot="utility", cooldown=3.0), "a pull on loose things")),
    ("orientation", lambda r: (_create(
        r, {"type": "place_marker", "duration": 90.0},
        slot="utility", cooldown=5.0), "a marker you can leave")),
    ("revelation", lambda r: (_readout(r, "enemy_radar"), "a radar")),
    ("knowledge", lambda r: (_readout(r, "enemy_health"), "a health read")),
    ("clarity", lambda r: (_readout(r, "trajectory_preview"),
                           "a trajectory preview")),
    ("illumination", lambda r: (_readout(r, "secret_ping"),
                                "a ping for what is hidden")),
    ("focus", lambda r: (_readout(r, "damage_numbers"), "damage numbers")),
    ("certainty", lambda r: (_readout(r, "threat_direction"),
                             "where it came from")),
    ("signal", lambda r: (_readout(r, "affordance_highlight"),
                          "a highlight on what you can use")),
    ("acceleration", lambda r: (_readout(r, "speedometer"), "a speedometer")),
    ("depletion", lambda r: (_readout(r, "resource_forecast"),
                             "a forecast for the bars")),
    ("scan", lambda r: (_create(
        r, {"type": "scan_mark", "range": 30.0, "duration": 10.0},
        slot="utility", cooldown=4.0), "a scan")),
    ("concealment", lambda r: (_create(
        r, {"type": "scan_mark", "range": 25.0, "duration": 12.0},
        slot="utility", cooldown=5.0), "a scan")),
    ("momentum", lambda r: (_scaled(
        r, stat="damage_dealt", multiplier=1.6, bar="Momentum",
        maximum=100.0, colour="ember"), "a trait that rides a bar")),
    ("accumulation", lambda r: (_scaled(
        r, stat="move_speed", multiplier=1.35, bar="Head of Steam",
        maximum=100.0, colour="ember"), "a trait that rides a bar")),
    ("permission", lambda r: (_gated(
        r, {"type": "burst_fire", "damage": 9.0, "shots": 3,
            "interval": 0.09, "spread_degrees": 2.0, "range": 30.0},
        slot="echo_a", cooldown=1.0, bar="Authority", maximum=60.0,
        colour="signal", threshold=0.5), "a burst behind a threshold")),
    ("authority", lambda r: (_gated(
        r, {"type": "burst_fire", "damage": 11.0, "shots": 3,
            "interval": 0.08, "spread_degrees": 1.5, "range": 34.0},
        slot="echo_a", cooldown=1.1, bar="Authority", maximum=70.0,
        colour="signal", threshold=0.6), "a burst behind a threshold")),
)


def _create(request, primitive: dict, *, slot: str, cooldown: float) -> list:
    return [_action(request, primitive, slot=slot, cooldown=cooldown)]


def mock_echo_shape(request: EchoGenerationRequest):
    """The first §15 concept this item carries that mock has a shape for.

    Returns `(operations, phrase)` or None. Deterministic: the concept
    order comes from `read_concepts`, which is itself deterministic, so
    the same item always produces the same shape on any machine.
    """
    concepts = read_concepts(request.source.item_name,
                             request.source.source_game)
    by_concept = dict(_MOCK_SHAPES)
    for concept in concepts:
        build = by_concept.get(concept)
        if build is None:
            continue
        components, phrase = build(request)
        return components, phrase
    return None


def _mock_echo(request: EchoGenerationRequest) -> dict:
    """Mock's echo: the wider catalog when the item's reading supports it,
    the fallback's outcome when it does not.

    The fallback is still the floor, and deliberately: everything it does
    is proved by its own tests, and falling through to it is what keeps
    an item mock has no shape for from being an item mock gets wrong.
    What this adds is reach — the verbs, the link kinds and the readouts
    the fallback's pinned shape cannot express.

    The disposition chain runs on the result, exactly as it does inside
    `fallback_echo`. Skipping it looked safe — a table shape is a fresh
    CREATE by construction — and cost the campaign its evolutions: ten
    Zones ended with seventeen unrelated Actions against a soft budget of
    twelve, and eight upgrades where the fallback produced thirty-one. A
    second glide item has to become the first glide at Mk II, or mock is
    the accumulation problem `_as_sequel` was written to solve, wearing a
    wider catalog.
    """
    shape = mock_echo_shape(request)
    if shape is None:
        return fallback_echo(request)
    components, phrase = shape
    interpretation = as_disposition(
        _create_ops(request, f"{request.source.item_name}, as {phrase}.",
                    ["mock", "catalog"], components),
        request, enhancement=False)
    # The §15 reading is stamped the same way `fallback_echo` stamps it:
    # concepts from the item, mode DERIVED from what the operations did,
    # so the archive cannot describe a draft that no longer exists.
    interpretation["concepts"] = read_concepts(
        request.source.item_name, request.source.source_game)
    interpretation["mode"] = mode_for_operations(
        interpretation.get("operations", []))
    return interpretation


class MockEpsilonProvider:
    name = "mock"

    async def generate_zone(self, request: ZoneGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict:
        if request.campaign.is_finale:
            # The finale keeps the fallback's shape: one brute, one Check.
            return fallback_zone(request)

        rng = random.Random(C.prng_seed(
            request.campaign.seed_name, request.zone_id, "mock_epsilon"))
        locations = list(request.locations)

        # An opening corridor, then one reward chamber per allocated Check,
        # separated by connectors. Shapes are drawn without replacement so
        # a Zone never repeats itself, and the brute is a one-per-Zone
        # finisher on the last room.
        chambers: list[dict] = [dict(_connector(rng), id="c1")]
        shapes = list(_REWARD_SHAPES)
        rng.shuffle(shapes)
        for i, location in enumerate(locations):
            if i > 0:
                chambers.append(dict(_connector(rng),
                                     id=f"c{len(chambers) + 1}"))
            chamber = shapes[i % len(shapes)](rng, i)
            chamber["id"] = f"c{len(chambers) + 1}"
            chamber["reward_location_id"] = location.location_id
            last = i == len(locations) - 1
            if last and rng.random() < 0.6 and chamber["type"] == "arena":
                # Boss room: an arena holding the single brute.
                chamber["enemies"] = [{"archetype": "brute", "count": 1},
                                      {"archetype": "melee", "count": 2}]
                chamber["objective"] = "kill_all"
            chamber["flavor"] = _clamp(
                f"Presented in the manner of {location.recipient_game}.",
                C.MAX_TEXT_LEN)
            chambers.append(chamber)

        # Affordances (§13), on the connectors — the only chambers here
        # with neither a Check nor a gating objective. Shared with the
        # fallback rather than reimplemented: the placement RULES are
        # §13.2's, not this designer's taste, and a second copy would be a
        # second thing to get wrong. Mock Epsilon skipped this entirely
        # until the archive run noticed it shipping Zones with no optional
        # content at all, while the deliberately-boring fallback had some.
        _add_features(chambers, request.unlocked_affordances,
                      request.campaign.zone_index)

        # Naming draws from its own stream: sharing the layout stream made
        # every 3-Check Zone land on the same word, because the number of
        # prior draws was identical.
        namer = random.Random(C.prng_seed(
            request.campaign.seed_name, request.zone_id, "mock_name"))
        return {
            "schema_version": 7,
            "zone_id": request.zone_id,
            "display_name": _clamp(
                f"The {namer.choice(_ADJECTIVES)} {namer.choice(_NOUNS)} "
                f"of {request.campaign.target_game}", C.MAX_TEXT_LEN),
            "target_game": request.campaign.target_game,
            "theme": _theme_for(request.campaign.target_game),
            "designer_note": _clamp(namer.choice(_NOTES),
                                    C.MAX_DESIGNER_NOTE_LEN),
            "featured_echo_ids": [e.echo_id for e in request.player.echoes[:1]],
            "chambers": chambers,
        }

    async def generate_echo(self, request: EchoGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict:
        """The fallback's mechanics, read aloud (§15).

        Mock Epsilon does not invent mechanics the fallback cannot — the
        two providers share one validated vocabulary, and a mock that
        could express more would be testing a game nobody ships. What it
        adds is the *reading*: the concepts it took from the item, the
        mode it read it in, and a description that says so. That is the
        half of §15 the fallback deliberately does not do, and without a
        provider that does it the pipeline is only ever exercised by unit
        tests.
        """
        echo = _mock_echo(request)
        concepts = tuple(echo.get("concepts") or ())
        mode = str(echo.get("mode", "literal"))
        echo["description"] = _clamp(
            f"{_MODE_PHRASING.get(mode, 'Read')} "
            f"{request.source.item_name} as "
            f"{_join(concepts)}. " + echo["description"], C.MAX_TEXT_LEN)
        return echo
