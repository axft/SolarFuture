extends CanvasLayer

var fade_rect: ColorRect

func _ready():
	# layer = 128 ensures the transition draws over every UI element and modal
	layer = 128
	
	# Pure-code black transition curtain
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0 # Start fully transparent
	add_child(fade_rect)

# Call this from any script to transition smoothly
func change_scene(target_scene_path: String, fade_duration: float = 0.4):
	# 1. Block clicks while transitioning so players can't spam buttons
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. Smooth fade out to black
	var tween_out = create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween_out.finished
	
	# 3. Small dramatic delay (0.15s) so the screen doesn't feel rushed
	await get_tree().create_timer(0.15).timeout
	
	# 4. Switch the scene behind the black curtain
	get_tree().change_scene_to_file(target_scene_path)
	
	# 5. Smooth fade back in from black
	var tween_in = create_tween()
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween_in.finished
	
	# 6. Re-enable mouse clicks
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
