"""Deterministic fallback generators (EPSILON_SPEC §12).

Failure recovery AND the test oracle for engine-side generation: the whole
loop with no API cost and no nondeterminism. Output goes through the same
validators as model output — no exceptions.
"""

from __future__ import annotations

import math
import random

from pydantic import TypeAdapter

from .. import composition as X
from .. import content_value as V
from ..schemas import constants as C
from ..schemas.zone import HEADROOM, Zone as _Zone
from ..schemas import migration as MG
from ..schemas import echo as E
from ..schemas.echo import COMPLEXITY_BUDGETS
from .concepts import mode_for_operations, read_concepts
from .requests import EchoGenerationRequest, ZoneGenerationRequest


def _theme_for(target_game: str) -> str:
    theme = C.THEME_BY_GAME_HINT.get(target_game)
    if theme is None:
        theme = C.THEMES[C.prng_seed(target_game, "fallback_theme")
                         % len(C.THEMES)]
    return theme


def _clamp(text: str, limit: int) -> str:
    return text if len(text) <= limit else text[: limit - 1] + "…"


_ZONE_ADAPTER = TypeAdapter(_Zone)


def _rule_errors(zone, request, budget: int) -> list[str]:
    """The same rules the real provider's output has to satisfy."""
    from ..schemas.zone import validate_zone
    return validate_zone(
        zone, expected_zone_id=request.zone_id,
        allocated_location_ids=[loc.location_id
                                for loc in request.locations],
        owned_echo_ids=[],
        owned_affordance_tags=request.unlocked_affordances,
        guaranteed_capabilities=request.guaranteed_capabilities,
        zone_budget=budget)


def fallback_zone(request: ZoneGenerationRequest) -> dict:
    """The Zone. See `fallback_zone_attempt` for how it was reached."""
    return fallback_zone_attempt(request)[0]


def fallback_zone_attempt(request: ZoneGenerationRequest) -> tuple[dict, int]:
    """A Zone that satisfies the same rules the real provider must,
    and the salt that produced it.

    The salt is returned so the tests can tell a builder that gets it
    RIGHT from one that gets it right EVENTUALLY. The retry loop below
    hides construction bugs by definition -- a wrong enemy count on the
    first attempt is invisible once a later salt validates -- and a
    safety net nobody measures is a safety net that is quietly load
    bearing.

    This is the OFFLINE FIXTURE, and it is what a player without an API
    key actually plays -- so a four-room toy here means human playtesting
    never exercises production-scale gameplay, whatever the Claude
    provider is capable of (CAMPAIGN_SCALE.md 11).

    It therefore builds to the requested `zone_budget`, places every
    allocated Check, and satisfies the composition constraints: a
    landmark, quiet space, combat, variety, no long connector chains.
    It does not need an LLM's prose. It needs to be a level.

    Deterministic means the same campaign and zone replay identically.
    It does not mean every Zone is the same room list, which is what it
    used to mean.
    """
    locations = list(request.locations)
    theme = _theme_for(request.campaign.target_game)
    n = request.campaign.zone_index
    budget = request.campaign.zone_budget
    rng = random.Random(f"archipepsi/fallback/zone/{n}/{budget}")

    # The finale is a Zone. It holds one Check -- the goal -- so it is a
    # SHORT level rather than a full-length one, but a campaign that ends
    # in a corridor and one brute after thirty real Zones ends badly, and
    # a Zone built for a budget it does not meet fails validation
    # (CAMPAIGN_SCALE.md 5). It goes through the same builder.
    if request.campaign.is_finale:
        name = _clamp(f"Terminal Relay {n:03d}", C.MAX_TEXT_LEN)
        note = "Deterministic fallback finale."
    else:
        name = _clamp(f"Relay {n:03d}: {request.campaign.target_game}",
                      C.MAX_TEXT_LEN)
        note = "Deterministic fallback zone."

    def attempt(salt: int) -> dict:
        seeded = random.Random(
            f"archipepsi/fallback/zone/{n}/{budget}/{salt}")
        chambers = _build_to_budget(seeded, locations, budget,
                                    request.unlocked_affordances)
        _add_features(chambers, request.unlocked_affordances, n)
        return {
            "schema_version": 7,
            "zone_id": request.zone_id,
            "display_name": name,
            "target_game": request.campaign.target_game,
            "theme": theme,
            "designer_note": note,
            "chambers": chambers,
        }

    # The fallback CHECKS ITS OWN WORK, because it is the one provider
    # with nothing behind it: a Claude Zone that breaks a rule gets
    # repaired or replaced by this one, and when this one breaks a rule
    # the portal simply never opens.
    #
    # Retrying with a salted seed rather than adding another heuristic.
    # The construction satisfies the rules in 119 cases out of 120 across
    # the whole option space; the last one is a landmark that did not
    # quite stand out, and chasing it with more special cases makes the
    # builder harder to reason about than the rules it is trying to
    # satisfy. Still deterministic: the same zone index and budget
    # produce the same salt sequence, so the same Zone comes back.
    last = None
    for salt in range(8):
        candidate = attempt(salt)
        try:
            zone = _ZONE_ADAPTER.validate_python(candidate)
        except Exception:
            last = candidate
            continue
        if not _rule_errors(zone, request, budget):
            return candidate, salt
        last = candidate
    return last, 7


def _max_enemy_groups(chamber_type: str) -> int:
    """How many enemy GROUPS this chamber type accepts.

    Read off the schema rather than retyped: a platform path takes two
    and an arena four, and the fallback discovering that by failing
    validation is the fallback discovering it too late.
    """
    from ..schemas.zone import Chamber
    for model in Chamber.__origin__.__args__:
        if model.model_fields["type"].annotation.__args__[0] != chamber_type:
            continue
        field = model.model_fields.get("enemies")
        if field is None:                       # a treasure room has none
            return 0
        for meta in field.metadata:
            limit = getattr(meta, "max_length", None)
            if limit is not None:
                return limit
    return 0


def _content_room(rng, index: int, lean: bool, step: float,
                  enemies_left: int) -> dict:
    """A room that exists because the budget bought it, not a Check.

    Checks are worth nothing (CAMPAIGN_SCALE.md 5), so a Zone's length
    comes from its content -- and a Zone whose rooms all hang off a
    Check is as long as its Check count and no longer.
    """
    count = min(rng.randint(2, 4), max(0, enemies_left))
    if index % 2 and count:
        # `kill_all` with nothing to kill is not a legal objective, so a
        # Zone already at its enemy ceiling gets a traversal room here.
        return {
            "id": f"c{index:03d}", "type": "arena",
            **_arena_shape(rng, lean),
            "objective": "kill_all",
            "enemies": [{"archetype": rng.choice(["melee", "ranged"]),
                         "count": count}]}
    return {
        "id": f"c{index:03d}", "type": "platform_path",
        "segment_count": rng.randint(3, 5),
        "gap_size": round(min(rng.uniform(1.4, 2.4),
                              C.max_safe_gap(step)), 2),
        "vertical_step": step,
        "objective": "platform_to_goal"}


