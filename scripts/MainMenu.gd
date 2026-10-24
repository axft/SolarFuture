extends Control

# --- DYNAMIC SCENE DISCOVERY ---
@onready var background = find_child("Background")
@onready var leaderboard_request = find_child("LeaderboardRequest")

@onready var deploy_btn = find_child("DeployBtn")
@onready var leaderboard_btn = find_child("LeaderboardBtn")
@onready var encyclopedia_btn = find_child("EncyclopediaBtn")
@onready var sign_out_btn = find_child("SignOutBtn")

# Pre-existing Modals in Scene Tree
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

# Stage Carousel in Center
var stage_title_lbl: Label
var stage_desc_lbl: Label
var stage_target_lbl: Label

# Settings / Options Modal
var settings_modal: PanelContainer
var settings_btn: Button
var music_val_lbl: Label
var sfx_val_lbl: Label

# Modal Wrapper Layer (Guarantees Centering & Clickability)
var modal_wrapper: Control
var dim_overlay: ColorRect
var modal_center: CenterContainer

func _ready():
	# Fallback for close buttons if named generically as "Button"
	if not close_leaderboard_btn and leaderboard_modal:
		close_leaderboard_btn = leaderboard_modal.find_child("Button", true, false)
	if not close_encyclopedia_btn and encyclopedia_modal:
		close_encyclopedia_btn = encyclopedia_modal.find_child("Button", true, false)

	# 1. Build BTD6 Visual Interface & Carousel
	build_btd6_layout()

	# 2. Setup Dedicated Modal Popup Layer
	setup_modal_layer()
	update_stage_preview()

	# 3. Connect Buttons
	if deploy_btn: deploy_btn.pressed.connect(_on_deploy_pressed)
	if leaderboard_btn: leaderboard_btn.pressed.connect(_on_leaderboard_pressed)
	if encyclopedia_btn: encyclopedia_btn.pressed.connect(_on_encyclopedia_pressed)
	if sign_out_btn: sign_out_btn.pressed.connect(_on_sign_out_pressed)

	if close_leaderboard_btn: close_leaderboard_btn.pressed.connect(close_all_modals)
	if close_encyclopedia_btn: close_encyclopedia_btn.pressed.connect(close_all_modals)

	if leaderboard_request:
		leaderboard_request.request_completed.connect(_on_leaderboard_data_received)

	setup_encyclopedia_text()
	auto_play_menu_music()

