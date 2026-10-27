extends Node2D

# --- CORE NODE REFERENCES ---
@onready var stage_container = $StageContainer
@onready var http_request = $ScoreSyncRequest
@onready var ui_layer = $UI

# HUD Bar Elements
@onready var hud_bar = $UI/ColorRect
@onready var energy_label = $UI/ColorRect/HBoxContainer/EnergyLabel
@onready var health_label = $UI/ColorRect/HBoxContainer/HealthLabel
@onready var wave_label = $UI/ColorRect/HBoxContainer/WaveLabel
@onready var score_label = $UI/ColorRect/HBoxContainer/ScoreLabel

# Existing Buttons in Scene
@onready var start_wave_btn = $UI/StartWaveBtn
@onready var pause_btn = get_node_or_null("UI/PauseBtn")
@onready var speed_btn = get_node_or_null("UI/SpeedBtn")
@onready var build_solar_btn = get_node_or_null("UI/BuildSolarBtn")
@onready var build_wind_btn = get_node_or_null("UI/BuildWindBtn")

# Tower Inspector UI
@onready var tower_menu = get_node_or_null("UI/TowerMenu")
@onready var menu_title = get_node_or_null("UI/TowerMenu/VBoxContainer/TitleLabel")
@onready var stats_label = get_node_or_null("UI/TowerMenu/VBoxContainer/StatsLabel")
@onready var target_option = get_node_or_null("UI/TowerMenu/VBoxContainer/TargetOptionBtn")
@onready var upgrade_dmg_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/UpgradeDmgBtn")
@onready var upgrade_spd_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/UpgradeSpdBtn")
@onready var close_menu_btn = get_node_or_null("UI/TowerMenu/VBoxContainer/CloseBtn")

# Tower Scene Registry
var base_tower_scene: PackedScene = preload("res://scenes/BaseTower.tscn") if ResourceLoader.exists("res://scenes/BaseTower.tscn") else preload("res://scenes/TowerSolar.tscn")
var solar_tower_scene: PackedScene = preload("res://scenes/TowerSolar.tscn")
var wind_tower_scene: PackedScene = preload("res://scenes/TowerWind.tscn") if ResourceLoader.exists("res://scenes/TowerWind.tscn") else preload("res://scenes/TowerSolar.tscn")

var tower_scenes: Dictionary = {}
var enemy_scenes: Dictionary = {}
var current_path_2d: Path2D = null

# Runtime States
var selected_tower: Node2D = null
var enemies_to_spawn: int = 6
var enemies_spawned: int = 0
var spawn_timer: float = 0.0
var game_speed: float = 1.0

# UI Controls & Shelf Wrapper
var exit_btn: Button
var exit_modal: PanelContainer
var victory_modal: PanelContainer
var right_shelf_wrapper: PanelContainer
var animated_placement_buttons: Array[Dictionary] = []

func _ready():
	Engine.time_scale = 1.0

	# 1. Load active stage scene
	load_active_stage()

	# 2. Preload assets
	load_enemy_scenes()
	setup_tower_scenes()

	# 3. Build UI layouts
	setup_top_hud_layout()
	setup_right_tower_shelf()

	# 4. Connect Core Controls
	start_wave_btn.pressed.connect(_on_start_wave_pressed)

	if build_solar_btn: build_solar_btn.visible = false
	if build_wind_btn: build_wind_btn.visible = false

	# Tower Inspector Setup
	if tower_menu:
		tower_menu.visible = false
		tower_menu.position = Vector2(630, 260) # Positioned cleanly to the left of the right shelf
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

	# 5. Play Cinematic Slide-In Intro Animations!
	play_hud_intro_animations()

# ==============================================================================
# ✨ CINEMATIC SLIDE-IN INTRO ANIMATIONS
# ==============================================================================
func play_hud_intro_animations():
	# A. Top HUD Bar slides down from ceiling
	hud_bar.position.y = -50
	var tw_top = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_top.tween_property(hud_bar, "position:y", 0.0, 0.45)

	# B. Right-Side Tower Shelf slides in from the right edge
	if right_shelf_wrapper:
		right_shelf_wrapper.position.x = 980
		var tw_right = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_right.tween_property(right_shelf_wrapper, "position:x", 874.0, 0.55).set_delay(0.1)

	# C. Start Wave Button slides up from the floor
	start_wave_btn.position.y = 620
	var tw_bot = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_bot.tween_property(start_wave_btn, "position:y", 535.0, 0.5).set_delay(0.2)

