extends Node

@export var playlist: Array[MusicData]
@export var theme_music: AudioStreamMP3
@export var audio_player_music: AudioStreamPlayer
@export var audio_player_sound: AudioStreamPlayer
@export var audio_player_voice: AudioStreamPlayer
@export var audio_player_bonus: AudioStreamPlayer

@export_dir var voice_path: String

var current_voice: AudioStreamWAV

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

func play_theme() -> void:
	audio_player_music.stream = theme_music
	audio_player_music.play()

func set_track_position_by_ratio(ratio: float):
	var target_position = audio_player_bonus.stream.get_length() * ratio
	audio_player_bonus.stop()
	audio_player_bonus.play(target_position)

func play_voice(filename: String, set_current: bool = false) -> void:
	var file_path = "%s/%s.wav" % [AudioManager.voice_path, filename]
	var voice: AudioStreamWAV = load(file_path)
	if set_current:
		current_voice = voice
	audio_player_voice.stream = voice
	audio_player_voice.play()
	
func replay_voice() -> void:
	audio_player_voice.stream = current_voice
	audio_player_voice.play()
