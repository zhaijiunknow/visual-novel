class_name BootSplash
extends CanvasLayer
# 启动时社团 logo 淡入淡出过场：淡入 → 停留 → 淡出，露出下方主菜单
# 由 Game 调用 play()，播完（finished）后再播放主菜单 BGM；点击可跳过

signal finished

const SKIP_FADE_DURATION := 0.15

@export_range(0.0, 3.0, 0.1) var fade_in_duration: float = 0.8
@export_range(0.0, 5.0, 0.1) var hold_duration: float = 1.2
@export_range(0.0, 3.0, 0.1) var fade_out_duration: float = 0.8

@onready var root: Control = $Root
@onready var logo_rect: TextureRect = $Root/Logo

var _finished := false

func _ready() -> void:
	# 初始为纯背景色盖住主菜单，logo 透明，避免闪帧；由 Game 调用 play()
	logo_rect.modulate.a = 0.0
	root.modulate.a = 1.0
	$Root.gui_input.connect(_on_root_gui_input)

func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip()

func play() -> void:
	# 淡入
	var fade_in := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	fade_in.tween_property(logo_rect, "modulate:a", 1.0, fade_in_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	if _finished:
		return

	# 停留（点击可跳过）
	await get_tree().create_timer(hold_duration).timeout
	if _finished:
		return

	# 淡出
	var fade_out := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	fade_out.tween_property(root, "modulate:a", 0.0, fade_out_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished
	if _finished:
		return
	_finish()

func _skip() -> void:
	if _finished:
		return
	# 直接跳过：加速淡出，立刻露出主菜单
	var quick := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	quick.tween_property(root, "modulate:a", 0.0, SKIP_FADE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await quick.finished
	_finish()

func _finish() -> void:
	if _finished:
		return
	hide()
	_finished = true
	finished.emit()
