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
from .fallback import _clamp, _theme_for, fallback_echo, fallback_zone
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


def _connector(rng: random.Random) -> dict:
    return {"type": "corridor",
            "length": float(rng.randrange(8, 20)),
            "width": float(rng.randrange(4, 8))}


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
        echo = fallback_echo(request)
        echo["description"] = _clamp(
            f"Mock Epsilon's reading of {request.source.item_name}: "
            + echo["description"], C.MAX_TEXT_LEN)
        return echo
