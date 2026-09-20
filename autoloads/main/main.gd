extends Node

enum ProfileMode { LOAD, SAVE }

var save_data: SaveData = SaveData.new()
var save_path = "user://save_data.tres"
var collection_data: CollectionData = CollectionData.new()
var collection_path = "user://collection_data.tres"
var setting_data: SettingData = SettingData.new()
var setting_path = "user://setting_data.tres"

var clicked: bool
var dragged: bool

var profile_mode: ProfileMode:
	set(value):
		profile_mode = value

signal gallery_card_index_changed
signal speed_settings_changed
signal voice_collection_changed(voice_filename: String)
var gallery_card_index: int:
	set(value):
		gallery_card_index = value
		emit_signal("gallery_card_index_changed")

@export_file_path("json") var expression_json: String
var expression_dict: Dictionary

func _ready() -> void:
	if FileAccess.file_exists(save_path):
		save_data = load(save_path)
	if FileAccess.file_exists(collection_path):
		collection_data = load(collection_path)
	if FileAccess.file_exists(setting_path):
		setting_data = load(setting_path)

	# 按存档把窗口摆到上次的位置。实测两个坑：
	#   1) 直接在 _ready 里设会被引擎在 autoload 加载期间自己摆的那次覆盖掉，所以等一帧
	#   2) 「第一帧」要等所有 autoload + 主场景 + 资源加载完才来，所以这段实际生效时间≈设置页 _ready，
	#      想让它更早只能靠 project 设置的 window_*_override（尺寸第一帧就对，位置不行）
	# 启动时只按存档应用、不记录：那会儿窗口不是玩家摆的，记下来会冲掉上次的窗口状态
	await get_tree().process_frame
	apply_window_mode(setting_data.fullscreen, false)

	#expression_dict = JSON.parse_string()

func has_voice_collection(filename) -> bool:
	return collection_data.voice_collections.filter(
		func (collection: VoiceCollection):
			return collection.voice_filename == filename
	).size() > 0

## 收藏一条语音并落盘。
## 章节号/章节名取演出表的值（Stage 在 ShowChapterInfo 时记下的），
## 拿不到才退回调用方给的章节名——那是对话文件名，不是表里的标题。
func collect_voice(character_name: String, text: String, voice_filename: String,
		fallback_chapter_name: String = "") -> void:
	var collection := VoiceCollection.new()
	collection.character_name = character_name
	collection.text = text
	collection.voice_filename = voice_filename
	collection.chapter_designation = Stage.current_chapter_designation
	collection.chapter_name = Stage.current_chapter_title \
		if Stage.current_chapter_title != "" else fallback_chapter_name
	collection_data.voice_collections.append(collection)
	save_collection_data()
	voice_collection_changed.emit(voice_filename)

func unlock_cg(cg_name: String) -> void:
	if cg_name.is_empty():
		return
	if cg_name in collection_data.unlocked_cgs:
		return
	collection_data.unlocked_cgs.append(cg_name)
	save_collection_data()

func has_unlocked_cg(cg_name: String) -> bool:
	return cg_name in collection_data.unlocked_cgs

var _setting_save_pending: bool = false
var _setting_save_thread: Thread

func save_collection_data() -> void:
	var err := ResourceSaver.save(collection_data, collection_path)
	if err != OK:
		push_error("save_collection_data failed (%d): %s" % [err, collection_path])

func save_setting_data() -> void:
	if _setting_save_pending:
		return
	_setting_save_pending = true
	if _setting_save_thread and _setting_save_thread.is_started():
		_setting_save_thread.wait_to_finish()
	_setting_save_thread = Thread.new()
	_setting_save_thread.start(
		func():
			ResourceSaver.save(setting_data, setting_path)
			_setting_save_pending = false
	)

func save_save_data() -> void:
	ResourceSaver.save(save_data, save_path)

# ─── 存档查询（纯数据，不经过存档页）─────────────────────
# 放在这里是因为：这些查询会在「主菜单刷新按钮」这类自动路径上被调用，
# 而存档页现在是惰性创建的——不能为了问一句「有没有存档」就把它建出来

## 存档槽是否可用（有内容）
func is_profile_usable(profile: ProfileData) -> bool:
	return profile != null and profile.dialogue_id != ""


## 最新的手动存档槽
func get_latest_manual_profile() -> ProfileData:
	var best: ProfileData = null
	for i in save_data.profiles.size():
		var profile: ProfileData = save_data.profiles[i]
		if not is_profile_usable(profile):
			continue
		if best == null:
			best = profile
			continue
		if profile.last_saved_at_unix_ms > best.last_saved_at_unix_ms:
			best = profile
		elif profile.last_saved_at_unix_ms == best.last_saved_at_unix_ms and i > save_data.profiles.find(best):
			best = profile
	return best


## 「继续游戏」用哪个槽：有快速存档就用它，否则用最新的手动档
func get_continue_profile() -> ProfileData:
	if is_profile_usable(save_data.auto_profile):
		return save_data.auto_profile
	return get_latest_manual_profile()


func has_continue_save() -> bool:
	return get_continue_profile() != null

