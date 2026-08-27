"""Deterministic fallback generators (EPSILON_SPEC §12).

Failure recovery AND the test oracle for engine-side generation: the whole
loop with no API cost and no nondeterminism. Output goes through the same
validators as model output — no exceptions.
"""

from __future__ import annotations

from ..schemas import constants as C
from ..schemas import migration as MG
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
        "concepts": (),
        # The fallback does not interpret, it maps. Claiming a richer mode
        # would be a lie the archive then shows to the player.
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
            description="Reach beats width. Pick your line and commit.",
            tags=["melee", "weapon"])
    if has("hammer", "mallet", "stomp", "smash", "quake"):
        return _primary(
            request, archetype="weapon", cooldown=3.5,
            initiator={"type": "slam_ground", "damage": 32.0, "radius": 5.0,
                       "descent_force": 20.0},
            description="Only works from up there. Bring yourself down hard.",
            tags=["melee", "slam"])
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
    if has("claw", "gecko", "climb", "wall", "gauntlet"):
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
