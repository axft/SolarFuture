extends Node

var sfx_players: Array[AudioStreamPlayer] = []
var max_players: int = 12

var music_player: AudioStreamPlayer

# Volume levels (0.0 = Mute, 1.0 = Max volume)
var music_volume: float = 0.7
var sfx_volume: float = 0.8

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# SFX Pool
	for i in range(max_players):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
		
	# Music Player
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# Apply initial volumes
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)

# --- SFX PLAYBACK ---
func play_sfx(audio_resource: AudioStream, pitch_variance: float = 0.05):
	if not audio_resource or sfx_volume <= 0.01:
		return
		
	for p in sfx_players:
		if not p.playing:
			p.stream = audio_resource
			p.volume_db = linear_to_db(sfx_volume)
			# Small pitch variance makes popping sounds feel punchy and dynamic
			p.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
			p.play()
			return

# --- MUSIC PLAYBACK & STOPPING ---
func play_music(music_stream: AudioStream):
	if not music_stream:
		return
	if music_player.stream == music_stream and music_player.playing:
		return
		
	music_player.stream = music_stream
	music_player.volume_db = linear_to_db(music_volume)
	music_player.play()

func stop_music():
	if music_player:
		music_player.stop()

# Smoothly fades music out over X seconds
func fade_out_music(duration: float = 0.5):
	if not music_player or not music_player.playing:
		return
		
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	await tween.finished
	music_player.stop()
	music_player.volume_db = linear_to_db(music_volume) # Reset volume for next song

# --- VOLUME CONTROLS (0.0 to 1.0) ---
func set_music_volume(val: float):
	music_volume = clampf(val, 0.0, 1.0)
	if music_player:
		if music_volume <= 0.01:
			music_player.volume_db = -80.0 # Mute
		else:
			music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(val: float):
	sfx_volume = clampf(val, 0.0, 1.0)
	for p in sfx_players:
		if sfx_volume <= 0.01:
			p.volume_db = -80.0
		else:
			p.volume_db = linear_to_db(sfx_volume)
