class_name EnemyMethane
extends BaseEnemy

func _init():
	enemy_name = "Methane Vent"
	speed = 150.0
	max_hp = 40.0
	base_damage = 12
	bounty_reward = 20
	eco_score_reward = 15
	co2_reward = 25
	death_sfx_path = "res://assets/enemyGas_pop.mp3"
	
	if ResourceLoader.exists("res://assets/enemy_methane.png"):
		sprite_texture = load("res://assets/enemy_methane.png")
	if ResourceLoader.exists("res://assets/fx_methane_pop.png"):
		death_fx_texture = load("res://assets/fx_methane_pop.png")

# Gas leak accelerates as it moves
func custom_movement(delta: float):
	speed += delta * 6.0
