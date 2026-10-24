extends Node2D

var current_radius: float = 160.0
var preview_color: Color = Color.CYAN

func _ready():
	visible = false
	z_index = 50

func _process(_delta: float):
	if GameState.is_paused or GameState.is_game_over or GameState.selected_build_type == "":
		visible = false
		return

	var cfg = GameState.TOWER_CATALOG.get(GameState.selected_build_type, null)
	if cfg:
		visible = true
		current_radius = cfg.range
		preview_color = cfg.preview_color
		global_position = get_global_mouse_position()
		queue_redraw()
	else:
		visible = false

func _draw():
	if not visible: return
	draw_circle(Vector2.ZERO, current_radius, Color(preview_color.r, preview_color.g, preview_color.b, 0.25))
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 64, preview_color, 3.0)
	draw_circle(Vector2.ZERO, 22.0, Color(1, 1, 1, 0.5))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color.WHITE, 2.0)
