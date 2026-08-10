extends Node

@export var playlist: Array[MusicData]
@export var theme_music: AudioStreamMP3
@export var audio_player_music: AudioStreamPlayer
@export var audio_player_sound: AudioStreamPlayer
@export var audio_player_voice: AudioStreamPlayer
@export var intro_sfx_debugging: AudioStream

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
				# Stage 音乐循环播放，不切下一首
				play_track()
	)
	# AudioManager 独占 audio_player_voice.finished
	audio_player_voice.finished.connect(_on_voice_finished)

# 外部代码连接此信号监听语音播放结束，不要直接连 audio_player_voice.finished
signal voice_finished

func _on_voice_finished() -> void:
	voice_finished.emit()
	if _is_ducked:
		if _music_paused:
			# 音乐已被 pause 接管，unduck 只清标志，不做 tween
			_is_ducked = false
		else:
			_unduck_music()
	if _music_paused:
		resume_music()

# ─── 舞台语音的暂停/恢复（设置等覆盖页面用） ───

var _stage_voice_stream: AudioStream
var _stage_voice_position: float = 0.0

## 覆盖页面打开时暂停当前对白语音，并恢复被 duck 的音乐
func pause_stage_voice() -> void:
	if _stage_voice_stream != null:
		return
	if not audio_player_voice.playing:
		return
	_stage_voice_stream = audio_player_voice.stream
	_stage_voice_position = audio_player_voice.get_playback_position()
	audio_player_voice.stop()
	if _is_ducked:
		if _music_paused:
			_is_ducked = false
		else:
			_unduck_music()
	if _music_paused:
		resume_music()

## 覆盖页面关闭时恢复对白语音
func resume_stage_voice() -> void:
	var stream := _stage_voice_stream
	_stage_voice_stream = null
	if stream == null:
		return
	audio_player_voice.stream = stream
	audio_player_voice.play(_stage_voice_position)
	_duck_music()

## 主动停止语音（如设置页的预览语音），并同步恢复音乐 duck 状态
func stop_voice() -> void:
	audio_player_voice.stop()
	if _is_ducked:
		if _music_paused:
			_is_ducked = false
		else:
			_unduck_music()
	if _music_paused:
		resume_music()

func play_track() -> void:
	_playlist_paused = false
	_music_source = MusicSource.PLAYLIST
	audio_player_music.stream_paused = false
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

func pause_playlist() -> void:
	_playlist_position = audio_player_music.get_playback_position()
	_playlist_paused = true
	audio_player_music.stream_paused = true

func resume_playlist() -> void:
	_playlist_paused = false
	audio_player_music.stream_paused = false

func play_voice(filename: String, set_current: bool = false) -> void:
	if voice_cache.has(filename):
		var voice = voice_cache[filename]
		if set_current:
			current_voice = voice
		audio_player_voice.stream = voice
		audio_player_voice.play()
		_duck_music()
		return

	var file_path = "%s/%s.wav" % [AudioManager.voice_path, filename]
	if not ResourceLoader.exists(file_path):
		push_warning("play_voice: 语音文件不存在 %s" % file_path)
		return
	# CACHE_MODE_IGNORE：不进 Godot 全局资源缓存，避免所有播放过的语音常驻内存
	# （晚章节内存压力→音频卡顿）；voice_cache 是唯一持有者，淘汰时自然释放
	ResourceLoader.load_threaded_request(file_path, "", false, ResourceLoader.CACHE_MODE_IGNORE)
	# 等待加载完成；加帧数上限，避免加载卡住时对白永久阻塞
	var frames := 0
	var status = ResourceLoader.load_threaded_get_status(file_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and frames < 600:
		await get_tree().process_frame
		frames += 1
		status = ResourceLoader.load_threaded_get_status(file_path)
	var voice: AudioStream = null
	if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		voice = ResourceLoader.load_threaded_get(file_path)
	if voice == null:
		voice = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)  # 兜底同步加载，同样不进全局缓存
	if voice == null:
		push_warning("play_voice: 无法加载语音 %s" % file_path)
		return
	voice_cache[filename] = voice
	voice_cache_order.append(filename)
	while voice_cache_order.size() > MAX_VOICE_CACHE:
		var oldest = voice_cache_order.pop_front()
		voice_cache.erase(oldest)
	if set_current:
		current_voice = voice
	audio_player_voice.stream = voice
	audio_player_voice.play()
	_duck_music()

