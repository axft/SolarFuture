class_name EnemyStyrofoam
extends BaseEnemy

var wobble_time: float = 0.0

func _init():
	enemy_name = "Styrofoam Block"
	speed = 95.0
	max_hp = 35.0
	base_damage = 10
	bounty_reward = 15
	eco_score_reward = 10
	co2_reward = 12
	death_sfx_path = "res://assets/enemyGas_pop.mp3"
	
	if ResourceLoader.exists("res://assets/enemy_styrofoam.png"):
		sprite_texture = load("res://assets/enemy_styrofoam.png")
	if ResourceLoader.exists("res://assets/fx_styrofoam_pop.png"):
		death_fx_texture = load("res://assets/fx_styrofoam_pop.png")

# Custom wobble float
func custom_movement(delta: float):
	wobble_time += delta * 5.0
	if sprite:
		sprite.position.y = sin(wobble_time) * 3.0
