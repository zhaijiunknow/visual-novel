@tool
extends EditorPlugin

var dock
var main_panel

func _enter_tree() -> void:
	dock = preload("res://addons/expression_editor/dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
	main_panel = dock.get_node("MainPanel")
	main_panel.plugin = self

func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()

func _has_main_screen() -> bool:
	return false

func _make_visible(visible: bool) -> void:
	if dock:
		dock.visible = visible

## 刷新编辑器（当表情数据变化时调用）
func refresh() -> void:
	if main_panel:
		main_panel.refresh_expressions()

## 通知场景中的角色更新（当需要时）
func notify_character_update(character_name: String, expression_name: String) -> void:
	# 可以在这里发送信号通知场景中的角色更新
	print("角色表情已更新: ", character_name, " - ", expression_name)
