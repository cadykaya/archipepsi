# GENERATED FILE - do not edit.
# Source: schemas/constants.py. Regenerate with `python export.py`.
#
# Godot reads its gameplay numbers from here so the engine cannot
# drift from the bounds the Python validator enforces.
extends Node

const AIR_CONTROL = 0.4
const CHAMBER_TYPES = ["corridor", "arena", "platform_path", "tower", "treasure_room"]
const COYOTE_TIME = 0.12
const ECHO_COOLDOWN_MAX = 15.0
const ECHO_COOLDOWN_MIN = 0.15
const ECHO_EFFECTS_MAX = 3
const ECHO_EFFECTS_MIN = 1
const ENEMY_AGGRO_RADIUS = 18.0
const ENEMY_ARCHETYPES = ["melee", "ranged", "brute"]
const ENEMY_FALL_KILL_Y = -30.0
const EPSILON_COIN_COUNT = 10
const EPSILON_STATIC_COUNT = 18
const FALL_KILL_Y = -30.0
const FINALE_REQUIRED_OTHER_CHECKS = 24
const FINALE_REQUIRED_SIGNAL_KEYS = 2
const FIRST_LOCATION_ID = 89100001
const FLAG_PROGRESSION = 1
const FLAG_TRAP = 4
const FLAG_USEFUL = 2
const GOAL_LOCATION_ID = 89100030
const GRAVITY = 24.0
const GRAVITY_MULT_MAX = 1.0
const GRAVITY_MULT_MIN = 0.35
const ITEM_ID_BASE = 89200000
const ITEM_ID_EPSILON_COIN = 89200002
const ITEM_ID_EPSILON_STATIC = 89200003
const ITEM_ID_SIGNAL_KEY = 89200001
const ITEM_NAME_EPSILON_COIN = "Epsilon Coin"
const ITEM_NAME_EPSILON_STATIC = "Epsilon Static"
const ITEM_NAME_SIGNAL_KEY = "Signal Key"
const JUMP_AIRTIME = 0.6666666666666666
const JUMP_APEX_HEIGHT = 1.3333333333333333
const JUMP_BUFFER = 0.1
const JUMP_FLAT_REACH = 4.666666666666666
const JUMP_VELOCITY = 8.0
const LAST_LOCATION_ID = 89100030
const LOCATION_COUNT = 30
const LOCATION_ID_BASE = 89100000
const MAX_AP_STRING_LEN = 96
const MAX_BRUTES_PER_ZONE = 1
const MAX_DESIGNER_NOTE_LEN = 300
const MAX_ENEMIES_PER_CHAMBER = 8
const MAX_ENEMIES_PER_ZONE = 14
const MAX_TEXT_LEN = 160
const MAX_VERTICAL_STEP = 1.0
const MIN_PLATFORM_SIZE = 2.5
const OBJECTIVES = ["reach_reward", "kill_all", "platform_to_goal"]
const PLAYER_EYE_HEIGHT = 1.6
const PLAYER_HEIGHT = 1.8
const PLAYER_MAX_HP = 100.0
const PLAYER_RADIUS = 0.4
const POSTGAME_ENABLED = true
const PROVIDER_TIMEOUT_SECONDS = 60.0
const RANGED_PROJECTILE_SPEED = 14.0
const REFERENCE_ECHO_COOLDOWN = 0.8
const REFERENCE_ECHO_DAMAGE = 12.0
const REFERENCE_ECHO_PELLETS = 3
const REPAIR_ATTEMPTS = 1
const RESPAWN_DELAY = 1.5
const SAFE_BASE_JUMP_GAP = 2.6
const SAFE_GAP_MARGIN = 0.64
const SAFE_STEP_MARGIN = 0.75
const SHOP_FIRST_STOCK_AFTER_ZONES = 2
const SHOP_MIN_REMAINING_AFTER_STOCK = 3
const SHOP_PRICE_OTHER = 2
const SHOP_PRICE_PROGRESSION = 6
const SHOP_PRICE_USEFUL = 4
const SHOP_RESTOCK_EVERY_ZONES = 2
const SHOP_STOCK_SIZE = 2
const SIGNAL_KEY_COUNT = 2
const SPEED_MULT_MAX = 1.6
const SPEED_MULT_MIN = 0.9
const STATIC_GLITCH_UNITS_PER_ITEM = 1
const STATIC_GLITCH_VISUAL_CAP = 18
const STATIC_PULSE_COOLDOWN = 0.35
const STATIC_PULSE_DAMAGE = 6.0
const STATIC_PULSE_DPS = 17.142857142857142
const STATIC_PULSE_RANGE = 40.0
const TEXTURE_SIZE_DEFAULT = 64
const TEXTURE_SIZE_MAX = 128
const TEXTURE_SIZE_MIN = 32
const THEMES = ["concrete_facility", "rusted_industrial", "neon_transit", "gothic_stone", "temple_ruin", "void_glitch"]
const THEME_BY_GAME_HINT = {"Super Mario 64": "concrete_facility", "Ocarina of Time": "temple_ruin", "Bomb Rush Cyberfunk": "neon_transit", "Dark Souls III": "gothic_stone", "Borderlands 2": "rusted_industrial", "Archipepsi": "void_glitch"}
const TIER_COUNT = 3
const TIER_SIZE = 10
const WALK_SPEED = 7.0
const WORST_CASE_ZONE_TTK_BUDGET = 40.0
const ZONE_MAX_CHAMBERS = 6
const ZONE_MAX_CHECKS = 3
const ZONE_MIN_CHAMBERS = 1
const ZONE_MIN_CHECKS = 2
const ZONE_TARGET_CHECKS = 3

# Tier bounds: tier N holds [TIER_BOUNDS[N], TIER_BOUNDS[N+1]).
const TIER_BOUNDS = [89100001, 89100011, 89100021, 89100031]

# Enemy stat block, keyed by archetype.
const ENEMY_STATS = {
	"melee": {"hp": 24.0, "damage": 6.0, "cooldown": 1.0, "speed": 4.0, "reach": 2.0},
	"ranged": {"hp": 16.0, "damage": 8.0, "cooldown": 2.0, "speed": 0.0, "reach": 40.0},
	"brute": {"hp": 120.0, "damage": 18.0, "cooldown": 1.6, "speed": 2.2, "reach": 2.5},
}
