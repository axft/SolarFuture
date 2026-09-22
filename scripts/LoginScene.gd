extends Control

@onready var auth_request = $AuthRequest
@onready var user_input = $VBoxContainer/UsernameInput
@onready var pass_input = $VBoxContainer/PasswordInput
@onready var status_lbl = $VBoxContainer/StatusLabel

@onready var login_btn = $VBoxContainer/LoginBtn
@onready var reg_btn = $VBoxContainer/RegisterBtn

func _ready():
	login_btn.pressed.connect(func(): send_auth("login"))
	reg_btn.pressed.connect(func(): send_auth("register"))
	auth_request.request_completed.connect(_on_response)

func send_auth(action_type: String):
	status_lbl.text = "Connecting to XAMPP..."
	var url = "http://localhost/solarfuture/api/login.php"
	var headers = ["Content-Type: application/json"]
	var data = JSON.stringify({
		"username": user_input.text,
		"password": pass_input.text,
		"action": action_type
	})
	auth_request.request(url, headers, HTTPClient.METHOD_POST, data)

func _on_response(result, code, headers, body):
	var res = JSON.parse_string(body.get_string_from_utf8())
	if res and res.has("success") and res.success:
		if res.has("user_id"):
			GameState.current_user_id = res.user_id
			GameState.current_username = res.username
			get_tree().change_scene_to_file("res://scenes/MainGame.tscn")
		else:
			status_lbl.text = res.message
	else:
		status_lbl.text = res.message if res else "Connection Error. Is XAMPP running?"
