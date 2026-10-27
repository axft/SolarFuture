extends Area2D

var target: Node2D = null
var speed: float = 480.0
var damage: float = 22.0
var source_tower: Node2D = null
var assigned_key: String = "solar"

# Sprite Sheet Variables
var active_sprite: Sprite2D = null
var total_frames: int = 1
var current_frame: int = 0
var anim_timer: float = 0.0
var frame_duration: float = 0.07

# Called by towers BEFORE add_child()
func setup(target_node: Node2D, shot_damage: float, shot_speed: float, proj_key: String = "solar", tower_ref: Node2D = null):
	target = target_node
	damage = shot_damage
	speed = shot_speed
	source_tower = tower_ref
	
	# Sanitize key (e.g. "GEOTHERMAL", "tower_geothermal" -> "geothermal")
	assigned_key = proj_key.to_lower().replace("tower_", "").replace("projectile_", "").strip_edges()
	
	# If already inside the scene tree, apply immediately
	if is_node_ready():
		apply_projectile_key(assigned_key)

# Runs AFTER add_child(), guaranteeing nodes exist
func _ready():
	z_index = 15
	apply_projectile_key(assigned_key)

func apply_projectile_key(key: String):
	# 1. Hide any pre-existing sprites saved in Projectile.tscn
	var default_sprite = get_node_or_null("Sprite2D")
	var default_anim = get_node_or_null("AnimatedSprite2D")
	if default_sprite: default_sprite.visible = false
	if default_anim: default_anim.visible = false

	# 2. Locate or create our dedicated dynamic sprite
	active_sprite = get_node_or_null("DynamicProjectileSprite")
	if not active_sprite:
		active_sprite = Sprite2D.new()
		active_sprite.name = "DynamicProjectileSprite"
		add_child(active_sprite)

	# 3. Find matching texture
	var path = "res://assets/projectile_%s.png" % key
	if not FileAccess.file_exists(path):
		print("⚠️ Projectile file not found: '", path, "' -> Falling back to solar.")
		path = "res://assets/projectile_solar.png"

	if FileAccess.file_exists(path):
		var tex = load(path)
		active_sprite.texture = tex
		active_sprite.visible = true

		# Auto-slice horizontal strip (e.g. 48x16 -> 3 frames)
		var sz = tex.get_size()
		if sz.x > sz.y and sz.y > 0:
			total_frames = max(1, int(round(sz.x / sz.y)))
			active_sprite.hframes = total_frames
			active_sprite.frame = 0
		else:
			total_frames = 1
			active_sprite.hframes = 1

		print("🎯 Fired projectile with key: '%s' (Frames: %d)" % [key, total_frames])

func _process(delta: float):
	if GameState.is_paused or GameState.is_game_over:
		return

	if not is_instance_valid(target):
		queue_free()
		return

	# Cycle flight animation frames
	if total_frames > 1 and active_sprite:
		anim_timer += delta
		if anim_timer >= frame_duration:
			anim_timer = 0.0
			current_frame = (current_frame + 1) % total_frames
			active_sprite.frame = current_frame

	# Move toward target
	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()

	# Hit detection
	if global_position.distance_to(target.global_position) < 18.0:
		if target.has_method("take_damage"):
			var will_kill: bool = false
			if "current_hp" in target:
				will_kill = (target.current_hp <= damage)

			target.take_damage(damage)

			if is_instance_valid(source_tower) and source_tower.has_method("record_hit"):
				source_tower.record_hit(damage, will_kill)

		queue_free()
