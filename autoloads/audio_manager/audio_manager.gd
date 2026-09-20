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

## 最近一次语音请求的序号。未缓存的语音要异步加载，
## 加载期间玩家可能已经点了别的语音（或按了停止），迟到的旧请求不能再抢播放器。
var _voice_request_id: int = 0

## 作废所有还没加载完的语音请求：播放/停止/暂停/重播都算「最新意图」，之后回来的加载一律放弃
func _invalidate_pending_voice_loads() -> void:
	_voice_request_id += 1

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
	# 开局就把存档音量应用上。这一步以前是设置页 _ready 里顺手做的（setting_page.gd 的
	# _load_settings），但设置页改成惰性实例化后开局不再创建，于是没人应用 →
	# 播放器停在默认的 0 dB，BGM 以满音量放出来。AudioManager 排在 Main 之后，
	# 这时 setting_data 已经加载好了，所以放在这里最稳
	apply_settings(Main.setting_data)

# 外部代码连接此信号监听语音播放结束，不要直接连 audio_player_voice.finished
signal voice_finished

func _on_voice_finished() -> void:
	voice_finished.emit()
	_restore_music_after_voice()

# ─── 舞台语音的暂停/恢复（设置等覆盖页面用） ───

var _stage_voice_stream: AudioStream
var _stage_voice_position: float = 0.0

## 覆盖页面打开时暂停当前对白语音，并恢复被 duck 的音乐
func pause_stage_voice() -> void:
	_invalidate_pending_voice_loads()
	if _stage_voice_stream != null:
		return
	if not audio_player_voice.playing:
		return
	_stage_voice_stream = audio_player_voice.stream
	_stage_voice_position = audio_player_voice.get_playback_position()
	audio_player_voice.stop()
	_restore_music_after_voice()

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
	_invalidate_pending_voice_loads()
	audio_player_voice.stop()
	_restore_music_after_voice()

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

# ─── 剧情 BGM 存档：进音乐鉴赏（bonus 附加页）前保存，回剧情时恢复 ───
var _story_music_valid := false
var _story_music_stream: AudioStream
var _story_music_index := -1
var _story_music_position := 0.0
var _story_music_db := 0.0
var _story_music_source := MusicSource.NONE
var _story_music_playing := false
var _story_music_paused := false

## 保存剧情当前 BGM（曲目/进度/播放态/音量），供从鉴赏返回后恢复
func save_story_music() -> void:
	_story_music_valid = true
	_story_music_stream = audio_player_music.stream
	_story_music_index = track_index
	_story_music_db = audio_player_music.volume_db
	_story_music_source = _music_source
	_story_music_playing = audio_player_music.playing
	_story_music_paused = audio_player_music.stream_paused
	if _story_music_playing or _story_music_paused:
		_story_music_position = audio_player_music.get_playback_position()
	else:
		_story_music_position = 0.0

## 恢复剧情 BGM；若鉴赏期间没动过音乐则不打断，若剧情当时静默则保持静默
func restore_story_music() -> void:
	if not _story_music_valid:
		return
	_story_music_valid = false
	# 鉴赏期间没改过音乐（还是剧情那首、仍在播）→ 不打断，任其自然延续
	if audio_player_music.stream == _story_music_stream \
		and _music_source == _story_music_source \
		and not audio_player_music.stream_paused \
		and audio_player_music.playing == _story_music_playing:
		return
	# 清掉鉴赏遗留的播放列表暂停状态，交还给剧情
	_playlist_paused = false
	audio_player_music.stream_paused = false
	# 剧情当时静默：停掉鉴赏选播的 BGM，不要漏进剧情
	if _story_music_stream == null or (not _story_music_playing and not _story_music_paused):
		audio_player_music.stop()
		audio_player_music.stream = null
		_music_source = MusicSource.NONE
		return
	# 恢复剧情原本的曲目与进度
	track_index = _story_music_index
	audio_player_music.stream = _story_music_stream
	audio_player_music.volume_db = _story_music_db
	_music_source = _story_music_source
	audio_player_music.play(_story_music_position)
	audio_player_music.stream_paused = _story_music_paused

func play_voice(filename: String, set_current: bool = false) -> void:
	# 每次调用都占一个序号；下面异步加载回来的旧请求会被作废
	_invalidate_pending_voice_loads()
	var request_id := _voice_request_id
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
	# TODO(优化)：这段等待的根因是「播放时才加载」。未缓存的语音要现读磁盘（打包后是 .pck 解压），
	# 而 voice_cache 上限只有 50 条、超了就淘汰，所以迟早会碰上要现加载的那句——
	# 表现就是玩家点了语音却像没反应。上面的 _voice_request_id 只保证迟到的加载不抢走播放器，
	# 消不掉这段等待本身。后面优化可以考虑：
	#   ① 提前预热：对白行本来就带 #语音= tag，可以在上一句播放时先对下一句 load_threaded_request，
	#      轮到它时直接命中缓存，等待就没了；
	#   ② 在章节过场、加载页这类空闲时间按需预热；
	#   ③ 重新权衡缓存上限/淘汰策略（现在是 IGNORE 全局缓存 + 自己管 50 条，全是为了内存，
	#      而「预热」和「省内存」是互相拉扯的，得一起定）。
	# CACHE_MODE_IGNORE：不进 Godot 全局资源缓存，避免所有播放过的语音常驻内存
	# （晚章节内存压力→音频卡顿）；voice_cache 是唯一持有者，淘汰时自然释放
	ResourceLoader.load_threaded_request(file_path, "", false, ResourceLoader.CACHE_MODE_IGNORE)
	# 等待加载完成；加帧数上限，避免加载卡住时对白永久阻塞
	var frames := 0
	var status = ResourceLoader.load_threaded_get_status(file_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and frames < 600:
		await get_tree().process_frame
		# 加载期间玩家又点了别的语音：作废这次请求，否则它加载完会顶掉新点的那句
		if request_id != _voice_request_id:
			print("[play_voice] 放弃迟到的加载：%s" % filename)
			return
		frames += 1
		status = ResourceLoader.load_threaded_get_status(file_path)
	if request_id != _voice_request_id:
		print("[play_voice] 放弃迟到的加载：%s" % filename)
		return
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
	_invalidate_pending_voice_loads()
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
	_duck_tween = create_tween()
	_duck_tween.tween_property(audio_player_music, "volume_db", _music_base_db(), 0.3)


## 语音结束（或被暂停/停止）后，把为它让路而 duck 下去的音乐还原回去
func _restore_music_after_voice() -> void:
	if _is_ducked:
		_unduck_music()


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
