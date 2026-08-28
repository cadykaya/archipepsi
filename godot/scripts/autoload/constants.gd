# GENERATED FILE - do not edit.
# Source: schemas/constants.py. Regenerate with `python export.py`.
#
# Godot reads its gameplay numbers from here so the engine cannot
# drift from the bounds the Python validator enforces.
extends Node

const AFFORDANCE_DYNAMIC_CHANNELS = ["breakable_wall_damage", "wind_ring_count"]
const AFFORDANCE_SIGNAL_HEX = "#39d7c8"
const AFFORDANCE_SIGNAL_RGB = [0.2235294117647059, 0.8431372549019608, 0.7843137254901961]
const AIR_CONTROL = 0.4
const BRIDGE_HOST = "127.0.0.1"
const BRIDGE_PORT = 38290
const BRUTES_PER_BUDGET_POINT = 0.005
const CHAMBER_TYPES = ["corridor", "arena", "platform_path", "tower", "treasure_room"]
const CLUSTER_ANCHORS = ["floor_wall", "floor_corner", "wall", "ceiling"]
const CLUSTER_CLEARANCE = 0.4
const CLUSTER_FLOOR_ANCHORS = ["floor_wall", "floor_corner"]
const CLUSTER_MAX_DEPTH = 2.5
const CLUSTER_MAX_HEIGHT = 4.0
const CLUSTER_MAX_WIDTH = 6.0
const CLUSTER_MOUNTED_UNDERSIDE_MIN = 2.75
const COIN_SHARE_OF_NON_KEY = 0.35714285714285715
const COYOTE_TIME = 0.12
const DEFAULT_LOCATION_COUNT = 450
const DEFAULT_ZONE_BUDGET = 1000
const DEFAULT_ZONE_TARGET_CHECKS = 15
const ECHO_COOLDOWN_MAX = 15.0
const ECHO_COOLDOWN_MIN = 0.15
const ECHO_EFFECTS_MAX = 3
const ECHO_EFFECTS_MIN = 1
const ECHO_MAX_OPERATIONS = 4
const ENEMIES_PER_BUDGET_POINT = 0.07
const ENEMY_AGGRO_RADIUS = 18.0
const ENEMY_ARCHETYPES = ["melee", "ranged", "brute"]
const ENEMY_FALL_KILL_Y = -30.0
const ENEMY_ROLES = ["melee", "ranged", "brute", "charger", "bulwark", "scuttler", "artillery", "beacon", "diver", "drifter"]
const EPSILON_COIN_COUNT = 10
const EPSILON_STATIC_COUNT = 18
const FALL_KILL_Y = -30.0
const FEATURE_MIN_WIDTH = {"grapple_anchor": 7.5, "breakable_wall": 7.5, "water_volume": 7.9, "rail": 6.7, "wind_volume": 7.9, "bounce_pad": 7.1, "moving_platform": 7.9}
const FINALE_REQUIRED_FRACTION = 0.8
const FINALE_REQUIRED_OTHER_CHECKS = 24
const FINALE_REQUIRED_SIGNAL_KEYS = 2
const FIRST_LOCATION_ID = 89100001
const FIRST_NON_FINALE_LOCATION_ID = 89100001
const FLAG_PROGRESSION = 1
const FLAG_TRAP = 4
const FLAG_USEFUL = 2
const FLYING_ENEMY_ROLES = ["diver", "drifter"]
const GOAL_LOCATION_ID = 89100030
const GRAVITY = 24.0
const GRAVITY_MULT_MAX = 1.0
const GRAVITY_MULT_MIN = 0.35
const GROUND_ENEMY_ROLES = ["melee", "ranged", "brute", "charger", "bulwark", "scuttler", "artillery", "beacon"]
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
const LAST_NON_FINALE_LOCATION_ID = 89100029
const LAST_UNIVERSE_ID = 89100600
const LOCATION_COUNT = 30
const LOCATION_COUNT_MAX = 600
const LOCATION_COUNT_MIN = 30
const LOCATION_ID_BASE = 89100000
const LOCATION_UNIVERSE = 600
const LOW_HEALTH_FRACTION = 0.33
const MAX_AP_STRING_LEN = 96
const MAX_BRUTES_PER_ENCOUNTER = 1
const MAX_DESIGNER_NOTE_LEN = 300
const MAX_ENEMIES_ACTIVE = 12
const MAX_ENEMIES_PER_CHAMBER = 12
const MAX_ENEMIES_PER_ENCOUNTER = 10
const MAX_ENEMIES_SPAWNED_CAP = 240
const MAX_LOCAL_REWARDS = 120
const MAX_TEXT_LEN = 160
const MAX_VERTICAL_STEP = 1.0
const MIN_BUDGET_PER_CHECK = 25
const MIN_FEATURE_CHAMBER_WIDTH = 6.7
const MIN_PLATFORM_SIZE = 2.5
const OBJECTIVES = ["reach_reward", "kill_all", "platform_to_goal"]
const ORDERED_ACTIVITY_TIME_MULTIPLIER = 1.5
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
const ROOMS_PER_BUDGET_POINT = 0.015
const RULE_FIRINGS_PER_TICK_CAP = 8
const SAFE_BASE_JUMP_GAP = 2.6
const SAFE_GAP_MARGIN = 0.64
const SAFE_STEP_MARGIN = 0.75
const SECONDS_PER_ACTIVITY_ELEMENT = 4.0
const SHOP_FIRST_STOCK_AFTER_ZONES = 2
const SHOP_MIN_REMAINING_AFTER_STOCK = 3
const SHOP_PRICE_OTHER = 2
const SHOP_PRICE_PROGRESSION = 6
const SHOP_PRICE_USEFUL = 4
const SHOP_RESTOCK_EVERY_ZONES = 2
const SHOP_STOCK_SIZE = 2
const SIGNAL_KEY_COUNT = 2
const SLOT_NAMES = ["echo_a", "echo_b", "mobility", "utility"]
const SPEED_MULT_MAX = 1.6
const SPEED_MULT_MIN = 0.9
const STATIC_GLITCH_UNITS_PER_ITEM = 1
const STATIC_GLITCH_VISUAL_CAP = 18
const STATIC_PULSE_COOLDOWN = 0.35
const STATIC_PULSE_DAMAGE = 6.0
const STATIC_PULSE_DPS = 17.142857142857142
const STATIC_PULSE_RANGE = 40.0
const STAT_STACK_MAX = 4.0
const STAT_STACK_MIN = 0.25
const TALLEST_ACTOR_INCLUDING_FLYERS = 3.025
const TALLEST_GROUND_ACTOR = 2.6
const TEXTURE_SIZE_DEFAULT = 64
const TEXTURE_SIZE_MAX = 128
const TEXTURE_SIZE_MIN = 32
const THEMES = ["concrete_facility", "rusted_industrial", "neon_transit", "gothic_stone", "temple_ruin", "void_glitch"]
const THEME_BY_GAME_HINT = {"Super Mario 64": "concrete_facility", "Ocarina of Time": "temple_ruin", "Bomb Rush Cyberfunk": "neon_transit", "Dark Souls III": "gothic_stone", "Borderlands 2": "rusted_industrial", "Archipepsi": "void_glitch"}
const THEME_MATERIALS = {"concrete_facility": {"base_color": "#b9bcb6", "accent_color": "#4f6f8f", "trim_color": "#2e3338", "light_color": "#eaf2ff", "light_energy": 3.0, "roughness": 0.85, "noise": "speckle"}, "rusted_industrial": {"base_color": "#8a5a3b", "accent_color": "#c8722c", "trim_color": "#3d2a1e", "light_color": "#ffd9a0", "light_energy": 2.2, "roughness": 0.95, "noise": "rust"}, "neon_transit": {"base_color": "#d8d4c8", "accent_color": "#18b7c4", "trim_color": "#1b1d26", "light_color": "#7cf2ff", "light_energy": 4.0, "roughness": 0.35, "noise": "tile"}, "gothic_stone": {"base_color": "#6b6560", "accent_color": "#3a3f4a", "trim_color": "#241f1c", "light_color": "#ffb45e", "light_energy": 2.0, "roughness": 0.9, "noise": "brick"}, "temple_ruin": {"base_color": "#c2a878", "accent_color": "#5f7a4a", "trim_color": "#7a6034", "light_color": "#ffe9b8", "light_energy": 2.6, "roughness": 0.8, "noise": "sandstone"}, "void_glitch": {"base_color": "#2b2b3a", "accent_color": "#ff00e6", "trim_color": "#00ffbf", "light_color": "#ffffff", "light_energy": 3.5, "roughness": 0.5, "noise": "checker"}}
const THEME_MATERIAL_KEYS = ["base_color", "accent_color", "trim_color", "light_color", "light_energy", "roughness", "noise"]
const TIER_COUNT = 3
const TIER_SIZE = 10
const WALK_SPEED = 7.0
const WORST_CASE_ENCOUNTER_TTK_BUDGET = 40.0
const ZONE_BUDGET_MAX = 2000
const ZONE_BUDGET_MIN = 200
const ZONE_MAX_CHAMBERS = 40
const ZONE_MAX_CHECKS = 3
const ZONE_MIN_CHAMBERS = 1
const ZONE_MIN_CHECKS = 2
const ZONE_TARGET_CHECKS = 3
const ZONE_TARGET_CHECKS_MAX = 30
const ZONE_TARGET_CHECKS_MIN = 1

