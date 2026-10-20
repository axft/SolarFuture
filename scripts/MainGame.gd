extends Node2D

@onready var path_2d = $Path2D
@onready var http_request = $ScoreSyncRequest
@onready var map_bg = get_node_or_null("MapBackground")

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
@onready var speed_btn = get_node_or_null("UI/SpeedBtn")

# --- TOWER INSPECTOR UI ---
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

# --- RUNTIME STATE ---
var selected_tower: Node2D = null
var enemies_to_spawn: int = 6
var enemies_spawned: int = 0
var spawn_timer: float = 0.0
var game_speed: float = 1.0

# Victory Popup Modal
var victory_modal: PanelContainer

func _ready():
	Engine.time_scale = 1.0
	
	# Load Selected Stage Settings
	var stage_cfg = GameState.STAGES.get(GameState.selected_stage_id, GameState.STAGES[1])
	if map_bg and "color" in map_bg:
		map_bg.color = stage_cfg.bg_color

	start_wave_btn.pressed.connect(_on_start_wave_pressed)
	build_solar_btn.pressed.connect(_on_build_solar_pressed)
	
	if build_wind_btn: build_wind_btn.pressed.connect(_on_build_wind_pressed)
	if pause_btn: pause_btn.pressed.connect(_on_pause_pressed)
	if speed_btn: speed_btn.pressed.connect(_on_speed_pressed)
		
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

	if is_instance_valid(selected_tower) and tower_menu and tower_menu.visible:
		update_tower_stats_text()

# --- ENEMY SPAWNING ---
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
	if GameState.is_game_over: return
		
	var active_enemies = get_tree().get_nodes_in_group("enemies")
	if enemies_spawned >= enemies_to_spawn and active_enemies.size() == 0:
		GameState.is_wave_active = false
		
		# Check Stage Victory Objective
		var target_wave = GameState.STAGES[GameState.selected_stage_id].target_wave
		if GameState.wave >= target_wave and not GameState.is_endless_mode:
			trigger_stage_victory()
			return

		GameState.wave += 1
		GameState.energy += 100
		enemies_spawned = 0
		enemies_to_spawn += 3
		start_wave_btn.disabled = false
		start_wave_btn.text = "▶️ Start Wave %d" % GameState.wave
		update_ui()

# --- STAGE VICTORY & SCORE TRACKING CONFIRMATION ---
func trigger_stage_victory():
	var cfg = GameState.STAGES[GameState.selected_stage_id]
	GameState.energy += cfg.bonus_kwh
	GameState.clean_kwh_earned += cfg.bonus_kwh
	GameState.sustainability_score += 200
	
	# Save Score to MySQL Immediately!
	sync_score_to_mysql()
	
	show_victory_modal()

