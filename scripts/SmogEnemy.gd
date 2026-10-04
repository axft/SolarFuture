extends PathFollow2D

# MUST BE DECLARED HERE AT THE TOP:
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
	if GameState.is_paused or GameState.is_game_over:
		return
		
	progress += speed * delta
	
	if progress_ratio >= 1.0:
		reached_end.emit()   # <-- Emits the signal when hitting the end
		queue_free()

func take_damage(amount: float):
	current_hp -= amount
	if current_hp <= 0:
		defeated.emit(self)  # <-- Emits the signal when killed
		queue_free()
