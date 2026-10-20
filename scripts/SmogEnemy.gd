extends PathFollow2D

signal reached_end(damage_amount)
signal defeated(enemy)

@onready var anim_sprite = $AnimatedSprite2D  # <-- Matches the node name!

@export_category("Enemy Stats")
@export var speed: float = 110.0
@export var max_hp: float = 50.0
@export var base_damage: int = 15
@export var bounty_reward: int = 25
@export var eco_score_reward: int = 15
@export var co2_reward: int = 18

var current_hp: float = 50.0
var is_dying: bool = false

func _ready():
	loop = false
	current_hp = max_hp
	# Play the moving smog animation while alive
	if anim_sprite and anim_sprite.sprite_frames.has_animation("default"):
		anim_sprite.play("default")

func _process(delta: float):
	if GameState.is_paused or GameState.is_game_over or is_dying:
		return
		
	progress += speed * delta
	
	if progress_ratio >= 1.0:
		reached_end.emit(base_damage)
		queue_free()

func take_damage(amount: float):
	if is_dying:
		return
		
	current_hp -= amount
	if current_hp <= 0:
		die()

func die():
	is_dying = true
	speed = 0 # Freeze in place while popping
	SoundManager.play_sfx_path("res://assets/enemyGas_pop.mp3")
	
	# Disable hitbox so towers immediately retarget other enemies
	var hitbox = get_node_or_null("Hitbox/CollisionShape2D")
	if hitbox:
		hitbox.set_deferred("disabled", true)
		
	# Play the death puff
	if anim_sprite and anim_sprite.sprite_frames.has_animation("death"):
		anim_sprite.play("death")
		await anim_sprite.animation_finished # Waits for the 4 frames to finish
		
	defeated.emit(self)
	queue_free()