func show_victory_modal():
	victory_modal = PanelContainer.new()
	victory_modal.custom_minimum_size = Vector2(480, 320)
	victory_modal.position = Vector2(240, 140)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#102231")
	sb.border_color = Color("#2ecc71")
	sb.set_corner_radius_all(14)
	sb.border_width_bottom = 6
	sb.set_border_width_all(2)
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	victory_modal.add_theme_stylebox_override("panel", sb)
	$UI.add_child(victory_modal)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	victory_modal.add_child(vbox)

	var title = Label.new()
	title.text = "🏆 MISSION ACCOMPLISHED! 🏆"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#2ecc71"))
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "Regional Biosphere Protected!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color("#bdc3c7"))
	vbox.add_child(sub)

	var stats_box = Label.new()
	stats_box.text = "Score: %d pts  |  Clean Energy: %d kWh\nCO₂ Mitigated: %d kg  |  Smog Clouds Filtered: %d" % [
		GameState.sustainability_score, GameState.clean_kwh_earned,
		GameState.co2_mitigated_kg, GameState.enemies_defeated
	]
	stats_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_box.add_theme_font_size_override("font_size", 13)
	stats_box.add_theme_color_override("font_color", Color("#f1c40f"))
	vbox.add_child(stats_box)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_hbox)

	var return_btn = Button.new()
	return_btn.text = "🏠 Command Hub"
	return_btn.custom_minimum_size = Vector2(170, 42)
	return_btn.pressed.connect(func():
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	btn_hbox.add_child(return_btn)

	var endless_btn = Button.new()
	endless_btn.text = "🌊 Endless Mode"
	endless_btn.custom_minimum_size = Vector2(170, 42)
	endless_btn.pressed.connect(func():
		GameState.is_endless_mode = true
		victory_modal.queue_free()
		GameState.wave += 1
		enemies_spawned = 0
		enemies_to_spawn += 3
		start_wave_btn.disabled = false
		start_wave_btn.text = "▶️ Wave %d (Endless)" % GameState.wave
		update_ui()
	)
	btn_hbox.add_child(endless_btn)

# --- CONTROLS ---
func _on_start_wave_pressed():
	if GameState.is_paused:
		show_warning_toast("⚠️ Operation paused! Unpause to start wave.")
		return
	if not GameState.is_wave_active:
		GameState.is_wave_active = true
		start_wave_btn.disabled = true

func _on_pause_pressed():
	if GameState.is_game_over: return
	GameState.is_paused = !GameState.is_paused
	if pause_btn: pause_btn.text = "▶️ Resume" if GameState.is_paused else "⏸️ Pause"
	if GameState.is_paused:
		cancel_placement()
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = game_speed

func _on_speed_pressed():
	if GameState.is_paused: return
	game_speed = 2.0 if game_speed == 1.0 else 1.0
	if speed_btn: speed_btn.text = "⏩ 2x" if game_speed == 2.0 else "▶️ 1x"
	Engine.time_scale = game_speed

func _on_build_solar_pressed():
	if GameState.is_paused: return
	if GameState.energy < 100:
		show_warning_toast("⚡ Insufficient kWh for Solar Array!")
		return
	GameState.selected_build_type = "" if GameState.selected_build_type == "SOLAR" else "SOLAR"
	deselect_tower()

func _on_build_wind_pressed():
	if GameState.is_paused: return
	if GameState.energy < 150:
		show_warning_toast("⚡ Insufficient kWh for Wind Turbine!")
		return
	GameState.selected_build_type = "" if GameState.selected_build_type == "WIND" else "WIND"
	deselect_tower()

func cancel_placement():
	GameState.selected_build_type = ""

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if GameState.selected_build_type != "": cancel_placement()
		else: deselect_tower()
		return
			
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if GameState.selected_build_type != "": cancel_placement()
		else: deselect_tower()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hovered = get_viewport().gui_get_hovered_control()
		if hovered != null and $UI.is_ancestor_of(hovered): return
		if GameState.is_paused: return

		if GameState.selected_build_type != "":
			handle_tower_placement()
			return

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

func check_tower_click(click_pos: Vector2):
	var towers = get_tree().get_nodes_in_group("towers")
	var closest_tower: Node2D = null
	var min_distance: float = 40.0
	for tower in towers:
		var dist = tower.global_position.distance_to(click_pos)
		if dist < min_distance:
			min_distance = dist
			closest_tower = tower
	if closest_tower != null: select_tower(closest_tower)
	else: deselect_tower()

func select_tower(tower: Node2D):
	selected_tower = tower
	if selected_tower.has_method("play_punch_animation"): selected_tower.play_punch_animation()
	if tower_menu:
		tower_menu.visible = true
		update_tower_menu()
	queue_redraw()

func deselect_tower():
	selected_tower = null
	if tower_menu: tower_menu.visible = false
	queue_redraw()

func update_tower_menu():
	if not is_instance_valid(selected_tower) or not tower_menu:
		deselect_tower()
		return
	if menu_title: menu_title.text = selected_tower.name
	update_tower_stats_text()
	if upgrade_dmg_btn: upgrade_dmg_btn.text = "⚡ Dmg Lvl %d (%d kWh)" % [selected_tower.damage_level, selected_tower.damage_upgrade_cost]
	if upgrade_spd_btn: upgrade_spd_btn.text = "💨 Spd Lvl %d (%d kWh)" % [selected_tower.speed_level, selected_tower.speed_upgrade_cost]
	if target_option:
		match selected_tower.target_mode:
			"FIRST": target_option.selected = 0
			"CLOSEST": target_option.selected = 1
			"LAST": target_option.selected = 2

func update_tower_stats_text():
	if not is_instance_valid(selected_tower) or not stats_label: return
	var dps = selected_tower.get_dps() if selected_tower.has_method("get_dps") else (selected_tower.damage * selected_tower.fire_rate)
	stats_label.text = "Dmg: %.1f | Rate: %.1f/s\nDPS: %.1f | Range: %dpx\n🎯 Kills: %d | 💥 Total: %.0f" % [
		selected_tower.damage, selected_tower.fire_rate, dps,
		int(selected_tower.range_radius), selected_tower.kills if "kills" in selected_tower else 0,
		selected_tower.total_damage_dealt if "total_damage_dealt" in selected_tower else 0.0
	]

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

func _draw():
	if is_instance_valid(selected_tower):
		var tower_pos = to_local(selected_tower.global_position)
		var r = selected_tower.range_radius if "range_radius" in selected_tower else 140.0
		draw_circle(tower_pos, r, Color(0.2, 0.6, 1.0, 0.15))
		draw_arc(tower_pos, r, 0.0, TAU, 64, Color(0.2, 0.7, 1.0, 0.8), 2.0)
		draw_arc(tower_pos, 28.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.2, 0.95), 3.0)

