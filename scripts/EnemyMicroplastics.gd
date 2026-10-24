class_name EnemyMicroplastics
extends BaseEnemy

func _init():
	enemy_name = "Microplastic Cloud"
	speed = 210.0 # Extremely fast!
	max_hp = 22.0 # Fragile
	base_damage = 15
	bounty_reward = 20
	eco_score_reward = 15
	co2_reward = 16
	death_sfx_path = "res://assets/enemyGas_pop.mp3"
	
	if ResourceLoader.exists("res://assets/enemy_microplastics.png"):
		sprite_texture = load("res://assets/enemy_microplastics.png")
	if ResourceLoader.exists("res://assets/fx_microplastics_pop.png"):
		death_fx_texture = load("res://assets/fx_microplastics_pop.png")
