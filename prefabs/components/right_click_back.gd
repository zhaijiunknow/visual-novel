class_name RightClickBack
extends Node

## 鼠标右键 = 返回（等价于按一下 Esc）。
##
## 挂在 game.tscn 的 SubViewport 下，和 Pages 平级。**必须挂在 SubViewport 里面**：
##   · Game._unhandled_input 收不到鼠标。根视图下 SubViewportContainer 的 mouse_filter 是默认的 STOP，
##     鼠标事件在根这一层就被它吃了，到不了 _unhandled_input（键盘没这问题，所以 Esc 一直好使）。
##   · Game._input 也收不到。SubViewport 是 handle_input_locally = false，子视图里被吃掉的「已处理」
##     会往上冒到根视图，根视图派发 _input 的循环在轮到 Game 之前就断了；而各页面的全屏背景板
##     （setting / profile / log / phone / bonus / travel 的根 Control）正好是 STOP，会把右键吃掉。
##   反过来挂在 SubViewport 里就稳了：本视图的 _input 早于本视图的 GUI 派发，
##   背景板吃没吃掉都不影响这里先拿到事件。
##
## 为什么是「合成一个 Esc」而不是直接调 Game.go_back()：
## 返回是分层的 —— 鉴赏大图要先把大图收回卡片（再按一次才关面板）、回想页只在滚到底时才退出、
## 旅行页和剧情里的手机由剧情自己收。这些层级现在都挂在各自的 Esc 处理里，事件在树里自下而上派发，
## 谁先拿到谁说了算。合成 Esc 等于让右键白蹭这套派发，不必把层级再抄一遍、也不会日后走岔。
##
## 不消费右键事件：剧情页右键收起对话框、主菜单「开始游戏」右键继续，这两个原有含义保持不动
## （它们和 Esc 不重叠，所以不会互相打架）。

func _input(event: InputEvent) -> void:
	if Game.loading:
		return
	var mouse_event := event as InputEventMouseButton
	# 只在按下时触发（抬起那半会再来一次，不然一次右键返回两层）
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	print("[UI] 右键·返回 → %s" % Game.describe_state())
	_send_escape()


## 合成一次 Esc（按下 + 抬起），走的是和真键盘完全同一条输入管线
## （Input.parse_input_event → 各视图派发 _input / GUI / _unhandled_input），
## 所以右键和 Esc 的行为不会分叉 —— 同 Game.open_panel_by_name「造事件复用同一条路」的做法。
func _send_escape() -> void:
	for pressed: bool in [true, false]:
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_ESCAPE
		key_event.physical_keycode = KEY_ESCAPE
		key_event.pressed = pressed
		Input.parse_input_event(key_event)