## Largest gap a MANDATORY jump may span, landing this much
## higher. The joint bound: gap and step maxed independently is
## not the same as either maxed alone. Mirrors
## `constants.max_safe_gap`, pinned by `test_schemas.py`.
## NOT `static`: `Constants` is an autoload, so every call site reaches it
## through the singleton INSTANCE. A static function called that way is
## correct but warns on every one of them, and a warning nobody can act
## on is a warning everybody learns to scroll past.
func max_safe_gap(vertical_step: float = 0.0) -> float:
	var g := GRAVITY * GRAVITY_MULT_MAX
	var disc := JUMP_VELOCITY * JUMP_VELOCITY - 2.0 * g * vertical_step
	if disc < 0.0:
		return 0.0
	var reach := WALK_SPEED * SPEED_MULT_MIN \
			* (JUMP_VELOCITY + sqrt(disc)) / g
	# Floor to one decimal: a safety bound must never round upward.
	return floor(reach * SAFE_GAP_MARGIN * 10.0) / 10.0

# The SIGNAL colour. FORM says which affordance; this says that
# it IS one. Theme, source-game colour and Epsilon green do not
# redefine it (art requirement 15).
const AFFORDANCE_SIGNAL := Color(0.223529, 0.843137, 0.784314)

# Tier bounds: tier N holds [TIER_BOUNDS[N], TIER_BOUNDS[N+1]).
const TIER_BOUNDS = [89100001, 89100011, 89100021, 89100031]

