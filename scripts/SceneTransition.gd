extends CanvasLayer

var fade_rect: ColorRect

func _ready():
	layer = 128
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0 # Start invisible
	add_child(fade_rect)

func change_scene(target_scene_path: String, fade_duration: float = 0.3):
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 1. Fade to black
	var tween_out = create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, fade_duration)
	await tween_out.finished
	
	# 2. Switch scene with error checking
	var err = get_tree().change_scene_to_file(target_scene_path)
	if err != OK:
		print("❌ [SceneTransition] Failed to open scene: ", target_scene_path, " Error code: ", err)
		fade_rect.modulate.a = 0.0 # Force remove black screen immediately!
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	# 3. Small pause then fade back in
	await get_tree().create_timer(0.1).timeout
	var tween_in = create_tween()
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, fade_duration)
	await tween_in.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
