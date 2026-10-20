extends Control

@onready var auth_request = $AuthRequest
@onready var user_input = $VBoxContainer/UsernameInput
@onready var pass_input = $VBoxContainer/PasswordInput
@onready var status_lbl = $VBoxContainer/StatusLabel

@onready var login_btn = $VBoxContainer/LoginBtn
@onready var reg_btn = $VBoxContainer/RegisterBtn

func _ready():
	# Make sure AnimatedSprite2D background fills and plays
	var bg = get_node_or_null("Background")
	if bg and bg is AnimatedSprite2D:
		if bg.centered:
			bg.position = Vector2(480, 300)
		else:
			bg.position = Vector2.ZERO
		bg.play()

	login_btn.pressed.connect(func(): send_auth("login"))
	reg_btn.pressed.connect(func(): send_auth("register"))
	auth_request.request_completed.connect(_on_response)

func send_auth(action_type: String):
	status_lbl.text = "Connecting to Central Grid..."
	var url = "http://localhost/solarfuture/api/login.php"
	var headers = ["Content-Type: application/json"]
	var data = JSON.stringify({
		"username": user_input.text,
		"password": pass_input.text,
		"action": action_type
	})
	auth_request.request(url, headers, HTTPClient.METHOD_POST, data)

func _on_response(_result, response_code, _headers, body):
	var raw_text = body.get_string_from_utf8()
	
	if response_code == 404:
		status_lbl.text = "Error 404: api/login.php not found in htdocs/solarfuture!"
		return
		
	var res = JSON.parse_string(raw_text)
	if res and res.has("success") and res.success:
		if res.has("user_id"):
			# Store Officer Identity
			GameState.current_user_id = res.user_id
			GameState.current_username = res.username
			
			# Store Personal Lifetime Records from MySQL
			GameState.user_high_score = res.get("high_score", 0)
			GameState.user_max_wave = res.get("max_wave", 0)
			GameState.user_total_kwh = res.get("total_clean_kwh", 0)
			
			# Advance to the Main Menu Command Hub
			SceneTransition.change_scene("res://scenes/MainMenu.tscn", 0.4)
		else:
			status_lbl.text = res.message # Registration success message
	else:
		status_lbl.text = res.message if (res and res.has("message")) else "Authentication Failed. Is XAMPP running?"
