extends Node2D

@onready var path_2d = $Path2D
@onready var http_request = $ScoreSyncRequest

@onready var energy_label = $UI/ColorRect/HBoxContainer/EnergyLabel
@onready var health_label = $UI/ColorRect/HBoxContainer/HealthLabel
@onready var wave_label = $UI/ColorRect/HBoxContainer/WaveLabel
@onready var score_label = $UI/ColorRect/HBoxContainer/ScoreLabel

@onready var start_wave_btn = $UI/StartWaveBtn
@onready var build_solar_btn = $UI/BuildSolarBtn

var enemy_scene: PackedScene = preload("res://scenes/SmogEnemy.tscn")
var solar_tower_scene: PackedScene = preload("res://scenes/TowerSolar.tscn")

var enemies_to_spawn: int = 6
var enemies_spawned: int = 0
var spawn_timer: float = 0.0

func _ready():
	start_wave_btn.pressed.connect(_on_start_wave_pressed)
	build_solar_btn.pressed.connect(_on_build_solar_pressed)
	http_request.request_completed.connect(_on_score_synced)
	update_ui()
	
	if has_node("Path2D/RoadVisual") and $Path2D.curve:
		$Path2D/RoadVisual.points = $Path2D.curve.get_baked_points()

func _process(delta: float):
	# Spawning system during active wave
	if GameState.is_wave_active and not GameState.is_game_over:
		spawn_timer += delta
		if spawn_timer >= 1.2 and enemies_spawned < enemies_to_spawn:
			spawn_enemy()
			spawn_timer = 0.0
			enemies_spawned += 1

	# Keep ghost range circle following mouse smoothly while selecting a tower
	if GameState.selected_build_type != "":
		queue_redraw()

func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	enemy.add_to_group("enemies")
	enemy.reached_end.connect(_on_enemy_reached_end)
	enemy.defeated.connect(_on_enemy_defeated)
	path_2d.add_child(enemy)

func _on_enemy_reached_end():
	GameState.eco_health -= 15
	update_ui()
	
	if GameState.eco_health <= 0 and not GameState.is_game_over:
		trigger_game_over()
	else:
		# Check wave progression even when enemies leak through!
		check_wave_status()

func _on_enemy_defeated(enemy):
	GameState.energy += enemy.bounty_reward
	GameState.sustainability_score += enemy.eco_score_reward
	GameState.clean_kwh_earned += enemy.bounty_reward
	GameState.enemies_defeated += 1
	GameState.co2_mitigated_kg += 18
	update_ui()
	
	# Check wave progression
	check_wave_status()
	
	var active = get_tree().get_nodes_in_group("enemies")
	if enemies_spawned >= enemies_to_spawn and active.size() <= 1:
		GameState.is_wave_active = false
		GameState.wave += 1
		GameState.energy += 100
		enemies_spawned = 0
		enemies_to_spawn += 3
		start_wave_btn.disabled = false
		update_ui()

func _on_start_wave_pressed():
	if not GameState.is_wave_active:
		GameState.is_wave_active = true
		start_wave_btn.disabled = true

func _on_build_solar_pressed():
	print("Solar button clicked! Current state:", GameState.selected_build_type)
	GameState.selected_build_type = "SOLAR"
	print("New state:", GameState.selected_build_type)

# Changed to _input to ensure clicks are caught even over background elements
func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameState.selected_build_type == "SOLAR":
			# Prevent placing if clicking on HUD buttons
			if get_viewport().gui_get_hovered_control() != null:
				return
				
			if GameState.energy >= 100:
				GameState.energy -= 100
				var tower = solar_tower_scene.instantiate()
				tower.global_position = get_global_mouse_position()
				add_child(tower)
				GameState.selected_build_type = ""
				update_ui()

func trigger_game_over():
	GameState.is_game_over = true
	var url = "http://localhost/solarfuture/api/save_score.php"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"wave": GameState.wave,
		"score": GameState.sustainability_score,
		"cleanKwh": GameState.clean_kwh_earned
	})
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_score_synced(_result, _code, _headers, body):
	print("Saved to MySQL: ", body.get_string_from_utf8())
	start_wave_btn.text = "MISSION OVER - Check MySQL"

func update_ui():
	energy_label.text = "⚡ Energy: %d kWh   " % GameState.energy
	health_label.text = "🌍 Health: %d%%   " % GameState.eco_health
	wave_label.text = "🌊 Wave: %d   " % GameState.wave
	score_label.text = "🌱 Score: %d" % GameState.sustainability_score

func _draw():
	if GameState.selected_build_type == "SOLAR":
		# Always use local mouse coordinates for canvas drawing
		var m_pos = get_local_mouse_position()
		var range_radius = 160.0
		
		# 1. Electric Cyan / High-Visibility Sky Blue (Contrasts sharply with green grass)
		var fill_color = Color(0.0, 0.8, 1.0, 0.25)    # 25% opacity cyan fill
		var border_color = Color(0.0, 0.95, 1.0, 0.9)  # 90% bright cyan border
		
		# Draw the range preview circle
		draw_circle(m_pos, range_radius, fill_color)
		draw_arc(m_pos, range_radius, 0.0, TAU, 64, border_color, 3.0)
		
		# 2. Footprint / Tower Placement Ghost indicator (Small inner circle)
		draw_circle(m_pos, 24.0, Color(1.0, 0.85, 0.0, 0.6)) # Golden-yellow solar footprint
		draw_arc(m_pos, 24.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.9), 2.0)
		
func check_wave_status():
	# Wait for the current frame to end so queued_free enemies are fully removed
	await get_tree().process_frame
	
	if GameState.is_game_over:
		return
		
	var active_enemies = get_tree().get_nodes_in_group("enemies")
	
	# If all enemies for this wave were spawned AND none remain alive on screen
	if enemies_spawned >= enemies_to_spawn and active_enemies.size() == 0:
		GameState.is_wave_active = false
		GameState.wave += 1
		GameState.energy += 100 # Wave completion clean energy bonus
		
		# Reset spawn counters for next wave
		enemies_spawned = 0
		enemies_to_spawn += 3
		
		# Re-enable the Start Wave button for the next round
		start_wave_btn.disabled = false
		start_wave_btn.text = "▶️ Start Wave %d" % GameState.wave
		update_ui()
		print("Wave cleared! Ready for Wave ", GameState.wave)
