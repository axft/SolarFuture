extends Control

# --- SCENE REFERENCES ---
@onready var background = find_child("Background")
@onready var leaderboard_request = find_child("LeaderboardRequest")

@onready var deploy_btn = find_child("DeployBtn")
@onready var leaderboard_btn = find_child("LeaderboardBtn")
@onready var encyclopedia_btn = find_child("EncyclopediaBtn")
@onready var sign_out_btn = find_child("SignOutBtn")

# Modals
@onready var leaderboard_modal = find_child("LeaderboardModal")
@onready var leaderboard_list = find_child("LeaderboardList")
@onready var close_leaderboard_btn = find_child("CloseLeaderboardBtn")

@onready var encyclopedia_modal = find_child("EncyclopediaModal")
@onready var info_text = find_child("InfoText")
@onready var close_encyclopedia_btn = find_child("CloseEncyclopediaBtn")

# Dynamic UI Elements
var welcome_lbl: Label
var stats_lbl: Label
var energy_lbl: Label
var bgm_menu = preload("res://assets/main_menu.mp3")

# Stage Carousel in Center
var stage_card: PanelContainer
var stage_title_lbl: Label
var stage_desc_lbl: Label
var stage_target_lbl: Label
var prev_stage_btn: Button
var next_stage_btn: Button

# Modal Layer
var modal_wrapper: Control
var dim_overlay: ColorRect
var modal_center: CenterContainer

func _ready():
	SoundManager.play_music(bgm_menu)
	# 1. Fallback for close buttons if named generically
	if not close_leaderboard_btn and leaderboard_modal:
		close_leaderboard_btn = leaderboard_modal.find_child("Button", true, false)
	if not close_encyclopedia_btn and encyclopedia_modal:
		close_encyclopedia_btn = encyclopedia_modal.find_child("Button", true, false)

	# 2. Build BTD6 Visuals
	build_btd6_layout()
	setup_modal_layer()
	update_stage_preview()

	# 3. Connect Navigation
	if deploy_btn: deploy_btn.pressed.connect(_on_deploy_pressed)
	if leaderboard_btn: leaderboard_btn.pressed.connect(_on_leaderboard_pressed)
	if encyclopedia_btn: encyclopedia_btn.pressed.connect(_on_encyclopedia_pressed)
	if sign_out_btn: sign_out_btn.pressed.connect(_on_sign_out_pressed)

	if close_leaderboard_btn: close_leaderboard_btn.pressed.connect(close_all_modals)
	if close_encyclopedia_btn: close_encyclopedia_btn.pressed.connect(close_all_modals)

	if leaderboard_request:
		leaderboard_request.request_completed.connect(_on_leaderboard_data_received)

	setup_encyclopedia_text()

