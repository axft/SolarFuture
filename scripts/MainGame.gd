extends Node2D

@onready var path_2d = $Path2D
@onready var http_request = $ScoreSyncRequest

# --- HUD LABELS ---
@onready var energy_label = $UI/ColorRect/HBoxContainer/EnergyLabel
@onready var health_label = $UI/ColorRect/HBoxContainer/HealthLabel
@onready var wave_label = $UI/ColorRect/HBoxContainer/WaveLabel
@onready var score_label = $UI/ColorRect/HBoxContainer/ScoreLabel

# --- BOTTOM CONTROLS ---
@onready var start_wave_btn = $UI/StartWaveBtn
@onready var build_solar_btn = $UI/BuildSolarBtn
@onready var build_wind_btn = get_node_or_null("UI/BuildWindBtn")
@onready var pause_btn = get_node_or_null("UI/PauseBtn")
@onready var speed_btn = get_node_or_null("UI/SpeedBtn") # Feature 1

# --- TOWER INSPECTOR UI (Feature 2) ---
@onready var tower_menu = get_node_or_null("UI/TowerMenu")
@onready var menu_title = get_node_or_null("UI/TowerMenu/VBoxContainer/TitleLabel")
@onready var stats_label = get_node_or_null("UI/TowerMenu/VBoxContainer/StatsLabel")
@onready var target_option = get_node_or_null("UI/TowerMenu/VBoxContainer/TargetOptionBtn")
@onready var upgrade_dmg_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/UpgradeDmgBtn")
@onready var upgrade_spd_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/UpgradeSpdBtn")
@onready var close_menu_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/CloseBtn")

# --- SCENE PRELOADS ---
var solar_tower_scene: PackedScene = preload("res://scenes/TowerSolar.tscn")
var wind_tower_scene: PackedScene = preload("res://scenes/TowerWind.tscn")

var smog_scene: PackedScene = preload("res://scenes/SmogEnemy.tscn")
var methane_scene: PackedScene = preload("res://scenes/EnemyMethane.tscn") if ResourceLoader.exists("res://scenes/EnemyMethane.tscn") else smog_scene
var soot_scene: PackedScene = preload("res://scenes/EnemySoot.tscn") if ResourceLoader.exists("res://scenes/EnemySoot.tscn") else smog_scene
var boss_scene: PackedScene = preload("res://scenes/EnemyBoss.tscn") if ResourceLoader.exists("res://scenes/EnemyBoss.tscn") else smog_scene

# --- GAMEPLAY STATE ---
var selected_tower: Node2D = null
var enemies_to_spawn: int = 6
var enemies_spawned: int = 0
var spawn_timer: float = 0.0
var game_speed: float = 1.0 # 1.0 or 2.0

func _ready():
	Engine.time_scale = 1.0
	
	start_wave_btn.pressed.connect(_on_start_wave_pressed)
	build_solar_btn.pressed.connect(_on_build_solar_pressed)
	
	if build_wind_btn:
		build_wind_btn.pressed.connect(_on_build_wind_pressed)
	if pause_btn:
		pause_btn.pressed.connect(_on_pause_pressed)
	if speed_btn:
		speed_btn.pressed.connect(_on_speed_pressed)
		
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

	# Keep live stats ticking in the inspector if a tower is currently selected
	if is_instance_valid(selected_tower) and tower_menu and tower_menu.visible:
		update_tower_stats_text()

# --- WAVE & ENEMY SPAWNING ---
func spawn_enemy():
	var enemy_to_spawn: PackedScene = smog_scene
	
	if GameState.wave == 5:
		enemy_to_spawn = boss_scene if enemies_spawned == 0 else [smog_scene, methane_scene].pick_random()
	elif GameState.wave >= 4:
		var roll = randf()
		if roll < 0.35: enemy_to_spawn = methane_scene
		elif roll < 0.70: enemy_to_spawn = soot_scene
		else: enemy_to_spawn = smog_scene
	elif GameState.wave >= 2:
		enemy_to_spawn = methane_scene if randf() < 0.45 else smog_scene

	var enemy = enemy_to_spawn.instantiate()
	enemy.add_to_group("enemies")
	enemy.reached_end.connect(_on_enemy_reached_end)
	enemy.defeated.connect(_on_enemy_defeated)
	path_2d.add_child(enemy)