# ==============================================================================
# 📐 UI LAYOUT: TOP HUD & VERTICAL RIGHT SHELF
# ==============================================================================
func setup_top_hud_layout():
	hud_bar.position = Vector2(0, 0)
	hud_bar.size = Vector2(960, 44)
	hud_bar.color = Color("#0e161c")

	var top_hbox = hud_bar.get_node_or_null("HBoxContainer")
	if top_hbox:
		top_hbox.position = Vector2(16, 6)
		top_hbox.size = Vector2(928, 32)
		top_hbox.add_theme_constant_override("separation", 16)

		# Spacer pushes action buttons to the far right
		var spacer = Control.new()
		spacer.name = "HUDSpacer"
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_hbox.add_child(spacer)

		# 1. Speed Button
		if not speed_btn:
			speed_btn = Button.new()
			speed_btn.name = "SpeedBtn"
		if speed_btn.get_parent(): speed_btn.reparent(top_hbox)
		else: top_hbox.add_child(speed_btn)
		style_hud_control_btn(speed_btn, "⏩ 1x", Color("#2c3e50"), Color("#34495e"), Vector2(75, 28))
		if not speed_btn.pressed.is_connected(_on_speed_pressed):
			speed_btn.pressed.connect(_on_speed_pressed)

		# 2. Pause Button
		if not pause_btn:
			pause_btn = Button.new()
			pause_btn.name = "PauseBtn"
		if pause_btn.get_parent(): pause_btn.reparent(top_hbox)
		else: top_hbox.add_child(pause_btn)
		style_hud_control_btn(pause_btn, "⏸️ Pause", Color("#2c3e50"), Color("#34495e"), Vector2(85, 28))
		if not pause_btn.pressed.is_connected(_on_pause_pressed):
			pause_btn.pressed.connect(_on_pause_pressed)

		# 3. Exit Button
		exit_btn = Button.new()
		exit_btn.name = "HUDExitBtn"
		top_hbox.add_child(exit_btn)
		style_hud_control_btn(exit_btn, "🚪 Exit", Color("#c0392b"), Color("#e74c3c"), Vector2(85, 28))
		exit_btn.pressed.connect(_on_exit_stage_clicked)

	build_exit_modal()