def _build_to_budget(rng, locations, budget, unlocked) -> list[dict]:
    """Rooms enough to hold the Checks, then content enough to be a level.

    Two passes on purpose. The first places what the campaign REQUIRES --
    every allocated Check, in its own room, with a connector rhythm. The
    second adds content until the Zone is worth what it was asked for.
    Doing it in one pass makes the Checks compete with the budget, and
    the Checks are not negotiable.
    """
    from ..content_value import budget_band, room_value, zone_value

    low, high = budget_band(budget)
    enemy_cap = C.max_enemies_per_zone(budget)
    brute_cap = C.max_brutes_per_zone(budget)

    # How rich the BASE rooms are, before any top-up.
    #
    # Scaled by how much budget each Check has to play with. A 200-point
    # Zone holding three Checks has ~66 points per Check, and rooms built
    # for a 1000-point Zone overshoot its ceiling before the top-up loop
    # runs at all -- which no amount of careful adding can then fix,
    # because the floor is already above the roof.
    room_low, room_high = C.zone_room_envelope(budget)
    room_high = max(2, min(C.ZONE_MAX_CHAMBERS - 2, room_high))
    planned = max(len(locations), room_low)
    lean = budget / max(1, planned) < 45.0

    chambers: list[dict] = [
        {"id": "c001", "type": "corridor",
         "length": round(rng.uniform(10.0, 18.0), 1),
         "width": round(rng.uniform(5.0, 8.0), 1)}]

    # Connectors thin out as the Check count rises: 30 Checks plus a
    # connector between every pair is more rooms than the engine ceiling
    # allows, and the Checks are the part that cannot be dropped.
    room_budget = C.ZONE_MAX_CHAMBERS - 2
    # Varied per Zone, not just per campaign: a fixed rhythm gives every
    # Zone in a run the same number of rooms in the same order, which is
    # the skeleton behind "the levels are the same". Content varies
    # already; the SHAPE has to vary too.
    if len(locations) * 3 // 2 < room_budget:
        connector_every = rng.choice([2, 2, 3, 4])
    else:
        connector_every = rng.choice([5, 6])

    step = round(rng.uniform(0.4, 0.9), 2)
    for index, loc in enumerate(locations):
        kind = ("arena", "platform_path", "arena")[index % 3]
        if kind == "arena":
            chambers.append({
                "id": f"c{len(chambers) + 1:03d}", "type": "arena",
                **_arena_shape(rng, lean),
                "objective": "kill_all",
                "enemies": [{"archetype": rng.choice(["melee", "ranged"]),
                             "count": rng.randint(1, 2 if lean else 5)}],
                "reward_location_id": loc.location_id})
        else:
            chambers.append({
                "id": f"c{len(chambers) + 1:03d}", "type": "platform_path",
                "segment_count": rng.randint(3, 4 if lean else 6),
                "gap_size": round(min(rng.uniform(1.4, 2.4),
                                      C.max_safe_gap(step)), 2),
                "vertical_step": step,
                "objective": "platform_to_goal",
                "reward_location_id": loc.location_id})
        if (index % connector_every == connector_every - 1
                and index < len(locations) - 1
                and len(chambers) < room_budget):
            chambers.append({
                "id": f"c{len(chambers) + 1:03d}", "type": "corridor",
                "length": round(rng.uniform(8.0, 16.0), 1),
                "width": round(rng.uniform(5.0, 8.0), 1)})

    # The landmark is built RICH, not merely large. Growing it afterwards
    # runs into the per-chamber caps at exactly the room counts where the
    # average is highest, so it starts where it needs to end up.
    rooms = [c for c in chambers if c["type"] == "arena"]
    landmark = None
    if rooms:
        landmark = rooms[len(rooms) // 2]
        landmark["width"] = 26.0
        landmark["depth"] = 24.0
        landmark["wall_height"] = 7.0
        landmark["enemies"] = [
            {"archetype": "melee", "count": 4 if lean else 7},
            {"archetype": "brute", "count": 1}]
        if not lean:
            landmark["activities"] = [
                _activity("switch_sequence", 5),
                _activity("target_challenge", 4)]

    # Now top up to the band with activities and enemies, cheapest lever
    # first, never past a cap.
    def totals() -> tuple[int, int]:
        return (sum(sum(g["count"] for g in c.get("enemies", []))
                    for c in chambers),
                sum(g["count"] for c in chambers
                    for g in c.get("enemies", [])
                    if g["archetype"] == "brute"))

    def chamber_enemies(chamber: dict) -> int:
        return sum(g["count"] for g in chamber.get("enemies", []) or ())

    def would_fit(extra: int) -> bool:
        """Room in the BAND for this much more content.

        Checked before adding rather than after: an activity is worth
        12-20 points, which on a 200-point Zone is a tenth of the whole
        budget. Adding first and noticing later overshoots the ceiling,
        which is a validation failure rather than a rounding error.
        """
        current = sum(room_value(_AsChamber(c)) for c in chambers)
        return current + extra <= high

    kinds = ["switch_sequence", "target_challenge", "pressure_routing",
             "timed_run"]
    ceiling = min(room_budget, room_high)

    #: How rich an ORDINARY room is allowed to get while there is still
    #: room in the Zone for another one. Without it the loop fills each
    #: room to its per-chamber ceiling and only then adds a new one, so
    #: every room ends up at the ceiling -- and a Zone where everything
    #: is maximal has no landmark, because nothing can stand out from
    #: it. Spreading the budget over rooms is also what makes a level
    #: feel long rather than merely dense (CAMPAIGN_SCALE.md 5, 6).
    soft_cap = budget / max(1, ceiling)

    def grow(target: dict, guard: int) -> bool:
        """Put more into one existing room. False when it cannot."""
        if (len(chambers) < ceiling and target is not landmark
                and room_value(_AsChamber(target)) >= soft_cap):
            return False
        if target["type"] == "corridor":
            # A level needs somewhere to breathe, and the top-up loop is
            # perfectly capable of filling every connector on its way to
            # the budget -- which is how a 2000-point Zone came out dense
            # in all thirty rooms. The quietest room is protected
            # outright rather than left to a coin flip.
            quiet = [c for c in chambers
                     if room_value(_AsChamber(c)) < X.CONNECTOR_VALUE]
            if len(quiet) <= 1 and target in quiet:
                return False
            if rng.random() < 0.5:
                return False
        acts = target.setdefault("activities", [])
        elements = rng.randint(2, 5)
        kind = kinds[(guard + len(acts)) % len(kinds)]
        # Scored from the activity that will actually be appended, not
        # from a base-plus-elements guess: a `timed_run` now carries a
        # clock, which is worth `ACTIVITY_TIMED_BONUS` more, and a fit
        # check that under-counts by four is a fit check that can walk
        # the Zone out of its band at small budgets.
        candidate = _activity(kind, elements)
        if len(acts) < 3 and would_fit(V.room_value(_AsChamber(
                {"type": "arena", "width": 0.0, "depth": 0.0,
                 "activities": [candidate]}))):
            acts.append(candidate)
            return True
        enemies, _ = totals()
        groups = target.setdefault("enemies", [])
        count = rng.randint(2, 4)
        if (target["type"] != "corridor"
                and len(groups) < _max_enemy_groups(target["type"])
                and enemies + count <= enemy_cap
                and chamber_enemies(target) + count
                <= C.MAX_ENEMIES_PER_CHAMBER
                and would_fit(V.ENEMY_VALUE["melee"] * count)):
            groups.append({"archetype": rng.choice(["melee", "ranged"]),
                           "count": count})
            return True
        return False

    guard = 0
    stalled = 0
    while guard <= 2000:
        if sum(room_value(_AsChamber(c)) for c in chambers) >= low:
            break
        guard += 1
        if grow(chambers[guard % len(chambers)], guard):
            stalled = 0
            continue
        stalled += 1
        if stalled < len(chambers):
            continue
        # Every room is full and the Zone is still under its band, so
        # what it needs is another ROOM. A one-Check Zone starts with
        # two rooms and a per-chamber ceiling, and no amount of adding
        # to those two reaches its floor: the budget buys rooms, and
        # Checks are not what pays for them (CAMPAIGN_SCALE.md 5).
        if len(chambers) < ceiling:
            spent, _ = totals()
            chambers.append(_content_room(rng, len(chambers) + 1, lean,
                                          step, enemy_cap - spent))
            stalled = 0
            continue
        # A room that declined this pass has not necessarily run out --
        # connectors are left alone on a coin flip, so one sweep of
        # refusals is normal and giving up on it left 2000-point Zones
        # a quarter short of their floor. Give up only when several
        # full sweeps in a row change nothing.
        if stalled >= 4 * len(chambers):
            break

    # The landmark, LAST. Topping the Zone up to its budget spreads
    # content everywhere and flattens the distribution, so a room that
    # was distinctive before the loop is merely large after it -- which
    # is how a 2000-point Zone ended up failing the landmark rule while
    # every individual room looked fine.
    #
    # Restored by giving the biggest room more of what it already is,
    # rather than by shrinking the others: a level wants somewhere that
    # stands out, not everywhere else made duller.
    if landmark is not None:
        for _ in range(24):
            values = [room_value(_AsChamber(c)) for c in chambers]
            average = sum(values) / len(values)
            if room_value(_AsChamber(landmark)) >= average * 1.9:
                break
            acts = landmark.setdefault("activities", [])
            if len(acts) < 3:
                acts.append(_activity("switch_sequence",
                                      rng.randint(3, 6)))
                continue
            enemies, _ = totals()
            groups = landmark.setdefault("enemies", [])
            count = rng.randint(2, 4)
            if (len(groups) < 4 and enemies + count <= enemy_cap
                    and chamber_enemies(landmark) + count
                    <= C.MAX_ENEMIES_PER_CHAMBER):
                groups.append({"archetype": "ranged", "count": count})
            else:
                break

    return chambers


class _AsChamber:
    """Scoring a chamber DICT before it is a model.

    The fallback builds dictionaries and has to know their value while it
    is still deciding what to add. `room_value` reads attributes, so this
    presents the same fields -- rather than validating a whole Zone on
    every iteration of the loop, which is the same number twice.
    """

    def __init__(self, data: dict):
        self._data = data
        self.enemies = tuple(
            _Group(g) for g in data.get("enemies", []) or ())
        self.features = tuple(
            _Tagged(f) for f in data.get("features", []) or ())
        self.activities = tuple(
            _Activity(a) for a in data.get("activities", []) or ())
        # Presence is all `room_value` asks about, so the dict itself is
        # a good enough stand-in for the model.
        self.elevation = data.get("elevation")

    def __getattr__(self, name):
        if name == "reward_ids":
            first = self._data.get("reward_location_id")
            extra = tuple(self._data.get(
                "additional_reward_location_ids", ()) or ())
            return ((first,) if first is not None else ()) + extra
        return self._data.get(name)


class _Group:
    def __init__(self, data: dict):
        self.archetype = data["archetype"]
        self.count = data["count"]


class _Tagged:
    def __init__(self, data: dict):
        self.tag = data["tag"]


class _Activity:
    def __init__(self, data: dict):
        self.kind = data["kind"]
        self.element_count = data.get("element_count", 1)
        self.time_limit = data.get("time_limit", 0.0)
        self.ordered = data.get("ordered", False)


#: The schema's own upper bound on a corridor (`CorridorChamber.width`).
#: Widening past it would make a Zone the validator refuses, which is the
#: opposite of what the widening is for.
MAX_CORRIDOR_WIDTH = 10.0


#: How often an arena gets a second walkable height (ROOM_GRAMMAR v0).
#:
#: PROVISIONAL, and the number the next playtest sets. Not 1.0: a raised
#: area in every arena is the flat rectangle again with a step in it, and
#: the variety is in some rooms having one and some not. Not low either,
#: because a feature the owner meets twice in a Zone cannot be judged.
BAND_CHANCE = 0.55


def _arena_shape(rng, lean: bool) -> dict:
    """An arena's dimensions and its band, decided together.

    Together because they constrain each other: a gallery's rise is
    bounded by the ceiling it sits under, so rolling the wall height
    first and the band second is the only order that cannot produce a
    room the validator has to refuse.
    """
    width = round(rng.uniform(12.0, 18.0 if lean else 24.0), 1)
    depth = round(rng.uniform(10.0, 16.0 if lean else 22.0), 1)
    wall_height = round(rng.uniform(4.5, 7.0), 1)
    shape = {"width": width, "depth": depth, "wall_height": wall_height}
    band = _band(rng, width, depth, wall_height)
    if band is not None:
        shape["elevation"] = band
    return shape


def _band(rng, width: float, depth: float, wall_height: float) -> dict | None:
    """An elevation band for an arena, or None (ROOM_GRAMMAR v0).

    NOT every room. A raised area in every arena is the flat rectangle
    again with an extra step in it -- the variety is in some rooms having
    one and some not, and in which wall it hugs.

    The rise is bounded by the CEILING as well as by the schema: a
    gallery must leave a player room to stand up on it, which
    `ArenaChamber._a_band_leaves_room_to_stand` refuses at validation.
    Computing it here rather than rolling and retrying keeps the
    fallback's "valid on the first attempt" property, which is measured.
    """
    if rng.random() > BAND_CHANCE:
        return None
    # A pit needs floor to spare; a narrow room gets a gallery instead.
    kind = "pit" if (min(width, depth) >= 16.0 and rng.random() < 0.3) \
        else "gallery"
    if kind == "gallery":
        highest = wall_height - HEADROOM
        if highest < C.MAX_VERTICAL_STEP:
            return None
        # FLOORED, not rounded. `round` can move a number UP by half a
        # centimetre, which is enough to push a rise that exactly fitted
        # under the ceiling back through the schema's headroom check --
        # and the fallback is measured on getting it right at salt 0, so
        # a five-millimetre error costs a reroll rather than a warning.
        rise = math.floor(min(rng.uniform(1.6, 2.6), highest) * 100) / 100
    else:
        rise = round(rng.uniform(1.2, 2.0), 2)
    return {
        "kind": kind,
        "rise": rise,
        "coverage": round(rng.uniform(0.25, 0.45), 2),
        "side": rng.choice(["left", "right", "back"]),
        "access": "ramp",
    }


def _activity(kind: str, elements: int, ordered: bool = False) -> dict:
    """One activity, with the clock its family needs.

    A `timed_run` with no clock is a contradiction: activate, then reach
    the target BEFORE IT LAPSES, with nothing that can lapse. The played
    Zone contained seven of them and every one had `time_limit = 0`, so
    the one dial that can make the family fail was never set.

    The number is DERIVED, not chosen. `ActivityPrimitive` already
    computes the minimum a clock may be -- the walk at base movement
    speed, generously -- and this asks for exactly that floor, which is
    the most forgiving legal value. Tuning it is a playtest's job, not a
    fallback's.
    """
    activity = {"kind": kind, "element_count": elements}
    if ordered:
        activity["ordered"] = True
    if kind == "timed_run":
        needed = elements * C.SECONDS_PER_ACTIVITY_ELEMENT
        if ordered:
            needed *= C.ORDERED_ACTIVITY_TIME_MULTIPLIER
        activity["time_limit"] = round(needed, 1)
    return activity


def _add_features(chambers: list[dict], unlocked: tuple[str, ...],
                  zone_index: int = 0) -> None:
    """Hang the unlocked affordances (§13) off the plain chambers.

    Only chambers with nothing riding on them: a feature may not share a
    chamber with an AP reward or a gating objective (§13.2), and
    `validate_zone` refuses the Zone if one does. Placing them only where
    they are legal keeps the fallback's Zones acceptable by construction
    rather than by a validator catching it afterwards.

    Every tag here is one the campaign can already USE — `unlocked` comes
    from `owned_affordance_tags`, over owned mechanics. A campaign that has
    interpreted nothing still gets the two base-kit tags, so even the first
    Zone has something optional in it.
    """
    if not unlocked:
        return
    # Connectors, which the fallback still prefers for features even
    # though CAMPAIGN_SCALE.md 7 now permits them in reward rooms: the
    # fallback is not trying to be interesting here, and a corridor is
    # where a feature is unambiguously off the mandatory route.
    #
    # ALL the room's Checks, not just the primary. A room whose only
    # Checks were "additional" would otherwise read as empty -- which
    # cannot happen today because extras require a primary, but a rule
    # that holds only because of another rule is one refactor from being
    # false.
    plain = [c for c in chambers
             if c.get("reward_location_id") is None
             and not c.get("additional_reward_location_ids")
             and not c.get("objective")]
    if not plain:
        return
    # Widen enough for the WIDEST tag this Zone will actually place, and
    # never past the schema's corridor cap. A single conservative width
    # would refuse a rail from a corridor it fits in perfectly well.
    wanted = [t for t in unlocked if t in C.FEATURE_MIN_WIDTH]
    if not wanted:
        return
    widest = min(MAX_CORRIDOR_WIDTH,
                 max(C.FEATURE_MIN_WIDTH[t] for t in wanted))
    for chamber in plain:
        chamber["width"] = max(float(chamber.get("width", 5.0)), widest)
    # Deal round-robin so a run that unlocks five tags does not stack all
    # five in the first corridor. Both loops are ordered, so the same
    # campaign lays out the same Zone twice — the fallback is the
    # deterministic provider, and a feature set that wandered between runs
    # would make the integration run's assertions unreproducible.
    # Rotated by the Zone's index. Both the tag order and the corridor
    # list are fixed, so a plain round-robin dealt the same hand every
    # time: a fully-unlocked campaign has 7 tags, a fallback Zone has 2
    # corridors capped at 3 features each, and the sixth tag in sorted
    # order was dropped from EVERY Zone, forever. Rotating means each
    # Zone drops a different one, so all seven appear across a campaign.
    ordered = sorted(unlocked)
    if ordered:
        offset = zone_index % len(ordered)
        ordered = ordered[offset:] + ordered[:offset]
    for index, tag in enumerate(ordered):
        chamber = plain[index % len(plain)]
        # A tag the corridor cannot hold is skipped rather than emitted
        # for the validator to refuse: the fallback's job is to always
        # produce something acceptable.
        if float(chamber["width"]) < C.FEATURE_MIN_WIDTH.get(
                tag, C.MIN_FEATURE_CHAMBER_WIDTH):
            continue
        features = list(chamber.get("features", []))
        # The schema's per-chamber cap is the only cap there is; when the
        # plain chambers are full the remaining tags simply do not appear
        # in this Zone. They are optional content, so dropping one costs
        # nothing — and the next Zone deals from the same ordered set.
        if len(features) >= 3:
            continue
        # Off-centre and staggered down the length. The builder pushes a
        # feature clear of the walking lane whatever it is handed, but
        # asking for the lane and relying on that would be writing a bug
        # that another file happens to correct.
        lateral = 0.18 if index % 2 == 0 else 0.82
        along = 0.3 + 0.2 * (index // 2 % 3)
        features.append({"tag": tag, "at": (lateral, along)})
        chamber["features"] = features


# ---------------------------------------------------------------------------
# Echo
# ---------------------------------------------------------------------------

def _common(request: EchoGenerationRequest, description: str,
            tags: list[str]) -> dict:
    src = request.source
    return {
        "schema_version": 8,
        "echo_id": request.required_echo_id,
        # Overwritten by `transitions.append_interpretation`, which owns
        # sequence assignment. A provider never chooses its own number.
        "interpretation_seq": 0,
        "source_location_id": src.location_id,
        "source_item_name": src.item_name,
        "source_game": src.source_game,
        "source_recipient_name": src.recipient_name,
        # Both are stamped by `_read_and_label` once the operations are
        # settled — the mode is derived FROM them, so choosing it here
        # would describe a draft rather than the finished Echo.
        "concepts": (),
        "mode": "literal",
        "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
        "description": _clamp(description, C.MAX_TEXT_LEN),
        "tags": tags,
    }


def _primary(request: EchoGenerationRequest, *, archetype: str, cooldown: float,
             initiator: dict, modifiers: list[dict] | None = None,
             description: str, tags: list[str]) -> dict:
    """One CREATE, one Action. The v8 shape; the same §12.2 decisions.

    The heuristics below are pinned by the packet and did not change — only
    what they emit did. Keeping the signature means the mapping table stays
    readable as a mapping table rather than becoming a wall of component
    dictionaries.
    """
    src = request.source
    return {**_common(request, description, tags), "operations": [{
        "op": "create",
        "component": {
            "kind": "action",
            "component_id": MG.component_id_for("act", src.location_id),
            "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
            "description": _clamp(description, C.MAX_TEXT_LEN),
            "slot": MG.ARCHETYPE_SLOT.get(archetype, "echo_a"),
            "cooldown": cooldown,
            "primitive": initiator,
            "modifiers": modifiers or [],
        },
    }]}


def _primary_and_resource(
        request: EchoGenerationRequest, *, archetype: str, cooldown: float,
        initiator: dict, resource: dict, description: str,
        tags: list[str], powers: float | None = None) -> dict:
    """One Action and one Resource, from one item.

    The recorded S1 decision is that the fallback stays deliberately boring,
    and this does not breach it: still `CREATE` only, still no links, merges
    or rules, still nothing that can dangle a target or fail a fold. What it
    adds is a second component from a single interpretation, which is the
    only way the resource pipeline — grant, fold, channel assignment,
    snapshot, HUD — is exercised end to end by the integration run.

    S5 closed the loop: `powers` names the press cost the resource pays
    for the action, so the button finally spends the bar it arrived with.
    Starting below full with a slow regen keeps the pressure valve visible.
    """
    src = request.source
    return {**_common(request, description, tags), "operations": [
        {
            "op": "create",
            "component": {
                "kind": "action",
                "component_id": MG.component_id_for("act", src.location_id),
                "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
                "description": _clamp(description, C.MAX_TEXT_LEN),
                "slot": MG.ARCHETYPE_SLOT.get(archetype, "echo_a"),
                "cooldown": cooldown,
                "primitive": initiator,
                "modifiers": [],
            },
        },
        {
            "op": "create",
            "component": {
                "kind": "resource",
                "component_id": MG.component_id_for("res", src.location_id),
                **resource,
            },
        },
    ] + ([] if powers is None else [{
        "op": "link", "link": "powers",
        "source": MG.component_id_for("res", src.location_id),
        "target": MG.component_id_for("act", src.location_id),
        "strength": powers,
    }])}


def _create_ops(request: EchoGenerationRequest, description: str,
                tags: list[str], components: list[dict]) -> dict:
    """1-4 operations, in the order given. An entry carrying its own `op`
    passes through (S5 links); anything else is wrapped as a CREATE. Still
    the boring shape — nothing reaches backward into the campaign — but the
    fold requires a rule's resource, and a link's endpoints, to exist
    EARLIER in the interpretation, so order here is load-bearing."""
    return {**_common(request, description, tags), "operations": [
        component if "op" in component
        else {"op": "create", "component": component}
        for component in components
    ]}


def _passive(request: EchoGenerationRequest, *, effects: list[dict],
             description: str, tags: list[str]) -> dict:
    """One CREATE per passive, each a Trait. Traits are always on, so a
    fallback passive is strictly better for the player than v0.7's was."""
    src = request.source
    return {**_common(request, description, tags), "operations": [{
        "op": "create",
        "component": {
            "kind": "trait",
            "component_id": MG.component_id_for("trait", src.location_id,
                                                str(index)),
            "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
            "description": _clamp(description, C.MAX_TEXT_LEN),
            "stat": MG.PASSIVE_STAT[effect["type"]],
            "multiplier": effect["multiplier"],
        },
    } for index, effect in enumerate(effects)]}


def _budget_room(mechanics, *, resources: int = 0, rules: int = 0,
                 request=None) -> bool:
    """Whether the campaign can absorb this many more without breaching a
    hard budget (§16). The fallback is the last resort AFTER validation has
    already refused the provider — a fallback the same validation then
    refuses is a RuntimeError in `_pipeline` ("a bug in our own
    generator"), so a resource- or rule-bearing outcome must step aside
    near the ceiling and let the item read as its budget-free shape.

    Reads the REQUEST when no fold is handed over, which is the case that
    actually matters. `FallbackEpsilonProvider` and `MockEpsilonProvider`
    are called through the provider protocol, which has no `mechanics`
    parameter — so both were asking this question with `None` and always
    hearing "yes". At a full resource budget that produced an Echo the
    validator refused, burned the one repair round, and only then reached
    the last-resort builder (which does get the fold). With
    `--epsilon=mock` the player watched a run that never involved a model
    report "EPSILON OFFLINE — FALLBACK USED".

    S10 put `budget_headroom` in the request for exactly this shape of
    question, and a provider reading what it was given is the right way
    round: it sees what any other provider sees.
    """
    owned_counts: dict[str, int] = {}
    if mechanics is not None:
        for component in mechanics.owned:
            owned_counts[component.kind] = owned_counts.get(
                component.kind, 0) + 1
    elif request is not None and getattr(request, "budget_headroom", None):
        for kind, (owned, _soft, _hard) in request.budget_headroom.items():
            owned_counts[kind] = int(owned)
    else:
        return True

    return (owned_counts.get("resource", 0) + resources
            <= COMPLEXITY_BUDGETS["resource"][1]
            and owned_counts.get("rule", 0) + rules
            <= COMPLEXITY_BUDGETS["rule"][1])


#: What to raise when an item turns out to be a sequel, per field, and by
#: how much. Ordered: the first field the target actually has, wins.
#: Deltas are deliberately modest — a Mk II should read as "the same thing,
#: better", not as a replacement — and every one is checked against the
#: target's own bounds before it is emitted.
#: How an upgraded field is DESCRIBED, one word per field.
#:
#: This used to be `"sharper" if delta >= 0 else "quicker"` -- two words
#: for eleven fields, and since ten of the eleven deltas are positive,
#: almost everything in the game was "sharper". A Warp Whistle that
#: gained +6 range read "The same Warp Whistle, sharper", which is not
#: what happened to it: sharpness is not a property a teleport has.
#:
#: The word follows the FIELD, because the field is what changed. A
#: census, not a default -- `test_fallback_variety.py` fails on a ladder
#: entry with no word, so adding an upgradable field means saying what
#: improving it feels like rather than inheriting "sharper".
_UPGRADE_WORD = {
    "damage": "heavier",
    "damage_per_second": "fiercer",
    "range": "farther",
    "reach": "longer",
    "radius": "wider",
    "pull_force": "stronger",
    "force": "stronger",
    "amount": "deeper",
    "max_value": "deeper",
    "multiplier": "steeper",
    "cooldown": "quicker",
}

_UPGRADE_LADDER = (
    ("damage", 4.0),
    ("damage_per_second", 6.0),
    ("range", 6.0),
    ("reach", 0.6),
    ("radius", 1.0),
    ("pull_force", 3.0),
    ("force", 2.0),
    ("amount", 8.0),
    ("max_value", 25.0),
    ("multiplier", 0.15),
    ("cooldown", -0.2),
)


def _family_of_summary(summary) -> str:
    """What makes two components "the same thing" for evolution.

    ECHOES §11: ancestry is semantic, not textual — *Hookshot* and
    *Longshot* are one grapple because they resolve to the same verb, not
    because their names rhyme. The request's `detail` carries that verb
    for an action and the stat for a trait, which is exactly the key.
    """
    if summary.kind not in ("action", "trait"):
        return ""
    return f"{summary.kind}:{summary.detail}"


def _as_sequel(interpretation: dict, request: EchoGenerationRequest):
    """Turn a CREATE into an UPGRADE when the campaign already owns the
    family — the *Hookshot → Longshot* rule, ECHOES §11.

    Works from the REQUEST, not from the fold: a provider sees what it is
    given and nothing else, and the fallback is a provider. Everything it
    needs is in `player_state.owned_components` — the family key, and the
    bounds each field still has room inside.

    Returns None when there is nothing to evolve, when the item is not a
    single-component interpretation, or when every rung of the ladder
    would leave the target's declared range. In all three cases the caller
    keeps its ordinary CREATE, so this can only make the fallback richer,
    never invalid.
    """
    operations = interpretation.get("operations", [])
    if len(operations) != 1 or operations[0].get("op") != "create":
        return None
    component = operations[0]["component"]
    if component["kind"] not in ("action", "trait"):
        return None
    primitive = component.get("primitive")
    family = (f"action:{primitive['type']}" if primitive
              else f"trait:{component.get('stat')}")

    for owned in request.player_state.owned_components:
        if _family_of_summary(owned) != family:
            continue
        headroom = {field: (current, low, high)
                    for field, current, low, high in owned.upgradable}
        for field, delta in _UPGRADE_LADDER:
            if field not in headroom:
                continue
            current, low, high = headroom[field]
            if not (low <= current + delta <= high):
                continue
            return {
                **interpretation,
                "description": _clamp(
                    "The same %s, %s. Mk %d."
                    % (owned.display_name, _UPGRADE_WORD[field],
                       owned.mk + 1),
                    C.MAX_TEXT_LEN),
                "tags": list(interpretation.get("tags", [])) + ["evolution"],
                "operations": [{
                    "op": "upgrade",
                    "target": owned.component_id,
                    "field": field,
                    "delta": delta,
                }],
            }
    return None


#: A concept the §15 reader produces -> the status an item carrying it
#: makes a weapon apply. ECHOES §3's own MODIFY example is *Fire Flower*
#: making the gun's hits apply `burning`, and this is that rule written
#: down: the concept the item reads as decides the status, so the
#: disposition is derived from the reading rather than from the name.
_CONCEPT_STATUS = {
    "fire": ("burning", 1.2, 3.0),
    "cold": ("slowed", 0.8, 4.0),
    "electricity": ("shocked", 1.0, 2.5),
    "slowness": ("slowed", 0.6, 5.0),
    "brittleness": ("vulnerable", 0.9, 3.0),
    "decay": ("poisoned", 1.0, 5.0),
}


def _as_enhancement(interpretation: dict, request: EchoGenerationRequest):
    """Turn a CREATE into a MODIFY when the item reads as an element and
    the campaign already owns something that hits — the *Fire Flower*
    rule, ECHOES §3.

    Like `_as_sequel`, this works from the REQUEST alone and returns None
    whenever it cannot land, so the caller keeps its ordinary CREATE. The
    three ways it can fail to land are all visible from the summary: the
    target must be an action on a damage primitive, it must have room
    (`modifiers` caps at two), and the type must not already be there.

    Preferring MODIFY over another CREATE is what stops a campaign full of
    elemental items from being a campaign full of guns.
    """
    concepts = read_concepts(request.source.item_name,
                             request.source.source_game)
    match = next((c for c in concepts if c in _CONCEPT_STATUS), None)
    if match is None:
        return None
    status, magnitude, duration = _CONCEPT_STATUS[match]

    for owned in request.player_state.owned_components:
        if owned.kind != "action" or owned.detail not in E.DAMAGE_PRIMITIVES:
            continue
        if len(owned.modifiers) >= 2 or "apply_status_on_hit" in owned.modifiers:
            continue
        return {
            **interpretation,
            "description": _clamp(
                "%s now leaves %s behind. Mk %d."
                % (owned.display_name, status, owned.mk + 1),
                C.MAX_TEXT_LEN),
            "tags": list(interpretation.get("tags", [])) + ["enhancement"],
            "operations": [{
                "op": "modify",
                "target": owned.component_id,
                "add_modifier": {
                    "type": "apply_status_on_hit",
                    "status": status,
                    "duration": duration,
                    "magnitude": magnitude,
                },
            }],
        }
    return None


def _as_confluence(interpretation: dict, request: EchoGenerationRequest):
    """Turn a resource CREATE into a CREATE + MERGE once the campaign is
    at its resource budget — the *Blue Estus* rule, ECHOES §3.

    §16 says that over soft budget the request asks for `MERGE`, and this
    is the shape that answers it: the new economy is created and folded
    into an existing one, so the item is genuinely credited (provenance
    unions, Mk sums) while the channel count does not move. Fifteen HUD
    channels is the hard ceiling, and a campaign that spent them on
    sixteen flasks would have nowhere left to put the interesting ones.

    Returns None unless the merge would LAND: `capacity="sum"` walks the
    survivor's `max_value` up by the absorbed's, and the fold re-validates
    rather than clamping, so a survivor near the 1000 ceiling is not a
    candidate. That bound is in the summary already, as `upgradable`.
    """
    if "resource" not in (request.over_soft_budget or ()):
        return None
    operations = list(interpretation.get("operations", []))
    # The merge is APPENDED, so there has to be room for it under §2's
    # four-operation ceiling. The fallback's resource shapes are two and
    # three operations wide (a bar plus what spends it, plus the `powers`
    # link between them), which is what makes appending the right move:
    # the link keeps naming the absorbed id, and the fold rewrites both
    # endpoints onto the survivor when the merge lands.
    if len(operations) >= C.ECHO_MAX_OPERATIONS:
        return None
    created = [op for op in operations
               if op.get("op") == "create"
               and op["component"]["kind"] == "resource"]
    if len(created) != 1:
        return None
    component = created[0]["component"]
    incoming = float(component.get("max_value", 0.0))

    for owned in request.player_state.owned_components:
        if owned.kind != "resource":
            continue
        room = {field: (current, low, high)
                for field, current, low, high in owned.upgradable}
        if "max_value" not in room:
            continue
        current, low, high = room["max_value"]
        if not (low <= current + incoming <= high):
            continue
        return {
            **interpretation,
            "description": _clamp(
                "Folded into %s rather than adding a sixteenth meter."
                % owned.display_name, C.MAX_TEXT_LEN),
            "tags": list(interpretation.get("tags", [])) + ["confluence"],
            "operations": operations + [
                {"op": "merge",
                 "absorbed": component["component_id"],
                 "survivor": owned.component_id,
                 "capacity": "sum"},
            ],
        }
    return None


def fallback_echo(request: EchoGenerationRequest, *,
                  mechanics=None) -> dict:
    """The §12.2 heuristics, then one question: is this a sequel?

    S6. Every outcome below is a fresh CREATE, which is what made a
    26-Check campaign twenty-six unrelated things. Running the answer
    through `_as_sequel` first means an item whose verb the campaign
    already owns evolves it instead — *Longshot* after *Hookshot* is one
    grapple at Mk II, exactly as ECHOES §11 describes, and the archive's
    provenance chain becomes something real play produces rather than
    something only a fixture ever showed.
    """
    interpretation = _fallback_echo_create(request, mechanics=mechanics)
    return _read_and_label(as_disposition(interpretation, request), request)


def as_disposition(interpretation: dict, request: EchoGenerationRequest, *,
                   enhancement: bool = True) -> dict:
    """The strongest claim this interpretation can make on what is already
    owned, or the interpretation unchanged.

    Tried most-specific first. A sequel is the strongest claim (the
    campaign owns this exact verb already); an enhancement is next (it
    owns something the element can attach to); a confluence is last,
    because it fires on a budget condition rather than on a reading. Each
    returns None when it cannot land, so the ordinary CREATE survives and
    none of them can make a provider invalid.

    Public because mock is the other caller. A provider that skips this
    accumulates: mock's own catalog shapes are fresh CREATEs, and without
    the chain a ten-Zone campaign ended with seventeen unrelated Actions
    against a soft budget of twelve, and eight upgrades where the fallback
    produced thirty-one. Evolving is not decoration — it is what keeps a
    26-Check campaign from being 26 unrelated things.

    `enhancement=False` for a caller that has already made a specific
    reading of this item. Mock's catalog is that caller: "Ice Beam" reads
    as both `cold` and `beam`, and letting the generic enhancement (cold,
    so chill an owned weapon) outrank the specific shape (a beam and the
    charge it burns) swallowed every elemental item and put
    `beam_sustained` back out of reach. Sequel still applies, because
    owning the same verb is a fact about identity rather than a rival
    reading; confluence still applies, because it is about capacity.
    """
    return (_as_sequel(interpretation, request)
            or (_as_enhancement(interpretation, request)
                if enhancement else None)
            or _as_confluence(interpretation, request)
            or interpretation)


def _read_and_label(interpretation: dict, request: EchoGenerationRequest) -> dict:
    """The §15 reading, stamped on last.

    Concepts and mode are stamped after the operations are settled rather
    than chosen up front, because both are *about* the finished
    interpretation: the mode is derived from what the operations actually
    did (`mode_for_operations`), so it cannot end up describing an earlier
    draft. The fallback used to ship an empty concept tuple and a hardcoded
    "literal", which made §15's chain unexercised by every deterministic
    run — including the integration run.
    """
    interpretation["concepts"] = read_concepts(
        request.source.item_name, request.source.source_game)
    interpretation["mode"] = mode_for_operations(
        interpretation.get("operations", []))
    return interpretation


def _fallback_echo_create(request: EchoGenerationRequest, *,
                          mechanics=None) -> dict:
    """Deterministic heuristics on the lowercased item name (§12.2).

    `mechanics` is the campaign's current fold, for the hard budgets; None
    means "assume room", which every pre-S4 caller meant. Determinism is
    per (item, campaign state), which is the same determinism the archive
    replays: the same log prefix always yields the same interpretation.
    """
    name = request.source.item_name.lower()

    def has(*words: str) -> bool:
        return any(w in name for w in words)

    def room(**counts: int) -> bool:
        return _budget_room(mechanics, request=request, **counts)

    if has("conference call", "shotgun"):
        return _primary(
            request, archetype="weapon", cooldown=1.2,
            initiator={"type": "hitscan_damage", "damage": 12.0, "pellets": 12,
                       "spread_degrees": 12.0, "range": 25.0},
            modifiers=[{"type": "recoil_self", "force": 10.0},
                       {"type": "knockback_target", "force": 8.0}],
            description="A ridiculous scattergun. The recoil is a travel plan.",
            tags=["shotgun", "recoil", "mobility"])
    if has("gun", "rifle", "pistol", "cannon", "blaster", "bow"):
        return _primary(
            request, archetype="weapon", cooldown=0.6,
            initiator={"type": "hitscan_damage", "damage": 10.0, "pellets": 1,
                       "spread_degrees": 2.0, "range": 40.0},
            description="A straightforward sidearm, reinterpreted from static.",
            tags=["weapon"])
    if has("sword", "blade", "knife", "dagger", "axe"):
        # Was a 6-metre hitscan, because in S1 there was nothing else a
        # sword could be. It is a sword now.
        return _primary(
            request, archetype="weapon", cooldown=0.7,
            initiator={"type": "melee_swing", "damage": 24.0, "reach": 2.6,
                       "arc_degrees": 110.0},
            description="Short reach, serious opinion.",
            tags=["melee", "weapon"])
    if has("spear", "lance", "pike", "halberd", "trident"):
        return _primary(
            request, archetype="weapon", cooldown=0.9,
            initiator={"type": "melee_thrust", "damage": 34.0, "reach": 4.2},
            modifiers=[{"type": "apply_status_on_hit",
                        "status": "vulnerable", "duration": 4.0,
                        "magnitude": 0.6}],
            description="Reach beats width, and a pierced guard stays "
                        "pierced.",
            tags=["melee", "weapon", "status"])
    if has("hammer", "mallet", "stomp", "smash", "quake"):
        return _primary(
            request, archetype="weapon", cooldown=3.5,
            initiator={"type": "slam_ground", "damage": 32.0, "radius": 5.0,
                       "descent_force": 20.0},
            description="Only works from up there. Bring yourself down hard.",
            tags=["melee", "slam"])
    if has("magic", "mana", "ether", "spell", "meter", "essence") \
            and room(resources=1):
        return _primary_and_resource(
            request, archetype="weapon", cooldown=0.5,
            initiator={"type": "charge_shot", "min_damage": 5.0,
                       "max_damage": 34.0, "charge_time": 1.0, "speed": 28.0},
            resource={
                "display_name": "MP",
                "description": "A meter, reinterpreted as a meter.",
                "max_value": 100.0, "initial_fraction": 0.35,
                "regen_per_second": 4.0, "regen_delay": 1.0,
                "presentation": "bar", "palette_color": "tide",
            },
            description="A meter and something that spends it.",
            tags=["magic", "resource", "linked"], powers=12.0)
    if has("stamina", "vigor", "endurance", "breath") \
            and room(resources=1):
        return _primary_and_resource(
            request, archetype="mobility", cooldown=1.2,
            initiator={"type": "dash", "force": 13.0},
            resource={
                "display_name": "STAMINA",
                "description": "Spent on moving, in a world that allows it.",
                "max_value": 60.0, "initial_fraction": 0.5,
                "regen_per_second": 8.0, "regen_delay": 0.6,
                "presentation": "pips", "pip_count": 6,
                "palette_color": "moss",
            },
            description="Borrowed wind, spent a lungful per dash.",
            tags=["stamina", "resource", "linked"], powers=15.0)
    if has("staff", "wand", "charge", "rod", "focus"):
        return _primary(
            request, archetype="weapon", cooldown=0.5,
            initiator={"type": "charge_shot", "min_damage": 6.0,
                       "max_damage": 38.0, "charge_time": 1.1, "speed": 30.0},
            description="Hold it. It gets angrier. Let go.",
            tags=["charge", "weapon"])
    if has("smg", "burst", "repeater", "machine", "uzi"):
        return _primary(
            request, archetype="weapon", cooldown=0.9,
            initiator={"type": "burst_fire", "damage": 7.0, "shots": 4,
                       "interval": 0.08, "spread_degrees": 4.0,
                       "range": 35.0},
            description="Four opinions in rapid succession.",
            tags=["burst", "weapon"])
    if has("teleport", "warp", "blink", "recall", "portal"):
        return _primary(
            request, archetype="mobility", cooldown=2.5,
            initiator={"type": "blink", "range": 14.0, "clearance": 0.4},
            description="You are looking at somewhere. Now you are there.",
            tags=["blink", "mobility"])
    if has("glider", "glide", "parachute", "sail", "umbrella"):
        return _primary(
            request, archetype="mobility", cooldown=0.6,
            initiator={"type": "glide", "fall_speed": 2.0,
                       "forward_speed": 10.0},
            description="Hold it and the fall becomes a decision.",
            tags=["glide", "mobility"])
    if has("jet", "thruster", "rocket boot", "booster", "jump"):
        return _primary(
            request, archetype="mobility", cooldown=1.2,
            initiator={"type": "double_jump", "force": 8.0, "extra_jumps": 1},
            description="One more jump than the world budgeted for.",
            tags=["jump", "mobility"])
    # "clawshot" is a grapple that happens to contain "claw", and the
    # generic bucket would otherwise swallow it before the specific one
    # below ever ran. Specificity beats generality in a name mapper.
    if has("claw", "gecko", "climb", "wall", "gauntlet") \
            and not has("clawshot"):
        return _primary(
            request, archetype="mobility", cooldown=0.8,
            initiator={"type": "wall_kick", "force": 12.0,
                       "outward_fraction": 0.45},
            description="Walls are just floors you have not argued with.",
            tags=["wall", "mobility"])
    if has("parry", "riposte", "counter", "deflect"):
        return _primary(
            request, archetype="tool", cooldown=2.0,
            initiator={"type": "parry", "window": 0.35},
            description="A short window and a lot of confidence.",
            tags=["parry", "defense"])
    if has("compass", "map", "marker", "flag", "beacon"):
        return _primary(
            request, archetype="tool", cooldown=1.0,
            initiator={"type": "place_marker", "duration": 120.0},
            description="Somewhere worth remembering. Now it is marked.",
            tags=["marker", "utility"])
    # "longshot"/"clawshot" are named here for the same reason "hookshot"
    # is: this maps names to verbs, and those names mean grapple. It is
    # also what makes ECHOES §11's own example — Hookshot → Longshot →
    # Clawshot as one grapple — reachable from the shipped fallback.
    if has("hook", "grapple", "chain", "longshot", "clawshot"):
        return _primary(
            request, archetype="mobility", cooldown=2.0,
            initiator={"type": "grapple_to_surface", "range": 25.0,
                       "pull_force": 15.0},
            description="Latch onto geometry and get yanked there.",
            tags=["grapple", "mobility"])
    if has("boot", "shoe", "skate", "rep", "sprint"):
        return _primary(
            request, archetype="mobility", cooldown=2.0,
            initiator={"type": "dash", "force": 12.0},
            description="A burst of borrowed momentum.",
            tags=["dash", "mobility"])
    if has("wing", "feather", "cape", "cap"):
        return _passive(
            request,
            effects=[{"type": "modify_gravity", "multiplier": 0.6}],
            description="Gravity applies to you less than it used to.",
            tags=["float", "passive"])
    if has("shield", "armor", "armour", "guard"):
        return _primary(
            request, archetype="tool", cooldown=12.0,
            initiator={"type": "shield", "amount": 40.0, "duration": 8.0},
            description="A temporary layer of somebody else's protection.",
            tags=["shield", "defense"])
    if has("estus", "potion", "flask", "food", "heart", "heal", "shard") \
            and room(resources=1, rules=1):
        # S4: the drink kept its button, and gained an economy — three
        # charges a Zone, one of which spends ITSELF when you are about to
        # die. The first fallback outcome where a rule, a cost and a
        # resource meet.
        src = request.source
        return _create_ops(
            request,
            "Drink the interpretation of a drink. One drinks itself.",
            ["heal", "resource", "rule"],
            [
                {
                    "kind": "resource",
                    "component_id": MG.component_id_for("res",
                                                        src.location_id),
                    "display_name": "FLASK",
                    "description": "Charges of somebody's recovery item.",
                    "max_value": 3.0, "initial_fraction": 1.0,
                    "presentation": "pips", "pip_count": 3,
                    "palette_color": "ember",
                },
                {
                    "kind": "rule",
                    "component_id": MG.component_id_for("rule",
                                                        src.location_id),
                    "display_name": "Reflex Sip",
                    "description": "Falling low uncorks one on its own.",
                    "event": "low_health",
                    "conditions": [],
                    "costs": [{"resource_id": MG.component_id_for(
                        "res", src.location_id), "amount": 1.0}],
                    "effects": [{"type": "heal", "amount": 25.0}],
                    "cooldown": 5.0,
                },
                {
                    "kind": "action",
                    "component_id": MG.component_id_for("act",
                                                        src.location_id),
                    "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
                    "description": "Drink the interpretation of a drink.",
                    "slot": MG.ARCHETYPE_SLOT.get("tool", "echo_a"),
                    "cooldown": 10.0,
                    "primitive": {"type": "heal_self", "amount": 30.0},
                    "modifiers": [],
                },
                # S5: the button spends a charge too, so the meter is the
                # same economy whether you drink deliberately or the rule
                # drinks for you. Without this the charges only ever left
                # by the reflex, which read as two unrelated things.
                {
                    "op": "link", "link": "powers",
                    "source": MG.component_id_for("res", src.location_id),
                    "target": MG.component_id_for("act", src.location_id),
                    "strength": 1.0,
                },
            ])
    if has("star", "orb", "battery", "cell", "core", "dynamo") \
            and room(resources=1, rules=2):
        # A pure economy, no button at all: kills feed the cell, and a full
        # cell discharges itself into a shield. Exercises the edge-derived
        # events end to end in the shipped campaign.
        src = request.source
        cell = MG.component_id_for("res", src.location_id)
        return _create_ops(
            request,
            "It wants to be full. It has opinions about what happens then.",
            ["energy", "resource", "rule"],
            [
                {
                    "kind": "resource",
                    "component_id": cell,
                    "display_name": _clamp(src.item_name.upper(),
                                           C.MAX_TEXT_LEN),
                    "description": "Charged by violence, spent on your "
                                   "behalf.",
                    "max_value": 100.0, "initial_fraction": 0.0,
                    "presentation": "bar", "palette_color": "signal",
                },
                {
                    "kind": "rule",
                    "component_id": MG.component_id_for("rule",
                                                        src.location_id,
                                                        "feed"),
                    "display_name": "Kinetic Intake",
                    "description": "Every kill feeds the cell.",
                    "event": "kill",
                    "conditions": [],
                    "costs": [],
                    "effects": [{"type": "resource_add", "subject": cell,
                                 "amount": 15.0}],
                    "cooldown": 0.3,
                },
                {
                    "kind": "rule",
                    "component_id": MG.component_id_for("rule",
                                                        src.location_id,
                                                        "burst"),
                    "display_name": "Overflow Ward",
                    "description": "A full cell discharges into a shield.",
                    "event": "resource_full",
                    "conditions": [{"type": "resource_at_least",
                                    "subject": cell, "value": 0.999}],
                    "costs": [],
                    "effects": [
                        {"type": "grant_shield", "amount": 20.0,
                         "duration": 4.0},
                        {"type": "resource_add", "subject": cell,
                         "amount": -100.0},
                    ],
                    "cooldown": 2.0,
                },
            ])
    if has("bomb", "grenade", "mine", "explosive"):
        return _primary(
            request, archetype="weapon", cooldown=3.0,
            initiator={"type": "arc_lob", "damage": 34.0, "radius": 4.0,
                       "launch_force": 17.0, "fuse": 1.4},
            description="Lob it, count, regret nothing.",
            tags=["explosive", "weapon"])
    if has("rocket", "missile", "cannonball", "mortar"):
        return _primary(
            request, archetype="weapon", cooldown=3.0,
            initiator={"type": "projectile_damage", "damage": 22.0,
                       "speed": 26.0, "lifetime": 3.0,
                       "gravity_scale": 0.15, "bounces": 0},
            description="A slow, regrettable projectile.",
            tags=["projectile", "weapon"])

    # Most items reach here — nothing in a multiworld is named for what
    # Epsilon does with it — so this branch, not the table above, is what
    # variety means in play. S1 hashed to three outcomes: a gun, a dash, or
    # walking slightly faster. A whole campaign of that is one verb repeated
    # 26 times.
    #
    # Still deterministic (the same Check always yields the same Echo) and
    # still structurally boring: one CREATE, one component, no links. Only
    # the vocabulary widened.
    choice = C.prng_seed(request.source.source_game, request.source.item_name,
                         request.source.location_id) % 8
    if choice == 0:
        return _primary(
            request, archetype="weapon", cooldown=0.8,
            initiator={"type": "hitscan_damage", "damage": 12.0, "pellets": 3,
                       "spread_degrees": 6.0, "range": 30.0},
            description="Epsilon squints at the name and hands you a gun.",
            tags=["weapon"])
    if choice == 1:
        return _primary(
            request, archetype="mobility", cooldown=2.5,
            initiator={"type": "dash", "force": 10.0},
            description="Whatever it was, now it makes you faster briefly.",
            tags=["dash", "mobility"])
    if choice == 2:
        return _primary(
            request, archetype="weapon", cooldown=0.9,
            initiator={"type": "burst_fire", "damage": 6.0, "shots": 3,
                       "interval": 0.09, "spread_degrees": 5.0,
                       "range": 32.0},
            description="It stutters when it speaks. Three times, quickly.",
            tags=["burst", "weapon"])
    if choice == 3:
        return _primary(
            request, archetype="mobility", cooldown=3.0,
            initiator={"type": "blink", "range": 11.0, "clearance": 0.4},
            description="Epsilon could not place it, so it moved you instead.",
            tags=["blink", "mobility"])
    if choice == 4:
        return _primary(
            request, archetype="weapon", cooldown=1.0,
            initiator={"type": "melee_swing", "damage": 18.0, "reach": 2.4,
                       "arc_degrees": 120.0},
            description="Held wrong, swung anyway.",
            tags=["melee", "weapon"])
    if choice == 5:
        return _primary(
            request, archetype="mobility", cooldown=1.4,
            initiator={"type": "air_dash", "force": 14.0,
                       "uses_per_airtime": 1},
            description="It only means anything once you have left the floor.",
            tags=["dash", "mobility"])
    if choice == 6:
        return _primary(
            request, archetype="weapon", cooldown=2.6,
            initiator={"type": "arc_lob", "damage": 26.0, "radius": 3.5,
                       "launch_force": 15.0, "fuse": 1.2},
            description="Epsilon decided the safest reading was 'throw it'.",
            tags=["explosive", "weapon"])
    return _passive(
        request,
        effects=[{"type": "modify_speed", "multiplier": 1.2}],
        description="Worn quietly. You walk with more purpose.",
        tags=["speed", "passive"])


class FallbackEpsilonProvider:
    """Deterministic provider — the `--epsilon=fallback` axis value."""

    name = "fallback"

    async def generate_zone(self, request: ZoneGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict:
        return fallback_zone(request)

    async def generate_echo(self, request: EchoGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict:
        return fallback_echo(request)

    # No `mechanics` here, and none is needed: `_budget_room` reads the
    # request's own `budget_headroom` when no fold is passed, so this
    # provider obeys §16 from what it was given like any other.