func _on_enemy_reached_end(damage_amount: int = 15):
	GameState.eco_health -= damage_amount
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
	GameState.co2_mitigated_kg += enemy.co2_reward if "co2_reward" in enemy else 18
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

# --- CONTROLS: START, PAUSE & SPEED (Feature 1) ---
func _on_start_wave_pressed():
	if GameState.is_paused:
		show_warning_toast("⚠️ Operation paused! Unpause to start wave.")
		return
		
	if not GameState.is_wave_active:
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
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = game_speed

func _on_speed_pressed():
	if GameState.is_paused:
		show_warning_toast("⚠️ Cannot change speed while paused.")
		return

	if game_speed == 1.0:
		game_speed = 2.0
		if speed_btn: speed_btn.text = "⏩ 2x"
	else:
		game_speed = 1.0
		if speed_btn: speed_btn.text = "▶️ 1x"
		
	Engine.time_scale = game_speed

# --- BUILDING SELECTION & TOAST WARNINGS (Feature 3) ---
func _on_build_solar_pressed():
	if GameState.is_paused:
		show_warning_toast("⚠️ Grid is paused! Unpause to construct.")
		return
	if GameState.energy < 100:
		show_warning_toast("⚡ Insufficient Energy: 100 kWh required for Solar Array!")
		return

	if GameState.selected_build_type == "SOLAR":
		cancel_placement()
	else:
		GameState.selected_build_type = "SOLAR"
		deselect_tower()

func _on_build_wind_pressed():
	if GameState.is_paused:
		show_warning_toast("⚠️ Grid is paused! Unpause to construct.")
		return
	if GameState.energy < 150:
		show_warning_toast("⚡ Insufficient Energy: 150 kWh required for Wind Turbine!")
		return

	if GameState.selected_build_type == "WIND":
		cancel_placement()
	else:
		GameState.selected_build_type = "WIND"
		deselect_tower()

func cancel_placement():
	GameState.selected_build_type = ""

# --- INPUT HANDLING ---
func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if GameState.selected_build_type != "":
			cancel_placement()
		else:
			deselect_tower()
		return
			
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if GameState.selected_build_type != "":
			cancel_placement()
		else:
			deselect_tower()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hovered = get_viewport().gui_get_hovered_control()
		if hovered != null and $UI.is_ancestor_of(hovered):
			return
			
		if GameState.is_paused:
			if GameState.selected_build_type != "":
				show_warning_toast("⚠️ Unpause the simulation to place facilities.")
			return

		if GameState.selected_build_type != "":
			handle_tower_placement()
			return

		check_tower_click(get_global_mouse_position())

func handle_tower_placement():
	var spawn_pos = get_global_mouse_position()
	
	if GameState.selected_build_type == "SOLAR":
		if GameState.energy >= 100:
			GameState.energy -= 100
			var tower = solar_tower_scene.instantiate()
			tower.name = "Solar Array"
			tower.global_position = spawn_pos
			add_child(tower)
			cancel_placement()
			update_ui()
		else:
			show_warning_toast("⚡ Insufficient Energy (100 kWh required)!")
			
	elif GameState.selected_build_type == "WIND":
		if GameState.energy >= 150:
			GameState.energy -= 150
			var tower = wind_tower_scene.instantiate()
			tower.name = "Wind Turbine"
			tower.global_position = spawn_pos
			add_child(tower)
			cancel_placement()
			update_ui()
		else:
			show_warning_toast("⚡ Insufficient Energy (150 kWh required)!")

# --- DETAILED TOWER INSPECTOR & SELECTION (Feature 2) ---
func check_tower_click(click_pos: Vector2):
	var towers = get_tree().get_nodes_in_group("towers")
	var closest_tower: Node2D = null
	var min_distance: float = 40.0
	
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
	
	# Visual punch animation on click
	if selected_tower.has_method("play_punch_animation"):
		selected_tower.play_punch_animation()
		
	if tower_menu:
		tower_menu.visible = true
		update_tower_menu()
	queue_redraw()

func deselect_tower():
	selected_tower = null
	if tower_menu:
		tower_menu.visible = false
	queue_redraw()

