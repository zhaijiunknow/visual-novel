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
	# 读档一律「读到好档才替换全局」。以前是三行 `xxx = load(path)`，而 load() 解析失败
	# 返回的是 null，于是 Main.setting_data 变成 null 之后：音量没应用、窗口模式没应用，
	# 崩溃日志导出还会把 null 喂进 %.3f 格式化 —— 直接把进程打成 0xC0000005。
	# 现在读坏了只留默认值 + 把坏文件备份成 *.bad，玩家最多回到初始设置，不会连游戏都开不了
	var loaded_save = _read_resource(save_path)
	if loaded_save is SaveData:
		save_data = loaded_save
	var loaded_collection = _read_resource(collection_path)
	if loaded_collection is CollectionData:
		collection_data = loaded_collection
	var loaded_setting = _read_resource(setting_path)
	if loaded_setting is SettingData:
		setting_data = loaded_setting

	# 按存档把窗口摆到上次的位置。实测两个坑：
	#   1) 直接在 _ready 里设会被引擎在 autoload 加载期间自己摆的那次覆盖掉，所以等一帧
	#   2) 「第一帧」要等所有 autoload + 主场景 + 资源加载完才来，所以这段实际生效时间≈设置页 _ready，
	#      想让它更早只能靠 project 设置的 window_*_override（尺寸第一帧就对，位置不行）
	# 启动时只按存档应用、不记录：那会儿窗口不是玩家摆的，记下来会冲掉上次的窗口状态
	await get_tree().process_frame
	apply_window_mode(setting_data.fullscreen, false)

	#expression_dict = JSON.parse_string()

## 读一个 user:// 下的存档资源。
## 文件不存在 → null（调用方保持默认值，等于新玩家）。
## 文件存在但解析失败（半截写入 / 手改坏）→ 备份成 *.bad 并返回 null，
## 这样下一次启动不会一直读到坏档，玩家要找回数据也还能从 .bad 里捞
func _read_resource(path: String) -> Resource:
	if not FileAccess.file_exists(path):
		return null
	var loaded := ResourceLoader.load(path)
	if loaded != null:
		return loaded
	push_warning("%s 读取失败（文件可能写了一半），已备份为 .bad，本次使用默认值" % path)
	_backup_broken(path)
	return null


## 把读不出来的存档另存一份 *.bad 再从原位删掉，避免「每次启动都读坏档」
func _backup_broken(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	var backup := FileAccess.open(path + ".bad", FileAccess.WRITE)
	if backup != null:
		backup.store_buffer(bytes)
		backup.close()
	DirAccess.remove_absolute(path)

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

## 存档一律「先写 .tmp.tres，再改名覆盖」。
## 直接 ResourceSaver.save 到正式路径是「截断 + 边写边落盘」，玩家强退 / 崩溃 / 断电
## 正好落在写的半路，就会留下半截 .tres —— 下次启动 load() 解析失败，就是这次线上问题的起点。
## 临时文件后缀必须是 .tres，否则 ResourceSaver 不认格式
func _save_resource_atomic(resource: Resource, path: String) -> Error:
	if resource == null:
		return ERR_INVALID_PARAMETER
	var tmp_path := path.get_basename() + ".tmp.tres"
	var err := ResourceSaver.save(resource, tmp_path)
	if err != OK:
		DirAccess.remove_absolute(tmp_path)
		return err
	# Windows 的 rename 不覆盖已存在的目标文件，所以先删旧的。
	# 万一正好死在这两步之间，最坏结果是丢掉设置（下次按默认值起来），而不是读到坏档
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp_path, path)

func save_collection_data() -> void:
	var err := _save_resource_atomic(collection_data, collection_path)
	if err != OK:
		push_error("save_collection_data failed (%d): %s" % [err, collection_path])

func save_setting_data() -> void:
	if _setting_save_pending:
		return
	_setting_save_pending = true
	if _setting_save_thread and _setting_save_thread.is_started():
		_setting_save_thread.wait_to_finish()
	# 抓一份局部引用：写盘期间玩家可能又把 setting_data 换掉
	var data: SettingData = setting_data
	_setting_save_thread = Thread.new()
	_setting_save_thread.start(
		func():
			_save_resource_atomic(data, setting_path)
			_setting_save_pending = false
	)

func save_save_data() -> void:
	var err := _save_resource_atomic(save_data, save_path)
	if err != OK:
		push_error("save_save_data failed (%d): %s" % [err, save_path])

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
	var err := _save_resource_atomic(setting_data, setting_path)
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
