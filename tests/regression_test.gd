extends Node

## 回归测试：坏档自愈 + 原子写盘 + 诊断包空引用安全
##
## 背景（2026-10 线上问题）：玩家的 user://setting_data.tres 被写成半截文件
##   → Main._ready 把 load() 返回的 null 直接赋给全局 setting_data
##   → 启动时自动导出崩溃日志的流程拿 null 去做 %.3f 格式化
##   → 进程 0xC0000005，而"上次异常退出"的标记又让下次启动必然再走一遍 → 连环崩。
## 这套测试盯的就是这条链上的每一环，任何一环退回去都会变红。
##
## 跑法（不需要第三方框架，headless 直跑，退出码 0=全绿 / 1=有失败）：
##   Godot_v4.6.2-stable_win64_console.exe --headless --path <项目目录> res://tests/regression_test.tscn
##
## 说明：这里直接调 Main._read_resource / Main._save_resource_atomic 这类下划线方法，
## 故意的 —— 它们就是这次修复的核心，回归测试必须钉在实现上，不能只测公开包装。
## 所有临时文件都放 user://tests_tmp/，跑完自动清掉，不碰玩家真实存档。

const DiagnosticBundle := preload("res://autoloads/diagnostic/diagnostic_bundle.gd")
const TMP_DIR := "user://tests_tmp"
const STAMP := "20260101_000000"
const RUN_ID := "regression-test"

var _passed := 0
var _failed := 0
var _failures: PackedStringArray = []


func _ready() -> void:
	print("\n===== 回归测试：坏档 / 原子写盘 / 诊断导出 =====")
	_prepare_tmp()

	_test_load_missing_file()
	_test_load_valid_file()
	_test_load_corrupt_file()
	_test_atomic_save()
	_test_stale_tmp_is_harmless()
	_test_atomic_save_refuses_null()
	_test_snapshot_without_settings()
	_test_bundle_without_settings()
	_test_snapshot_with_settings()

	_cleanup_tmp()
	_report()


#region 用例

## 文件不存在 = 新玩家：返回 null，什么都不该造
func _test_load_missing_file() -> void:
	_begin("文件不存在")
	var path := TMP_DIR + "/missing.tres"
	_check(Main._read_resource(path) == null, "返回 null（调用方保持默认值）")
	_check(not FileAccess.file_exists(path), "没有凭空创建文件")
	_check(not FileAccess.file_exists(path + ".bad"), "没有产生 .bad")


## 正常档：原样读出，不产生备份
func _test_load_valid_file() -> void:
	_begin("正常存档")
	var path := TMP_DIR + "/valid.tres"
	var data := SettingData.new()
	data.text_speed = 0.25
	_check(ResourceSaver.save(data, path) == OK, "准备：写出一个有效档")
	var loaded = Main._read_resource(path)
	_check(loaded is SettingData, "读回 SettingData")
	_check(is_equal_approx((loaded as SettingData).text_speed, 0.25), "内容没走样")
	_check(not FileAccess.file_exists(path + ".bad"), "没有多出 .bad")
	_check(FileAccess.file_exists(path), "原文件仍在原位")


## 半截档（线上就是这个）：不能返回给调用方 + 必须备份 + 必须从原位挪走。
## 关键点是「返回 null」而不是「返回一个坏对象」，以及「挪走」——否则每次启动都读同一个坏档
func _test_load_corrupt_file() -> void:
	_begin("半截（写坏的）存档")
	var path := TMP_DIR + "/corrupt.tres"
	var truncated := "[gd_resource type=\"Resource\" script_class=\"SettingData\" form".to_utf8_buffer()
	_write_bytes(path, truncated)
	_check(Main._read_resource(path) == null, "坏档不会被当成有效数据返回")
	_check(not FileAccess.file_exists(path), "坏档已从正式位置移走（下次启动等于新玩家）")
	_check(FileAccess.file_exists(path + ".bad"), "坏档备份成 .bad")
	_check(FileAccess.get_file_as_bytes(path + ".bad").size() == truncated.size(),
		"备份与坏档逐字节一致（玩家数据没被悄悄丢掉）")
	_check(Main._read_resource(path) == null, "再读一次（等价于重启）= 文件不存在，仍是 null")
	_check(not FileAccess.file_exists(path), "没有把坏档恢复回原位")


## 原子写：正式文件永远完整，不留临时文件
func _test_atomic_save() -> void:
	_begin("原子写盘")
	var path := TMP_DIR + "/atomic.tres"
	var data := SettingData.new()
	data.music_volume = 0.5
	_check(Main._save_resource_atomic(data, path) == OK, "写入返回 OK")
	_check(FileAccess.file_exists(path), "正式文件存在")
	_check(not FileAccess.file_exists(path.get_basename() + ".tmp.tres"), "没有 .tmp.tres 残留")
	var loaded = ResourceLoader.load(path)
	_check(loaded is SettingData, "写出来的文件能读回来")
	_check(is_equal_approx((loaded as SettingData).music_volume, 0.5), "读回来的值正确")


## 上次崩在"写 tmp 的半路"：残留的 .tmp.tres 不能影响下一次保存
func _test_stale_tmp_is_harmless() -> void:
	_begin("残留 .tmp.tres（上次写到一半崩了）")
	var path := TMP_DIR + "/recover.tres"
	_write_bytes(path.get_basename() + ".tmp.tres", "garbage-from-last-crash".to_utf8_buffer())
	_check(Main._save_resource_atomic(SettingData.new(), path) == OK, "下一次保存照常成功")
	_check(ResourceLoader.load(path) is SettingData, "正式文件可读（不是半截）")
	_check(not FileAccess.file_exists(path.get_basename() + ".tmp.tres"), "残留的 .tmp.tres 被清掉")


