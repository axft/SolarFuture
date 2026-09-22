extends Node

# Active Session Data
var current_user_id: int = 0
var current_username: String = ""

# SDG 7 & 13 Metrics
var energy: int = 300
var eco_health: int = 100
var sustainability_score: int = 0
var wave: int = 1

var enemies_defeated: int = 0
var clean_kwh_earned: int = 0
var co2_mitigated_kg: int = 0

var selected_build_type: String = ""
var is_wave_active: bool = false
var is_game_over: bool = false

func reset_game():
	energy = 300
	eco_health = 100
	sustainability_score = 0
	wave = 1
	enemies_defeated = 0
	clean_kwh_earned = 0
	co2_mitigated_kg = 0
	is_wave_active = false
	is_game_over = false
	selected_build_type = ""
