class_name TextSpeedPreview
extends TextureRect

@export var preview_text: String = "这是一段用于预览文字显示速度的示例文本。当你调整滑块时，这里的文字会以对应的速度逐字显示。"
@export var loop_delay: float = 1.5
@export var dialogue_label: DialogueLabel


func _ready() -> void:
	if dialogue_label:
		dialogue_label.finished_typing.connect(_on_typing_finished)
	_start_preview()


func _start_preview() -> void:
	if not dialogue_label:
		return
	var line := DialogueLine.new()
	line.text = preview_text
	dialogue_label.dialogue_line = line
	dialogue_label.type_out()


func _on_typing_finished() -> void:
	await get_tree().create_timer(loop_delay).timeout
	_start_preview()


func set_speed(seconds_per_step: float) -> void:
	if dialogue_label:
		dialogue_label.seconds_per_step = seconds_per_step

