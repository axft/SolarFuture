class_name EnemyEWaste
extends BaseEnemy

func _init():
	enemy_name = "Electronic Waste"
	speed = 80.0
	max_hp = 110.0
	base_damage = 20
	bounty_reward = 35
	eco_score_reward = 25
	co2_reward = 22
	death_sfx_path = "res://assets/enemySludge_pop.mp3"
	
	if ResourceLoader.exists("res://assets/enemy_ewaste.png"):
		sprite_texture = load("res://assets/enemy_ewaste.png")
	if ResourceLoader.exists("res://assets/fx_ewaste_pop.png"):
		death_fx_texture = load("res://assets/fx_ewaste_pop.png")

# Armor reduction
func take_damage(amount: float):
	var armored_damage = amount * 0.8 # 20% metallic defense reduction
	super.take_damage(armored_damage)
