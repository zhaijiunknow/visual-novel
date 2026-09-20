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

## 上次记过日志的跳过/自动状态，用来区分「玩家真的切了」和「初始化时的级联」
var _logged_skip: bool = false
var _logged_auto: bool = false

func _ready() -> void:
	button_skip.toggle_changed.connect(
		func ():
			Game.stage_page.skip = button_skip.toggled
			button_auto.disabled = Game.stage_page.skip
			# 只在真的变了时记：初始化时 disabled 的级联也会走到这里，那不是玩家操作
			if button_skip.toggled != _logged_skip:
				_logged_skip = button_skip.toggled
				print("[UI] 快进 %s → %s" % ["开" if _logged_skip else "关", Game.describe_state()])
	)
	Game.stage_page.skip_cancelled.connect(
		func ():
			button_skip.toggled = false
	)
	# 跳过状态变化（含 Ctrl 键切换）：按钮的按下状态跟着状态走
	Game.stage_page.skip_changed.connect(
		func (skipping: bool):
			button_skip.toggled = skipping
			button_auto.disabled = skipping
	)
	Game.stage_page.auto_cancelled.connect(
		func ():
			button_auto.toggled = false
	)
	button_auto.toggle_changed.connect(
		func ():
			Game.stage_page.autoplay = button_auto.toggled
			if button_auto.toggled != _logged_auto:
				_logged_auto = button_auto.toggled
				print("[UI] 自动 %s → %s" % ["开" if _logged_auto else "关", Game.describe_state()])
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
	button_log.clicked.connect(Game.stage_page.open_log_page)
	# 对话框那排按钮：谁被点了、点完停在哪
	for pair in [
		[button_save, "存档"], [button_load, "读档"], [button_log, "回想"], [button_set, "设置"],
		[button_voice, "语音鉴赏"], [button_phone, "手机"], [button_book, "奇迹书"],
		[button_hide, "隐藏对话框"], [button_title, "回标题"],
	]:
		var button: DialogueButton = pair[0]
		var label: String = pair[1]
		button.clicked.connect(
			func(): print("[UI] 对话框·%s → %s" % [label, Game.describe_state()]))
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
