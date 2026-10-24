extends Area2D

@onready var sprite = get_node_or_null("Sprite2D")
@onready var anim_sprite = get_node_or_null("AnimatedSprite2D")

var target: Node2D = null
var speed: float = 480.0
var damage: float = 22.0
var source_tower: Node2D = null

func setup(target_node: Node2D, shot_damage: float, shot_speed: float, sprite_key: String, tower_ref: Node2D = null):
	target = target_node
	damage = shot_damage
	speed = shot_speed
	source_tower = tower_ref

	var path = "res://assets/projectile_%s.png" % sprite_key
	if FileAccess.file_exists(path):
		var tex = load(path)
		if sprite:
			sprite.texture = tex
		elif anim_sprite:
			# If using AnimatedSprite2D, add texture as single frame or fallback
			anim_sprite.visible = false
			var s = Sprite2D.new()
			s.name = "DynamicSprite"
			s.texture = tex
			add_child(s)

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
			var will_kill: bool = false
			if "current_hp" in target:
				will_kill = (target.current_hp <= damage)

			target.take_damage(damage)

			if is_instance_valid(source_tower) and source_tower.has_method("record_hit"):
				source_tower.record_hit(damage, will_kill)

		queue_free()
