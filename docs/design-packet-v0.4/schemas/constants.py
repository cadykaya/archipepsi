"""Archipepsi v0.4 — binding constants.

This module is the SINGLE SOURCE OF TRUTH for every tunable number in
Archipepsi. Godot reads the same values from `constants.gd`, which is
generated from this file by `tools/export_constants.py`. Do not hand-edit
the GDScript copy.

Two rules govern this file:

1. Every gameplay number in the design lives here. If a spec document
   states a number that is not in this file, this file wins and the
   document is wrong.

2. Derived constants are *derived*, never typed in by hand. In particular
   SAFE_BASE_JUMP_GAP is computed from the jump arc. Retune GRAVITY,
   WALK_SPEED or JUMP_VELOCITY and the validator's traversal guarantee
   recomputes correctly and stays true. This replaces the v0.3 rule that
   the game "must measure and store" the safe gap in-engine.

All values are v0.4 binding starting values, explicitly tunable after the
first playable build.

Units: metres, seconds, metres/second. Angles in degrees.
"""

from __future__ import annotations

# --------------------------------------------------------------------------
# Campaign shape
# --------------------------------------------------------------------------

LOCATION_COUNT = 30
LOCATION_ID_BASE = 89_100_000
ITEM_ID_BASE = 89_200_000

FIRST_LOCATION_ID = LOCATION_ID_BASE + 1          # 89100001
LAST_LOCATION_ID = LOCATION_ID_BASE + LOCATION_COUNT  # 89100030
GOAL_LOCATION_ID = LAST_LOCATION_ID               # Check 030

ITEM_ID_PEPSI_KEY = ITEM_ID_BASE + 1              # 89200001
ITEM_ID_EPSILON_COIN = ITEM_ID_BASE + 2           # 89200002
ITEM_ID_EPSILON_STATIC = ITEM_ID_BASE + 3         # 89200003

PEPSI_KEY_COUNT = 2
EPSILON_COIN_COUNT = 10
EPSILON_STATIC_COUNT = 18
assert PEPSI_KEY_COUNT + EPSILON_COIN_COUNT + EPSILON_STATIC_COUNT == LOCATION_COUNT

# Tier N contains locations [TIER_BOUNDS[N], TIER_BOUNDS[N+1]).
# Tier N requires N Pepsi Keys.
TIER_SIZE = 10
TIER_COUNT = 3

# --------------------------------------------------------------------------
# Finale (v0.4 decision D3)
# --------------------------------------------------------------------------

# Check 030 is fully reserved: never shop stock, never a normal Zone reward.
# The finale Zone is a dedicated single-Check Zone containing only 030, and
# becomes available when BOTH conditions hold.
FINALE_REQUIRED_PEPSI_KEYS = 2
FINALE_REQUIRED_OTHER_CHECKS = 24   # of the 29 non-goal Checks

# --------------------------------------------------------------------------
# Zone allocation
# --------------------------------------------------------------------------

ZONE_TARGET_CHECKS = 3
ZONE_MAX_CHECKS = 3
ZONE_MIN_CHECKS = 2       # 1 is allowed only when exactly one eligible Check remains
ZONE_MAX_CHAMBERS = 6
ZONE_MIN_CHAMBERS = 1

# --------------------------------------------------------------------------
# Shop
# --------------------------------------------------------------------------

SHOP_STOCK_SIZE = 2
SHOP_FIRST_STOCK_AFTER_ZONES = 2      # no stock before 2 Zones are COMPLETE
SHOP_RESTOCK_EVERY_ZONES = 2

SHOP_PRICE_PROGRESSION = 6
SHOP_PRICE_USEFUL = 4
SHOP_PRICE_OTHER = 2

# Never create stock that would starve the next Zone (v0.4 decision D5).
SHOP_MIN_REMAINING_AFTER_STOCK = ZONE_TARGET_CHECKS

# AP NetworkItem.flags bits
FLAG_PROGRESSION = 0b001
FLAG_USEFUL = 0b010
FLAG_TRAP = 0b100

# --------------------------------------------------------------------------
# Player movement  (v0.4 decision D4)
# --------------------------------------------------------------------------

GRAVITY = 24.0
WALK_SPEED = 7.0
JUMP_VELOCITY = 8.0
COYOTE_TIME = 0.12
JUMP_BUFFER = 0.10
AIR_CONTROL = 0.4

PLAYER_HEIGHT = 1.8
PLAYER_RADIUS = 0.4
PLAYER_EYE_HEIGHT = 1.6

FALL_KILL_Y = -30.0
RESPAWN_DELAY = 1.5

# --- derived: the traversal guarantee ------------------------------------
# Do not hand-edit these three. They are what makes "every mandatory path is
# completable with base movement" a checkable claim rather than a hope.

JUMP_APEX_HEIGHT = JUMP_VELOCITY ** 2 / (2 * GRAVITY)     # 1.333 m
JUMP_AIRTIME = 2 * JUMP_VELOCITY / GRAVITY                # 0.667 s
JUMP_FLAT_REACH = WALK_SPEED * JUMP_AIRTIME               # 4.667 m

# Margin against imperfect timing, imperfect approach speed, and air control.
SAFE_GAP_MARGIN = 0.64
SAFE_STEP_MARGIN = 0.75

