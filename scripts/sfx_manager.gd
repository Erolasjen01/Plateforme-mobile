extends Node
# Autoload : SfxManager
# Génère de petits sons synthétisés (ondes sinus) pour éviter d'avoir besoin
# de fichiers audio externes. Garde le jeu ultra léger (0 Ko d'assets sonores).

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

func play_tone(freq: float, duration: float = 0.12, volume_db: float = -6.0) -> void:
	if not SaveManager.sound_enabled:
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = duration + 0.05
	_player.stream = gen
	_player.volume_db = volume_db
	_player.play()
	var playback: AudioStreamGeneratorPlayback = _player.get_stream_playback()
	var frames := int(gen.mix_rate * duration)
	for i in range(frames):
		var t := float(i) / gen.mix_rate
		var envelope := 1.0 - (t / duration)
		var sample := sin(TAU * freq * t) * envelope
		playback.push_frame(Vector2(sample, sample))

func play_jump() -> void:
	play_tone(660.0, 0.08)

func play_coin() -> void:
	play_tone(1100.0, 0.07)

func play_death() -> void:
	play_tone(160.0, 0.25, -4.0)

func play_level_complete() -> void:
	play_tone(523.0, 0.1)
	await get_tree().create_timer(0.1).timeout
	play_tone(659.0, 0.1)
	await get_tree().create_timer(0.1).timeout
	play_tone(784.0, 0.18)

func play_click() -> void:
	play_tone(440.0, 0.05, -8.0)
