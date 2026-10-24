extends Node2D

@onready var stage_container = $StageContainer
@onready var http_request = $ScoreSyncRequest

# --- HUD LABELS ---
@onready var energy_label = $UI/ColorRect/HBoxContainer/EnergyLabel
@onready var health_label = $UI/ColorRect/HBoxContainer/HealthLabel
@onready var wave_label = $UI/ColorRect/HBoxContainer/WaveLabel
@onready var score_label = $UI/ColorRect/HBoxContainer/ScoreLabel

# --- CONTROL BUTTONS ---
@onready var start_wave_btn = $UI/StartWaveBtn
@onready var pause_btn = get_node_or_null("UI/PauseBtn")
@onready var speed_btn = get_node_or_null("UI/SpeedBtn")

# Pre-existing individual build buttons in your scene
@onready var build_solar_btn = get_node_or_null("UI/BuildSolarBtn")
@onready var build_wind_btn = get_node_or_null("UI/BuildWindBtn")

# --- TOWER INSPECTOR UI ---
@onready var tower_menu = get_node_or_null("UI/TowerMenu")
@onready var menu_title = get_node_or_null("UI/TowerMenu/VBoxContainer/TitleLabel")
@onready var stats_label = get_node_or_null("UI/TowerMenu/VBoxContainer/StatsLabel")
@onready var target_option = get_node_or_null("UI/TowerMenu/VBoxContainer/TargetOptionBtn")
@onready var upgrade_dmg_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/UpgradeDmgBtn")
@onready var upgrade_spd_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/UpgradeSpdBtn")
@onready var close_menu_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/CloseBtn")

# Tower Scene Fallbacks
# --- TOWER SCENES REGISTRY ---
var tower_scenes: Dictionary = {
	"SOLAR": preload("res://scenes/TowerSolar.tscn"),
	"WIND": preload("res://scenes/TowerWind.tscn") if ResourceLoader.exists("res://scenes/TowerWind.tscn") else preload("res://scenes/TowerSolar.tscn"),
	"MYCELIUM": preload("res://scenes/TowerMycelium.tscn") if ResourceLoader.exists("res://scenes/TowerMycelium.tscn") else preload("res://scenes/TowerSolar.tscn"),
	"GEOTHERMAL": preload("res://scenes/TowerGeothermal.tscn") if ResourceLoader.exists("res://scenes/TowerGeothermal.tscn") else preload("res://scenes/TowerSolar.tscn"),
	"SUBSTATION": preload("res://scenes/TowerSubstation.tscn") if ResourceLoader.exists("res://scenes/TowerSubstation.tscn") else preload("res://scenes/TowerSolar.tscn"),
	"SPRINKLER": preload("res://scenes/TowerSprinkler.tscn") if ResourceLoader.exists("res://scenes/TowerSprinkler.tscn") else preload("res://scenes/TowerSolar.tscn"),
	"SAPLING": preload("res://scenes/TowerSapling.tscn") if ResourceLoader.exists("res://scenes/TowerSapling.tscn") else preload("res://scenes/TowerSolar.tscn"),
}

var enemy_scenes: Dictionary = {}
var current_path_2d: Path2D = null

var selected_tower: Node2D = null
var enemies_to_spawn: int = 6
var enemies_spawned: int = 0
var spawn_timer: float = 0.0
var game_speed: float = 1.0

var victory_modal: PanelContainer

func _ready():
	Engine.time_scale = 1.0

	# 1. Load active stage scene (Stage1.tscn)
	load_active_stage()

	# 2. Preload enemies
	load_enemy_scenes()

	# 3. CONNECT ALL BUILD BUTTONS (Both existing buttons and new tray)
	if build_solar_btn:
		build_solar_btn.pressed.connect(func(): on_tower_select_clicked("SOLAR"))
	if build_wind_btn:
		build_wind_btn.pressed.connect(func(): on_tower_select_clicked("WIND"))
		
	build_tower_selection_bar()

	# 4. Connect Core Buttons
	start_wave_btn.pressed.connect(_on_start_wave_pressed)
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
	print("🎮 MainGame initialized successfully.")

# --- LOAD ACTIVE STAGE SCENE ---
func load_active_stage():
	var stage_num = GameState.selected_stage_id
	var stage_path = "res://scenes/stages/Stage%d.tscn" % stage_num
	
	if not FileAccess.file_exists(stage_path):
		stage_path = "res://scenes/stages/Stage1.tscn"
		
	var stage_res = load(stage_path)
	var stage_inst = stage_res.instantiate()
	$StageContainer.add_child(stage_inst)
	
	current_path_2d = stage_inst.find_child("Path2D", true, false)
	if current_path_2d:
		print("✅ Found Path2D in ", stage_path)
	else:
		print("⚠️ Path2D not found inside ", stage_path)

