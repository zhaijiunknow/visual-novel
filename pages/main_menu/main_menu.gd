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
		func():
			particle.emitting = visible
	)

	button_start.clicked.connect(
		func():
			var interact_sound := button_start.get_node("InteractSound") as InteractSound
			var sound_len: float = interact_sound.click_sound.get_length() if interact_sound and interact_sound.click_sound else 0.4
			var fade_dur: float = sound_len / 2.0
			Game.book_page.reset_notebook()
			Game.switch_to_page(Game.stage_page, true, false, Stage.start, fade_dur)
	)
	button_load.clicked.connect(
		func():
			Main.profile_mode = Main.ProfileMode.LOAD
			Game.switch_to_page(Game.profile_page, true, true)
	)
	button_bonus.clicked.connect(
		func():
			Game.switch_to_page(Game.bonus_page, true, true)
	)
	button_book.clicked.connect(
		func():
			Game.switch_to_page(Game.book_page, true, true)
	)
	button_setting.clicked.connect(
		func():
			Game.switch_to_page(Game.setting_page, true, true)
	)
	button_quit.clicked.connect(
		func(): get_tree().quit()
	)
