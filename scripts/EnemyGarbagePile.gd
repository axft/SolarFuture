class_name EnemyGarbagePile
extends BaseEnemy

func _init():
	enemy_name = "Landfill Garbage Heap"
	speed = 42.0   # Slow plodding
	max_hp = 520.0 # Massive health pool
	base_damage = 40
	bounty_reward = 140
	eco_score_reward = 100
	co2_reward = 80
	death_sfx_path = "res://assets/enemySludge_pop.mp3"
	
	if ResourceLoader.exists("res://assets/enemy_garbage_pile.png"):
		sprite_texture = load("res://assets/enemy_garbage_pile.png")
	if ResourceLoader.exists("res://assets/fx_garbage_pop.png"):
		death_fx_texture = load("res://assets/fx_garbage_pop.png")
