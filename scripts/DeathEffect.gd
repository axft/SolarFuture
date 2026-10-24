extends Sprite2D

func setup(fx_texture: Texture2D, start_pos: Vector2):
	texture = fx_texture
	global_position = start_pos
	z_index = 25 # Ensure death FX renders above the road and grass

	var tex_size = fx_texture.get_size()
	
	# If width is greater than height, it's a horizontal sprite sheet strip!
	# Calculate frame count (e.g. 144x36 = 4 frames)
	var frame_count = max(1, int(round(tex_size.x / tex_size.y)))
	hframes = frame_count
	frame = 0

	# Step through the animation frames
	var tween = create_tween()
	for f in range(frame_count):
		tween.tween_callback(func(): frame = f)
		tween.tween_interval(0.07) # 70ms per frame

	# Fade out at the end
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	queue_free()
