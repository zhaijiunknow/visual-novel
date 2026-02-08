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
			Game.profile_page.show()
	)
	button_load.clicked.connect(
		func ():
			Main.profile_mode = Main.ProfileMode.LOAD
			Game.profile_page.show()
	)
	button_log.clicked.connect(
		func (): Game.log_page.show()
	)
	button_set.clicked.connect(
		func ():
			pass
	)
	button_phone.clicked.connect(
		func (): Game.phone_page.show()
	)
	button_book.clicked.connect(
		func (): Game.book_page.show()
	)
	button_title.clicked.connect(
		func ():
			Game.hide_all_pages()
			Game.main_menu.show()
	)
