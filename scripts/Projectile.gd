extends Area2D

@onready var anim_sprite = get_node_or_null("AnimatedSprite2D")
@onready var static_sprite = get_node_or_null("Sprite2D")

var target: Node2D = null
var speed: float = 480.0
var damage: float = 22.0
var projectile_type: String = "solar"

func setup(target_node: Node2D, shot_damage: float, shot_speed: float, anim_name: String = "solar"):
	target = target_node
	damage = shot_damage
	speed = shot_speed
	projectile_type = anim_name

func _ready():
	if anim_sprite and anim_sprite.sprite_frames:
		if anim_sprite.sprite_frames.has_animation(projectile_type):
			anim_sprite.play(projectile_type)
		else:
			anim_sprite.play()

func _process(delta: float):
	if GameState.is_paused or GameState.is_game_over:
		return

	if not is_instance_valid(target):
		queue_free()
		return
		
	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()
	
	if global_position.distance_to(target.global_position) < 18.0:
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
