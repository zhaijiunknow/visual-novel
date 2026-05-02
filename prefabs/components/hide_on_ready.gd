class_name HideOnReady
extends Node

@onready var target: Control = get_parent()

func _ready() -> void:
	target.hide()