# ==============================================================================
# 🎮 BTD6 VISUAL & ARCADE STYLING ENGINE
# ==============================================================================
func build_btd6_layout():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Rich Tropical/Sky Blue Backdrop
# 1. Background (Handles both Control and AnimatedSprite2D cleanly)
	if background:
		if background is Control:
			background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		elif background is AnimatedSprite2D:
			# Auto-center on the 960x600 viewport
			if background.centered:
				background.position = Vector2(480, 300)
			else:
				background.position = Vector2.ZERO
				
			# Auto-scale to fill 960x600 if texture is smaller
			if background.sprite_frames and background.sprite_frames.has_animation(background.animation):
				var tex = background.sprite_frames.get_frame_texture(background.animation, 0)
				if tex:
					var sz = tex.get_size()
					if sz.x > 0 and sz.y > 0:
						background.scale = Vector2(960.0 / sz.x, 600.0 / sz.y)
						
			# Play the animation loop
			background.play()

	var old_center = find_child("CenterContainer")
	if old_center: old_center.visible = false

	# --------------------------------------------------------------------------
	# 1. TOP-LEFT: OFFICER BADGE PILL
	# --------------------------------------------------------------------------
	var profile_pill = PanelContainer.new()
	profile_pill.position = Vector2(24, 18)
	profile_pill.custom_minimum_size = Vector2(290, 56)
	profile_pill.add_theme_stylebox_override("panel", make_btd_box(Color("#102231"), Color("#f39c12"), 14, 4, 8))
	add_child(profile_pill)

	var prof_hbox = HBoxContainer.new()
	prof_hbox.add_theme_constant_override("separation", 10)
	profile_pill.add_child(prof_hbox)

	var star_badge = Label.new()
	star_badge.text = "⭐"
	star_badge.add_theme_font_size_override("font_size", 24)
	prof_hbox.add_child(star_badge)

	var prof_vbox = VBoxContainer.new()
	prof_vbox.add_theme_constant_override("separation", 1)
	prof_hbox.add_child(prof_vbox)

	welcome_lbl = Label.new()
	welcome_lbl.text = "OFFICER: %s" % (GameState.current_username.to_upper() if GameState.current_username != "" else "OPERATIVE")
	welcome_lbl.add_theme_font_size_override("font_size", 14)
	add_arcade_font_outline(welcome_lbl, Color.WHITE, Color("#0b1721"), 3)
	prof_vbox.add_child(welcome_lbl)

	stats_lbl = Label.new()
	stats_lbl.text = "🏆 Best: %d pts  |  🌊 Max Wave %d" % [GameState.user_high_score, GameState.user_max_wave]
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color("#4cd137"))
	prof_vbox.add_child(stats_lbl)

	# --------------------------------------------------------------------------
	# 2. TOP-RIGHT: ENERGY BANK (CURRENCY PILL)
	# --------------------------------------------------------------------------
	var energy_pill = PanelContainer.new()
	energy_pill.position = Vector2(720, 18)
	energy_pill.custom_minimum_size = Vector2(216, 52)
	energy_pill.add_theme_stylebox_override("panel", make_btd_box(Color("#102231"), Color("#2ecc71"), 14, 4, 8))
	add_child(energy_pill)

	var energy_hbox = HBoxContainer.new()
	energy_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	energy_hbox.add_theme_constant_override("separation", 8)
	energy_pill.add_child(energy_hbox)

	var bolt = Label.new()
	bolt.text = "⚡"
	bolt.add_theme_font_size_override("font_size", 20)
	energy_hbox.add_child(bolt)

	energy_lbl = Label.new()
	energy_lbl.text = "%d kWh" % GameState.user_total_kwh
	energy_lbl.add_theme_font_size_override("font_size", 16)
	add_arcade_font_outline(energy_lbl, Color("#f1c40f"), Color("#5f3b00"), 3)
	energy_hbox.add_child(energy_lbl)

	# --------------------------------------------------------------------------
	# 3. CENTER: TITLE & STAGE CAROUSEL (Fills the empty space!)
	# --------------------------------------------------------------------------
	var center_box = VBoxContainer.new()
	center_box.position = Vector2(180, 95)
	center_box.custom_minimum_size = Vector2(600, 0)
	center_box.add_theme_constant_override("separation", 8)
	add_child(center_box)

	var title_lbl = Label.new()
	title_lbl.text = "SOLARFUTURE"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 44)
	add_arcade_font_outline(title_lbl, Color("#f1c40f"), Color("#7a4d00"), 6)
	center_box.add_child(title_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "CLEAN ENERGY DEFENSE INITIATIVE"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 13)
	add_arcade_font_outline(sub_lbl, Color("#74b9ff"), Color("#093154"), 3)
	center_box.add_child(sub_lbl)

	# Interactive Stage Select Showcase Box
	stage_card = PanelContainer.new()
	stage_card.custom_minimum_size = Vector2(500, 150)
	stage_card.add_theme_stylebox_override("panel", make_btd_box(Color("#102231"), Color("#3498db"), 16, 5, 14))
	center_box.add_child(stage_card)

	var stage_vbox = VBoxContainer.new()
	stage_vbox.add_theme_constant_override("separation", 6)
	stage_card.add_child(stage_vbox)

	var carousel_header = HBoxContainer.new()
	carousel_header.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_vbox.add_child(carousel_header)

	prev_stage_btn = Button.new()
	prev_stage_btn.text = "◀"
	style_btd_button(prev_stage_btn, "◀", Color("#2c3e50"), Color("#34495e"), Vector2(36, 32))
	prev_stage_btn.pressed.connect(func(): cycle_stage(-1))
	carousel_header.add_child(prev_stage_btn)

	stage_title_lbl = Label.new()
	stage_title_lbl.text = "STAGE 1: GREENFIELD VALLEY"
	stage_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_title_lbl.add_theme_font_size_override("font_size", 16)
	add_arcade_font_outline(stage_title_lbl, Color("#2ecc71"), Color("#0b3b1e"), 3)
	carousel_header.add_child(stage_title_lbl)

	next_stage_btn = Button.new()
	next_stage_btn.text = "▶"
	style_btd_button(next_stage_btn, "▶", Color("#2c3e50"), Color("#34495e"), Vector2(36, 32))
	next_stage_btn.pressed.connect(func(): cycle_stage(1))
	carousel_header.add_child(next_stage_btn)

	stage_desc_lbl = Label.new()
	stage_desc_lbl.text = "Baseline clean energy deployment. Moderate carbon plumes."
	stage_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_desc_lbl.add_theme_font_size_override("font_size", 12)
	stage_desc_lbl.add_theme_color_override("font_color", Color("#bdc3c7"))
	stage_vbox.add_child(stage_desc_lbl)

	stage_target_lbl = Label.new()
	stage_target_lbl.text = "🎯 Objective: Survive 5 Waves for Mission Victory"
	stage_target_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_target_lbl.add_theme_font_size_override("font_size", 12)
	stage_target_lbl.add_theme_color_override("font_color", Color("#f1c40f"))
	stage_vbox.add_child(stage_target_lbl)

	# --------------------------------------------------------------------------
	# 4. BOTTOM CHUNKY DOCK BAR
	# --------------------------------------------------------------------------
	var bottom_shelf = PanelContainer.new()
	bottom_shelf.position = Vector2(60, 495)
	bottom_shelf.custom_minimum_size = Vector2(840, 85)
	bottom_shelf.add_theme_stylebox_override("panel", make_btd_box(Color("#0b1721"), Color("#1f3a52"), 20, 6, 8))
	add_child(bottom_shelf)

	var dock_hbox = HBoxContainer.new()
	dock_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_hbox.add_theme_constant_override("separation", 16)
	bottom_shelf.add_child(dock_hbox)

	if encyclopedia_btn:
		encyclopedia_btn.reparent(dock_hbox)
		style_btd_button(encyclopedia_btn, "📖 KNOWLEDGE", Color("#0984e3"), Color("#00cec9"), Vector2(160, 56))

	if leaderboard_btn:
		leaderboard_btn.reparent(dock_hbox)
		style_btd_button(leaderboard_btn, "🏆 RANKINGS", Color("#e67e22"), Color("#f39c12"), Vector2(160, 56))

	# Prominent Giant PLAY Button (With breathing idle tween!)
	if deploy_btn:
		deploy_btn.reparent(dock_hbox)
		style_btd_button(deploy_btn, "▶  DEPLOY", Color("#27ae60"), Color("#2ecc71"), Vector2(210, 64), true)
		animate_breathing(deploy_btn)

	if sign_out_btn:
		sign_out_btn.reparent(dock_hbox)
		style_btd_button(sign_out_btn, "🚪 EXIT", Color("#636e72"), Color("#d63031"), Vector2(120, 56))

