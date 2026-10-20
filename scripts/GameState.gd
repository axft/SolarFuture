extends Node

# --- AUTHENTICATED OFFICER PROFILE ---
var current_user_id: int = 0
var current_username: String = ""

# --- PERSONAL LIFETIME RECORDS (From MySQL) ---
var user_high_score: int = 0
var user_max_wave: int = 0
var user_total_kwh: int = 0

# --- STAGE DEFINITIONS & SELECTION ---
var selected_stage_id: int = 1

const STAGES = {
	1: {
		"name": "Greenfield Valley",
		"desc": "Baseline biosphere. Moderate smog density.",
		"target_wave": 5, # Beat Wave 5 to win!
		"bg_color": Color("#1e824c"),
		"bonus_kwh": 150
	},
	2: {
		"name": "Industrial Basin",
		"desc": "Dense soot and heavy smog. Fast methane leaks.",
		"target_wave": 8,
		"bg_color": Color("#34495e"),
		"bonus_kwh": 300
	}
}

# --- ACTIVE RUN / SESSION METRICS (SDG 7 & 13) ---
var energy: int = 300
var eco_health: int = 100
var sustainability_score: int = 0
var wave: int = 1

var enemies_defeated: int = 0
var clean_kwh_earned: int = 0
var co2_mitigated_kg: int = 0

# --- RUNTIME FLOW STATES ---
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