## 引擎启动建窗口用的尺寸，写死在 project.godot 的 window_*_override 里（1280x720）。
## 这里只是它没设时的兜底
const WINDOWED_FALLBACK_SIZE := Vector2i(1280, 720)


#region 窗口模式 / 窗口化状态

## 记下窗口化的窗口尺寸和位置，下次启动由脚本摆回去。
## project 设置的 window_*_override 是固定的 1280x720（引擎启动建窗口用），游戏不去改写它——
## 免得游戏反过来改自己的安装目录/仓库文件。
## 全屏时窗口铺满屏幕、那不是玩家的选择，所以只在窗口化时记
func capture_windowed_rect() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	setting_data.windowed_size = DisplayServer.window_get_size()
	setting_data.windowed_position = DisplayServer.window_get_position()


## capture_current=false 用于「启动时按存档应用」：那时窗口是引擎刚建出来的，
## 记下来会把玩家上次的窗口状态冲掉。只有玩家自己切模式、或退出游戏时才记
## 窗口模式 + 尺寸 + 位置。放在 Main 上（它是第一个 autoload，随时可用），
## "窗口化变无边框、拖不动"这类问题只能靠这一行的前后对比判断
func window_description() -> String:
	var mode_name := "窗口化"
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_MINIMIZED: mode_name = "最小化"
		DisplayServer.WINDOW_MODE_MAXIMIZED: mode_name = "最大化"
		DisplayServer.WINDOW_MODE_FULLSCREEN: mode_name = "全屏"
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: mode_name = "独占全屏"
	return "%s %s@%s" % [mode_name, DisplayServer.window_get_size(), DisplayServer.window_get_position()]


func apply_window_mode(fullscreen: bool, capture_current: bool = true) -> void:
	var before := window_description()
	if fullscreen:
		if capture_current:
			capture_windowed_rect()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("[UI] 窗口模式 → 全屏（%s ⇒ %s）" % [before, window_description()])
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	var rect := _windowed_rect()
	DisplayServer.window_set_size(rect.size)
	DisplayServer.window_set_position(rect.position)
	print("[UI] 窗口模式 → 窗口化（%s ⇒ %s）" % [before, window_description()])


## 窗口化用的窗口矩形：优先用本地存的尺寸/位置；没存过就取 project 设置里的 override
## （就是上次退出时的尺寸，首次是 1280x720）并在可用区居中
func _windowed_rect() -> Rect2i:
	var size := setting_data.windowed_size
	var pos := setting_data.windowed_position
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if size.x <= 0 or size.y <= 0:
		size = _override_window_size()
		pos = usable.position + (usable.size - size) / 2
	else:
		screen = _screen_for_position(pos)
		usable = DisplayServer.screen_get_usable_rect(screen)
	# 夹进可用区：换屏幕、改分辨率或拔掉副屏之后，旧记录可能放不下、甚至整个跑到屏幕外，
	# 那正是「窗口化变成无边框全屏、拖不动」的成因，夹一下才不会复发
	size = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
	pos.x = clampi(pos.x, usable.position.x, usable.position.x + usable.size.x - size.x)
	pos.y = clampi(pos.y, usable.position.y, usable.position.y + usable.size.y - size.y)
	return Rect2i(pos, size)


## project 设置里的窗口尺寸 override；(0, 0) 表示没设过
func _project_window_size() -> Vector2i:
	return Vector2i(
		ProjectSettings.get_setting("display/window/size/window_width_override", 0),
		ProjectSettings.get_setting("display/window/size/window_height_override", 0))


## 没记录、project 设置里也没设过时，窗口化的兜底尺寸
func _override_window_size() -> Vector2i:
	var size := _project_window_size()
	return size if size.x > 0 and size.y > 0 else WINDOWED_FALLBACK_SIZE


## 这个坐标落在哪块屏幕上；都不在（副屏被拔了）就退回当前屏幕，
## 免得玩家存在副屏上的窗口每次启动都被拽回主屏
func _screen_for_position(pos: Vector2i) -> int:
	for i in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_usable_rect(i).has_point(pos):
			return i
	return DisplayServer.window_get_current_screen()


## 退出前用：save_setting_data() 是异步写盘，进程直接结束的话配置会丢，
## 所以先等在路上的一次写完，再同步写一次
func save_setting_data_and_wait() -> void:
	if _setting_save_thread and _setting_save_thread.is_started():
		_setting_save_thread.wait_to_finish()
	_setting_save_pending = false
	var err := ResourceSaver.save(setting_data, setting_path)
	if err != OK:
		push_error("save_setting_data_and_wait failed (%d): %s" % [err, setting_path])


## 退出游戏。窗口状态的保存收在这里，免得「菜单退出」和「点窗口 X」两条路径不一致
func quit_game() -> void:
	capture_windowed_rect()
	save_setting_data_and_wait()
	get_tree().quit()

#endregion


func _notification(what: int) -> void:
	# 点窗口 X / Alt+F4
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		capture_windowed_rect()
		save_setting_data_and_wait()

#func auto_save() -> void:
	#ResourceSaver.save(sa)
