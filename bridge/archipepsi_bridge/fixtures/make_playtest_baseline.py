"""Generate `docs/baselines/playtest_2_5.json`, the PRE-ART baseline.

Playtest 2.5 is the last measurement taken before authored art lands, and
its whole value is that the run after it can be compared to it. That only
works if the two runs walked the SAME LOGICAL ZONE: a comparison across
two different levels measures the levels.

So this records, from source, exactly what the engine builds today --

* the campaign scale the baseline was taken at, so a later retune is
  visible as a retune rather than as an art result;
* three consecutive Zones, request and accepted output, verbatim;
* the first Echoes the same campaign produces;
* the derived measurements a playtest is compared against.

It records. It does not tune. Nothing in here chooses a budget, a Check
count, a zone length or a finale fraction -- every number is read from
`constants.py`, and the test beside it fails if any of them moves,
because a baseline taken at a different scale is not a baseline.

The fallback provider is the source on purpose: it is what a player with
no API key plays, it is what the integration run plays, and it is
deterministic. A Claude-generated Zone is a different Zone every time and
cannot be a baseline for anything.

Run with `make baseline`. The JSON is not to be edited.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from pydantic import TypeAdapter                              # noqa: E402

from archipepsi_bridge import content_value as V              # noqa: E402
from archipepsi_bridge.epsilon.fallback import (              # noqa: E402
    fallback_echo, fallback_zone)
from archipepsi_bridge.epsilon.requests import (              # noqa: E402
    CampaignContext, EchoGenerationRequest, EchoPlayerState, EchoSource,
    PlayerContext, RequestLocation, ZoneGenerationRequest)
from archipepsi_bridge.schemas import constants as C          # noqa: E402
from archipepsi_bridge.schemas import zone as Z               # noqa: E402
from archipepsi_bridge.schemas.mechanics import (             # noqa: E402
    Mechanics, owned_affordance_tags, owned_capabilities)
from archipepsi_bridge.schemas.echo import EchoInterpretation  # noqa: E402

OUT = (Path(__file__).resolve().parents[3]
       / "docs" / "baselines" / "playtest_2_5.json")

_ZONE = TypeAdapter(Z.Zone)
_ECHO = TypeAdapter(EchoInterpretation)

#: How many consecutive Zones to record. Three rather than one because
#: the thing playtest 2 reported was that four Zones in a row played the
#: same, and a one-Zone baseline cannot show that they no longer do.
ZONE_COUNT = 3

#: The items the recorded Echoes are interpreted from. Fixed strings, and
#: deliberately from four different worlds: the Echo an item becomes is a
#: function of its name, so a baseline built from one game's items would
#: measure a narrower campaign than anyone plays.
BASELINE_ITEMS = [
    ("Hookshot", "Ocarina of Time", "Zelda"),
    ("Estus Flask", "Dark Souls III", "Ashen One"),
    ("Morph Ball", "Super Metroid", "Samus"),
    ("Boost Boots", "Bomb Rush Cyberfunk", "Red"),
]


#: A campaign that has interpreted nothing, which is what the baseline
#: describes: zone 1, no Echoes, no Signal Keys, no Coins.
_FRESH_CAMPAIGN = Mechanics()


def _zone_request(index: int) -> ZoneGenerationRequest:
    config = C.DEFAULT_CONFIG
    locations = tuple(
        RequestLocation(
            location_id=C.FIRST_LOCATION_ID + (index - 1) * 100 + i,
            location_name=f"Archipepsi Check {(index - 1) * 100 + i:03d}",
            item_name=BASELINE_ITEMS[i % len(BASELINE_ITEMS)][0],
            recipient_name=BASELINE_ITEMS[i % len(BASELINE_ITEMS)][2],
            recipient_game=BASELINE_ITEMS[i % len(BASELINE_ITEMS)][1],
            item_flags=0)
        for i in range(config.zone_target_checks))
    return ZoneGenerationRequest(
        zone_id=f"zone_{index:03d}", generation_id=f"baseline-zone-{index}",
        campaign=CampaignContext(
            seed_name="ArchipepsiBaseline", slot_name="Playtester", team=0,
            slot_id=1, zone_index=index, target_game="Ocarina of Time",
            is_finale=False, static_glitch_units=0,
            zone_budget=config.zone_budget),
        player=PlayerContext(signal_keys=0, coins_available=0),
        locations=locations,
        # WHAT THE CAMPAIGN CAN USE, derived rather than hardcoded.
        #
        # This read `unlocked_affordances=()` and `guaranteed_capabilities`
        # would have been next. It was wrong in the way that is hardest to
        # see: the archived baseline then held ZERO affordance features
        # while the Zone the human actually played held two, because the
        # live path (`campaign.py`) computes both from the fold and this
        # fixture typed a constant instead. Evidence that under-reports
        # what was played is worse than no evidence, because it is
        # believed.
        #
        # A fresh campaign is `Mechanics()` -- nothing interpreted yet --
        # and the two functions below answer honestly for it: two base-kit
        # affordance tags, and the permanent-baseline capability.
        unlocked_affordances=owned_affordance_tags(_FRESH_CAMPAIGN),
        guaranteed_capabilities=owned_capabilities(_FRESH_CAMPAIGN))


def _echo_request(seq: int) -> EchoGenerationRequest:
    name, game, recipient = BASELINE_ITEMS[seq % len(BASELINE_ITEMS)]
    return EchoGenerationRequest(
        required_echo_id=f"echo_{C.FIRST_LOCATION_ID + seq}",
        source=EchoSource(
            location_id=C.FIRST_LOCATION_ID + seq, item_name=name,
            source_game=game, recipient_name=recipient, item_flags=0),
        player_state=EchoPlayerState())


def _measure(zone: Z.Zone) -> dict:
    """What a playtest is compared against. Derived, never chosen."""
    return {
        "chambers": len(zone.chambers),
        "content_value": round(V.zone_value(zone)),
        "enemy_total": sum(c.enemy_total for c in zone.chambers),
        "checks": sum(len(c.reward_ids) for c in zone.chambers),
        "rooms_holding_no_check":
            sum(1 for c in zone.chambers if not c.reward_ids),
        "chamber_types": sorted({c.type for c in zone.chambers}),
    }


def build() -> dict:
    config = C.DEFAULT_CONFIG
    zones = []
    for index in range(1, ZONE_COUNT + 1):
        request = _zone_request(index)
        raw = fallback_zone(request)
        zone = _ZONE.validate_python(raw)
        errors = Z.validate_zone(
            zone, expected_zone_id=request.zone_id,
            allocated_location_ids=[loc.location_id
                                    for loc in request.locations],
            owned_echo_ids=[],
            owned_affordance_tags=request.unlocked_affordances,
            guaranteed_capabilities=request.guaranteed_capabilities,
            zone_budget=request.campaign.zone_budget)
        if errors:                       # a bug in our own generator
            raise SystemExit(
                f"baseline zone {index} does not validate: {errors}")
        zones.append({
            "zone_index": index,
            "request": request.model_dump(mode="json"),
            "zone": raw,
            "measured": _measure(zone),
        })

    echoes = []
    for seq in range(len(BASELINE_ITEMS)):
        request = _echo_request(seq)
        raw = fallback_echo(request)
        _ECHO.validate_python(raw)       # parses, or the baseline is junk
        echoes.append({
            "interpretation_seq": seq,
            "request": request.model_dump(mode="json"),
            "echo": raw,
        })

    return {
        "label": "playtest_2_5",
        "purpose": (
            "The last measurement before authored art. A later run is "
            "compared against this one, so both have to have walked the "
            "same logical Zone."),
        "generated_by": "make baseline",
        "provider": "fallback",
        # The scale this was taken AT. Not a setting -- a record, so that
        # a retune shows up as a retune rather than as an art result.
        "scale": {
            "location_count": config.location_count,
            "zone_target_checks": config.zone_target_checks,
            "zone_budget": config.zone_budget,
            "check_value": V.CHECK_VALUE,
            "finale_required_fraction": C.FINALE_REQUIRED_FRACTION,
            "finale_required_checks": config.finale_required_checks(),
            "max_enemies_spawned_cap": C.MAX_ENEMIES_SPAWNED_CAP,
        },
        "zones": zones,
        "echoes": echoes,
    }


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(build(), indent=2, sort_keys=True) + "\n")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
