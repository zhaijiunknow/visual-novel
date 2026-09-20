extends RefCounted

## 诊断包的组装：环境快照文本、路径脱敏、日志收集、zip 打包。
## 故意不写 class_name：诊断是 diagnostic.gd 私有的辅助类，用 preload 取更省事，
## 也不会因为编辑器还没重扫全局类缓存就报「Identifier not declared」。
## 全是静态函数、不碰场景树，方便单独调用和以后测试。
##
## 两个容易踩的点写在实现里：
##   1. 文件名时间戳不能用 Time.get_datetime_string_from_system()——它带 ':'，是 Windows 非法文件名字符
##   2. 引擎启动时会把上一份 godot.log 改名成 godot<时间戳>.log（轮转），
##      所以崩溃现场往往在「旧」文件里，导出必须收 logs 下的全部 .log

const DIR := "user://diagnostics"
const MARKER_PATH := DIR + "/run.lock"
const LOG_DIR := "user://logs"
const SETTING_FILE := "user://setting_data.tres"
const SNAPSHOT_NAME := "environment.txt"
const MANIFEST_NAME := "manifest.txt"
const SETTING_NAME := "setting_data.tres"


## YYYYMMDD_HHMMSS
static func make_stamp() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]


static func make_zip_path(kind: String, stamp: String) -> String:
	return "%s/%s_%s.zip" % [DIR, kind, stamp]


static func read_file_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


## user://logs 下全部 .log，按修改时间新→旧。
## 每一项：{name, path, bytes, size, modified, error}
static func collect_logs() -> Array[Dictionary]:
	var logs: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(LOG_DIR):
		return logs
	var paths: Array[String] = []
	for file_name in DirAccess.get_files_at(LOG_DIR):
		if file_name.get_extension().to_lower() == "log":
			paths.append(LOG_DIR + "/" + file_name)
	for path in paths:
		var bytes := read_file_bytes(path)
		logs.append({
			"name": path.get_file(),
			"path": path,
			"bytes": bytes,
			"size": bytes.size(),
			"modified": FileAccess.get_modified_time(path),
			"error": "" if not bytes.is_empty() else "读取为空（可能被引擎占用）",
		})
	logs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["modified"] > b["modified"])
	return logs


## 只脱敏快照文本：把用户名目录换掉。引擎日志本身实测不含用户名，原样打包才能保留路径线索
static func sanitize(text: String) -> String:
	var profile := OS.get_environment("USERPROFILE")
	if profile != "":
		text = text.replace(profile, "<用户目录>")
	var user_dir := OS.get_user_data_dir()
	if user_dir != "":
		text = text.replace(user_dir, "<用户目录>\\Godot\\app_userdata")
	return text


## zip 里每项：{name, bytes}
static func create_bundle(zip_path: String, files: Array[Dictionary]) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return err
	var writer := ZIPPacker.new()
	err = writer.open(zip_path)
	if err != OK:
		return err
	for file in files:
		if writer.start_file(file["name"]) != OK:
			writer.close()
			return ERR_CANT_CREATE
		writer.write_file(file["bytes"])
		writer.close_file()
	return writer.close()