func setup_right_tower_shelf():
	# Position Start Wave Button cleanly on bottom-left
	start_wave_btn.position = Vector2(20, 535)
	start_wave_btn.custom_minimum_size = Vector2(145, 48)
	style_hud_control_btn(start_wave_btn, "▶️ Start Wave", Color("#27ae60"), Color("#2ecc71"), Vector2(145, 48))

	# 1. Dedicated Vertical Shelf Panel on the Right Side
	right_shelf_wrapper = PanelContainer.new()
	right_shelf_wrapper.name = "RightTowerShelf"
	right_shelf_wrapper.position = Vector2(874, 52)
	right_shelf_wrapper.custom_minimum_size = Vector2(76, 536)

	var shelf_sb = StyleBoxFlat.new()
	shelf_sb.bg_color = Color("#0b141aee")
	shelf_sb.border_color = Color("#1e2c38")
	shelf_sb.set_border_width_all(1)
	shelf_sb.set_corner_radius_all(10)
	shelf_sb.content_margin_top = 8
	shelf_sb.content_margin_bottom = 8
	shelf_sb.content_margin_left = 6
	shelf_sb.content_margin_right = 6
	right_shelf_wrapper.add_theme_stylebox_override("panel", shelf_sb)
	$UI.add_child(right_shelf_wrapper)

	# 2. Vertical Scroll Container (handles all 7 towers cleanly)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_shelf_wrapper.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	animated_placement_buttons.clear()

	for type in GameState.TOWER_CATALOG:
		var cfg = GameState.TOWER_CATALOG[type]

		# Outer Card Box to guarantee a uniform, clean square border
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(64, 64)
		var card_sb = StyleBoxFlat.new()
		card_sb.bg_color = Color("#14202b")
		card_sb.border_color = Color("#223342")
		card_sb.set_border_width_all(1)
		card_sb.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", card_sb)
		vbox.add_child(card)

		# The Interactive Button
		var btn = Button.new()
		btn.tooltip_text = "%s\nCost: %d kWh\nRange: %dpx | Dmg: %.0f" % [cfg.name, cfg.cost, int(cfg.range), cfg.damage]
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.custom_minimum_size = Vector2(64, 64)
		btn.pivot_offset = Vector2(32, 32)
		btn.flat = true

		var empty_sb = StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_sb)
		btn.add_theme_stylebox_override("hover", empty_sb)
		btn.add_theme_stylebox_override("pressed", empty_sb)
		btn.add_theme_stylebox_override("focus", empty_sb)
		card.add_child(btn)

		# Load the 640x128 sprite sheet
		var sprite_path = "res://assets/place_%s.png" % type.to_lower()
		var frames: Array[AtlasTexture] = []

		if FileAccess.file_exists(sprite_path) or ResourceLoader.exists(sprite_path):
			var sheet_tex = load(sprite_path)
			# Slices the 5 frames (128x128 each)
			for i in range(5):
				var atlas = AtlasTexture.new()
				atlas.atlas = sheet_tex
				atlas.region = Rect2(i * 128, 0, 128, 128)
				frames.append(atlas)

			btn.icon = frames[0]
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER

			var anim_data = {
				"btn": btn,
				"frames": frames,
				"frame": 0,
				"timer": 0.0,
				"fps": 8.0,
				"is_hovered": false
			}
			animated_placement_buttons.append(anim_data)

			btn.mouse_entered.connect(func():
				anim_data.is_hovered = true
				var tw = create_tween().set_parallel(true)
				tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(card_sb, "border_color", Color("#2ecc71"), 0.1) # Highlights green on hover!
			)
			btn.mouse_exited.connect(func():
				anim_data.is_hovered = false
				anim_data.frame = 0
				anim_data.timer = 0.0
				btn.icon = frames[0]
				var tw = create_tween().set_parallel(true)
				tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
				tw.tween_property(card_sb, "border_color", Color("#223342"), 0.1)
			)
		else:
			btn.text = "%s\n%d" % [cfg.name.split(" ")[0], cfg.cost]

		btn.pressed.connect(func(): on_tower_select_clicked(type))

func style_hud_control_btn(btn: Button, title: String, bg_col: Color, hover_col: Color, btn_sz: Vector2):
	btn.text = title
	btn.custom_minimum_size = btn_sz
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = bg_col
	sb_normal.border_color = bg_col.lightened(0.2)
	sb_normal.set_border_width_all(1)
	sb_normal.set_corner_radius_all(6)

	var sb_hover = StyleBoxFlat.new()
	sb_hover.bg_color = hover_col
	sb_hover.border_color = hover_col.lightened(0.3)
	sb_hover.set_border_width_all(1)
	sb_hover.set_corner_radius_all(6)

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 12)

# ==============================================================================
# 🗺️ STAGE & ENEMY LOADER
# ==============================================================================
func load_active_stage():
	var stage_num = GameState.selected_stage_id
	var stage_path = "res://scenes/stages/Stage%d.tscn" % stage_num

	if not FileAccess.file_exists(stage_path):
		stage_path = "res://scenes/stages/Stage1.tscn"

	var stage_res = load(stage_path)
	var stage_inst = stage_res.instantiate()
	$StageContainer.add_child(stage_inst)

	current_path_2d = stage_inst.find_child("Path2D", true, false)

