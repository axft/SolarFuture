class_name BaseEnemy
extends PathFollow2D

signal reached_end(damage_amount)
signal defeated(enemy)

@export_category("Base Attributes")
@export var enemy_name: String = "Pollutant"
@export var speed: float = 100.0
@export var max_hp: float = 50.0
@export var base_damage: int = 15
@export var bounty_reward: int = 25
@export var eco_score_reward: int = 15
@export var co2_reward: int = 18

@export_category("Visuals & Audio")
@export var sprite_texture: Texture2D
@export var death_fx_texture: Texture2D
@export var death_sfx_path: String = "res://assets/enemyGas_pop.mp3"

var current_hp: float = 50.0
var is_dying: bool = false
var death_fx_scene: PackedScene = preload("res://scenes/DeathEffect.tscn") if ResourceLoader.exists("res://scenes/DeathEffect.tscn") else null

@onready var sprite = get_node_or_null("Sprite2D")
@onready var anim_sprite = get_node_or_null("AnimatedSprite2D")
@onready var hitbox = get_node_or_null("Hitbox/CollisionShape2D")

func _ready():
	loop = false
	current_hp = max_hp
	add_to_group("enemies")

	# FORCE THE EXACT DEATH FX TEXTURE FOR EACH ENEMY TYPE
	assign_unique_enemy_assets()

	if sprite and sprite_texture:
		sprite.texture = sprite_texture

func assign_unique_enemy_assets():
	# Maps each enemy script/class to its own exact textures
	var script_name = get_script().resource_path.get_file()
	
	match script_name:
		"EnemyStyrofoam.gd":
			enemy_name = "Styrofoam Block"
			death_fx_texture = load_if_exists("res://assets/fx_styrofoam_pop.png")
			sprite_texture = load_if_exists("res://assets/enemy_styrofoam.png")
			death_sfx_path = "res://assets/enemyGas_pop.mp3"
		"EnemyEWaste.gd":
			enemy_name = "Electronic Waste"
			death_fx_texture = load_if_exists("res://assets/fx_ewaste_pop.png")
			sprite_texture = load_if_exists("res://assets/enemy_ewaste.png")
			death_sfx_path = "res://assets/enemySludge_pop.mp3"
		"EnemyMicroplastics.gd":
			enemy_name = "Microplastic Cloud"
			death_fx_texture = load_if_exists("res://assets/fx_microplastics_pop.png")
			sprite_texture = load_if_exists("res://assets/enemy_microplastics.png")
			death_sfx_path = "res://assets/enemyGas_pop.mp3"
		"EnemyGarbagePile.gd":
			enemy_name = "Landfill Garbage Heap"
			death_fx_texture = load_if_exists("res://assets/fx_garbage_pop.png")
			sprite_texture = load_if_exists("res://assets/enemy_garbage_pile.png")
			death_sfx_path = "res://assets/enemySludge_pop.mp3"
		"EnemySoot.gd":
			enemy_name = "Industrial Soot"
			death_fx_texture = load_if_exists("res://assets/fx_soot_melt.png")
			sprite_texture = load_if_exists("res://assets/enemy_soot.png")
			death_sfx_path = "res://assets/enemySludge_pop.mp3"
		"EnemyBoss.gd":
			enemy_name = "Climate Crisis Super-Storm"
			death_fx_texture = load_if_exists("res://assets/fx_bosssmog_blow.png")
			sprite_texture = load_if_exists("res://assets/enemy_boss_smog.png")
			death_sfx_path = "res://assets/enemySludge_pop.mp3"
		"EnemyMethane.gd":
			enemy_name = "Methane Vent"
			death_fx_texture = load_if_exists("res://assets/fx_methane_pop.png")
			sprite_texture = load_if_exists("res://assets/enemy_methane.png")
			death_sfx_path = "res://assets/enemyGas_pop.mp3"
		_:
			# Default Smog Enemy
			enemy_name = "Smog Cloud"
			death_fx_texture = load_if_exists("res://assets/fx_smog_pop.png")
			sprite_texture = load_if_exists("res://assets/enemy_smog.png")

func load_if_exists(path: String) -> Texture2D:
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		return load(path)
	return null

func _process(delta: float):
	if GameState.is_paused or GameState.is_game_over or is_dying:
		return

	custom_movement(delta)
	progress += speed * delta
	queue_redraw()

	if progress_ratio >= 1.0:
		reached_end.emit(base_damage)
		queue_free()

func custom_movement(_delta: float):
	pass

func take_damage(amount: float):
	if is_dying: return
	current_hp -= amount
	if current_hp <= 0:
		die()

func die():
	is_dying = true
	speed = 0.0

	if hitbox:
		hitbox.set_deferred("disabled", true)

	# Hide living sprite so only death FX shows
	if sprite: sprite.visible = false
	if anim_sprite: anim_sprite.visible = false

	# Play audio
	if death_sfx_path != "" and has_node("/root/SoundManager"):
		SoundManager.play_sfx_path(death_sfx_path)

	# Spawn the unique death effect
	if death_fx_texture and death_fx_scene:
		print("💥 %s defeated -> Spawning FX: %s" % [enemy_name, death_fx_texture.resource_path])
		var fx = death_fx_scene.instantiate()
		fx.setup(death_fx_texture, global_position)
		get_tree().current_scene.add_child(fx)
	else:
		print("⚠️ No death FX texture for: ", enemy_name)

	defeated.emit(self)
	queue_free()

func _draw():
	if is_dying or current_hp >= max_hp:
		return
	var bar_w = 26.0
	var bar_h = 4.0
	var bar_pos = Vector2(-bar_w / 2.0, -22.0)
	var hp_pct = clampf(current_hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_pct, bar_h)), Color(0.9, 0.2, 0.2))
