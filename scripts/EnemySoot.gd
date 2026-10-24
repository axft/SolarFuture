class_name EnemySoot
extends BaseEnemy

func _init():
	enemy_name = "Industrial Soot"
	speed = 70.0
	max_hp = 130.0
	base_damage = 25
	bounty_reward = 40
	eco_score_reward = 30
	co2_reward = 35
	death_sfx_path = "res://assets/enemySludge_pop.mp3"
	
	if ResourceLoader.exists("res://assets/enemy_soot.png"):
		sprite_texture = load("res://assets/enemy_soot.png")
	if ResourceLoader.exists("res://assets/fx_soot_melt.png"):
		death_fx_texture = load("res://assets/fx_soot_melt.png")