func load_enemy_scenes():
	var paths = {
		"smog": "res://scenes/SmogEnemy.tscn",
		"methane": "res://scenes/EnemyMethane.tscn",
		"soot": "res://scenes/EnemySoot.tscn",
		"boss": "res://scenes/EnemyBoss.tscn",
		"styrofoam": "res://scenes/EnemyStyrofoam.tscn",
		"ewaste": "res://scenes/EnemyEWaste.tscn",
		"microplastics": "res://scenes/EnemyMicroplastics.tscn",
		"garbage": "res://scenes/EnemyGarbagePile.tscn"
	}
	var fallback = preload("res://scenes/SmogEnemy.tscn")
	for k in paths:
		if FileAccess.file_exists(paths[k]):
			enemy_scenes[k] = load(paths[k])
		else:
			enemy_scenes[k] = fallback

# --- TOWER SELECTION TRAY ---
func build_tower_selection_bar():
	# If player has old buttons in scene, keep them and add remaining towers
	var bar_scroll = ScrollContainer.new()
	bar_scroll.position = Vector2(160, 545)
	bar_scroll.custom_minimum_size = Vector2(550, 48)
	bar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	$UI.add_child(bar_scroll)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	bar_scroll.add_child(hbox)

	for type in GameState.TOWER_CATALOG:
		var cfg = GameState.TOWER_CATALOG[type]
		var btn = Button.new()
		btn.text = "%s (%d)" % [cfg.name.split(" ")[0], cfg.cost]
		btn.custom_minimum_size = Vector2(95, 36)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): on_tower_select_clicked(type))
		hbox.add_child(btn)

func on_tower_select_clicked(type: String):
	print("🔘 Clicked build button for: ", type)
	if GameState.is_paused:
		show_warning_toast("⚠️ Game paused! Unpause to build.")
		return
		
	var cost = GameState.TOWER_CATALOG[type].cost
	if GameState.energy < cost:
		show_warning_toast("⚡ Insufficient kWh! Need %d." % cost)
		return

	if GameState.selected_build_type == type:
		cancel_placement()
	else:
		GameState.selected_build_type = type
		print("🎯 Placement mode ACTIVE for: ", type)
		deselect_tower()

func cancel_placement():
	print("🚫 Placement canceled.")
	GameState.selected_build_type = ""

# --- INPUT HANDLING ---
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
		# Ignore click only if clicking directly on a button inside $UI
		if hovered != null and $UI.is_ancestor_of(hovered):
			return
			
		if GameState.is_paused: 
			return

		# PLACING TOWER
		if GameState.selected_build_type != "":
			print("🖱️ Left-click on map! Placing tower of type: ", GameState.selected_build_type)
			handle_tower_placement()
			return

		# INSPECTING TOWER
		check_tower_click(get_global_mouse_position())

# --- PLACEMENT WITH FORCED Z-INDEX ---
func handle_tower_placement():
	var cfg = GameState.TOWER_CATALOG.get(GameState.selected_build_type, null)
	if not cfg: 
		print("❌ Error: Invalid tower type: ", GameState.selected_build_type)
		return

	if GameState.energy >= cfg.cost:
		GameState.energy -= cfg.cost
		
		# 1. Grab the specific scene for this tower type
		var scene_to_spawn: PackedScene = tower_scenes.get(GameState.selected_build_type, tower_scenes["SOLAR"])
		var tower = scene_to_spawn.instantiate()
		
		# 2. Configure position and guarantee high Z-index so it renders in front of the map
		tower.z_index = 20
		tower.name = cfg.name
		tower.global_position = get_global_mouse_position()
		
		# 3. Add to the game world
		add_child(tower)
		
		# If the scene uses BaseTower script, initialize its properties
		if tower.has_method("setup_tower"):
			tower.setup_tower(GameState.selected_build_type)
			
		print("🏗️ SPAWNED %s at %s" % [cfg.name, tower.global_position])
		cancel_placement()
		update_ui()
	else:
		show_warning_toast("⚡ Need %d kWh for %s!" % [cfg.cost, cfg.name])

func check_tower_click(click_pos: Vector2):
	var towers = get_tree().get_nodes_in_group("towers")
	var closest: Node2D = null
	var min_d: float = 40.0
	for t in towers:
		var d = t.global_position.distance_to(click_pos)
		if d < min_d:
			min_d = d
			closest = t
	if closest: select_tower(closest)
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

# --- PROCESS & SPAWNING ---
func _process(delta: float):
	if GameState.is_paused or GameState.is_game_over: return

	if GameState.is_wave_active:
		spawn_timer += delta
		if spawn_timer >= 1.2 and enemies_spawned < enemies_to_spawn:
			spawn_enemy_for_stage()
			spawn_timer = 0.0
			enemies_spawned += 1

	if is_instance_valid(selected_tower) and tower_menu and tower_menu.visible:
		update_tower_stats_text()

