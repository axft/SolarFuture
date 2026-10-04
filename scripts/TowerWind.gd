extends Node2D

@export var damage: float = 10.0
@export var fire_rate: float = 3.0
@export var range_radius: float = 110.0
@export var projectile_scene: PackedScene = preload("res://scenes/Projectile.tscn")

@onready var range_area = $RangeArea
@onready var anim_sprite = get_node_or_null("AnimatedSprite2D")

var cooldown_timer: float = 0.0
var targets_in_range: Array[Node2D] = []

# Targeting & Upgrades
var target_mode: String = "FIRST"
var damage_level: int = 1
var speed_level: int = 1
var damage_upgrade_cost: int = 50
var speed_upgrade_cost: int = 40

func _ready():
	add_to_group("towers")
	range_area.area_entered.connect(_on_area_entered)
	range_area.area_exited.connect(_on_area_exited)
	
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
		if anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")

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
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")

	var proj = projectile_scene.instantiate()
	proj.global_position = global_position
	if proj.has_method("setup"):
		proj.setup(target_enemy, damage, 550.0, "wind")
	else:
		proj.target = target_enemy
		proj.damage = damage
		
	get_tree().current_scene.add_child(proj)

func _on_animation_finished():
	if anim_sprite and anim_sprite.animation == "attack":
		anim_sprite.play("idle")

func upgrade_damage() -> bool:
	if GameState.energy >= damage_upgrade_cost:
		GameState.energy -= damage_upgrade_cost
		damage += 5.0
		damage_level += 1
		damage_upgrade_cost += 25
		return true
	return false

func upgrade_speed() -> bool:
	if GameState.energy >= speed_upgrade_cost:
		GameState.energy -= speed_upgrade_cost
		fire_rate += 0.8
		speed_level += 1
		speed_upgrade_cost += 20
		return true
	return false
