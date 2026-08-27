"""The fallback provider must stay legal, deterministic — and now, varied.

The fallback is not a corner case: `--epsilon=fallback` is the configuration
the integration run uses, the one `make bridge-mock` uses, and the one a
player without an API key plays. Whatever it can express IS the game for
them. Through S1 it could express three outcomes for an unrecognised item —
a gun, a dash, or walking faster — so a 26-Check campaign was one verb
repeated. S2 widened the vocabulary, and these tests hold that widening to
the same rules everything else obeys.
"""

from __future__ import annotations

from archipepsi_bridge.epsilon import capabilities as CAP
from archipepsi_bridge.epsilon.fallback import fallback_echo
from archipepsi_bridge.epsilon.requests import (
    EchoGenerationRequest, EchoPlayerState, EchoSource,
)
from archipepsi_bridge.schemas.echo import (
    EchoInterpretation, IMPLEMENTED_PRIMITIVES, validate_interpretation,
)

#: The canonical §3.1 fixture plus ordinary multiworld item names, held to
#: 30 because that is how many Checks a campaign has — the location id range
#: is bounded to exactly that, and a corpus that outgrew it would be testing
#: a campaign that cannot exist.
ITEM_NAMES = [
    "Conference Call", "Hookshot", "Wing Cap", "Estus Shard", "REP",
    "Progressive Sword", "Iron Spear", "War Hammer", "Oak Staff",
    "Compact SMG", "Warp Whistle", "Deku Glider", "Rocket Boots",
    "Climbing Claws", "Riposte Manual", "Brass Compass", "Bomb Bag",
    "Rocket Launcher", "Boss Key", "Small Key", "Rupee", "Blue Orb",
    "Power Star", "Heart Container", "Master Ball", "Ancient Tablet",
    "Red Coin", "Silver Feather", "Magic Meter", "Stamina Ring",
]
assert len(ITEM_NAMES) == 30, len(ITEM_NAMES)


def _echo_for(index: int, name: str) -> EchoInterpretation:
    request = EchoGenerationRequest(
        source=EchoSource(
            location_id=89100001 + index, item_name=name,
            source_game="Some Game", recipient_name="Partner", item_flags=0),
        player_state=EchoPlayerState(),
        required_echo_id=f"echo_{89100001 + index}",
    )
    return EchoInterpretation.model_validate(fallback_echo(request))


def test_every_fallback_echo_is_valid_and_runnable_today():
    """Legal by the schema AND executable by the engine.

    The pipeline raises rather than persisting if a fallback is out of
    stage, so this failing means `make bridge-mock` would crash on a grant
    rather than degrade — which is why it is checked over a corpus and not
    on one example.
    """
    for index, name in enumerate(ITEM_NAMES):
        echo = _echo_for(index, name)
        assert validate_interpretation(
            echo, expected_source_location_id=89100001 + index) == [], name
        assert CAP.validate_stage_support(echo) == [], name


def test_the_fallback_reaches_a_real_spread_of_verbs():
    """A campaign should not be one verb 26 times."""
    primitives = set()
    for index, name in enumerate(ITEM_NAMES):
        for operation in _echo_for(index, name).operations:
            component = operation.component
            if component.kind == "action":
                primitives.add(component.primitive.type)
    assert len(primitives) >= 10, sorted(primitives)
    assert primitives <= set(IMPLEMENTED_PRIMITIVES), (
        primitives - set(IMPLEMENTED_PRIMITIVES))


def test_the_fallback_is_still_deterministic():
    """Same Check, same Echo — every time, and across processes.

    This is what lets a v7 save migrate and a fresh fallback for the same
    location agree, and what makes `make replay` meaningful at all.
    """
    for index, name in enumerate(ITEM_NAMES):
        first = _echo_for(index, name)
        second = _echo_for(index, name)
        assert first.model_dump() == second.model_dump(), name


def test_the_fallback_is_still_structurally_boring():
    """One CREATE per operation, no links, no merges.

    The fallback is the test oracle for every stage after this one. It got a
    wider vocabulary in S2; it did not get permission to become interesting.
    """
    from archipepsi_bridge.epsilon import capabilities as CAP
    for index, name in enumerate(ITEM_NAMES):
        echo = _echo_for(index, name)
        assert echo.mode == "literal", name
        assert 1 <= len(echo.operations) <= 4, name
        for operation in echo.operations:
            # CREATE only is the load-bearing half: no UPGRADE, MODIFY,
            # LINK or MERGE means the fallback can never dangle a target or
            # fail a fold, which is what keeps it usable as the oracle for
            # every stage after this one.
            assert operation.op == "create", (name, operation.op)
            # Which KINDS it may create is a staging question, not a
            # boringness one, so it is asked of the registry rather than of
            # a literal that would need editing every stage. S3 added
            # "resource" here; the constraint above did not move.
            assert operation.component.kind in CAP.IMPLEMENTED_COMPONENT_KINDS, (
                name, operation.component.kind)


def test_the_fallback_produces_resource_channels():
    """S3's pipeline is only proven if something actually creates a channel.

    Without a fallback that makes one, `--epsilon=fallback` — which is what
    the integration run and any keyless player use — would never exercise
    grant, fold, channel assignment, snapshot or HUD for resources at all.
    """
    from archipepsi_bridge.schemas.mechanics import derive_mechanics
    log = []
    for index, name in enumerate(ITEM_NAMES):
        echo = _echo_for(index, name)
        log.append(echo.model_copy(update={"interpretation_seq": index}))
    mechanics = derive_mechanics(log)
    resources = mechanics.resources
    assert len(resources) >= 2, [r.component_id for r in resources]

    # Channels are dense and creation-ordered, and the serialized order the
    # client reads agrees with the method the bridge uses.
    assert mechanics.channel_order == tuple(
        r.component_id for r in resources)
    for index, owned in enumerate(resources):
        assert mechanics.channel_of(owned.component_id) == index

    # Each carries the world that made it, which is what the source glyph
    # and accent are drawn from.
    for owned in resources:
        assert owned.source_game, owned.component_id

    # And a channel that starts full would never visibly move, so at least
    # one starts below it — that is what makes the pressure valve legible
    # rather than theoretical.
    assert any(r.component.initial_fraction < 1.0 for r in resources)