# ==============================================================================
# ✨ JUICE, OUTLINES, & HOVER TWEENS
# ==============================================================================
func add_arcade_font_outline(node: Control, text_col: Color, outline_col: Color, outline_sz: int):
	node.add_theme_color_override("font_color", text_col)
	node.add_theme_color_override("font_outline_color", outline_col)
	node.add_theme_constant_override("outline_size", outline_sz)
	if node is Label:
		node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		node.add_theme_constant_override("shadow_offset_y", 2)

func make_btd_box(bg_col: Color, border_col: Color, radius: int, bottom_bevel: int, pad: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.set_corner_radius_all(radius)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = bottom_bevel
	sb.border_color = border_col
	sb.content_margin_left = pad
	sb.content_margin_top = pad
	sb.content_margin_right = pad
	sb.content_margin_bottom = pad
	return sb

func style_btd_button(btn: Button, title: String, normal_color: Color, hover_color: Color, btn_size: Vector2, is_huge: bool = false):
	btn.text = title
	btn.custom_minimum_size = btn_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pivot_offset = btn_size / 2.0

	var font_size = 18 if is_huge else 13
	btn.add_theme_font_size_override("font_size", font_size)
	add_arcade_font_outline(btn, Color.WHITE, normal_color.darkened(0.5), 3)

	var normal_sb = make_btd_box(normal_color, normal_color.darkened(0.35), 14, 6 if is_huge else 5, 8)
	var hover_sb = make_btd_box(hover_color, hover_color.darkened(0.35), 14, 6 if is_huge else 5, 8)
	var pressed_sb = make_btd_box(normal_color.darkened(0.2), normal_color.darkened(0.4), 14, 2, 8)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	# Bouncing Hover Tweens!
	btn.mouse_entered.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	)

# Subtle BTD6-style breathing pulse on the Play button
func animate_breathing(node: Control):
	var tw = create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ==============================================================================
