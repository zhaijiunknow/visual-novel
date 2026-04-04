extends TextureButton

@export var with_transition: bool

func _ready() -> void:
	pressed.connect(
		func ():
			Game.go_back(with_transition)
	)
