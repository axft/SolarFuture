class_name EnemyBoss
extends BaseEnemy

func _init():
	enemy_name = "Climate Crisis Super-Storm"
	speed = 40.0
	max_hp = 650.0
	base_damage = 50
	bounty_reward = 200
	eco_score_reward = 150
	co2_reward = 100
	death_sfx_path = "res://assets/enemySludge_pop.mp3"
	
	if ResourceLoader.exists("res://assets/enemy_boss_smog.png"):
		sprite_texture = load("res://assets/enemy_boss_smog.png")
	if ResourceLoader.exists("res://assets/fx_bosssmog_blow.png"):
		death_fx_texture = load("res://assets/fx_bosssmog_blow.png")