# STAGE CAROUSEL LOGIC
# ==============================================================================
func cycle_stage(dir: int):
	GameState.selected_stage_id += dir
	if GameState.selected_stage_id > 2: GameState.selected_stage_id = 1
	if GameState.selected_stage_id < 1: GameState.selected_stage_id = 2
	update_stage_preview()

func update_stage_preview():
	var cfg = GameState.STAGES[GameState.selected_stage_id]
	stage_title_lbl.text = "STAGE %d: %s" % [GameState.selected_stage_id, cfg.name.to_upper()]
	stage_desc_lbl.text = cfg.desc
	stage_target_lbl.text = "🎯 Objective: Survive Wave %d for Victory (+%d kWh Bonus)" % [cfg.target_wave, cfg.bonus_kwh]

# ==============================================================================
# MODALS & ACTIONS
# ==============================================================================
func setup_modal_layer():
	modal_wrapper = Control.new()
	modal_wrapper.name = "ModalWrapper"
	modal_wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_wrapper.z_index = 20
	modal_wrapper.visible = false
	add_child(modal_wrapper)

	dim_overlay = ColorRect.new()
	dim_overlay.color = Color(0, 0, 0, 0.75)
	dim_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_all_modals()
	)
	modal_wrapper.add_child(dim_overlay)

	modal_center = CenterContainer.new()
	modal_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_wrapper.add_child(modal_center)

	if leaderboard_modal:
		leaderboard_modal.reparent(modal_center)
		leaderboard_modal.custom_minimum_size = Vector2(540, 400)
		leaderboard_modal.add_theme_stylebox_override("panel", make_btd_box(Color("#102231"), Color("#f39c12"), 16, 6, 16))
		leaderboard_modal.visible = false

	if encyclopedia_modal:
		encyclopedia_modal.reparent(modal_center)
		encyclopedia_modal.custom_minimum_size = Vector2(600, 430)
		encyclopedia_modal.add_theme_stylebox_override("panel", make_btd_box(Color("#102231"), Color("#00cec9"), 16, 6, 16))
		encyclopedia_modal.visible = false

	if close_leaderboard_btn:
		style_btd_button(close_leaderboard_btn, "CLOSE", Color("#e74c3c"), Color("#ff7675"), Vector2(160, 40))
	if close_encyclopedia_btn:
		style_btd_button(close_encyclopedia_btn, "CLOSE", Color("#e74c3c"), Color("#ff7675"), Vector2(160, 40))

func _on_deploy_pressed():
	GameState.reset_run()
	SceneTransition.change_scene("res://scenes/MainGame.tscn", 0.5)

func _on_sign_out_pressed():
	GameState.logout()
	SceneTransition.change_scene("res://scenes/LoginScene.tscn", 0.4)

func _on_leaderboard_pressed():
	modal_wrapper.visible = true
	leaderboard_modal.visible = true
	encyclopedia_modal.visible = false

	# Ensure the ScrollContainer is tall enough to display rows
	var scroll = leaderboard_modal.find_child("ScrollContainer", true, false)
	if scroll:
		scroll.custom_minimum_size = Vector2(480, 240)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Clear previous entries
	if leaderboard_list:
		for child in leaderboard_list.get_children():
			child.queue_free()

		var loading = Label.new()
		loading.name = "Loading"
		loading.text = "Syncing with MySQL grid records..."
		loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loading.add_theme_font_size_override("font_size", 14)
		loading.add_theme_color_override("font_color", Color("#bdc3c7"))
		leaderboard_list.add_child(loading)

	# Fallback if LeaderboardRequest node wasn't in tree
	if not leaderboard_request:
		leaderboard_request = HTTPRequest.new()
		add_child(leaderboard_request)
		leaderboard_request.request_completed.connect(_on_leaderboard_data_received)

	print("Requesting leaderboard from backend...")
	leaderboard_request.request("http://localhost/solarfuture/api/get_leaderboard.php")

