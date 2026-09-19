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
@export var button_hide: DialogueButton
@export var button_title: DialogueButton

func _ready() -> void:
	button_skip.toggle_changed.connect(
		func ():
			Game.stage_page.skip = button_skip.toggled
			button_auto.disabled = Game.stage_page.skip
	)
	Game.stage_page.skip_cancelled.connect(
		func ():
			button_skip.toggled = false
	)
	Game.stage_page.auto_cancelled.connect(
		func ():
			button_auto.toggled = false
	)
	button_auto.toggle_changed.connect(
		func ():
			Game.stage_page.autoplay = button_auto.toggled
	)
	# 除快进/自动本身之外，对话框上的按钮点下去一律清掉自动/快进状态。
	# 它们都会盖一层界面（手机/存档/读档/回想/设置/收藏/奇迹书/标题/隐藏UI），
	# 不清的话剧情会在后台接着推进，语音还会去抢共用的 audio_player_voice。
	# 连在各自的动作之前，保证清状态发生在页面打开前。
	for button: DialogueButton in [
		button_save, button_load, button_log, button_set, button_voice,
		button_phone, button_book, button_hide, button_title,
	]:
		button.clicked.connect(Game.stage_page.cancel_auto_and_skip)
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
		func ():
			Game.bonus_page.tab_voice.select()
			Game.switch_to_page(Game.bonus_page, true, true)
	)
	button_phone.clicked.connect(
		func(): Game.phone_page.open(false)
	)
	button_book.clicked.connect(
		func (): Game.switch_to_page(Game.book_page, true, true)
	)
	button_hide.clicked.connect(
		func (): Game.stage_page.hide_dialogue_ui()
	)
	button_title.clicked.connect(
		func ():
			if Main.setting_data.need_confirmation:
				Game.confirm_page.show_confirm(
					"特别提醒",
					"确定要回到标题界面吗？\n未保存的进度将要丢失。",
					func (): Game.switch_to_page(Game.main_menu, true, false)
				)
				Game.switch_to_page(Game.confirm_page, true, true)
			else:
				Game.switch_to_page(Game.main_menu, true, false)
	)