# Enemy stat block, keyed by archetype.
const ENEMY_STATS = {
	"melee": {"hp": 24.0, "damage": 6.0, "cooldown": 1.0, "speed": 4.0, "reach": 2.0},
	"ranged": {"hp": 16.0, "damage": 8.0, "cooldown": 2.0, "speed": 0.0, "reach": 40.0},
	"brute": {"hp": 120.0, "damage": 18.0, "cooldown": 1.6, "speed": 2.2, "reach": 2.5},
}

# Enemy physical envelopes, keyed by role. PHYSICAL ONLY -- an
# envelope says how much room a role takes and whether it walks or
# holds a height, never what it does. `ENEMY_STATS` is behaviour,
# and it covers fewer roles on purpose.
#
# `size` is Godot's Vector3(width, height, depth). `centre_y` is
# where the collider's centre sits above the floor -- half the
# height for a walker, the hover height for a flyer.
const ENEMY_ENVELOPES = {
	"melee": {"size": Vector3(0.8, 1.6, 0.8), "centre_y": 0.8, "bottom_y": 0.0, "top_y": 1.6, "lane_width": 0.8, "hover_height": 0.0, "flying": false},
	"ranged": {"size": Vector3(0.7, 1.4, 0.7), "centre_y": 0.7, "bottom_y": 0.0, "top_y": 1.4, "lane_width": 0.7, "hover_height": 0.0, "flying": false},
	"brute": {"size": Vector3(1.8, 2.6, 1.8), "centre_y": 1.3, "bottom_y": 0.0, "top_y": 2.6, "lane_width": 1.8, "hover_height": 0.0, "flying": false},
	"charger": {"size": Vector3(0.9, 1.05, 1.9), "centre_y": 0.525, "bottom_y": 0.0, "top_y": 1.05, "lane_width": 1.9, "hover_height": 0.0, "flying": false},
	"bulwark": {"size": Vector3(1.45, 2.05, 0.85), "centre_y": 1.025, "bottom_y": 0.0, "top_y": 2.05, "lane_width": 1.45, "hover_height": 0.0, "flying": false},
	"scuttler": {"size": Vector3(1.3, 0.62, 1.2), "centre_y": 0.31, "bottom_y": 0.0, "top_y": 0.62, "lane_width": 1.3, "hover_height": 0.0, "flying": false},
	"artillery": {"size": Vector3(1.25, 1.55, 1.25), "centre_y": 0.775, "bottom_y": 0.0, "top_y": 1.55, "lane_width": 1.25, "hover_height": 0.0, "flying": false},
	"beacon": {"size": Vector3(0.62, 2.2, 0.62), "centre_y": 1.1, "bottom_y": 0.0, "top_y": 2.2, "lane_width": 0.62, "hover_height": 0.0, "flying": false},
	"diver": {"size": Vector3(0.7, 0.5, 1.2), "centre_y": 1.9, "bottom_y": 1.65, "top_y": 2.15, "lane_width": 1.2, "hover_height": 1.9, "flying": true},
	"drifter": {"size": Vector3(1.35, 0.95, 1.35), "centre_y": 2.55, "bottom_y": 2.0749999999999997, "top_y": 3.025, "lane_width": 1.35, "hover_height": 2.55, "flying": true},
}

