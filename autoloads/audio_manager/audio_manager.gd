extends Node

@export var playlist: Array[MusicData]
@export var theme_music: AudioStreamMP3
@export var audio_player_music: AudioStreamPlayer
@export var audio_player_sound: AudioStreamPlayer
@export var audio_player_voice: AudioStreamPlayer
@export var audio_player_bonus: AudioStreamPlayer

@export_dir var voice_path: String

const MAX_VOICE_CACHE := 50

var current_voice: AudioStreamWAV
var voice_cache: Dictionary = {}
var voice_cache_order: Array[String] = []

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
			audio_player_music.stop()
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
var _bonus_paused := false
var _bonus_position := 0.0

var _fade_tween: Tween

func pause_music() -> void:
	# 如果音乐正在播放，记录位置并开始 fade out
	var is_music_playing = audio_player_music.playing
	var is_bonus_playing = audio_player_bonus.playing
	if is_music_playing:
		_music_paused = true
		_music_position = audio_player_music.get_playback_position()
	if is_bonus_playing:
		_bonus_paused = true
		_bonus_position = audio_player_bonus.get_playback_position()
	# 确保语音播完后恢复音乐
	if _music_paused or _bonus_paused:
		if not audio_player_voice.finished.is_connected(resume_music):
			audio_player_voice.finished.connect(resume_music, CONNECT_ONE_SHOT)
	# 如果当前没有在播放，不需要等
	if not is_music_playing and not is_bonus_playing:
		return
	var music_db := audio_player_music.volume_db
	var bonus_db := audio_player_bonus.volume_db
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	if is_music_playing:
		_fade_tween.tween_property(audio_player_music, "volume_db", -80.0, 1.0) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	if is_bonus_playing:
		_fade_tween.tween_property(audio_player_bonus, "volume_db", -80.0, 1.0) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	_fade_tween.chain().tween_callback(
		func():
			if is_music_playing:
				audio_player_music.stop()
				audio_player_music.volume_db = music_db
			if is_bonus_playing:
				audio_player_bonus.stop()
				audio_player_bonus.volume_db = bonus_db
	)
	await _fade_tween.finished

func resume_music() -> void:
	if not _music_paused and not _bonus_paused:
		return
	var settings = Main.setting_data
	var target_music_db = linear_to_db(settings.music_volume) if not settings.mute_all else -80.0
	var target_voice_db = linear_to_db(settings.voice_volume) if not settings.mute_all else -80.0
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	if _music_paused:
		audio_player_music.volume_db = -80.0
		audio_player_music.play(_music_position)
		_fade_tween.tween_property(audio_player_music, "volume_db", target_music_db, 1.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		_music_paused = false
	if _bonus_paused:
		audio_player_bonus.volume_db = -80.0
		audio_player_bonus.play(_bonus_position)
		_fade_tween.tween_property(audio_player_bonus, "volume_db", target_music_db, 1.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		_bonus_paused = false

func play_theme() -> void:
	audio_player_bonus.stop()
	audio_player_music.stream = theme_music
	theme_music.loop = true
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

func apply_character_volume(character_name: String) -> void:
	if Main.setting_data.mute_all:
		audio_player_voice.volume_db = -80.0
		return
	var vol = Main.setting_data.character_volumes.get(character_name, 1.0)
	audio_player_voice.volume_db = linear_to_db(vol * Main.setting_data.voice_volume)

func set_track_position_by_ratio(ratio: float):
	var target_position = audio_player_bonus.stream.get_length() * ratio
	audio_player_music.stop()
	audio_player_bonus.stop()
	audio_player_bonus.play(target_position)
