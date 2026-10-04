extends Node2D

@onready var path_2d = $Path2D
@onready var http_request = $ScoreSyncRequest

# HUD Labels
@onready var energy_label = $UI/ColorRect/HBoxContainer/EnergyLabel
@onready var health_label = $UI/ColorRect/HBoxContainer/HealthLabel
@onready var wave_label = $UI/ColorRect/HBoxContainer/WaveLabel
@onready var score_label = $UI/ColorRect/HBoxContainer/ScoreLabel

# Bottom Control Buttons
@onready var start_wave_btn = $UI/StartWaveBtn
@onready var build_solar_btn = $UI/BuildSolarBtn
@onready var build_wind_btn = get_node_or_null("UI/BuildWindBtn")
@onready var pause_btn = get_node_or_null("UI/PauseBtn")

# Tower Inspector UI
@onready var tower_menu = get_node_or_null("UI/TowerMenu")
@onready var menu_title = get_node_or_null("UI/TowerMenu/VBoxContainer/TitleLabel")
@onready var target_option = get_node_or_null("UI/TowerMenu/VBoxContainer/TargetOptionBtn")
@onready var upgrade_dmg_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/UpgradeDmgBtn")
@onready var upgrade_spd_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/UpgradeSpdBtn")
@onready var close_menu_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/CloseBtn")

var enemy_scene: PackedScene = preload("res://scenes/SmogEnemy.tscn")
var solar_tower_scene: PackedScene = preload("res://scenes/TowerSolar.tscn")
var wind_tower_scene: PackedScene = preload("res://scenes/TowerWind.tscn")

var selected_tower: Node2D = null
var enemies_to_spawn: int = 6
var enemies_spawned: int = 0
var spawn_timer: float = 0.0

func _ready():
	start_wave_btn.pressed.connect(_on_start_wave_pressed)
	build_solar_btn.pressed.connect(_on_build_solar_pressed)
	
	if build_wind_btn:
		build_wind_btn.pressed.connect(_on_build_wind_pressed)
	if pause_btn:
		pause_btn.pressed.connect(_on_pause_pressed)
		
	# Tower Inspector Setup
	if tower_menu:
		tower_menu.visible = false
		if close_menu_btn: close_menu_btn.pressed.connect(deselect_tower)
		if upgrade_dmg_btn: upgrade_dmg_btn.pressed.connect(_on_upgrade_damage_pressed)
		if upgrade_spd_btn: upgrade_spd_btn.pressed.connect(_on_upgrade_speed_pressed)
		if target_option:
			target_option.item_selected.connect(_on_target_mode_selected)
			target_option.clear()
			target_option.add_item("🎯 Target: First", 0)
			target_option.add_item("🎯 Target: Closest", 1)
			target_option.add_item("🎯 Target: Last", 2)
	else:
		print("Note: $UI/TowerMenu node not found. Add it to MainGame.tscn if you want the visual popup.")

	http_request.request_completed.connect(_on_score_synced)
	update_ui()
	
	if has_node("Path2D/RoadVisual") and $Path2D.curve:
		$Path2D/RoadVisual.points = $Path2D.curve.get_baked_points()

func _process(delta: float):
	if GameState.is_paused or GameState.is_game_over:
		return

	if GameState.is_wave_active:
		spawn_timer += delta
		if spawn_timer >= 1.2 and enemies_spawned < enemies_to_spawn:
			spawn_enemy()
			spawn_timer = 0.0
			enemies_spawned += 1

func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	enemy.add_to_group("enemies")
	enemy.reached_end.connect(_on_enemy_reached_end)
	enemy.defeated.connect(_on_enemy_defeated)
	path_2d.add_child(enemy)

func _on_enemy_reached_end():
	GameState.eco_health -= 15
	update_ui()
	if GameState.eco_health <= 0 and not GameState.is_game_over:
		trigger_game_over()
	else:
		check_wave_status()

func _on_enemy_defeated(enemy):
	GameState.energy += enemy.bounty_reward
	GameState.sustainability_score += enemy.eco_score_reward
	GameState.clean_kwh_earned += enemy.bounty_reward
	GameState.enemies_defeated += 1
	GameState.co2_mitigated_kg += 18
	update_ui()
	check_wave_status()

func check_wave_status():
	await get_tree().process_frame
	if GameState.is_game_over:
		return
		
	var active_enemies = get_tree().get_nodes_in_group("enemies")
	if enemies_spawned >= enemies_to_spawn and active_enemies.size() == 0:
		GameState.is_wave_active = false
		GameState.wave += 1
		GameState.energy += 100
		enemies_spawned = 0
		enemies_to_spawn += 3
		start_wave_btn.disabled = false
		start_wave_btn.text = "▶️ Start Wave %d" % GameState.wave
		update_ui()

func _on_start_wave_pressed():
	if not GameState.is_wave_active and not GameState.is_paused:
		GameState.is_wave_active = true
		start_wave_btn.disabled = true

func _on_pause_pressed():
	if GameState.is_game_over:
		return
	GameState.is_paused = !GameState.is_paused
	if pause_btn:
		pause_btn.text = "▶️ Resume" if GameState.is_paused else "⏸️ Pause"
	if GameState.is_paused:
		cancel_placement()

func _on_build_solar_pressed():
	if GameState.selected_build_type == "SOLAR":
		cancel_placement()
	else:
		GameState.selected_build_type = "SOLAR"
		deselect_tower()

func _on_build_wind_pressed():
	if GameState.selected_build_type == "WIND":
		cancel_placement()
	else:
		GameState.selected_build_type = "WIND"
		deselect_tower()

