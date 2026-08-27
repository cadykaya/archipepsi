"""Mock Epsilon: deterministic like the fallback, with a little more flair.

Used only when Mock Campaign is explicitly chosen. Distinct from the
fallback so the two axes stay observable: a mock Zone is recognisably
"designed" (varied chamber picks seeded from the campaign key) while the
fallback is the same boring shape every time.
"""

from __future__ import annotations

import random

from ..schemas import constants as C
from .fallback import _clamp, fallback_echo, fallback_zone
from .requests import EchoGenerationRequest, ZoneGenerationRequest

_ADJECTIVES = ("Humming", "Sunken", "Borrowed", "Restless", "Overgrown",
               "Backwards", "Polite", "Leaking", "Forgotten", "Enthusiastic")
_NOUNS = ("Concourse", "Substation", "Vault", "Undercroft", "Gallery",
          "Loading Bay", "Cistern", "Archive", "Switchyard", "Atrium")


class MockEpsilonProvider:
    name = "mock"

    async def generate_zone(self, request: ZoneGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict:
        zone = fallback_zone(request)
        rng = random.Random(C.prng_seed(
            request.campaign.seed_name, request.zone_id, "mock_epsilon"))
        if not request.campaign.is_finale:
            zone["display_name"] = _clamp(
                f"The {rng.choice(_ADJECTIVES)} {rng.choice(_NOUNS)} "
                f"of {request.campaign.target_game}", C.MAX_TEXT_LEN)
            zone["designer_note"] = _clamp(
                "Mock Epsilon assembled this from spare parts and confidence.",
                C.MAX_DESIGNER_NOTE_LEN)
        return zone

    async def generate_echo(self, request: EchoGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict:
        echo = fallback_echo(request)
        echo["description"] = _clamp(
            f"Mock Epsilon's reading of {request.source.item_name}: "
            + echo["description"], C.MAX_TEXT_LEN)
        return echo
