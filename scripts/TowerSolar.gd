extends Node2D

@export var damage: float = 22.0
@export var fire_rate: float = 1.2
@export var projectile_scene: PackedScene = preload("res://scenes/Projectile.tscn")

@onready var range_area = $RangeArea
@onready var anim_sprite = $AnimatedSprite2D

var cooldown_timer: float = 0.0
var targets_in_range: Array[Node2D] = []

func _ready():
	range_area.area_entered.connect(_on_area_entered)
	range_area.area_exited.connect(_on_area_exited)
	
	# Listen for when the attack animation completes
	anim_sprite.animation_finished.connect(_on_animation_finished)
	
	# Start in idle state
	anim_sprite.play("idle")

func _on_area_entered(area):
	var enemy = area.get_parent()
	if enemy.is_in_group("enemies") and not targets_in_range.has(enemy):
		targets_in_range.append(enemy)

func _on_area_exited(area):
	var enemy = area.get_parent()
	targets_in_range.erase(enemy)

func _process(delta: float):
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		
	# Clean up any targets that were freed/defeated
	targets_in_range = targets_in_range.filter(func(e): return is_instance_valid(e))
	
	if targets_in_range.size() > 0 and cooldown_timer <= 0.0:
		shoot(targets_in_range[0])
		cooldown_timer = 1.0 / fire_rate

func shoot(target_enemy: Node2D):
	# 1. Trigger the attack animation
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")

	# 2. Spawn and launch the projectile
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position
	proj.target = target_enemy
	proj.damage = damage
	get_tree().current_scene.add_child(proj)

# Automatically returns to idle once the attack animation finishes
func _on_animation_finished():
	if anim_sprite.animation == "attack":
		anim_sprite.play("idle")