func update_tower_menu():
	if not is_instance_valid(selected_tower) or not tower_menu:
		deselect_tower()
		return
		
	if menu_title: menu_title.text = selected_tower.name
	update_tower_stats_text()
	
	if upgrade_dmg_btn:
		upgrade_dmg_btn.text = "⚡ Dmg Lvl %d (%d kWh)" % [selected_tower.damage_level, selected_tower.damage_upgrade_cost]
	if upgrade_spd_btn:
		upgrade_spd_btn.text = "💨 Spd Lvl %d (%d kWh)" % [selected_tower.speed_level, selected_tower.speed_upgrade_cost]
	if target_option:
		match selected_tower.target_mode:
			"FIRST": target_option.selected = 0
			"CLOSEST": target_option.selected = 1
			"LAST": target_option.selected = 2

func update_tower_stats_text():
	if not is_instance_valid(selected_tower):
		return
		
	if stats_label:
		var dps = selected_tower.get_dps() if selected_tower.has_method("get_dps") else (selected_tower.damage * selected_tower.fire_rate)
		var k = selected_tower.kills if "kills" in selected_tower else 0
		var td = selected_tower.total_damage_dealt if "total_damage_dealt" in selected_tower else 0.0
		
		stats_label.text = "Dmg: %.1f | Rate: %.1f/s\nDPS: %.1f | Range: %dpx\n🎯 Kills: %d\n💥 Total Dealt: %.0f" % [
			selected_tower.damage,
			selected_tower.fire_rate,
			dps,
			int(selected_tower.range_radius),
			k,
			td
		]

func _on_upgrade_damage_pressed():
	if not is_instance_valid(selected_tower): return
	
	if GameState.energy < selected_tower.damage_upgrade_cost:
		show_warning_toast("⚡ Need %d kWh for Damage Upgrade!" % selected_tower.damage_upgrade_cost)
		return
		
	if selected_tower.upgrade_damage():
		update_ui()
		update_tower_menu()
		queue_redraw()

func _on_upgrade_speed_pressed():
	if not is_instance_valid(selected_tower): return
	
	if GameState.energy < selected_tower.speed_upgrade_cost:
		show_warning_toast("⚡ Need %d kWh for Speed Upgrade!" % selected_tower.speed_upgrade_cost)
		return
		
	if selected_tower.upgrade_speed():
		update_ui()
		update_tower_menu()
		queue_redraw()

func _on_target_mode_selected(index: int):
	if is_instance_valid(selected_tower):
		match index:
			0: selected_tower.target_mode = "FIRST"
			1: selected_tower.target_mode = "CLOSEST"
			2: selected_tower.target_mode = "LAST"

# --- VISUAL SELECTION HIGHLIGHT ---
func _draw():
	if is_instance_valid(selected_tower):
		var tower_pos = to_local(selected_tower.global_position)
		var r = selected_tower.range_radius if "range_radius" in selected_tower else 140.0
		draw_circle(tower_pos, r, Color(0.2, 0.6, 1.0, 0.15))
		draw_arc(tower_pos, r, 0.0, TAU, 64, Color(0.2, 0.7, 1.0, 0.8), 2.0)
		draw_arc(tower_pos, 28.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.2, 0.95), 3.0)

# --- POPUP WARNING TOAST SYSTEM (Feature 3) ---
func show_warning_toast(message: String):
	var toast = $UI.get_node_or_null("ToastPopup")
	if not toast:
		# Automatically construct self-contained banner if node not in scene
		toast = Label.new()
		toast.name = "ToastPopup"
		toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		toast.custom_minimum_size = Vector2(360, 40)
		toast.position = Vector2(300, 65)
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.8, 0.2, 0.2, 0.9) # Vivid alert red
		sb.set_corner_radius_all(6)
		sb.border_width_bottom = 2
		sb.border_color = Color(1.0, 0.4, 0.4)
		toast.add_theme_stylebox_override("normal", sb)
		toast.add_theme_color_override("font_color", Color.WHITE)
		toast.add_theme_font_size_override("font_size", 14)
		$UI.add_child(toast)

	toast.text = message
	toast.modulate.a = 0.0
	toast.scale = Vector2(0.8, 0.8)
	toast.pivot_offset = toast.size / 2.0
	toast.visible = true

	var tween = create_tween()
	# Pop in
	tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(toast, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Hold for 1.5 seconds
	tween.tween_interval(1.5)
	# Fade out
	tween.tween_property(toast, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): toast.visible = false)

# --- DATABASE PERSISTENCE ---
func trigger_game_over():
	GameState.is_game_over = true
	Engine.time_scale = 1.0
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
