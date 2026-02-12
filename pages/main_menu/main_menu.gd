class_name MainMenu
extends CanvasLayer

@export var particle: GPUParticles2D
@export var button_start: MainMenuButton
@export var button_load: MainMenuButton
@export var button_bonus: MainMenuButton
@export var button_book: MainMenuButton
@export var button_setting: MainMenuButton
@export var button_quit: MainMenuButton

func _ready() -> void:
	visibility_changed.connect(
		func ():
			particle.emitting = visible
	)
	
	button_start.clicked.connect(
		func ():
			hide()
			Stage.start()
	)
	button_load.clicked.connect(
		func ():
			Main.profile_mode = Main.ProfileMode.LOAD
			Game.profile_page.show()
	)
	button_bonus.clicked.connect(
		func ():
			Game.bonus_page.show()
	)
	button_book.clicked.connect(
		func (): Game.book_page.show()
	)
	button_setting.clicked.connect(
		func (): Game.setting_page.show()
	)
	button_quit.clicked.connect(
		func (): get_tree().quit()
	)