# ==============================================================================
# 🎮 BTD6 LAYOUT WITH GAMELOGO & CAROUSEL
# ==============================================================================
func build_btd6_layout():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 1. Fallback ColorRect Background (Screen will NEVER be pure black)
	var fallback_bg = ColorRect.new()
	fallback_bg.color = Color("#183048")
	fallback_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback_bg.z_index = -10
	add_child(fallback_bg)

	# Handle Background if present in scene tree
	if background:
		if background is Control:
			background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		elif background is AnimatedSprite2D:
			background.position = Vector2(480, 300) if background.centered else Vector2.ZERO
			if background.sprite_frames and background.sprite_frames.get_animation_names().size() > 0:
				background.play()

	# Hide previous container to prevent layout conflicts
	var old_center = find_child("CenterContainer")
	if old_center:
		old_center.visible = false

	# --------------------------------------------------------------------------
	# A. TOP-LEFT: OFFICER BADGE PILL
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
	# B. TOP-RIGHT: ENERGY BANK (CURRENCY PILL)
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
	# C. CENTER: GAMELOGO LOADER & STAGE CAROUSEL
	# --------------------------------------------------------------------------
	var center_box = VBoxContainer.new()
	center_box.position = Vector2(180, 85)
	center_box.custom_minimum_size = Vector2(600, 0)
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 10)
	add_child(center_box)

	# Safe GameLogo Loader (Slices strip if animated, or displays static)
	var logo_paths = ["res://assets/GameLogo.png", "res://assets/gamelogo.png", "res://assets/logo.png"]
	var logo_tex: Texture2D = null

	for path in logo_paths:
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			var res = load(path)
			if res and res is Texture2D:
				logo_tex = res
				print("✅ Loaded GameLogo from: ", path)
				break

	if logo_tex:
		var total_size = logo_tex.get_size()
		# Change frame_count to match the number of frames in your logo strip (1 if static)
		var frame_count: int = 4
		var frame_w = max(1.0, total_size.x / frame_count)
		var frame_h = max(1.0, total_size.y)

		var sprite_frames = SpriteFrames.new()
		sprite_frames.add_animation("logo_loop")
		sprite_frames.set_animation_loop("logo_loop", true)
		sprite_frames.set_animation_speed("logo_loop", 8.0)

		for i in range(frame_count):
			var atlas = AtlasTexture.new()
			atlas.atlas = logo_tex
			atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
			sprite_frames.add_frame("logo_loop", atlas)

		var scale_mult = 2.0 if frame_w < 120 else 1.0
		var target_w = min(frame_w * scale_mult, 380.0)
		var target_h = frame_h * scale_mult

		var logo_holder = Control.new()
		logo_holder.custom_minimum_size = Vector2(target_w, target_h)
		logo_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		center_box.add_child(logo_holder)

		var anim_logo = AnimatedSprite2D.new()
		anim_logo.sprite_frames = sprite_frames
		anim_logo.animation = "logo_loop"
		anim_logo.scale = Vector2(scale_mult, scale_mult)
		anim_logo.position = Vector2(target_w / 2.0, target_h / 2.0)
		anim_logo.play("logo_loop")
		logo_holder.add_child(anim_logo)
	else:
		var title_lbl = Label.new()
		title_lbl.text = "SOLARFUTURE"
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", 42)
		add_arcade_font_outline(title_lbl, Color("#f1c40f"), Color("#7a4d00"), 6)
		center_box.add_child(title_lbl)

	# Stage Selection Carousel Box
	var stage_card = PanelContainer.new()
	stage_card.custom_minimum_size = Vector2(500, 140)
	stage_card.add_theme_stylebox_override("panel", make_btd_box(Color("#102231"), Color("#3498db"), 16, 5, 12))
	center_box.add_child(stage_card)

	var stage_vbox = VBoxContainer.new()
	stage_vbox.add_theme_constant_override("separation", 6)
	stage_card.add_child(stage_vbox)

	var carousel_header = HBoxContainer.new()
	carousel_header.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_vbox.add_child(carousel_header)

	var prev_btn = Button.new()
	style_btd_button(prev_btn, "◀", Color("#2c3e50"), Color("#34495e"), Vector2(36, 32))
	prev_btn.pressed.connect(func(): cycle_stage(-1))
	carousel_header.add_child(prev_btn)

	stage_title_lbl = Label.new()
	stage_title_lbl.text = "STAGE 1: GREENFIELD VALLEY"
	stage_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_title_lbl.add_theme_font_size_override("font_size", 16)
	add_arcade_font_outline(stage_title_lbl, Color("#2ecc71"), Color("#0b3b1e"), 3)
	carousel_header.add_child(stage_title_lbl)

	var next_btn = Button.new()
	style_btd_button(next_btn, "▶", Color("#2c3e50"), Color("#34495e"), Vector2(36, 32))
	next_btn.pressed.connect(func(): cycle_stage(1))
	carousel_header.add_child(next_btn)

	stage_desc_lbl = Label.new()
	stage_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_desc_lbl.add_theme_font_size_override("font_size", 12)
	stage_desc_lbl.add_theme_color_override("font_color", Color("#bdc3c7"))
	stage_vbox.add_child(stage_desc_lbl)

	stage_target_lbl = Label.new()
	stage_target_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_target_lbl.add_theme_font_size_override("font_size", 12)
	stage_target_lbl.add_theme_color_override("font_color", Color("#f1c40f"))
	stage_vbox.add_child(stage_target_lbl)

	# --------------------------------------------------------------------------
	# D. BOTTOM CHUNKY DOCK BAR (CUSTOM SPRITE BUTTONS)
	# --------------------------------------------------------------------------
	var bottom_shelf = PanelContainer.new()
	bottom_shelf.position = Vector2(40, 500)
	bottom_shelf.custom_minimum_size = Vector2(880, 80)
	bottom_shelf.add_theme_stylebox_override("panel", make_btd_box(Color("#0b1721"), Color("#1f3a52"), 18, 5, 8))
	add_child(bottom_shelf)

	var dock_hbox = HBoxContainer.new()
	dock_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_hbox.add_theme_constant_override("separation", 12)
	bottom_shelf.add_child(dock_hbox)

	if encyclopedia_btn:
		encyclopedia_btn.reparent(dock_hbox)
		apply_texture_button(encyclopedia_btn, "res://assets/button_knowledge.png", "📖 KNOWLEDGE", Color("#0984e3"), Color("#00cec9"), Vector2(150, 56))

	if leaderboard_btn:
		leaderboard_btn.reparent(dock_hbox)
		apply_texture_button(leaderboard_btn, "res://assets/button_rankings.png", "🏆 RANKINGS", Color("#e67e22"), Color("#f39c12"), Vector2(150, 56))

	# Big Central Play Button
	if deploy_btn:
		deploy_btn.reparent(dock_hbox)
		apply_texture_button(deploy_btn, "res://assets/button_play.png", "▶  PLAY", Color("#27ae60"), Color("#2ecc71"), Vector2(190, 64), true)

	# Audio Settings Button
	settings_btn = Button.new()
	dock_hbox.add_child(settings_btn)
	style_btd_button(settings_btn, "⚙️ AUDIO", Color("#4b6584"), Color("#778ca3"), Vector2(120, 56))
	settings_btn.pressed.connect(_on_settings_pressed)

	if sign_out_btn:
		sign_out_btn.reparent(dock_hbox)
		apply_texture_button(sign_out_btn, "res://assets/button_exit.png", "🚪 EXIT", Color("#636e72"), Color("#d63031"), Vector2(110, 56))

