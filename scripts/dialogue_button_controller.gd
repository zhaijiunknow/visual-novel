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

## 所属剧情页（_ready 里用父链找到后存下来）
var _stage: StagePage

func _ready() -> void:
	# 用父链找自己所属的剧情页：绝不能读 Game.stage_page——剧情页正在被实例化时它的子节点
	# 会先 _ready，那时去读 Game.stage_page 会反过来触发创建（惰性实例化下无限递归）
	var stage := _find_stage_page()
	if stage == null:
		# 没有所属剧情页有两种情况：角色自带的对话框（离屏预览模板）是正常的，安静跳过；
		# 其余就是真配错了，报出来
		if not _has_character_ancestor():
			push_warning("[DialogueButtonController] 没找到所属的 StagePage")
		return
	_stage = stage
	button_skip.toggle_changed.connect(
		func ():
			stage.skip = button_skip.toggled
			button_auto.disabled = stage.skip
			# 只在真的变了时记：初始化时 disabled 的级联也会走到这里，那不是玩家操作
			if button_skip.toggled != _logged_skip:
				_logged_skip = button_skip.toggled
				print("[UI] 快进 %s → %s" % ["开" if _logged_skip else "关", Game.describe_state()])
	)
	stage.skip_cancelled.connect(
		func ():
			button_skip.toggled = false
	)
	# 跳过状态变化（含 Ctrl 键切换）：按钮的按下状态跟着状态走
	stage.skip_changed.connect(
		func (skipping: bool):
			button_skip.toggled = skipping
			button_auto.disabled = skipping
	)
	stage.auto_cancelled.connect(
		func ():
			button_auto.toggled = false
	)
	button_auto.toggle_changed.connect(
		func ():
			stage.autoplay = button_auto.toggled
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
		button.clicked.connect(stage.cancel_auto_and_skip)
	button_save.clicked.connect(Game.open_save)
	button_load.clicked.connect(Game.open_load)
	button_log.clicked.connect(stage.open_log_page)
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
	# 这几个动作都放在 Game 上：快捷键（主界面也要能用）和按钮共用同一份实现
	button_set.clicked.connect(Game.open_settings)
	button_voice.clicked.connect(Game.open_bonus_tab.bind(&"voice"))
	button_phone.clicked.connect(Game.open_phone)
	button_book.clicked.connect(Game.open_book)
	button_hide.clicked.connect(
		func (): stage.hide_dialogue_ui()
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


## 从父链往上找自己所属的 StagePage（对话框 prefab 就挂在剧情页里）
func _find_stage_page() -> StagePage:
	var node: Node = get_parent()
	while node != null:
		if node is StagePage:
			return node as StagePage
		node = node.get_parent()
	return null


## 自己是不是挂在角色自带的那份对话框里。
## characters/character.tscn 里也有一份 DialogueBox，但它只是**离屏预览模板**——
## character.gd 靠它的 preview_texture 取立绘贴图，它挂在 Stage 的 character_pool 下、
## 不属于任何页面，按钮也不该连信号。所以这种「找不到 StagePage」是预期内的，不用报错。
func _has_character_ancestor() -> bool:
	var node: Node = get_parent()
	while node != null:
		if node is Character:
			return true
		node = node.get_parent()
	return false