SAFE_BASE_JUMP_GAP = round(JUMP_FLAT_REACH * SAFE_GAP_MARGIN, 1)    # 3.0 m
MAX_VERTICAL_STEP = round(JUMP_APEX_HEIGHT * SAFE_STEP_MARGIN, 1)   # 1.0 m
MIN_PLATFORM_SIZE = 2.5

# --------------------------------------------------------------------------
# Combat  (v0.4 decision D4)
# --------------------------------------------------------------------------

PLAYER_MAX_HP = 100.0

# Pepsi Pop: LMB, always available, never replaced by an Echo.
PEPSI_POP_DAMAGE = 6.0
PEPSI_POP_COOLDOWN = 0.35
PEPSI_POP_RANGE = 40.0
PEPSI_POP_DPS = PEPSI_POP_DAMAGE / PEPSI_POP_COOLDOWN      # ~17.1

ENEMY_STATS = {
    "melee":  {"hp": 24.0,  "damage": 6.0,  "cooldown": 1.0, "speed": 4.0, "reach": 2.0},
    "ranged": {"hp": 16.0,  "damage": 8.0,  "cooldown": 2.0, "speed": 0.0, "reach": 40.0},
    "brute":  {"hp": 120.0, "damage": 18.0, "cooldown": 1.6, "speed": 2.2, "reach": 2.5},
}
ENEMY_AGGRO_RADIUS = 18.0
RANGED_PROJECTILE_SPEED = 14.0

# --------------------------------------------------------------------------
# Zone content limits
# --------------------------------------------------------------------------

MAX_ENEMIES_PER_ZONE = 14
MAX_ENEMIES_PER_CHAMBER = 8
MAX_BRUTES_PER_ZONE = 1

# Worst-case time-to-clear a fully-loaded Zone using only Pepsi Pop.
# Asserted in tests so a future retune cannot silently create a plinkfest.
WORST_CASE_ZONE_TTK_BUDGET = 40.0


def worst_case_zone_ttk() -> float:
    """Seconds of sustained Pepsi Pop fire to clear the worst legal Zone."""
    brute_hp = ENEMY_STATS["brute"]["hp"] * MAX_BRUTES_PER_ZONE
    grunt_hp = ENEMY_STATS["melee"]["hp"] * (MAX_ENEMIES_PER_ZONE - MAX_BRUTES_PER_ZONE)
    return (brute_hp + grunt_hp) / PEPSI_POP_DPS


# --------------------------------------------------------------------------
# Echo bounds
# --------------------------------------------------------------------------

ECHO_EFFECTS_MIN = 1
ECHO_EFFECTS_MAX = 3
ECHO_COOLDOWN_MIN = 0.15
ECHO_COOLDOWN_MAX = 15.0

# --------------------------------------------------------------------------
# Epsilon
# --------------------------------------------------------------------------

THEMES = (
    "grass_block",
    "stone_dungeon",
    "neon_city",
    "gothic_castle",
    "desert_scrap",
    "void_glitch",
)
CHAMBER_TYPES = ("corridor", "arena", "platform_path", "tower", "treasure_room")
ENEMY_ARCHETYPES = ("melee", "ranged", "brute")
OBJECTIVES = ("reach_reward", "kill_all", "platform_to_goal")

THEME_BY_GAME_HINT = {
    "Super Mario 64": "grass_block",
    "Ocarina of Time": "stone_dungeon",
    "Bomb Rush Cyberfunk": "neon_city",
    "Dark Souls III": "gothic_castle",
    "Borderlands 2": "desert_scrap",
    "Archipepsi": "void_glitch",
}

PROVIDER_TIMEOUT_SECONDS = 60.0
REPAIR_ATTEMPTS = 1

# Text limits. Also applied to AP-sourced strings before they reach a prompt
# or the screen — see EPSILON_SPEC "Untrusted input".
MAX_TEXT_LEN = 160
MAX_DESIGNER_NOTE_LEN = 300
MAX_AP_STRING_LEN = 96

# --------------------------------------------------------------------------
# Epsilon Static  (v0.4: no longer a no-op)
# --------------------------------------------------------------------------

# Each Epsilon Static received adds one permanent unit of cosmetic Hub
# corruption and increments a counter Epsilon may reference in flavor text.
# Purely cosmetic: never affects logic, difficulty, or reachability.
STATIC_GLITCH_UNITS_PER_ITEM = 1
STATIC_GLITCH_VISUAL_CAP = 18


# --------------------------------------------------------------------------
# Determinism  (v0.4 decision: exact recipe, fixes v0.3 C8)
# --------------------------------------------------------------------------

def prng_seed(*parts: object) -> int:
    """Derive a stable 64-bit PRNG seed from a campaign key.

    The v0.3 spec said "deterministically shuffle using seed_name | team |
    slot_id | ..." without defining the string->int step, which meant no two
    implementations would agree. This is the exact recipe.

    Never use Python's built-in hash() here: it is randomized per process.
    """
    import hashlib

    key = "|".join(str(p) for p in parts)
    digest = hashlib.sha256(key.encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big")


def deterministic_shuffle(items: list, *seed_parts: object) -> list:
    """Fisher-Yates over a seeded Mersenne Twister. Returns a new list.

    Descending index, j = rng.randrange(i + 1). Any reimplementation must
    match this exactly, including the direction of the loop.
    """
    import random

    rng = random.Random(prng_seed(*seed_parts))
    out = list(items)
    for i in range(len(out) - 1, 0, -1):
        j = rng.randrange(i + 1)
        out[i], out[j] = out[j], out[i]
    return out