# ==============================================================================
# 🎯 MODALS: LEADERBOARD, COMPENDIUM & AUDIO SETTINGS
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

	build_settings_modal()

func build_settings_modal():
	settings_modal = PanelContainer.new()
	settings_modal.custom_minimum_size = Vector2(440, 310)
	settings_modal.add_theme_stylebox_override("panel", make_btd_box(Color("#102231"), Color("#3498db"), 16, 6, 16))
	settings_modal.visible = false
	modal_center.add_child(settings_modal)

	var set_vbox = VBoxContainer.new()
	set_vbox.add_theme_constant_override("separation", 12)
	settings_modal.add_child(set_vbox)

	var set_title = Label.new()
	set_title.text = "⚙️ AUDIO CONTROLS"
	set_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_title.add_theme_font_size_override("font_size", 18)
	add_arcade_font_outline(set_title, Color("#3498db"), Color("#0d2438"), 3)
	set_vbox.add_child(set_title)

	# Music Volume Slider
	var music_hbox = HBoxContainer.new()
	var m_lbl = Label.new(); m_lbl.text = "🎵 Music Volume:"; m_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_val_lbl = Label.new(); music_val_lbl.text = "%d%%" % int(SoundManager.music_volume * 100)
	music_hbox.add_child(m_lbl); music_hbox.add_child(music_val_lbl)
	set_vbox.add_child(music_hbox)

	var m_slider = HSlider.new()
	m_slider.min_value = 0.0; m_slider.max_value = 1.0; m_slider.step = 0.05
	m_slider.value = SoundManager.music_volume
	m_slider.value_changed.connect(func(v):
		SoundManager.set_music_volume(v)
		music_val_lbl.text = "%d%%" % int(v * 100)
	)
	set_vbox.add_child(m_slider)

	# SFX Volume Slider
	var sfx_hbox = HBoxContainer.new()
	var s_lbl = Label.new(); s_lbl.text = "💥 Sound Effects:"; s_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_val_lbl = Label.new(); sfx_val_lbl.text = "%d%%" % int(SoundManager.sfx_volume * 100)
	sfx_hbox.add_child(s_lbl); sfx_hbox.add_child(sfx_val_lbl)
	set_vbox.add_child(sfx_hbox)

	var s_slider = HSlider.new()
	s_slider.min_value = 0.0; s_slider.max_value = 1.0; s_slider.step = 0.05
	s_slider.value = SoundManager.sfx_volume
	s_slider.value_changed.connect(func(v):
		SoundManager.set_sfx_volume(v)
		sfx_val_lbl.text = "%d%%" % int(v * 100)
	)
	set_vbox.add_child(s_slider)

	var close_set = Button.new()
	style_btd_button(close_set, "SAVE & CLOSE", Color("#e74c3c"), Color("#ff7675"), Vector2(150, 38))
	close_set.pressed.connect(close_all_modals)
	set_vbox.add_child(close_set)