func spawn_enemy_for_stage():
	if not current_path_2d: return

	var enemy_key = "smog"
	if GameState.selected_stage_id == 1:
		if GameState.wave == 5 and enemies_spawned == 0: enemy_key = "boss"
		elif GameState.wave >= 3: enemy_key = ["smog", "methane", "styrofoam"].pick_random()
		else: enemy_key = "smog"
	elif GameState.selected_stage_id == 2:
		if GameState.wave == 8 and enemies_spawned == 0: enemy_key = "garbage"
		elif GameState.wave >= 4: enemy_key = ["soot", "ewaste", "styrofoam"].pick_random()
		else: enemy_key = ["smog", "methane"].pick_random()
	elif GameState.selected_stage_id == 3:
		if GameState.wave == 10 and enemies_spawned == 0: enemy_key = "boss"
		elif GameState.wave >= 5: enemy_key = ["garbage", "microplastics", "ewaste"].pick_random()
		else: enemy_key = ["microplastics", "soot", "styrofoam"].pick_random()

	var enemy = enemy_scenes[enemy_key].instantiate()
	enemy.reached_end.connect(_on_enemy_reached_end)
	enemy.defeated.connect(_on_enemy_defeated)
	current_path_2d.add_child(enemy)

func _on_enemy_reached_end(dmg: int = 15):
	GameState.eco_health -= dmg
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

	var active = get_tree().get_nodes_in_group("enemies")
	if enemies_spawned >= enemies_to_spawn and active.size() == 0:
		GameState.is_wave_active = false

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

func trigger_stage_victory():
	var cfg = GameState.STAGES[GameState.selected_stage_id]
	GameState.energy += cfg.bonus_kwh
	GameState.clean_kwh_earned += cfg.bonus_kwh
	GameState.sustainability_score += 250
	sync_score_to_mysql()
	show_victory_modal()

func show_victory_modal():
	victory_modal = PanelContainer.new()
	victory_modal.custom_minimum_size = Vector2(460, 300)
	victory_modal.position = Vector2(250, 150)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#102231")
	sb.border_color = Color("#2ecc71")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	victory_modal.add_theme_stylebox_override("panel", sb)
	$UI.add_child(victory_modal)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	victory_modal.add_child(vb)

	var title = Label.new()
	title.text = "🏆 STAGE %d COMPLETED! 🏆" % GameState.selected_stage_id
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#2ecc71"))
	vb.add_child(title)

	var sub = Label.new()
	sub.text = "Regional biosphere secured! Telemetry logged to database."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	vb.add_child(sub)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	var hub_btn = Button.new()
	hub_btn.text = "🏠 Command Hub"
	hub_btn.custom_minimum_size = Vector2(150, 40)
	hub_btn.pressed.connect(func(): SceneTransition.change_scene("res://scenes/MainMenu.tscn", 0.4))
	btn_row.add_child(hub_btn)

	var end_btn = Button.new()
	end_btn.text = "🌊 Endless Mode"
	end_btn.custom_minimum_size = Vector2(150, 40)
	end_btn.pressed.connect(func():
		GameState.is_endless_mode = true
		victory_modal.queue_free()
		GameState.wave += 1
		enemies_spawned = 0
		enemies_to_spawn += 3
		start_wave_btn.disabled = false
		start_wave_btn.text = "▶️ Wave %d (Endless)" % GameState.wave
		update_ui()
	)
	btn_row.add_child(end_btn)

func _on_start_wave_pressed():
	if GameState.is_paused: return
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

func show_warning_toast(msg: String):
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
		toast.add_theme_stylebox_override("normal", sb)
		toast.add_theme_color_override("font_color", Color.WHITE)
		toast.add_theme_font_size_override("font_size", 14)
		$UI.add_child(toast)

	toast.text = msg
	toast.modulate.a = 0.0
	toast.visible = true
	var tw = create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.5)
	tw.tween_property(toast, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): toast.visible = false)

func sync_score_to_mysql():
	var url = "http://localhost/solarfuture/api/save_score.php"
	var headers = ["Content-Type: application/json"]
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
	var res = JSON.parse_string(body.get_string_from_utf8())
	if res and res.has("success") and res.success:
		if res.has("high_score"): GameState.user_high_score = res.high_score
		if res.has("max_wave"): GameState.user_max_wave = res.max_wave
		if res.has("total_clean_kwh"): GameState.user_total_kwh = res.total_clean_kwh

func update_ui():
	energy_label.text = "⚡ Energy: %d kWh   " % GameState.energy
	health_label.text = "🌍 Health: %d%%   " % GameState.eco_health
	wave_label.text = "🌊 Wave: %d   " % GameState.wave
	score_label.text = "🌱 Score: %d" % GameState.sustainability_score
