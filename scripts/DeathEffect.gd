extends Sprite2D

func setup(fx_texture: Texture2D, start_pos: Vector2, custom_scale: Vector2 = Vector2.ONE):
	texture = fx_texture
	global_position = start_pos
	scale = custom_scale

func _ready():
	# Juicy pop & fade-out animation using Godot Tween
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.3, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	
	# Delete node when fade finishes
	await tween.finished
	queue_free()