func setup_tower_scenes():
	tower_scenes = {
		"SOLAR": solar_tower_scene,
		"WIND": wind_tower_scene,
		"MYCELIUM": load_scene_or_fallback("res://scenes/TowerMycelium.tscn", base_tower_scene),
		"GEOTHERMAL": load_scene_or_fallback("res://scenes/TowerGeothermal.tscn", base_tower_scene),
		"SUBSTATION": load_scene_or_fallback("res://scenes/TowerSubstation.tscn", base_tower_scene),
		"SPRINKLER": load_scene_or_fallback("res://scenes/TowerSprinkler.tscn", base_tower_scene),
		"SAPLING": load_scene_or_fallback("res://scenes/TowerSapling.tscn", base_tower_scene)
	}

func load_scene_or_fallback(path: String, fallback: PackedScene) -> PackedScene:
	return load(path) if FileAccess.file_exists(path) else fallback

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
		enemy_scenes[k] = load(paths[k]) if FileAccess.file_exists(paths[k]) else fallback

# ==============================================================================
# 🏗️ TOWER PLACEMENT & INSPECTOR
# ==============================================================================
func on_tower_select_clicked(type: String):
	if GameState.is_paused:
		show_warning_toast("⚠️ Game paused! Unpause to build.")
		return

	var cost = GameState.TOWER_CATALOG[type].cost
	if GameState.energy < cost:
		show_warning_toast("⚡ Need %d kWh for %s!" % [cost, GameState.TOWER_CATALOG[type].name])
		return

	if GameState.selected_build_type == type:
		cancel_placement()
	else:
		GameState.selected_build_type = type
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
		# Only ignore if clicking directly on a button/HUD inside $UI
		if hovered != null and $UI.is_ancestor_of(hovered):
			return

		if GameState.is_paused: return

		if GameState.selected_build_type != "":
			handle_tower_placement()
			return

		check_tower_click(get_global_mouse_position())

func handle_tower_placement():
	var cfg = GameState.TOWER_CATALOG.get(GameState.selected_build_type, null)
	if not cfg: return

	if GameState.energy >= cfg.cost:
		GameState.energy -= cfg.cost

		var type_capitalized = GameState.selected_build_type.capitalize().replace(" ", "")
		var specific_path = "res://scenes/Tower%s.tscn" % type_capitalized

		var tower_to_spawn: PackedScene = null
		if FileAccess.file_exists(specific_path):
			tower_to_spawn = load(specific_path)
		elif FileAccess.file_exists("res://scenes/BaseTower.tscn"):
			tower_to_spawn = load("res://scenes/BaseTower.tscn")
		else:
			tower_to_spawn = load("res://scenes/TowerSolar.tscn")

		var tower = tower_to_spawn.instantiate()
		tower.name = cfg.name
		tower.z_index = 20
		tower.global_position = get_global_mouse_position()

		for child in tower.get_children():
			if child is CanvasItem:
				child.z_as_relative = true
				if child.z_index < 0: child.z_index = 0
				child.visible = true

		add_child(tower)

		if tower.has_method("setup_tower"):
			tower.setup_tower(GameState.selected_build_type)

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
	if selected_tower.has_method("play_punch_animation"):
		selected_tower.play_punch_animation()
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

# ==============================================================================
# 🌊 SPAWNING & ANIMATED HOVER PROCESSING
# ==============================================================================
func _process(delta: float):
	# 1. Animate hovered tower buttons in the vertical right shelf
	for item in animated_placement_buttons:
		if item.is_hovered:
			item.timer += delta
			if item.timer >= (1.0 / item.fps):
				item.timer = 0.0
				item.frame = (item.frame + 1) % item.frames.size()
				item.btn.icon = item.frames[item.frame]

	if GameState.is_paused or GameState.is_game_over: return

	if GameState.is_wave_active:
		spawn_timer += delta

		var stage_cfg = GameState.STAGES.get(GameState.selected_stage_id, GameState.STAGES[1])
		var current_delay = stage_cfg.get("spawn_delay", 1.2)

		if spawn_timer >= current_delay and enemies_spawned < enemies_to_spawn:
			spawn_enemy_for_stage()
			spawn_timer = 0.0
			enemies_spawned += 1

	if is_instance_valid(selected_tower) and tower_menu and tower_menu.visible:
		update_tower_stats_text()

