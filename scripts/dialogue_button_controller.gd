extends Node

@export var button_skip: DialogueButton
@export var button_auto: DialogueButton
@export var button_save: DialogueButton
@export var button_load: DialogueButton
@export var button_log: DialogueButton
@export var button_set: DialogueButton
@export var button_voice: DialogueButton
@export var button_phone: DialogueButton
@export var button_book: DialogueButton
@export var button_title: DialogueButton

func _ready() -> void:
	button_skip.toggle_changed.connect(
		func ():
			Game.stage_page.skip = button_skip.toggled
			button_auto.disabled = Game.stage_page.skip
	)
	button_auto.toggle_changed.connect(
		func ():
			Game.stage_page.autoplay = button_auto.toggled
	)
	button_save.clicked.connect(
		func ():
			Main.profile_mode = Main.ProfileMode.SAVE
			Game.switch_to_page(Game.profile_page, true, true)
	)
	button_load.clicked.connect(
		func ():
			Main.profile_mode = Main.ProfileMode.LOAD
			Game.switch_to_page(Game.profile_page, true, true)
	)
	button_log.clicked.connect(
		func (): Game.switch_to_page(Game.log_page, true, true)
	)
	button_set.clicked.connect(
		func (): Game.switch_to_page(Game.setting_page, true, true)
	)
	button_voice.clicked.connect(
		func (): Game.switch_to_page(Game.bonus_page, true, true)
	)
	button_phone.clicked.connect(
		func (): Game.switch_to_page(Game.phone_page, true, true)
	)
	button_book.clicked.connect(
		func (): Game.switch_to_page(Game.book_page, true, true)
	)
	button_title.clicked.connect(
		func (): Game.switch_to_page(Game.main_menu, true, true)
	)