func replay_voice() -> void:
	audio_player_voice.stream = current_voice
	audio_player_voice.play()
	_duck_music()

func play_sound_by_name(sound_name: String, wait_for_finish: bool = false) -> void:
	var stream: AudioStream = null
	var fade_in := false
	match sound_name:
		"设备调试":
			stream = intro_sfx_debugging
			fade_in = true
		_:
			push_warning("play_sound_by_name: 未知音效 %s" % sound_name)
			return
	if stream == null:
		push_warning("play_sound_by_name: 音效未配置 %s" % sound_name)
		return
	if _sound_fade_tween:
		_sound_fade_tween.kill()
	var target_db: float = audio_player_sound.volume_db
	audio_player_sound.stream = stream
	if fade_in:
		var start_db: float = max(-80.0, target_db - 18.0)
		audio_player_sound.volume_db = start_db
	audio_player_sound.play()
	if fade_in:
		_sound_fade_tween = create_tween()
		_sound_fade_tween.tween_property(audio_player_sound, "volume_db", target_db, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	if wait_for_finish:
		await audio_player_sound.finished

func stop_sound() -> void:
	if _sound_fade_tween:
		_sound_fade_tween.kill()
	audio_player_sound.stop()


var _sound_fade_tween: Tween

var _duck_tween: Tween
var _is_ducked := false

## BGM 的「真实」目标音量（dB）：只由设置推导，不随 duck/unduck 动画浮动。
## 恢复时永远回到它，避免捕捉到动画进行中的中间值导致音量逐句「棘轮」下降。
func _music_base_db() -> float:
	var s: SettingData = Main.setting_data
	if s == null or s.mute_all:
		return -80.0
	return linear_to_db(s.music_volume)

func _duck_music() -> void:
	if _is_ducked:
		return
	if _duck_tween:
		_duck_tween.kill()
	_is_ducked = true
	# 从真实目标音量算 duck 值，绝不捕捉实时音量
	var ducked_db := linear_to_db(db_to_linear(_music_base_db()) * 0.5)
	_duck_tween = create_tween()
	_duck_tween.tween_property(audio_player_music, "volume_db", ducked_db, 0.3)

func _unduck_music() -> void:
	_is_ducked = false
	if _duck_tween:
		_duck_tween.kill()
	if _fade_tween:
		_fade_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(audio_player_music, "volume_db", _music_base_db(), 0.3)

var _music_paused := false
var _music_position := 0.0
var _paused_source := MusicSource.NONE
var _paused_stream: AudioStream

var _fade_tween: Tween

func pause_music() -> void:
	if _music_paused:
		return
	if not audio_player_music.playing and not audio_player_music.stream_paused:
		return
	_music_paused = true
	_music_position = audio_player_music.get_playback_position()
	_paused_source = _music_source
	_paused_stream = audio_player_music.stream
	# 用真实目标音量，避免捕捉到 duck 动画中的低值
	var saved_db := _music_base_db()
	if _fade_tween:
		_fade_tween.kill()
	if _duck_tween:
		_duck_tween.kill()
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
	if _duck_tween:
		_duck_tween.kill()
	audio_player_music.stream = _paused_stream
	audio_player_music.volume_db = -80.0
	audio_player_music.play(_music_position)
	_music_source = _paused_source
	_music_paused = false
	_fade_tween = create_tween()
	_fade_tween.tween_property(audio_player_music, "volume_db", target_db, 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

func play_theme() -> void:
	if _music_source == MusicSource.PLAYLIST:
		_playlist_paused = true
		if audio_player_music.playing or audio_player_music.stream_paused:
			_playlist_position = audio_player_music.get_playback_position()
	_music_source = MusicSource.THEME
	audio_player_music.stream_paused = false
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
