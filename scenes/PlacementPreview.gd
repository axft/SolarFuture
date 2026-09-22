extends Node2D

@export var range_radius: float = 160.0

var fill_color: Color = Color(0.0, 0.85, 1.0, 0.3)
var border_color: Color = Color(0.0, 1.0, 1.0, 0.95)
var footprint_fill: Color = Color(1.0, 0.85, 0.0, 0.7)
var footprint_border: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready():
	visible = false
	z_index = 50 # High Z-Index guarantees it draws over grass and road

func _process(_delta: float):
	if GameState.selected_build_type == "SOLAR":
		if not visible:
			visible = true
			print("Placement preview activated at mouse position!")
		
		global_position = get_global_mouse_position()
		queue_redraw()
	else:
		if visible:
			visible = false

func _draw():
	# Draw cyan range ring (160px radius)
	draw_circle(Vector2.ZERO, range_radius, fill_color)
	draw_arc(Vector2.ZERO, range_radius, 0.0, TAU, 64, border_color, 3.0)
	
	# Draw golden footprint circle (24px radius)
	draw_circle(Vector2.ZERO, 24.0, footprint_fill)
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, footprint_border, 2.0)
