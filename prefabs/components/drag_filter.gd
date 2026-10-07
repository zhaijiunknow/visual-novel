class_name DragFilter
extends Node

signal execute

## 光标离开按下点超过这么多像素才算「拖拽」，否则当成点击。
## 真人点击时鼠标几乎必然抖 1~3px —— 「有任何移动就算拖拽」会把这类点击全丢掉，
## 表现就是卡片/歌名「点了没反应」；而真要滚动列表时拖动幅度远大于这个值，门限不会误判。
const DRAG_THRESHOLD: float = 8.0

@export var target_object: Control

var _press_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	target_object.gui_input.connect(
		func (event: InputEvent):
			if event is InputEventMouseButton:
				var button := event as InputEventMouseButton
				if button.button_index == MOUSE_BUTTON_LEFT:
					if button.is_pressed():
						Main.clicked = true
						Main.dragged = false
						_press_position = button.global_position
					if button.is_released():
						if not Main.dragged and Main.clicked:
							emit_signal("execute")
						# 释放就清干净：以前只在「成功点击」那条分支里清 clicked，
						# 拖拽结束时 clicked 会一直是 true 留在全局状态里
						Main.clicked = false
						Main.dragged = false
			if event is InputEventMouseMotion:
				if Main.clicked:
					var motion := event as InputEventMouseMotion
					if motion.global_position.distance_to(_press_position) > DRAG_THRESHOLD:
						Main.dragged = true

	)
