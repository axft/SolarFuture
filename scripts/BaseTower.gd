extends Node2D

@export var tower_type: String = "SOLAR"

var damage: float = 22.0
var fire_rate: float = 1.2
var range_radius: float = 160.0
var projectile_key: String = "solar"
var projectile_speed: float = 480.0
var fallback_color: Color = Color.CYAN
var projectile_scene: PackedScene = preload("res://scenes/Projectile.tscn")

@onready var range_area = $RangeArea
@onready var anim_sprite = get_node_or_null("AnimatedSprite2D")
@onready var sprite = get_node_or_null("Sprite2D")

var cooldown_timer: float = 0.0
var targets_in_range: Array[Node2D] = []

var target_mode: String = "FIRST"
var kills: int = 0
var total_damage_dealt: float = 0.0
var damage_level: int = 1
var speed_level: int = 1
var damage_upgrade_cost: int = 60
var speed_upgrade_cost: int = 50

var has_texture_loaded: bool = false

func setup_tower(type: String):
	tower_type = type
	var cfg = GameState.TOWER_CATALOG.get(type, GameState.TOWER_CATALOG["SOLAR"])
	name = cfg.name
	damage = cfg.damage
	fire_rate = cfg.fire_rate
	range_radius = cfg.range
	projectile_key = cfg.projectile_key
	projectile_speed = cfg.projectile_speed
	fallback_color = cfg.preview_color

	# CRITICAL: Force high Z-Index so tower is NEVER behind the grass
	z_index = 10

	# Update collision shape radius
	if range_area:
		var shape = range_area.get_node_or_null("CollisionShape2D")
		if shape and shape.shape is CircleShape2D:
			shape.shape.radius = range_radius

	# Try multiple possible filenames for idle sprite
	var possible_textures = [
		cfg.sprite_idle,
		cfg.sprite_idle.replace("_idle.png", "_sheet.png"),
		cfg.sprite_idle.replace("_idle.png", ".png"),
		"res://assets/tower_%s_sheet.png" % type.to_lower(),
		"res://assets/tower_%s.png" % type.to_lower()
	]

	var loaded_tex: Texture2D = null
	for path in possible_textures:
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			loaded_tex = load(path)
			if loaded_tex:
				print("✅ Loaded tower texture: ", path)
				break

	if loaded_tex:
		has_texture_loaded = true
		if sprite:
			sprite.texture = loaded_tex
			sprite.visible = true
		elif anim_sprite:
			# If AnimatedSprite2D was set to z_index -5, fix it to 0 relative to tower
			anim_sprite.z_index = 0
			anim_sprite.visible = false
			var s = get_node_or_null("DynamicSprite")
			if not s:
				s = Sprite2D.new()
				s.name = "DynamicSprite"
				add_child(s)
			s.texture = loaded_tex
			s.visible = true
	else:
		print("⚠️ No sprite found for %s. Using procedural fallback circle!" % type)
		has_texture_loaded = false

	queue_redraw()

func _ready():
	add_to_group("towers")
	z_index = 10 # Guarantee in front of map!
	
	if range_area:
		range_area.area_entered.connect(_on_area_entered)
		range_area.area_exited.connect(_on_area_exited)

func _on_area_entered(area):
	var enemy = area.get_parent()
	if enemy.is_in_group("enemies") and not targets_in_range.has(enemy):
		targets_in_range.append(enemy)

func _on_area_exited(area):
	var enemy = area.get_parent()
	targets_in_range.erase(enemy)

func _process(delta: float):
	if GameState.is_paused or GameState.is_game_over:
		return

	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	targets_in_range = targets_in_range.filter(func(e): return is_instance_valid(e))

	if targets_in_range.size() > 0 and cooldown_timer <= 0.0:
		var target = get_best_target()
		if target:
			shoot(target)
			cooldown_timer = 1.0 / fire_rate

func get_best_target() -> Node2D:
	if targets_in_range.is_empty():
		return null

	var best_target = targets_in_range[0]
	if target_mode == "FIRST":
		var max_prog: float = -1.0
		for e in targets_in_range:
			if e.progress > max_prog:
				max_prog = e.progress
				best_target = e
	elif target_mode == "LAST":
		var min_prog: float = INF
		for e in targets_in_range:
			if e.progress < min_prog:
				min_prog = e.progress
				best_target = e
	elif target_mode == "CLOSEST":
		var min_dist: float = INF
		for e in targets_in_range:
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				best_target = e

	return best_target

func shoot(target_enemy: Node2D):
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position
	proj.setup(target_enemy, damage, projectile_speed, projectile_key, self)
	get_tree().current_scene.add_child(proj)

func record_hit(dmg: float, was_killed: bool = false):
	total_damage_dealt += dmg
	if was_killed: kills += 1

func get_dps() -> float:
	return damage * fire_rate

func upgrade_damage() -> bool:
	if GameState.energy >= damage_upgrade_cost:
		GameState.energy -= damage_upgrade_cost
		damage += 8.0
		damage_level += 1
		damage_upgrade_cost += 30
		play_punch_animation()
		return true
	return false

func upgrade_speed() -> bool:
	if GameState.energy >= speed_upgrade_cost:
		GameState.energy -= speed_upgrade_cost
		fire_rate += 0.5
		speed_level += 1
		speed_upgrade_cost += 25
		play_punch_animation()
		return true
	return false

func play_punch_animation():
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE)

# --- PROCEDURAL FALLBACK (GUARANTEES YOU ALWAYS SEE THE TOWER) ---
func _draw():
	if not has_texture_loaded:
		# Draw solid colored body
		draw_circle(Vector2.ZERO, 22.0, fallback_color)
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color.WHITE, 2.0)
		
		# Draw the tower's initial letter in the center
		var letter = tower_type.substr(0, 1)
		draw_string(ThemeDB.fallback_font, Vector2(-5, 5), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.BLACK)