## 数据为 null 时绝不能碰磁盘：以前 ResourceSaver.save(null) 虽报错，
## 但现在要明确保证「正式文件字节不变」，因为写空=玩家设置全丢
func _test_atomic_save_refuses_null() -> void:
	_begin("写 null（数据没加载出来时）")
	var path := TMP_DIR + "/keep.tres"
	var data := SettingData.new()
	data.auto_speed = 0.75
	_check(Main._save_resource_atomic(data, path) == OK, "准备：先写一份好的")
	var before := FileAccess.get_file_as_bytes(path).size()
	_check(Main._save_resource_atomic(null, path) == ERR_INVALID_PARAMETER, "传 null 直接返回参数错误")
	_check(FileAccess.get_file_as_bytes(path).size() == before, "原文件一个字节都没动")
	_check(ResourceLoader.load(path) is SettingData, "原文件仍然可读")


## 这一条是这次线上崩溃的正身：setting_data 为 null 时生成环境快照。
## 老代码在这里直接读 Main.setting_data.xxx，null 一路进 %.3f 格式化 → 进程 0xC0000005。
## 如果谁把兜底删了，这里会直接把测试进程打死（测试失败），而不是悄悄返回空串
func _test_snapshot_without_settings() -> void:
	_begin("setting_data 为 null 时生成环境快照")
	var saved := Main.setting_data
	Main.setting_data = null
	var text := DiagnosticBundle.build_snapshot_text(
		"回归测试", STAMP, RUN_ID, "2026-01-01 00:00:00", {})
	Main.setting_data = saved
	_check(not text.is_empty(), "快照不是空字符串")
	_check(text.contains("设置: <setting_data.tres 读取失败"), "写明了设置读取失败")
	_check(text.contains("设置里记录的窗口化矩形: <setting_data 未加载>"), "窗口化矩形走兜底分支")
	_check(text.contains("--- 引擎 ---"), "其余段落照常输出（不是半截文本）")
	_check(text.contains("--- 内存 ---"), "内存段落也在")


## 同样的空引用，走完整打包流程：zip 要能出来，而且里面的 environment.txt 不能是 0 字节
## （线上最尴尬的一点就是崩溃时导出的包本身是残缺的，等于没有现场）
func _test_bundle_without_settings() -> void:
	_begin("setting_data 为 null 时打整包")
	var saved := Main.setting_data
	Main.setting_data = null
	var logs := DiagnosticBundle.collect_logs()
	var manifest := DiagnosticBundle.build_manifest("回归测试", STAMP, RUN_ID, logs, {})
	var snapshot := DiagnosticBundle.build_snapshot_text(
		"回归测试", STAMP, RUN_ID, "2026-01-01 00:00:00", {})
	Main.setting_data = saved

	var files: Array[Dictionary] = [
		{"name": DiagnosticBundle.MANIFEST_NAME, "bytes": manifest.to_utf8_buffer()},
		{"name": DiagnosticBundle.SNAPSHOT_NAME, "bytes": snapshot.to_utf8_buffer()},
	]
	var zip_path := TMP_DIR + "/bundle.zip"
	_check(DiagnosticBundle.create_bundle(zip_path, files) == OK, "zip 创建成功")
	var reader := ZIPReader.new()
	_check(reader.open(zip_path) == OK, "zip 能被打开")
	var env_bytes := reader.read_file(DiagnosticBundle.SNAPSHOT_NAME)
	_check(env_bytes.size() > 0, "包里的 environment.txt 非空")
	_check(env_bytes.get_string_from_utf8().contains("设置: <setting_data.tres 读取失败"),
		"包里的快照带上了失败原因（客服一眼能看出是坏档）")
	var manifest_bytes := reader.read_file(DiagnosticBundle.MANIFEST_NAME)
	_check(manifest_bytes.size() > 0, "包里的 manifest.txt 非空")
	reader.close()


## 正常设置时不能被兜底分支吞掉：数值该有的都得有
func _test_snapshot_with_settings() -> void:
	_begin("setting_data 正常时生成环境快照")
	var text := DiagnosticBundle.build_snapshot_text(
		"回归测试", STAMP, RUN_ID, "2026-01-01 00:00:00", {})
	_check(not text.is_empty(), "快照非空")
	_check(text.contains("文本速度="), "有文本速度")
	_check(text.contains("音量: 音乐="), "有音量")
	_check(text.contains("设置里记录的窗口化矩形: "), "有窗口化矩形")
	_check(not text.contains("setting_data.tres 读取失败"), "没有误报读取失败")

#endregion


#region 框架

func _begin(title: String) -> void:
	print("\n[", title, "]")


func _check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
		print("  OK   ", what)
	else:
		_failed += 1
		_failures.append(what)
		printerr("  FAIL ", what)


func _prepare_tmp() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	for file_name in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(TMP_DIR + "/" + file_name)


func _cleanup_tmp() -> void:
	if not DirAccess.dir_exists_absolute(TMP_DIR):
		return
	for file_name in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(TMP_DIR + "/" + file_name)
	DirAccess.remove_absolute(TMP_DIR)


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("测试准备失败，写不进去：%s" % path)
		return
	file.store_buffer(bytes)
	file.close()


func _report() -> void:
	print("\n================ 结果：通过 %d，失败 %d ================" % [_passed, _failed])
	for failure in _failures:
		printerr("  失败用例：", failure)
	# 退出码给 CI / 手动批处理用
	get_tree().quit(0 if _failed == 0 else 1)

#endregion
