class_name InteractSound
extends Node

## 挂到任何 Control 节点下，自动在点击/悬停时播放音效。
## 通过 AudioManager.audio_player_sound 共享同一个播放器。
## 如果不指定 target，默认使用父节点。

@export var target: Control
@export var click_sound: AudioStream
@export var hover_sound: AudioStream

func _ready() -> void:
	if not target:
		target = get_parent() as Control
	if not target:
		return
	target.gui_input.connect(_on_gui_input)
	target.mouse_entered.connect(_on_mouse_entered)


func _play_sound(s: AudioStream) -> void:
	AudioManager.audio_player_sound.stream = s
	AudioManager.audio_player_sound.play()


func _on_gui_input(event: InputEvent) -> void:
	if not click_sound:
		return
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			_play_sound(click_sound)


func _on_mouse_entered() -> void:
	if hover_sound:
		_play_sound(hover_sound)