func _on_leaderboard_data_received(_result, response_code, _headers, body):
	var raw_text = body.get_string_from_utf8()
	print("Leaderboard HTTP %d: %s" % [response_code, raw_text])

	if not leaderboard_list: 
		return

	# Clear loading label
	var loading = leaderboard_list.get_node_or_null("Loading")
	if loading: 
		loading.queue_free()

	if response_code != 200:
		var err = Label.new()
		err.text = "⚠️ Connection error (HTTP %d). Is XAMPP Apache running?" % response_code
		err.add_theme_color_override("font_color", Color("#e74c3c"))
		leaderboard_list.add_child(err)
		return

	var res = JSON.parse_string(raw_text)
	if res and res.has("success") and res.success:
		var records = res.get("leaderboard", [])
		if records.is_empty():
			var empty = Label.new()
			empty.text = "No registered officers found in database."
			leaderboard_list.add_child(empty)
			return

		# 1. Add Table Header Row
		var header_row = HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 10)
		
		var h_rank = Label.new(); h_rank.custom_minimum_size.x = 45; h_rank.text = "RANK"
		var h_name = Label.new(); h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h_name.text = "OFFICER"
		var h_score = Label.new(); h_score.custom_minimum_size.x = 120; h_score.text = "SUSTAINABILITY"
		var h_wave = Label.new(); h_wave.custom_minimum_size.x = 90; h_wave.text = "MAX WAVE"
		
		for h in [h_rank, h_name, h_score, h_wave]:
			h.add_theme_font_size_override("font_size", 12)
			h.add_theme_color_override("font_color", Color("#7f8c8d"))
			header_row.add_child(h)
		leaderboard_list.add_child(header_row)

		# 2. Add Officer Rows
		for entry in records:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)

			# Rank badge
			var rank_lbl = Label.new()
			rank_lbl.custom_minimum_size.x = 45
			rank_lbl.text = "#%d" % entry.rank
			rank_lbl.add_theme_font_size_override("font_size", 13)
			rank_lbl.add_theme_color_override("font_color", Color("#f1c40f") if entry.rank <= 3 else Color("#bdc3c7"))

			# Officer Name
			var user_lbl = Label.new()
			user_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			user_lbl.text = entry.username
			user_lbl.add_theme_font_size_override("font_size", 13)
			if entry.username == GameState.current_username:
				user_lbl.text += " (You)"
				user_lbl.add_theme_color_override("font_color", Color("#2ecc71")) # Highlight current player green
			else:
				user_lbl.add_theme_color_override("font_color", Color.WHITE)

			# Sustainability Score
			var score_lbl = Label.new()
			score_lbl.custom_minimum_size.x = 120
			score_lbl.text = "🌱 %d pts" % entry.top_score
			score_lbl.add_theme_font_size_override("font_size", 13)
			score_lbl.add_theme_color_override("font_color", Color("#2ecc71"))

			# Wave Reached
			var wave_lbl = Label.new()
			wave_lbl.custom_minimum_size.x = 90
			wave_lbl.text = "🌊 Wave %d" % entry.max_wave
			wave_lbl.add_theme_font_size_override("font_size", 13)
			wave_lbl.add_theme_color_override("font_color", Color("#3498db"))

			row.add_child(rank_lbl)
			row.add_child(user_lbl)
			row.add_child(score_lbl)
			row.add_child(wave_lbl)

			leaderboard_list.add_child(row)

func _on_encyclopedia_pressed():
	modal_wrapper.visible = true
	encyclopedia_modal.visible = true
	leaderboard_modal.visible = false

func close_all_modals():
	modal_wrapper.visible = false
	if leaderboard_modal: leaderboard_modal.visible = false
	if encyclopedia_modal: encyclopedia_modal.visible = false

func setup_encyclopedia_text():
	if not info_text: return
	info_text.custom_minimum_size = Vector2(540, 260)
	info_text.scroll_active = true
	info_text.clear()
	info_text.append_text("[b][color=#f1c40f]⚡ SDG 7: Affordable and Clean Energy[/color][/b]\n")
	info_text.append_text("• [b]Photovoltaic Solar Arrays:[/b] Converts solar irradiance into clean electricity. High upfront capital (100 kWh), but produces clean, reliable output with zero operating carbon emissions.\n")
	info_text.append_text("• [b]Kinetic Wind Turbines:[/b] Converts atmospheric air currents into high-frequency kinetic intercept pulses. Highly effective at dispersing agile emissions.\n\n")
	info_text.append_text("[b][color=#e74c3c]🌍 SDG 13: Climate Action[/color][/b]\n")
	info_text.append_text("• [b]Carbon Plumes & Industrial Soot:[/b] Particulate emissions that degrade regional air quality and lower Eco-Health.\n")
	info_text.append_text("• [b]Methane Vents:[/b] Potent greenhouse gases with high warming potential requiring rapid clean energy interdiction.\n")
	info_text.append_text("• [b]Mission Directive:[/b] Defend the regional biosphere to maximize your Sustainability Score.")