func show_warning_toast(message: String):
	var toast = $UI.get_node_or_null("ToastPopup")
	if not toast:
		toast = Label.new()
		toast.name = "ToastPopup"
		toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		toast.custom_minimum_size = Vector2(360, 40)
		toast.position = Vector2(300, 65)
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.8, 0.2, 0.2, 0.9)
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
	tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(toast, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.5)
	tween.tween_property(toast, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): toast.visible = false)

# --- DATABASE PERSISTENCE ---
func sync_score_to_mysql():
	var url = "http://localhost/solarfuture/api/save_score.php"
	var headers = ["Content-Type: application/json"]
	
	# Send user_id so PHP knows which account to credit (falls back to 1 for quick F6 testing)
	var active_user_id = GameState.current_user_id if GameState.current_user_id > 0 else 1
	
	var body = JSON.stringify({
		"user_id": active_user_id,
		"wave": GameState.wave,
		"score": GameState.sustainability_score,
		"cleanKwh": GameState.clean_kwh_earned
	})
	
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

func trigger_game_over():
	GameState.is_game_over = true
	Engine.time_scale = 1.0
	sync_score_to_mysql()

func _on_score_synced(_result, _code, _headers, body):
	var raw_text = body.get_string_from_utf8()
	print("MySQL Response: ", raw_text)
	
	var res = JSON.parse_string(raw_text)
	if res and res.has("success") and res.success:
		# Update lifetime stats in GameState so MainMenu updates instantly!
		if res.has("high_score"):
			GameState.user_high_score = res.high_score
		if res.has("max_wave"):
			GameState.user_max_wave = res.max_wave
		if res.has("total_clean_kwh"):
			GameState.user_total_kwh = res.total_clean_kwh
			
		print("✅ Lifetime records updated! New Total kWh: ", GameState.user_total_kwh)
		
		if GameState.is_game_over:
			start_wave_btn.text = "MISSION OVER - Saved to MySQL"

func update_ui():
	energy_label.text = "⚡ Energy: %d kWh   " % GameState.energy
	health_label.text = "🌍 Health: %d%%   " % GameState.eco_health
	wave_label.text = "🌊 Wave: %d   " % GameState.wave
	score_label.text = "🌱 Score: %d" % GameState.sustainability_score