func spawn_enemy_for_stage():
	if not current_path_2d: return

	var stage_id = GameState.selected_stage_id
	var w = GameState.wave
	var enemy_key = "smog"

	if stage_id == 1:
		if w == 5: enemy_key = "boss" if enemies_spawned == 0 else ["smog", "methane"].pick_random()
		elif w == 4: enemy_key = ["soot", "methane", "styrofoam"].pick_random()
		elif w == 3: enemy_key = ["methane", "styrofoam", "smog"].pick_random()
		elif w == 2: enemy_key = "styrofoam" if randf() < 0.5 else "smog"
		else: enemy_key = "smog"
	elif stage_id == 2:
		if w == 8: enemy_key = "boss" if enemies_spawned == 0 else ["ewaste", "soot"].pick_random()
		elif w >= 6: enemy_key = ["ewaste", "soot", "methane"].pick_random()
		elif w >= 4: enemy_key = ["ewaste", "styrofoam", "soot"].pick_random()
		else: enemy_key = ["soot", "styrofoam", "methane"].pick_random()
	elif stage_id == 3:
		if w == 10: enemy_key = "garbage" if enemies_spawned == 0 else ["microplastics", "ewaste", "soot"].pick_random()
		elif w == 5: enemy_key = "boss" if enemies_spawned == 0 else ["microplastics", "methane"].pick_random()
		elif w >= 6: enemy_key = ["garbage", "microplastics", "ewaste"].pick_random()
		elif w >= 3: enemy_key = ["microplastics", "ewaste", "styrofoam"].pick_random()
		else: enemy_key = ["microplastics", "styrofoam", "methane"].pick_random()

	var enemy = enemy_scenes[enemy_key].instantiate()

	var cfg = GameState.STAGES.get(stage_id, GameState.STAGES[1])
	var hp_mult = cfg.get("hp_mult", 1.0)
	var speed_mult = cfg.get("speed_mult", 1.0)

	enemy.max_hp *= hp_mult
	enemy.current_hp = enemy.max_hp
	enemy.speed *= speed_mult

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

# ==============================================================================
# 🏆 VICTORY & SAFE EXIT SYSTEM
# ==============================================================================
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
	sub.text = "Regional biosphere secured! Telemetry logged to MySQL."
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

func build_exit_modal():
	exit_modal = PanelContainer.new()
	exit_modal.name = "ExitConfirmModal"
	exit_modal.custom_minimum_size = Vector2(400, 190)
	exit_modal.position = Vector2(280, 200)
	exit_modal.z_index = 60
	exit_modal.visible = false

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#102231")
	sb.border_color = Color("#e74c3c")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	exit_modal.add_theme_stylebox_override("panel", sb)
	$UI.add_child(exit_modal)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	exit_modal.add_child(vb)

	var title = Label.new()
	title.text = "⚠️ RETREAT FROM OPERATION?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#e74c3c"))
	vb.add_child(title)

	var desc = Label.new()
	desc.text = "Progress will be concluded. Current score & clean energy telemetry will be saved to MySQL."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color("#bdc3c7"))
	vb.add_child(desc)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vb.add_child(btn_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm & Exit"
	confirm_btn.custom_minimum_size = Vector2(130, 36)
	confirm_btn.pressed.connect(confirm_safe_exit)
	btn_row.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Resume"
	cancel_btn.custom_minimum_size = Vector2(130, 36)
	cancel_btn.pressed.connect(cancel_safe_exit)
	btn_row.add_child(cancel_btn)

func _on_exit_stage_clicked():
	GameState.is_paused = true
	Engine.time_scale = 1.0
	exit_modal.visible = true

func cancel_safe_exit():
	exit_modal.visible = false
	GameState.is_paused = false
	Engine.time_scale = game_speed

func confirm_safe_exit():
	if GameState.sustainability_score > 0 or GameState.clean_kwh_earned > 0:
		sync_score_to_mysql()
	Engine.time_scale = 1.0
	if has_node("/root/SoundManager"):
		SoundManager.stop_music()
	SceneTransition.change_scene("res://scenes/MainMenu.tscn", 0.4)

# ==============================================================================
# ⚙️ CONTROL BUTTON CALLBACKS
# ==============================================================================
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
