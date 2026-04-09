extends Node

@export var playlist: Array[MusicData]
@export var theme_music: AudioStreamMP3
@export var audio_player_music: AudioStreamPlayer
@export var audio_player_sound: AudioStreamPlayer
@export var audio_player_voice: AudioStreamPlayer

@export_dir var voice_path: String

const MAX_VOICE_CACHE := 50

var current_voice: AudioStreamWAV
var voice_cache: Dictionary = {}
var voice_cache_order: Array[String] = []

enum MusicSource { NONE, THEME, PLAYLIST }
var _music_source := MusicSource.NONE

# playlist 暂存，用于离开 bonus 后回来 resume
var _playlist_position := 0.0
var _playlist_paused := false


signal track_index_changed
var track_index: int:
	set(value):
		track_index = value
		if track_index < 0: track_index = playlist.size() - 1
		if track_index >= playlist.size(): track_index = 0
		track_index_changed.emit()

var current_track: MusicData:
	get:
		return playlist[track_index]

func _ready() -> void:
	track_index = 0
	audio_player_music.finished.connect(
		func():
			if _music_source == MusicSource.PLAYLIST:
				track_index += 1
				play_track()
	)

func play_track() -> void:
	_playlist_paused = false
	_music_source = MusicSource.PLAYLIST
	audio_player_music.stream = current_track.track
	audio_player_music.play()

func resume_or_play_track() -> void:
	if _playlist_paused:
		_playlist_paused = false
		_music_source = MusicSource.PLAYLIST
		audio_player_music.stream = current_track.track
		audio_player_music.play(_playlist_position)
	else:
		play_track()

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
	voice_cache_order.append(filename)
	while voice_cache_order.size() > MAX_VOICE_CACHE:
		var oldest = voice_cache_order.pop_front()
		voice_cache.erase(oldest)
	if set_current:
		current_voice = voice
	audio_player_voice.stream = voice
	audio_player_voice.play()

func replay_voice() -> void:
	audio_player_voice.stream = current_voice
	audio_player_voice.play()

var _music_paused := false
var _music_position := 0.0
var _paused_source := MusicSource.NONE
var _paused_stream: AudioStream

var _fade_tween: Tween

func pause_music() -> void:
	if not audio_player_music.playing:
		# 音乐没在播放但之前有暂停记录，确保 finished 连接
		if _music_paused:
			if not audio_player_voice.finished.is_connected(resume_music):
				audio_player_voice.finished.connect(resume_music, CONNECT_ONE_SHOT)
		return
	_music_paused = true
	_music_position = audio_player_music.get_playback_position()
	_paused_source = _music_source
	_paused_stream = audio_player_music.stream
	# 确保语音播完后恢复音乐
	if not audio_player_voice.finished.is_connected(resume_music):
		audio_player_voice.finished.connect(resume_music, CONNECT_ONE_SHOT)
	var saved_db := audio_player_music.volume_db
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(audio_player_music, "volume_db", -80.0, 1.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	_fade_tween.tween_callback(
		func():
			audio_player_music.stop()
			audio_player_music.volume_db = saved_db
	)
	await _fade_tween.finished

func resume_music() -> void:
	if not _music_paused:
		return
	var settings = Main.setting_data
	var target_db = linear_to_db(settings.music_volume) if not settings.mute_all else -80.0
	if _fade_tween:
		_fade_tween.kill()
	audio_player_music.stream = _paused_stream
	audio_player_music.volume_db = -80.0
	audio_player_music.play(_music_position)
	_music_source = _paused_source
	_music_paused = false
	_fade_tween = create_tween()
	_fade_tween.tween_property(audio_player_music, "volume_db", target_db, 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

func play_theme() -> void:
	if _music_source == MusicSource.PLAYLIST and audio_player_music.playing:
		_playlist_position = audio_player_music.get_playback_position()
		_playlist_paused = true
	_music_source = MusicSource.THEME
	audio_player_music.stream = theme_music
	theme_music.loop = true
	audio_player_music.play()

func apply_settings(settings: SettingData) -> void:
	if settings.mute_all:
		audio_player_music.volume_db = -80.0
		audio_player_sound.volume_db = -80.0
		audio_player_voice.volume_db = -80.0
	else:
		audio_player_music.volume_db = linear_to_db(settings.music_volume)
		audio_player_sound.volume_db = linear_to_db(settings.sound_volume)
		audio_player_voice.volume_db = linear_to_db(settings.voice_volume)

func apply_character_volume(character_name: String) -> void:
	if Main.setting_data.mute_all:
		audio_player_voice.volume_db = -80.0
		return
	var vol = Main.setting_data.character_volumes.get(character_name, 1.0)
	audio_player_voice.volume_db = linear_to_db(vol * Main.setting_data.voice_volume)

func set_track_position_by_ratio(ratio: float):
	var target_position = audio_player_music.stream.get_length() * ratio
	audio_player_music.stop()
	audio_player_music.play(target_position)