static func build_manifest(kind: String, stamp: String, run_id: String,
		logs: Array[Dictionary], crash_info: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("诊断包清单")
	lines.append("导出类型: %s" % kind)
	lines.append("导出时间戳: %s" % stamp)
	lines.append("本次运行 ID: %s" % run_id)
	if crash_info.is_empty():
		lines.append("上次退出: 正常（没有残留标记）")
	else:
		lines.append("上次退出: 异常（残留标记如下，最可能是崩溃现场的那次运行）")
		lines.append(JSON.stringify(crash_info, "  "))
	lines.append("")
	lines.append("日志文件（新 → 旧；第 1 个是当前这次运行，崩溃现场通常在旧文件里）:")
	if logs.is_empty():
		lines.append("  （没有找到 %s 下的 .log）" % LOG_DIR)
	for i in logs.size():
		var log: Dictionary = logs[i]
		var note := "" if log["error"] == "" else "  [%s]" % log["error"]
		lines.append("  %d. %s  %d 字节%s" % [i + 1, log["name"], log["size"], note])
	return "\n".join(lines)


## 人类可读的环境快照。所有字段都做了容错（headless / 空页面栈下也不该崩）
static func build_snapshot_text(kind: String, stamp: String, run_id: String,
		started_at: String, crash_info: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("===== %s 诊断日志 =====" % ProjectSettings.get_setting("application/config/name", ""))
	lines.append("导出类型: %s" % kind)
	lines.append("导出时间: %s" % stamp)
	lines.append("本次运行: 开始于 %s，运行 ID %s" % [started_at, run_id])
	if not crash_info.is_empty():
		lines.append("上次运行异常退出，残留标记: %s" % JSON.stringify(crash_info))

	lines.append_array(_section("引擎"))
	var engine_info: Dictionary = Engine.get_version_info()
	lines.append("Godot: %s" % engine_info.get("string", ""))
	lines.append("游戏版本: %s" % ProjectSettings.get_setting("application/config/version", "未设置"))
	lines.append("渲染方式: %s" % RenderingServer.get_current_rendering_method())
	lines.append("调试构建: %s" % OS.is_debug_build())

	lines.append_array(_section("系统"))
	lines.append("OS: %s %s (%s)" % [OS.get_name(), OS.get_version(), OS.get_distribution_name()])
	lines.append("CPU: %s x%d" % [OS.get_processor_name(), OS.get_processor_count()])
	lines.append("内存占用: %.1f MB" % (OS.get_static_memory_usage() / 1048576.0))
	lines.append("区域/语言: %s" % OS.get_locale())

	lines.append_array(_section("显卡"))
	lines.append("适配器: %s" % RenderingServer.get_video_adapter_name())
	lines.append("厂商: %s" % RenderingServer.get_video_adapter_vendor())
	lines.append("类型: %s" % RenderingServer.get_video_adapter_type())
	lines.append("API 版本: %s" % RenderingServer.get_video_adapter_api_version())

	lines.append_array(_section("显示"))
	var screen := DisplayServer.window_get_current_screen()
	lines.append("显示服务: %s，屏幕数: %d，当前屏幕: %d" % [
		DisplayServer.get_name(), DisplayServer.get_screen_count(), screen])
	for i in DisplayServer.get_screen_count():
		lines.append("  屏幕 %d: %s，可用区 %s" % [
			i, DisplayServer.screen_get_size(i), DisplayServer.screen_get_usable_rect(i)])
	lines.append("窗口: %s @ %s，模式 %s" % [
		DisplayServer.window_get_size(), DisplayServer.window_get_position(),
		_window_mode_name(DisplayServer.window_get_mode())])
	lines.append("设置里记录的窗口化矩形: %s @ %s（全屏=%s）" % [
		Main.setting_data.windowed_size, Main.setting_data.windowed_position,
		Main.setting_data.fullscreen])

	lines.append_array(_section("页面"))
	lines.append("当前页: %s" % (Game.current_page.name if Game.current_page else "<无>"))
	lines.append("页面栈: %s" % " > ".join(_page_stack_names()))
	lines.append("加载中: %s" % Game.loading)

	lines.append_array(_section("剧情"))
	lines.append("章节: %s / %s" % [Stage.current_chapter_designation, Stage.current_chapter_title])
	lines.append("背景: %s，日期: %s，CG: %s（%s）" % [
		Stage.current_background, Stage.current_date, Stage.current_cg, Stage.current_cg_variation])
	lines.append("对白: %s" % JSON.stringify(Game.stage_page.get_bridge_dialogue_state()))
	lines.append("语音: %s" % Game.stage_page.voice_name)
	for line in _character_lines():
		lines.append(line)

	lines.append_array(_section("设置"))
	var s: SettingData = Main.setting_data
	lines.append("全屏=%s 未读跳过=%s 选项后继续=%s 忽略转场=%s 需要确认=%s" % [
		s.fullscreen, s.skip_unread, s.skip_after_choice, s.skip_ignore_transitions, s.need_confirmation])
	lines.append("文本速度=%.3f 自动速度=%.3f 跳过未读文本=%s 静音=%s" % [
		s.text_speed, s.auto_speed, s.skip_unread_text, s.mute_all])
	lines.append("音量: 音乐=%.3f 音效=%.3f 语音=%.3f" % [s.music_volume, s.sound_volume, s.voice_volume])
	lines.append("角色音量: %s" % JSON.stringify(s.character_volumes))

	lines.append_array(_section("音频"))
	var music := AudioManager.audio_player_music
	var voice := AudioManager.audio_player_voice
	lines.append("音乐: %s，播放中=%s，位置=%.1f" % [
		music.stream.resource_path if music.stream else "<无>",
		music.playing, music.get_playback_position() if music.playing else 0.0])
	lines.append("语音: 播放中=%s，名称=%s" % [voice.playing, Game.stage_page.voice_name])

	lines.append_array(_section("启动参数"))
	lines.append("引擎参数: %s" % str(OS.get_cmdline_args()))
	lines.append("用户参数: %s" % str(OS.get_cmdline_user_args()))

	lines.append_array(_section("user:// 文件（路径已脱敏）"))
	for line in _user_file_lines():
		lines.append(line)

	return sanitize("\n".join(lines))


static func _section(title: String) -> PackedStringArray:
	return PackedStringArray(["", "--- %s ---" % title])


static func _page_stack_names() -> Array[String]:
	var names: Array[String] = []
	for page in Game.page_stack:
		names.append(page.name)
	return names


static func _character_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for character: Character in Stage.character_array:
		var data: CharacterData = character.get_character_data()
		if data.position == "":
			continue
		lines.append("  角色 %s: %s/%s/%s/%s 表情=%s 位置=%s 附加=%s" % [
			data.character_name, data.body, data.eyebrows, data.eyes, data.mouth,
			character.current_expression, data.position, str(data.optionals)])
	return lines


static func _user_file_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for path in _user_file_paths():
		var size := 0
		if FileAccess.file_exists(path):
			size = FileAccess.get_file_as_bytes(path).size()
		lines.append("  %s  %d 字节  最后写入 %s" % [
			ProjectSettings.globalize_path(path), size,
			Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(path))])
	if lines.is_empty():
		lines.append("  （没有找到文件）")
	return lines


static func _user_file_paths() -> Array[String]:
	var paths: Array[String] = []
	for name in DirAccess.get_files_at("user://"):
		paths.append("user://" + name)
	for log in collect_logs():
		paths.append(log["path"])
	return paths


static func _window_mode_name(mode: int) -> String:
	match mode:
		DisplayServer.WINDOW_MODE_WINDOWED: return "窗口化"
		DisplayServer.WINDOW_MODE_MINIMIZED: return "最小化"
		DisplayServer.WINDOW_MODE_MAXIMIZED: return "最大化"
		DisplayServer.WINDOW_MODE_FULLSCREEN: return "全屏"
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: return "独占全屏"
	return "未知(%d)" % mode
