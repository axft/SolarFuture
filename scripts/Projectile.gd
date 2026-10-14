extends Area2D

@onready var anim_sprite = get_node_or_null("AnimatedSprite2D")
@onready var static_sprite = get_node_or_null("Sprite2D")

var target: Node2D = null
var speed: float = 480.0
var damage: float = 22.0
var projectile_type: String = "solar"
var source_tower: Node2D = null # Reference to originating tower

func setup(target_node: Node2D, shot_damage: float, shot_speed: float, anim_name: String = "solar", tower_ref: Node2D = null):
	target = target_node
	damage = shot_damage
	speed = shot_speed
	projectile_type = anim_name
	source_tower = tower_ref

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
	
	# Hit detection when reaching target center
	if global_position.distance_to(target.global_position) < 18.0:
		if target.has_method("take_damage"):
			var will_kill: bool = false
			if "current_hp" in target:
				will_kill = (target.current_hp <= damage)
			
			target.take_damage(damage)
			
			# Credit damage and kills to the source facility
			if is_instance_valid(source_tower) and source_tower.has_method("record_hit"):
				source_tower.record_hit(damage, will_kill)
				
		queue_free()
