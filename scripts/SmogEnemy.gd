class_name SmogEnemy
extends BaseEnemy

func _init():
	enemy_name = "Smog Cloud"
	speed = 110.0
	max_hp = 50.0
	base_damage = 15
	bounty_reward = 25
	eco_score_reward = 15
	co2_reward = 18
	death_sfx_path = "res://assets/enemyGas_pop.mp3"
	
	if ResourceLoader.exists("res://assets/enemy_smog.png"):
		sprite_texture = load("res://assets/enemy_smog.png")
	if ResourceLoader.exists("res://assets/fx_methane_pop.png"):
		death_fx_texture = load("res://assets/fx_methane_pop.png")
