extends PathFollow2D

signal reached_end
signal defeated(enemy)

@export var speed: float = 110.0
var max_hp: float = 50.0
var current_hp: float = 50.0
var bounty_reward: int = 25
var eco_score_reward: int = 15

func _ready():
	loop = false
	current_hp = max_hp

func _process(delta: float):
	if GameState.is_game_over:
		return
		
	progress += speed * delta
	
	if progress_ratio >= 1.0:
		reached_end.emit()
		queue_free()

func take_damage(amount: float):
	current_hp -= amount
	if current_hp <= 0:
		defeated.emit(self)
		queue_free()
