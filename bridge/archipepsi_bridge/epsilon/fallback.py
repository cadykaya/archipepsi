"""Deterministic fallback generators (EPSILON_SPEC §12).

Failure recovery AND the test oracle for engine-side generation: the whole
loop with no API cost and no nondeterminism. Output goes through the same
validators as model output — no exceptions.
"""

from __future__ import annotations

from ..schemas import constants as C
from .requests import EchoGenerationRequest, ZoneGenerationRequest


def _theme_for(target_game: str) -> str:
    theme = C.THEME_BY_GAME_HINT.get(target_game)
    if theme is None:
        theme = C.THEMES[C.prng_seed(target_game, "fallback_theme")
                         % len(C.THEMES)]
    return theme


def _clamp(text: str, limit: int) -> str:
    return text if len(text) <= limit else text[: limit - 1] + "…"


def fallback_zone(request: ZoneGenerationRequest) -> dict:
    """Linear corridor→arena→corridor→platform→brute-arena, trimmed to the
    allocated Check count. The finale is a single brute arena with Check 030."""
    locations = list(request.locations)
    theme = _theme_for(request.campaign.target_game)
    n = request.campaign.zone_index

    if request.campaign.is_finale:
        return {
            "schema_version": 7,
            "zone_id": request.zone_id,
            "display_name": _clamp(
                f"Terminal Relay {n:03d}", C.MAX_TEXT_LEN),
            "target_game": request.campaign.target_game,
            "theme": theme,
            "designer_note": "Deterministic fallback finale.",
            "chambers": [
                {"id": "c1", "type": "corridor", "length": 14.0, "width": 6.0},
                {"id": "c2", "type": "arena", "width": 22.0, "depth": 22.0,
                 "wall_height": 6.0, "objective": "kill_all",
                 "enemies": [{"archetype": "brute", "count": 1}],
                 "reward_location_id": locations[0].location_id},
            ],
        }

    step = 0.6
    gap = min(2.2, C.max_safe_gap(step))
    reward_chambers = [
        {"id": "c2", "type": "arena", "width": 16.0, "depth": 14.0,
         "wall_height": 5.0, "objective": "kill_all",
         "enemies": [{"archetype": "melee", "count": 3}]},
        {"id": "c4", "type": "platform_path", "segment_count": 4,
         "gap_size": gap, "vertical_step": step,
         "objective": "platform_to_goal"},
        {"id": "c5", "type": "arena", "width": 20.0, "depth": 18.0,
         "wall_height": 6.0, "objective": "kill_all",
         "enemies": [{"archetype": "brute", "count": 1},
                     {"archetype": "melee", "count": 2}]},
    ]
    chambers: list[dict] = [
        {"id": "c1", "type": "corridor", "length": 12.0, "width": 5.0}]
    for i, loc in enumerate(locations[:3]):
        chamber = dict(reward_chambers[i])
        chamber["reward_location_id"] = loc.location_id
        if i == 1:
            chambers.append({"id": "c3", "type": "corridor",
                             "length": 10.0, "width": 4.0})
        chambers.append(chamber)

    return {
        "schema_version": 7,
        "zone_id": request.zone_id,
        "display_name": _clamp(
            f"Relay {n:03d}: {request.campaign.target_game}", C.MAX_TEXT_LEN),
        "target_game": request.campaign.target_game,
        "theme": theme,
        "designer_note": "Deterministic fallback zone.",
        "chambers": chambers,
    }


# ---------------------------------------------------------------------------
# Echo
# ---------------------------------------------------------------------------

def _primary(request: EchoGenerationRequest, *, archetype: str, cooldown: float,
             initiator: dict, modifiers: list[dict] | None = None,
             description: str, tags: list[str]) -> dict:
    src = request.source
    return {
        "schema_version": 7,
        "echo_id": request.required_echo_id,
        "source_location_id": src.location_id,
        "source_item_name": src.item_name,
        "source_game": src.source_game,
        "source_recipient_name": src.recipient_name,
        "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
        "description": _clamp(description, C.MAX_TEXT_LEN),
        "tags": tags,
        "activation": "primary",
        "archetype": archetype,
        "cooldown": cooldown,
        "initiator": initiator,
        "modifiers": modifiers or [],
    }


def _passive(request: EchoGenerationRequest, *, effects: list[dict],
             description: str, tags: list[str]) -> dict:
    src = request.source
    return {
        "schema_version": 7,
        "echo_id": request.required_echo_id,
        "source_location_id": src.location_id,
        "source_item_name": src.item_name,
        "source_game": src.source_game,
        "source_recipient_name": src.recipient_name,
        "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
        "description": _clamp(description, C.MAX_TEXT_LEN),
        "tags": tags,
        "activation": "passive",
        "archetype": "passive",
        "effects": effects,
    }


def fallback_echo(request: EchoGenerationRequest) -> dict:
    """Deterministic heuristics on the lowercased item name (§12.2)."""
    name = request.source.item_name.lower()

    def has(*words: str) -> bool:
        return any(w in name for w in words)

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
        return _primary(
            request, archetype="weapon", cooldown=0.8,
            initiator={"type": "hitscan_damage", "damage": 20.0, "pellets": 1,
                       "spread_degrees": 0.0, "range": 6.0},
            description="Short reach, serious opinion.",
            tags=["melee", "weapon"])
    if has("hook", "grapple", "chain"):
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
    if has("estus", "potion", "flask", "food", "heart", "heal", "shard"):
        return _primary(
            request, archetype="tool", cooldown=10.0,
            initiator={"type": "heal_self", "amount": 30.0},
            description="Drink the interpretation of a drink.",
            tags=["heal"])
    if has("bomb", "grenade", "rocket", "missile"):
        return _primary(
            request, archetype="weapon", cooldown=3.0,
            initiator={"type": "projectile_damage", "damage": 22.0,
                       "speed": 18.0, "lifetime": 3.0},
            description="A slow, regrettable projectile.",
            tags=["projectile", "weapon"])

    # Hash to a modest default: hitscan weapon, dash, or passive speed.
    choice = C.prng_seed(request.source.source_game, request.source.item_name,
                         request.source.location_id) % 3
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
