extends Node

var sfx_players: Array[AudioStreamPlayer] = []
var max_players: int = 12
var music_player: AudioStreamPlayer

# Volume levels (0.0 = Mute, 1.0 = Max)
var music_volume: float = 0.7
var sfx_volume: float = 0.8

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create SFX pool
	for i in range(max_players):
		var p = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		add_child(p)
		sfx_players.append(p)
		
	# Dedicated Music Player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	add_child(music_player)
	
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)
	print("🔊 [SoundManager] Initialized with %d audio channels." % max_players)

# --- SFX PLAYBACK ---
func play_sfx(audio_resource: AudioStream, pitch_variance: float = 0.05):
	if not audio_resource:
		return
	if sfx_volume <= 0.01:
		return
		
	for p in sfx_players:
		if not p.playing:
			p.stream = audio_resource
			p.volume_db = linear_to_db(sfx_volume)
			p.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
			p.play()
			return

# Bulletproof path player with console logging
func play_sfx_path(path: String, pitch_variance: float = 0.05):
	# Check both ResourceLoader and direct FileAccess
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		print("❌ [SoundManager] SFX file NOT found at: '", path, "'. Check spelling or folder!")
		return
		
	var stream = load(path)
	if stream and stream is AudioStream:
		play_sfx(stream, pitch_variance)
	else:
		print("❌ [SoundManager] Could not load AudioStream from: '", path, "'")

# --- MUSIC CONTROLS ---
func play_music(music_stream: AudioStream):
	if not music_stream:
		return
	if music_player.stream == music_stream and music_player.playing:
		return
		
	music_player.stream = music_stream
	music_player.volume_db = linear_to_db(music_volume)
	music_player.play()
	print("🎵 [SoundManager] Now playing music stream.")

func play_music_path(path: String):
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		print("❌ [SoundManager] Music file NOT found at: '", path, "'")
		return
		
	var stream = load(path)
	if stream and stream is AudioStream:
		play_music(stream)
	else:
		print("❌ [SoundManager] Failed to load music stream from: '", path, "'")

func stop_music():
	if music_player:
		music_player.stop()

func fade_out_music(duration: float = 0.4):
	if not music_player or not music_player.playing:
		return
		
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	await tween.finished
	music_player.stop()
	music_player.volume_db = linear_to_db(music_volume)

# --- VOLUME CONTROLS ---
func set_music_volume(val: float):
	music_volume = clampf(val, 0.0, 1.0)
	if music_player:
		music_player.volume_db = -80.0 if music_volume <= 0.01 else linear_to_db(music_volume)

func set_sfx_volume(val: float):
	sfx_volume = clampf(val, 0.0, 1.0)
	for p in sfx_players:
		p.volume_db = -80.0 if sfx_volume <= 0.01 else linear_to_db(sfx_volume)
