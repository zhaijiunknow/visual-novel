extends CanvasLayer

@export var button_play_audio: Button
@export var label_line_id: Label

func _ready() -> void:
	button_play_audio.pressed.connect(
		func ():
			#AudioManager.play_voice("余洛琛_0_1_1")
			print(Stage.main_dialogue.lines["0"])
	)
	
	#while Stage.resou
	
	#Game.main_menu.button_start.clicked.emit()