# The closed Action catalog (all 28), in catalog order.
const ECHO_ACTION_PRIMITIVES = ["melee_swing", "melee_thrust", "slam_ground", "hitscan_damage", "projectile_damage", "arc_lob", "burst_fire", "charge_shot", "beam_sustained", "dash", "air_dash", "double_jump", "wall_kick", "hover", "glide", "blink", "grapple_to_surface", "grapple_pull_target", "grapple_swing", "shield", "block", "parry", "heal_self", "cleanse", "scan_mark", "restore_resource", "pull_pickup", "place_marker"]

# The subset this engine must be able to execute today.
const ECHO_IMPLEMENTED_PRIMITIVES = ["melee_swing", "melee_thrust", "slam_ground", "hitscan_damage", "projectile_damage", "arc_lob", "burst_fire", "charge_shot", "beam_sustained", "dash", "air_dash", "double_jump", "wall_kick", "hover", "glide", "blink", "grapple_to_surface", "grapple_pull_target", "grapple_swing", "shield", "block", "parry", "heal_self", "cleanse", "scan_mark", "restore_resource", "pull_pickup", "place_marker"]

# Held back by a stage, with the stage that lands each one.
const ECHO_DEFERRED_PRIMITIVES = {}

# The closed status vocabulary, so `StatusEffects.apply` can refuse
# a kind the schema does not admit. An unknown kind is inert --
# nothing reads it -- while still satisfying `status_active`
# conditions and `status_applied` edges, and `cleanse` can never
# remove it, because it is not in the cleanse order.
const ECHO_STATUS_KINDS = ["burning", "slowed", "frozen", "shocked", "poisoned", "marked", "stunned", "vulnerable", "empowered", "low_profile", "haste", "regenerating"]