func _on_settings_pressed():
	modal_wrapper.visible = true
	settings_modal.visible = true
	leaderboard_modal.visible = false
	encyclopedia_modal.visible = false

# ==============================================================================
# 🎨 SPRITE BUTTON LOADER & HELPER STYLES
# ==============================================================================
func apply_texture_button(btn: Button, image_path: String, fallback_title: String, fallback_color: Color, fallback_hover: Color, default_size: Vector2, is_huge: bool = false):
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.visible = true

	if FileAccess.file_exists(image_path) or ResourceLoader.exists(image_path):
		var tex = load(image_path)
		btn.text = ""
		btn.icon = tex
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.flat = true

		var tex_sz = tex.get_size()
		var target_size = default_size
		if tex_sz.x > 0 and tex_sz.y > 0:
			var scale_factor = 2.0 if tex_sz.x < 90 else 1.0
			target_size = tex_sz * scale_factor
			
		btn.custom_minimum_size = target_size
		btn.pivot_offset = target_size / 2.0

		var empty_sb = StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_sb)
		btn.add_theme_stylebox_override("hover", empty_sb)
		btn.add_theme_stylebox_override("pressed", empty_sb)
		btn.add_theme_stylebox_override("focus", empty_sb)

		btn.mouse_entered.connect(func():
			var tw = create_tween().set_parallel(true)
			tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "modulate", Color(1.25, 1.25, 1.25), 0.1)
		)
		btn.mouse_exited.connect(func():
			var tw = create_tween().set_parallel(true)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
			tw.tween_property(btn, "modulate", Color.WHITE, 0.1)
		)

		if is_huge:
			animate_breathing(btn)
	else:
		style_btd_button(btn, fallback_title, fallback_color, fallback_hover, default_size, is_huge)

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

func animate_breathing(node: Control):
	var tw = create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ==============================================================================
# CAROUSEL & NAVIGATION
# ==============================================================================
func cycle_stage(dir: int):
	GameState.selected_stage_id += dir
	if GameState.selected_stage_id > 2: GameState.selected_stage_id = 1
	if GameState.selected_stage_id < 1: GameState.selected_stage_id = 3
	update_stage_preview()

func update_stage_preview():
	var cfg = GameState.STAGES[GameState.selected_stage_id]
	stage_title_lbl.text = "STAGE %d: %s" % [GameState.selected_stage_id, cfg.name.to_upper()]
	stage_desc_lbl.text = cfg.desc
	stage_target_lbl.text = "🎯 Objective: Survive Wave %d for Victory (+%d kWh Bonus)" % [cfg.target_wave, cfg.bonus_kwh]

func _on_deploy_pressed():
	SoundManager.fade_out_music(0.4)
	GameState.reset_run()
	SceneTransition.change_scene("res://scenes/MainGame.tscn", 0.5)

func _on_sign_out_pressed():
	SoundManager.fade_out_music(0.3)
	GameState.logout()
	SceneTransition.change_scene("res://scenes/LoginScene.tscn", 0.4)

