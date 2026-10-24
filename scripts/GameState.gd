extends Node

# --- AUTHENTICATION & PROFILE ---
var current_user_id: int = 0
var current_username: String = ""

var user_high_score: int = 0
var user_max_wave: int = 0
var user_total_kwh: int = 0

# --- TOWER DEFINITIONS REGISTRY (SDG 7) ---
const TOWER_CATALOG = {
	"SOLAR": {
		"name": "Solar Array",
		"cost": 100,
		"range": 160.0,
		"damage": 22.0,
		"fire_rate": 1.2,
		"projectile_key": "solar",
		"projectile_speed": 480.0,
		"preview_color": Color(0.0, 0.85, 1.0),
		"sprite_idle": "res://assets/tower_solar_idle.png",
		"sprite_attack": "res://assets/tower_solar_attack.png"
	},
	"WIND": {
		"name": "Wind Turbine",
		"cost": 150,
		"range": 110.0,
		"damage": 10.0,
		"fire_rate": 3.0,
		"projectile_key": "wind",
		"projectile_speed": 550.0,
		"preview_color": Color(0.2, 0.9, 0.7),
		"sprite_idle": "res://assets/tower_wind_idle.png",
		"sprite_attack": "res://assets/tower_wind_attack.png"
	},
	"MYCELIUM": {
		"name": "Mycelium Network",
		"cost": 120,
		"range": 130.0,
		"damage": 14.0,
		"fire_rate": 1.8,
		"projectile_key": "mycelium",
		"projectile_speed": 420.0,
		"preview_color": Color(0.8, 0.4, 0.9),
		"sprite_idle": "res://assets/tower_mycelium_idle.png",
		"sprite_attack": "res://assets/tower_mycelium_attack.png"
	},
	"GEOTHERMAL": {
		"name": "Geothermal Vent",
		"cost": 220,
		"range": 140.0,
		"damage": 40.0,
		"fire_rate": 0.8,
		"projectile_key": "geothermal",
		"projectile_speed": 460.0,
		"preview_color": Color(1.0, 0.4, 0.2),
		"sprite_idle": "res://assets/tower_geothermal_idle.png",
		"sprite_attack": "res://assets/tower_geothermal_attack.png"
	},
	"SUBSTATION": {
		"name": "Substation Grid",
		"cost": 180,
		"range": 150.0,
		"damage": 18.0,
		"fire_rate": 2.2,
		"projectile_key": "substation",
		"projectile_speed": 600.0,
		"preview_color": Color(0.3, 0.7, 1.0),
		"sprite_idle": "res://assets/tower_substation_idle.png",
		"sprite_attack": "res://assets/tower_substation_attack.png"
	},
	"SPRINKLER": {
		"name": "Water Sprinkler",
		"cost": 90,
		"range": 100.0,
		"damage": 8.0,
		"fire_rate": 3.5,
		"projectile_key": "sprinkler",
		"projectile_speed": 520.0,
		"preview_color": Color(0.2, 0.6, 1.0),
		"sprite_idle": "res://assets/tower_sprinkler_idle.png",
		"sprite_attack": "res://assets/tower_sprinkler_attack.png"
	},
	"SAPLING": {
		"name": "Tree Sapling",
		"cost": 75,
		"range": 120.0,
		"damage": 12.0,
		"fire_rate": 1.5,
		"projectile_key": "sapling",
		"projectile_speed": 450.0,
		"preview_color": Color(0.4, 0.9, 0.3),
		"sprite_idle": "res://assets/tower_sapling_idle.png",
		"sprite_attack": "res://assets/tower_sapling_attack.png"
	}
}

# --- MULTI-STAGE SYSTEM (SDG 13 BIOMES & ROADS) ---
var selected_stage_id: int = 1

const STAGES = {
	1: {
		"name": "Greenfield Valley",
		"desc": "Baseline biosphere. Smog and light waste.",
		"target_wave": 5,
		"bg_color": Color("#1e824c"),
		"bonus_kwh": 150,
		"points": [
			Vector2(0, 300), Vector2(260, 300), Vector2(260, 120),
			Vector2(680, 120), Vector2(680, 460), Vector2(960, 460)
		]
	},
	2: {
		"name": "Industrial Basin",
		"desc": "Dense soot, Styrofoam, and E-Waste threats.",
		"target_wave": 8,
		"bg_color": Color("#2c3e50"),
		"bonus_kwh": 300,
		"points": [
			Vector2(0, 150), Vector2(400, 150), Vector2(400, 350),
			Vector2(200, 350), Vector2(200, 500), Vector2(960, 500)
		]
	},
	3: {
		"name": "Coastal Landfill",
		"desc": "Extreme pollution: Microplastics & Massive Garbage Piles.",
		"target_wave": 10,
		"bg_color": Color("#162a38"),
		"bonus_kwh": 500,
		"points": [
			Vector2(0, 450), Vector2(300, 450), Vector2(300, 200),
			Vector2(600, 200), Vector2(600, 380), Vector2(850, 380), Vector2(850, 100), Vector2(960, 100)
		]
	}
}

# --- RUNTIME METRICS ---
var energy: int = 300
var eco_health: int = 100
var sustainability_score: int = 0
var wave: int = 1

var enemies_defeated: int = 0
var clean_kwh_earned: int = 0
var co2_mitigated_kg: int = 0

var selected_build_type: String = ""
var is_wave_active: bool = false
var is_paused: bool = false
var is_game_over: bool = false
var is_endless_mode: bool = false

func reset_run():
	energy = 300
	eco_health = 100
	sustainability_score = 0
	wave = 1
	enemies_defeated = 0
	clean_kwh_earned = 0
	co2_mitigated_kg = 0
	is_wave_active = false
	is_paused = false
	is_game_over = false
	is_endless_mode = false
	selected_build_type = ""

func logout():
	current_user_id = 0
	current_username = ""
	user_high_score = 0
	user_max_wave = 0
	user_total_kwh = 0
	reset_run()
