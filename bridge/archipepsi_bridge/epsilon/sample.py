"""Serve one NAMED proposal from the declared sample, live.

    python -m archipepsi_bridge --ap=mock --epsilon=sample \\
        --sample-zone=../godot/tests/fixtures/sample/zone_05.json

**Why this exists.** `make zone-sample` judges a manifest offline: the
engine builds the Zone, measures it, writes the manifest, and
`layout.validate` reads it. That answers "would the bridge accept this
geometry" and nothing about what a PLAYER meets -- whether the client
enters, whether a refusal recovers, whether the Hub stays usable. The
only path that answers those is the live one, and the live one has always
generated its own Zones.

So this is a provider that hands back a named sample instead of composing
one. Everything else stays real: the campaign is a real campaign, the
allocation is its own, the client builds the geometry itself, certifies
its own chains, and the bridge validates what comes back. **Nothing here
fabricates a certificate or skips acceptance** -- it only decides WHICH
proposal the campaign is asked to lay out.

**The proposal is re-keyed, not rewritten.** A sample Zone carries the
`zone_id` and the Check ids it was dumped with; the campaign asking for
it has its own. Identity and allocation are taken from the REQUEST --
that is what makes the acceptance real rather than a replay of someone
else's bookkeeping -- and the rooms, the graph, the doors and the
features are the sample's, untouched.

A campaign that allocates fewer Checks than the sample places is a
mismatch this cannot paper over, and it says so rather than quietly
dropping rooms.
"""

from __future__ import annotations

import json
from pathlib import Path

from .requests import EchoGenerationRequest, ZoneGenerationRequest
from .fallback import fallback_echo
from ..schemas.zone import Zone


class SampleZoneMismatch(RuntimeError):
    """The named sample cannot be keyed to this campaign's allocation."""


def rekey(zone: dict, request: ZoneGenerationRequest) -> dict:
    """The sample's rooms, this campaign's identity and Check ids."""
    out = json.loads(json.dumps(zone))       # a copy, never the fixture
    out["zone_id"] = request.zone_id
    wanted = [loc.location_id for loc in request.locations]
    # `reward_ids` IS THE ONE READING, and a raw-field read here would
    # see only the first Check in a room that holds several. The
    # proposal arrives as plain JSON, so it is parsed into the model
    # whose accessor that is rather than re-deriving the rule.
    parsed = Zone.model_validate(out)
    holds = {c.id: len(c.reward_ids) for c in parsed.chambers}
    holders = [c for c in out.get("chambers", ())
               if holds.get(c.get("id"), 0)]
    if len(holders) > len(wanted):
        raise SampleZoneMismatch(
            f"{len(holders)} rooms in the sample hold a Check and this "
            f"campaign allocated {len(wanted)}; ask for the sample at "
            "the scale it was dumped at rather than dropping rooms")
    for chamber, location_id in zip(holders, wanted):
        chamber["reward_location_id"] = location_id
        # EXTRAS GO. They are ids from another campaign's allocation, and
        # keeping them would name Checks this Zone was never given.
        chamber["additional_reward_location_ids"] = []
    return out


class SampleEpsilonProvider:
    """Replays one named sample proposal; Echoes come from the fallback.

    **`then` names a SECOND proposal, served from a Zone's second
    request onward.** Without it a Zone whose sample the engine cannot
    build fails identically on every retry -- which demonstrates the
    budget and the exhaustion honestly, and cannot demonstrate the other
    half: a failure followed by a replacement that really is built,
    certified and accepted.

    **And an ordinary provider cannot stand in for it.** The fallback
    seeds composition on `zone_index` and `zone_budget` alone, so the
    recompose after a refusal returns byte-identical content -- measured
    here: `zone_008` failed three times on the same rooms, twice from
    the fallback composing them fresh. That is a real property of the
    deterministic provider and is recorded rather than worked around;
    this axis exists so the client-and-bridge recovery path can be
    exercised without pretending the provider varied.

    The provider says on every hand-off which source a proposal came
    from, so a log cannot be read as "the sample was accepted on the
    third try".
    """

    name = "sample"

    def __init__(self, path: str | Path, then: str | Path | None = None):
        self.path = Path(path)
        self._zone = json.loads(self.path.read_text(encoding="utf-8"))
        self.then = Path(then) if then else None
        self._then_zone = (
            json.loads(self.then.read_text(encoding="utf-8"))
            if self.then else None)
        #: Zone ids this provider has already handed the first sample to.
        self._served: set[str] = set()

    async def generate_zone(self, request: ZoneGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict:
        repeat = request.zone_id in self._served
        if repeat and self._then_zone is not None:
            print(f"  sample: '{request.zone_id}' has had "
                  f"{self.path.name} once; serving {self.then.name} for "
                  f"this attempt", flush=True)
            return rekey(self._then_zone, request)
        self._served.add(request.zone_id)
        print(f"  sample: serving {self.path.name} as '{request.zone_id}'"
              + (f"  (a retry will get {self.then.name})"
                 if self.then and not repeat else ""), flush=True)
        return rekey(self._zone, request)

    async def generate_echo(self, request: EchoGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict:
        return fallback_echo(request)