func _on_leaderboard_pressed():
	modal_wrapper.visible = true
	leaderboard_modal.visible = true
	encyclopedia_modal.visible = false
	if settings_modal: settings_modal.visible = false

	if leaderboard_list:
		for child in leaderboard_list.get_children(): child.queue_free()
		var loading = Label.new()
		loading.name = "Loading"
		loading.text = "Syncing with MySQL grid records..."
		loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		leaderboard_list.add_child(loading)

	if leaderboard_request:
		leaderboard_request.request("http://localhost/solarfuture/api/get_leaderboard.php")

func _on_leaderboard_data_received(_result, response_code, _headers, body):
	if not leaderboard_list: return
	var loading = leaderboard_list.get_node_or_null("Loading")
	if loading: loading.queue_free()

	if response_code != 200:
		var err = Label.new(); err.text = "Failed to fetch leaderboard (HTTP %d)." % response_code
		leaderboard_list.add_child(err)
		return

	var res = JSON.parse_string(body.get_string_from_utf8())
	if res and res.has("success") and res.success:
		var records = res.get("leaderboard", [])
		if records.is_empty():
			var empty = Label.new(); empty.text = "No records found in database."
			leaderboard_list.add_child(empty)
			return

		for entry in records:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)

			var rank_lbl = Label.new(); rank_lbl.custom_minimum_size.x = 40; rank_lbl.text = "#%d" % entry.rank
			rank_lbl.add_theme_color_override("font_color", Color("#f1c40f"))

			var user_lbl = Label.new(); user_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; user_lbl.text = entry.username
			if entry.username == GameState.current_username:
				user_lbl.text += " (You)"
				user_lbl.add_theme_color_override("font_color", Color("#2ecc71"))

			var score_lbl = Label.new(); score_lbl.custom_minimum_size.x = 120; score_lbl.text = "🌱 %d pts" % entry.top_score
			var wave_lbl = Label.new(); wave_lbl.custom_minimum_size.x = 80; wave_lbl.text = "🌊 Wave %d" % entry.max_wave

			row.add_child(rank_lbl); row.add_child(user_lbl); row.add_child(score_lbl); row.add_child(wave_lbl)
			leaderboard_list.add_child(row)

func _on_encyclopedia_pressed():
	modal_wrapper.visible = true
	encyclopedia_modal.visible = true
	leaderboard_modal.visible = false
	if settings_modal: settings_modal.visible = false

func close_all_modals():
	modal_wrapper.visible = false
	if leaderboard_modal: leaderboard_modal.visible = false
	if encyclopedia_modal: encyclopedia_modal.visible = false
	if settings_modal: settings_modal.visible = false

func setup_encyclopedia_text():
	if not info_text: return
	info_text.custom_minimum_size = Vector2(540, 260)
	info_text.scroll_active = true
	info_text.clear()
	info_text.append_text("[b][color=#f1c40f]⚡ SDG 7: Affordable and Clean Energy[/color][/b]\n")
	info_text.append_text("• [b]Photovoltaic Solar Arrays:[/b] Converts direct solar irradiance into clean electricity using PV cells. High emission abatement with zero operational emissions.\n")
	info_text.append_text("• [b]Kinetic Wind Turbines:[/b] Converts atmospheric air currents into high-frequency kinetic intercept pulses.\n\n")
	info_text.append_text("[b][color=#e74c3c]🌍 SDG 13: Climate Action[/color][/b]\n")
	info_text.append_text("• [b]Carbon Plumes & Industrial Soot:[/b] Particulate emissions degrading regional biosphere integrity.\n")
	info_text.append_text("• [b]Methane Vents:[/b] Potent greenhouse gases requiring rapid clean energy interdiction.\n")
	info_text.append_text("• [b]Mission Directive:[/b] Defend the regional biosphere to maximize your Sustainability Score.")

func auto_play_menu_music():
	var possible_tracks = [
		"res://assets/menu_music.mp3",
		"res://assets/menu_theme.mp3",
		"res://assets/btd6_theme.mp3",
		"res://assets/music.mp3",
		"res://assets/menu_theme.ogg"
	]
	for track in possible_tracks:
		if FileAccess.file_exists(track) or ResourceLoader.exists(track):
			SoundManager.play_music_path(track)
			break
