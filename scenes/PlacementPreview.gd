extends Node2D

var current_radius: float = 160.0
var fill_color: Color
var border_color: Color
var footprint_fill: Color

func _ready():
	visible = false
	z_index = 50

func _process(_delta: float):
	if GameState.is_paused or GameState.is_game_over:
		visible = false
		return

	if GameState.selected_build_type == "SOLAR":
		visible = true
		current_radius = 160.0
		fill_color = Color(0.0, 0.85, 1.0, 0.25)
		border_color = Color(0.0, 1.0, 1.0, 0.95)
		footprint_fill = Color(1.0, 0.85, 0.0, 0.7)
		global_position = get_global_mouse_position()
		queue_redraw()
	elif GameState.selected_build_type == "WIND":
		visible = true
		current_radius = 110.0
		fill_color = Color(0.2, 0.9, 0.7, 0.25)
		border_color = Color(0.3, 1.0, 0.8, 0.95)
		footprint_fill = Color(0.0, 0.8, 0.8, 0.7)
		global_position = get_global_mouse_position()
		queue_redraw()
	else:
		visible = false

func _draw():
	if not visible:
		return
	draw_circle(Vector2.ZERO, current_radius, fill_color)
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 64, border_color, 3.0)
	draw_circle(Vector2.ZERO, 22.0, footprint_fill)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color.WHITE, 2.0)
