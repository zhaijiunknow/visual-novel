extends Node

## 内测用的诊断日志导出。
## 任意页面按 E → 把「引擎日志 + 环境快照 + 设置文件」打成 zip，弹出所在文件夹并把路径复制到剪贴板；
## 启动时若发现上次留下的运行标记（= 上次没正常退出），自动导出那一份日志，并用确认框告诉玩家路径。
##
## 正式版把 ENABLED 改成 false 就整块关掉（不写标记、不响应按键）。

const DiagnosticBundle := preload("res://autoloads/diagnostic/diagnostic_bundle.gd")

const ENABLED := true
const EXPORT_KEY := KEY_E
const KIND_MANUAL := "诊断日志"
const KIND_CRASH := "崩溃日志"

var _exporting := false
var _run_id := ""
var _started_at := ""
var _previous_crash: Dictionary = {}


func _ready() -> void:
	if not ENABLED:
		return
	# 先读上次的标记、再写这次的：顺序反了就把上次的现场覆盖掉了
	_previous_crash = _read_marker()
	_write_marker()
	# 编辑器里按停止按钮 = 硬杀进程，标记必然残留；开发时不要每次都弹「上次异常退出」
	if not _previous_crash.is_empty() and not OS.has_feature("editor"):
		_export_previous_crash_log()


func _unhandled_input(event: InputEvent) -> void:
	if not ENABLED or _exporting:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != EXPORT_KEY:
		return
	# 故意不 set_input_as_handled()：主菜单的作弊码 "neko" 里也有个 e，别把它吃掉。
	# 代价是在主菜单敲作弊码时会多导出一个包，无伤大雅
	_export(KIND_MANUAL)


func _exit_tree() -> void:
	# 正常退出（菜单退出 / 点窗口 X / Alt+F4）都会走到这里；硬杀和崩溃不会 —— 正是标记需要的语义
	_clear_marker()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_clear_marker()


## 导出诊断包，返回系统绝对路径；失败返回空串
func _export(kind: String) -> String:
	_exporting = true
	var stamp: String = DiagnosticBundle.make_stamp()
	var zip_path: String = DiagnosticBundle.make_zip_path(kind, stamp)
	var logs: Array[Dictionary] = DiagnosticBundle.collect_logs()
	var files: Array[Dictionary] = [
		{
			"name": DiagnosticBundle.MANIFEST_NAME,
			"bytes": DiagnosticBundle.build_manifest(
				kind, stamp, _run_id, logs, _previous_crash).to_utf8_buffer(),
		},
		{
			"name": DiagnosticBundle.SNAPSHOT_NAME,
			"bytes": DiagnosticBundle.build_snapshot_text(
				kind, stamp, _run_id, _started_at, _previous_crash).to_utf8_buffer(),
		},
	]
	var setting_bytes: PackedByteArray = DiagnosticBundle.read_file_bytes(DiagnosticBundle.SETTING_FILE)
	if not setting_bytes.is_empty():
		files.append({"name": DiagnosticBundle.SETTING_NAME, "bytes": setting_bytes})
	for log in logs:
		if not log["bytes"].is_empty():
			files.append({"name": log["name"], "bytes": log["bytes"]})

	var err: Error = DiagnosticBundle.create_bundle(zip_path, files)
	_exporting = false
	if err != OK:
		push_error("[Diagnostic] 导出失败(%d)：%s" % [err, zip_path])
		return ""

	# shell_show_in_file_manager 和剪贴板都不认 user:// 协议，必须先转成系统路径
	var abs_path: String = ProjectSettings.globalize_path(zip_path)
	printerr("[Diagnostic] 已导出 %s" % abs_path)
	DisplayServer.clipboard_set(abs_path)
	OS.shell_show_in_file_manager(abs_path, true)
	return abs_path


## 上次没正常退出：把上一份日志导出（_export 会顺便弹出文件夹 + 复制路径）。
## 不弹任何页面——内测只要拿到日志文件就行
func _export_previous_crash_log() -> void:
	var splash := Game.boot_splash
	if splash != null and splash.visible:
		# 等启动过场播完再动手，免得文件夹弹在社团 logo 上
		await splash.finished
	await get_tree().process_frame
	_export(KIND_CRASH)


#region 运行标记（判断上次是否异常退出）

func _write_marker() -> void:
	_run_id = "%d-%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]
	_started_at = Time.get_datetime_string_from_system(false, true)
	var marker := {
		"run_id": _run_id,
		"started_at": _started_at,
		"engine": Engine.get_version_info().get("string", ""),
		"pid": OS.get_process_id(),
	}
	DirAccess.make_dir_recursive_absolute(DiagnosticBundle.DIR)
	var file := FileAccess.open(DiagnosticBundle.MARKER_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[Diagnostic] 运行标记写不进去，异常退出检测不可用")
		return
	file.store_string(JSON.stringify(marker, "\t"))


## 返回空字典 = 上次正常退出；非空 = 上次的标记还在（内容尽量解析，解析不了也照样算异常退出）
func _read_marker() -> Dictionary:
	if not FileAccess.file_exists(DiagnosticBundle.MARKER_PATH):
		return {}
	var file := FileAccess.open(DiagnosticBundle.MARKER_PATH, FileAccess.READ)
	if file == null:
		return {"note": "标记文件存在但读不出来"}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {"note": "标记文件内容不是合法 JSON（可能是写标记的过程中崩的）"}


func _clear_marker() -> void:
	if FileAccess.file_exists(DiagnosticBundle.MARKER_PATH):
		DirAccess.remove_absolute(DiagnosticBundle.MARKER_PATH)

#endregion
