class_name HideOnReady
extends Node

@onready var target := get_parent()

func _ready() -> void:
	target.hide()
