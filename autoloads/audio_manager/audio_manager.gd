extends Node

@export var playlist: Array[MusicData]
@export var theme_music: AudioStreamMP3
@export var audio_player_music: AudioStreamPlayer
@export var audio_player_sound: AudioStreamPlayer
@export var audio_player_voice: AudioStreamPlayer
@export var audio_player_bonus: AudioStreamPlayer

@export_dir var voice_path: String

var current_voice: AudioStreamWAV
var voice_cache: Dictionary = {}

signal track_index_changed
var track_index: int:
	set(value):
		track_index = value
		if track_index < 0: track_index = playlist.size() - 1
		if track_index >= playlist.size(): track_index = 0
		audio_player_bonus.stream = current_track.track
		track_index_changed.emit()

var current_track: MusicData:
	get:
		return playlist[track_index]

func _ready() -> void:
	track_index = 0

	audio_player_bonus.finished.connect(
		func ():
			track_index += 1
			audio_player_bonus.play()
	)

func play_voice(filename: String, set_current: bool = false) -> void:
	if voice_cache.has(filename):
		var voice = voice_cache[filename]
		if set_current:
			current_voice = voice
		audio_player_voice.stream = voice
		audio_player_voice.play()
		return

	var file_path = "%s/%s.wav" % [AudioManager.voice_path, filename]
	ResourceLoader.load_threaded_request(file_path)
	var status = ResourceLoader.load_threaded_get_status(file_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(file_path)
	var voice = ResourceLoader.load_threaded_get(file_path)
	voice_cache[filename] = voice
	if set_current:
		current_voice = voice
	audio_player_voice.stream = voice
	audio_player_voice.play()

func replay_voice() -> void:
	audio_player_voice.stream = current_voice
	audio_player_voice.play()

func play_theme() -> void:
	audio_player_music.stream = theme_music
	audio_player_music.play()

func apply_settings(settings: SettingData) -> void:
	if settings.mute_all:
		audio_player_music.volume_db = -80.0
		audio_player_sound.volume_db = -80.0
		audio_player_voice.volume_db = -80.0
		audio_player_bonus.volume_db = -80.0
	else:
		audio_player_music.volume_db = linear_to_db(settings.music_volume)
		audio_player_sound.volume_db = linear_to_db(settings.sound_volume)
		audio_player_voice.volume_db = linear_to_db(settings.voice_volume)
		audio_player_bonus.volume_db = linear_to_db(settings.music_volume)

func set_track_position_by_ratio(ratio: float):
	var target_position = audio_player_bonus.stream.get_length() * ratio
	audio_player_bonus.stop()
	audio_player_bonus.play(target_position)