func cancel_placement():
	GameState.selected_build_type = ""

# --- INPUT HANDLING (FIXED CLICK DETECTION) ---
func _input(event):
	# Cancel on Right-Click or Escape
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if GameState.selected_build_type != "":
			cancel_placement()
			return
		else:
			deselect_tower()
			return
			
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if GameState.selected_build_type != "":
			cancel_placement()
		else:
			deselect_tower()
		return

	# Left-Click handling
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hovered = get_viewport().gui_get_hovered_control()
		
		# CRITICAL FIX: Only ignore clicks if clicking an actual UI button/menu inside $UI
		if hovered != null and $UI.is_ancestor_of(hovered):
			return
			
		if GameState.is_paused:
			return

		# If in placement mode -> place tower
		if GameState.selected_build_type != "":
			handle_tower_placement()
			return

		# Otherwise -> check if player clicked a tower on the map
		check_tower_click(get_global_mouse_position())

func handle_tower_placement():
	var spawn_pos = get_global_mouse_position()
	
	if GameState.selected_build_type == "SOLAR" and GameState.energy >= 100:
		GameState.energy -= 100
		var tower = solar_tower_scene.instantiate()
		tower.name = "Solar Array"
		tower.global_position = spawn_pos
		add_child(tower)
		cancel_placement()
		update_ui()
	elif GameState.selected_build_type == "WIND" and GameState.energy >= 150:
		GameState.energy -= 150
		var tower = wind_tower_scene.instantiate()
		tower.name = "Wind Turbine"
		tower.global_position = spawn_pos
		add_child(tower)
		cancel_placement()
		update_ui()

# --- TOWER SELECTION & INSPECTOR ---
func check_tower_click(click_pos: Vector2):
	var towers = get_tree().get_nodes_in_group("towers")
	var closest_tower: Node2D = null
	var min_distance: float = 40.0 # 40px generous click radius
	
	for tower in towers:
		var dist = tower.global_position.distance_to(click_pos)
		if dist < min_distance:
			min_distance = dist
			closest_tower = tower
			
	if closest_tower != null:
		select_tower(closest_tower)
	else:
		deselect_tower()

func select_tower(tower: Node2D):
	selected_tower = tower
	print("Tower Selected: ", tower.name, " (Target Mode: ", tower.target_mode, ")")
	if tower_menu:
		tower_menu.visible = true
		update_tower_menu()
	queue_redraw()

func deselect_tower():
	if selected_tower != null:
		print("Tower Deselected.")
	selected_tower = null
	if tower_menu:
		tower_menu.visible = false
	queue_redraw()

func update_tower_menu():
	if not is_instance_valid(selected_tower) or not tower_menu:
		deselect_tower()
		return
		
	if menu_title: menu_title.text = selected_tower.name
	if upgrade_dmg_btn:
		upgrade_dmg_btn.text = "⚡ Dmg Lvl %d (%d kWh)" % [selected_tower.damage_level, selected_tower.damage_upgrade_cost]
	if upgrade_spd_btn:
		upgrade_spd_btn.text = "💨 Spd Lvl %d (%d kWh)" % [selected_tower.speed_level, selected_tower.speed_upgrade_cost]
	if target_option:
		match selected_tower.target_mode:
			"FIRST": target_option.selected = 0
			"CLOSEST": target_option.selected = 1
			"LAST": target_option.selected = 2

func _on_upgrade_damage_pressed():
	if is_instance_valid(selected_tower) and selected_tower.upgrade_damage():
		update_ui()
		update_tower_menu()
		queue_redraw()

func _on_upgrade_speed_pressed():
	if is_instance_valid(selected_tower) and selected_tower.upgrade_speed():
		update_ui()
		update_tower_menu()
		queue_redraw()

func _on_target_mode_selected(index: int):
	if is_instance_valid(selected_tower):
		match index:
			0: selected_tower.target_mode = "FIRST"
			1: selected_tower.target_mode = "CLOSEST"
			2: selected_tower.target_mode = "LAST"
		print("Targeting changed to: ", selected_tower.target_mode)

# --- VISUAL SELECTION RING ON MAP ---
func _draw():
	if is_instance_valid(selected_tower):
		var tower_pos = to_local(selected_tower.global_position)
		var r = selected_tower.range_radius if "range_radius" in selected_tower else 140.0
		
		# Draw blue range circle of the selected tower
		draw_circle(tower_pos, r, Color(0.2, 0.6, 1.0, 0.15))
		draw_arc(tower_pos, r, 0.0, TAU, 64, Color(0.2, 0.7, 1.0, 0.8), 2.0)
		
		# Draw golden selection highlight ring around tower footprint
		draw_arc(tower_pos, 28.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.2, 0.95), 3.0)

func trigger_game_over():
	GameState.is_game_over = true
	var url = "http://localhost/solarfuture/api/save_score.php"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"wave": GameState.wave,
		"score": GameState.sustainability_score,
		"cleanKwh": GameState.clean_kwh_earned
	})
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_score_synced(_result, _code, _headers, body):
	print("Saved to MySQL: ", body.get_string_from_utf8())
	start_wave_btn.text = "MISSION OVER - Check MySQL"

func update_ui():
	energy_label.text = "⚡ Energy: %d kWh   " % GameState.energy
	health_label.text = "🌍 Health: %d%%   " % GameState.eco_health
	wave_label.text = "🌊 Wave: %d   " % GameState.wave
	score_label.text = "🌱 Score: %d" % GameState.sustainability_score
