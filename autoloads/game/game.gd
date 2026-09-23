extends Node

@export var page_pool: Node
@export var sv_container: SubViewportContainer
## 这两个不是「页面」（不在 page_pool 下），保持直接在场景里
@export var boot_splash: BootSplash
@export var chapter_transition: ChapterTransition

## 页面一律「用到才建」：开局只建 EAGER_PAGES 里那几个，其余首次访问 Game.xxx_page 时创建。
## 属性名保持不变（Game.stage_page 等），所以全项目 200 多处调用点一行都不用改。
const PAGE_SCENES := {
	&"main_menu": "res://pages/main_menu/main_menu.tscn",
	&"stage": "res://pages/stage_page/stage_page.tscn",
	&"bonus": "res://pages/bonus_page/bonus_page.tscn",
	&"profile": "res://pages/profile_page/profile_page.tscn",
	&"travel": "res://pages/travel_page/travel_page.tscn",
	&"book": "res://pages/book_page/book_page.tscn",
	&"log": "res://pages/log_page/log_page.tscn",
	&"phone": "res://pages/phone_page/phone_page.tscn",
	&"setting": "res://pages/setting_page/setting_page.tscn",
	&"confirm": "res://pages/confirm_page/confirm_page.tscn",
	&"loading": "res://pages/loading_page/loading_page.tscn",
}

## 开局就必须存在的三个页面：
##   log       —— _ready 里订阅了 DialogueManager.got_dialogue，建晚了会丢回想历史
##   main_menu —— 入口页
##   loading   —— 存档时会立刻用到，建晚了会在存档中途卡一下
const EAGER_PAGES: Array[StringName] = [&"log", &"main_menu", &"loading"]

var _pages: Dictionary = {}

var page_stack: Array[CanvasLayer] = []
var loading: bool = false

# 启动过场（社团 logo 淡入淡出）期间暂不自动播放主菜单 BGM，等过场结束再播
var _defer_menu_bgm := true

var current_page: CanvasLayer:
	get:
		return page_stack.back() if page_stack.size() > 0 else null

# ─── 惰性页面 ───────────────────────────────────────
# 自动触发的代码（日志、信号回调、输入处理）绝不能直接读 Game.xxx_page，
# 否则一开局就把页面全建出来、惰性化等于白做；那种地方用 get_page() / page_shown()。

var main_menu: MainMenu:
	get: return _ensure_page(&"main_menu") as MainMenu
var stage_page: StagePage:
	get: return _ensure_page(&"stage") as StagePage
var bonus_page: BonusPage:
	get: return _ensure_page(&"bonus") as BonusPage
var profile_page: ProfilePage:
	get: return _ensure_page(&"profile") as ProfilePage
var travel_page: TravelPage:
	get: return _ensure_page(&"travel") as TravelPage
var book_page: BookPage:
	get: return _ensure_page(&"book") as BookPage
var log_page: LogPage:
	get: return _ensure_page(&"log") as LogPage
var phone_page: PhonePage:
	get: return _ensure_page(&"phone") as PhonePage
var setting_page: SettingPage:
	get: return _ensure_page(&"setting") as SettingPage
var confirm_page: ConfirmPage:
	get: return _ensure_page(&"confirm") as ConfirmPage
var loading_page: LoadingPage:
	get: return _ensure_page(&"loading") as LoadingPage


## 惰性实例化的唯一入口
func _ensure_page(key: StringName) -> CanvasLayer:
	if _pages.has(key):
		return _pages[key]
	var scene: PackedScene = load(PAGE_SCENES[key])
	if scene == null:
		push_error("[Game] 页面场景加载失败：%s" % PAGE_SCENES[key])
		return null
	var page: CanvasLayer = scene.instantiate()
	page.layer = 1
	page.visible = false
	_apply_page_overrides(key, page)
	# 先登记再入树：页面的 _ready 里很可能又读 Game.xxx_page
	# （比如 profile_card._ready 会读 Game.profile_page）——那时必须拿到同一个实例，
	# 否则会再建一个、无限递归
	_pages[key] = page
	page_pool.add_child(page)
	return page


## 原来在 game.tscn 里对页面**实例**做的设置（逐实例覆盖）。惰性实例化是按场景裸建，
## 这些覆盖会丢，所以在这里补回来
func _apply_page_overrides(key: StringName, page: CanvasLayer) -> void:
	if key == &"phone":
		# 游戏里的手机不显示「自己」的头像（原来在 game.tscn 里覆盖成 null）
		var phone := page as PhonePage
		if phone != null:
			phone.self_avatar = null


## 已创建才返回（**不会**创建）。读页面状态用这个
func get_page(key: StringName) -> CanvasLayer:
	return _pages.get(key)


## 已创建且正在显示。判断某个浮层开着没有用这个
func page_shown(key: StringName) -> bool:
	var page: CanvasLayer = _pages.get(key)
	return page != null and page.visible


func _ready() -> void:
	_build_hotkeys()
	for key in EAGER_PAGES:
		_ensure_page(key)
	switch_to_page(main_menu, false, false)
	_play_boot_splash()

func _play_boot_splash() -> void:
	if boot_splash == null:
		# 防御：没有过场场景时正常立即播放
		_defer_menu_bgm = false
		update_audio()
		return
	boot_splash.play()
	boot_splash.finished.connect(_on_boot_splash_finished, CONNECT_ONE_SHOT)

func _on_boot_splash_finished() -> void:
	# logo 过场播完（或点击跳过）再播放主菜单 BGM
	_defer_menu_bgm = false
	update_audio()

func switch_to_page(page, _transition: bool, addition_mode: bool, callable: Callable = func():pass, transition_duration: float = 0.4):
	print("[Game] switch_to_page page=", page.name if page else "<null>", " transition=", _transition, " addition_mode=", addition_mode, " loading=", loading)
	if page == null:
		push_error("[Game] switch_to_page received null page")
		return
	if loading:
		print("[Game] switch_to_page aborted because loading is true")
		return
	loading = true

	# 注意：这里不能直接读 stage_page / confirm_page（会自动建页面）→ 用 get_page()
	var use_alpha = addition_mode and (page_stack.has(get_page(&"stage")) or page == get_page(&"confirm"))

	# 叠加+在游戏中：无前置过渡；其他：画面变黑
	if _transition and not use_alpha:
		await fade(false, transition_duration)

	if not addition_mode:
		hide_all_pages()
		page_stack.clear()

	page_stack.append(page)
	page.layer = page_stack.size()
	page.show()
	# 从剧情进入鉴赏（bonus 附加页）前，先存档剧情 BGM，避免被鉴赏选播顶替
	if page == get_page(&"bonus") and page_stack.has(get_page(&"stage")):
		AudioManager.save_story_music()
	update_audio()

	if _transition:
		callable.call()
		if use_alpha:
			await fade_alpha(page, true)
		else:
			await fade(true, transition_duration)
	else:
		callable.call()

	loading = false
	print("[UI] 打开 %s 完成 → %s" % [page.name, describe_state()])

## 给日志用的一行状态摘要：现在停在哪一页、页面栈、对话模式、当前行、还开着哪些浮层。
## 每次 UI 互动之后打一行，「我点了 X 之后就 Y 了」这种玩家反馈能直接对上号。
## 这里全程走 get_page()/page_shown()：没建的页面就是没显示，不去建它
func describe_state() -> String:
	var stage: StagePage = get_page(&"stage")
	var mode := "manual"
	if stage != null:
		if stage.skip:
			mode = "skip"
		elif stage.autoplay:
			mode = "auto"
	var overlays: PackedStringArray = []
	for pair in [[&"phone", "手机"], [&"book", "奇迹书"], [&"travel", "旅行"]]:
		if page_shown(pair[0]):
			overlays.append(pair[1])
	if chapter_transition != null and chapter_transition.visible:
		overlays.append("章节过场")
	# 在场角色：和调试桥同一套判据（有站位的才算上场）
	var on_stage := 0
	for character: Character in Stage.character_array:
		if character.get_character_data().position != "":
			on_stage += 1
	# 语音：正在播的是哪一条（"点了 B 但还在唱 A"要靠它和 [UI] 回放日志对不上才看得出来）
	var voice := "无"
	if AudioManager.audio_player_voice.playing and AudioManager.audio_player_voice.stream:
		voice = AudioManager.audio_player_voice.stream.resource_path.get_file()
	var line_id := "<未创建>"
	var dialogue_box := "<未创建>"
	if stage != null:
		line_id = stage.dialogue_line.id if stage.dialogue_line else "<无>"
		if stage.dialogue_screen != null:
			dialogue_box = "隐藏(%.2f)" % stage.dialogue_screen.modulate.a \
				if stage.dialogue_screen.modulate.a < 0.99 else "显示"
	return "page=%s stack=[%s] loading=%s 模式=%s 行=%s 浮层=%s 窗口=%s 对话框=%s 在场角色=%d 语音=%s" % [
		current_page.name if current_page else "<无>",
		" > ".join(_page_stack_names()),
		loading,
		mode,
		line_id,
		"、".join(overlays) if overlays.size() > 0 else "无",
		Main.window_description(),
		dialogue_box,
		on_stage,
		voice,
	]

func _page_stack_names() -> Array[String]:
	var names: Array[String] = []
	for page in page_stack:
		names.append(page.name)
	return names


## ─── 面板快捷键 ───
## 放在 Game 而不是对话框按钮那边：按钮挂在剧情页里，而页面是「用到才建」的 ——
## 主界面时剧情页还没创建，那些按钮节点根本不存在，快捷键就没人响应。
## 动作和对话框那排按钮调同一份（见 scripts/dialogue_button_controller.gd）。
## 表项：[键, 面板名, 显示名, 动作, 只在剧情页]。
## 面板名是 ASCII 的，给调试桥用（LocalhostBridge 的 game.open_panel）
const BONUS_TAB_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]

var _panel_hotkeys: Dictionary = {}
var _panel_key_by_id: Dictionary = {}

func _build_hotkeys() -> void:
	for entry in [
		# 存档要剧情里的进度、手机要剧情里的聊天数据，主界面打开都没意义，所以标 true
		[KEY_S, "save", "存档", open_save, true],
		[KEY_L, "load", "读档", open_load, false],
		[KEY_1, "character", "立绘鉴赏", open_bonus_tab.bind(&"character"), false],
		[KEY_2, "gallery", "插画鉴赏", open_bonus_tab.bind(&"gallery"), false],
		[KEY_3, "music", "音乐鉴赏", open_bonus_tab.bind(&"music"), false],
		[KEY_4, "voice", "语音鉴赏", open_bonus_tab.bind(&"voice"), false],
		[KEY_P, "phone", "手机", open_phone, true],
		[KEY_B, "book", "奇迹书", open_book, false],
		[KEY_G, "settings", "设置", open_settings, false],
	]:
		_panel_hotkeys[entry[0]] = [entry[2], entry[3], entry[4]]
		_panel_key_by_id[entry[1]] = entry[0]


## 调试桥（LocalhostBridge 的 game.open_panel）用：按面板名打开，
## 走的是和快捷键完全同一条路 —— 门禁、清自动/快进、日志都一样，
## 所以桥接测出来的行为和按键盘等价。
## 返回 false = 当前状态不允许（等于按了没反应），或者名字不认识
func open_panel_by_name(panel_name: String) -> bool:
	var keycode: int = _panel_key_by_id.get(panel_name, KEY_NONE)
	if keycode == KEY_NONE:
		return false
	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	key_event.pressed = true
	return _handle_panel_hotkey(key_event)


## 面板快捷键。返回 true = 这次按键已经处理掉了。
## 只在「顶层」响应：主界面、剧情页；鉴赏页里额外放行 1~4（用来切 tab，省得去点）。
## 其他情况（存档/设置/手机盖在上面）一律不响应，免得又叠一层。
func _handle_panel_hotkey(key_event: InputEventKey) -> bool:
	if loading:
		return false
	var entry: Array = _panel_hotkeys.get(key_event.keycode, [])
	if entry.is_empty():
		return false
	var hotkey_name: String = entry[0]
	var action: Callable = entry[1]
	var story_only: bool = entry[2]
	var page := current_page
	var on_stage := page != null and page == get_page(&"stage")
	var on_menu := page != null and page == get_page(&"main_menu")
	var in_bonus := page != null and page == get_page(&"bonus")
	if not (on_stage or on_menu or (in_bonus and key_event.keycode in BONUS_TAB_KEYS)):
		return false
	# 标了「只在剧情页」的那两个（存档 / 手机）在主界面按了没意义：没有进度可存、也没有聊天数据
	if story_only and not on_stage:
		return false
	# 和点对话框按钮一样：先把自动/快进清掉，免得页面盖上来剧情还在后台推进
	var stage: StagePage = get_page(&"stage") as StagePage
	if stage != null:
		stage.cancel_auto_and_skip()
	print("[UI] 快捷键·%s → %s" % [hotkey_name, describe_state()])
	action.call()
	get_viewport().set_input_as_handled()
	return true


func open_save() -> void:
	_open_profile(Main.ProfileMode.SAVE)

func open_load() -> void:
	_open_profile(Main.ProfileMode.LOAD)

func _open_profile(mode: Main.ProfileMode) -> void:
	Main.profile_mode = mode
	switch_to_page(profile_page, true, true)

func open_settings() -> void:
	switch_to_page(setting_page, true, true)

func open_phone() -> void:
	phone_page.open(false)

func open_book() -> void:
	switch_to_page(book_page, true, true)


## 需要确认的操作统一走这里：设置里开着「需要确认」就先弹二级确认框、点确认才执行 action，
## 关掉就直接执行。剧情页「返回主菜单」和主菜单「退出游戏」共用这一份。
## 取消＝退回上一层（ConfirmPage 的默认 on_cancel 就是 Game.go_back()），右键返回也一样。
## title 目前只是透传（确认框的标题是美术图，见 confirm_page.tscn 的 TitleTexture）
func confirm_or_run(title: String, message: String, action: Callable) -> void:
	if Main.setting_data.need_confirmation:
		confirm_page.show_confirm(title, message, action)
		switch_to_page(confirm_page, true, true)
	else:
		action.call()


## 跳到鉴赏页的某个 tab。已经在鉴赏页时只切 tab、不重复压栈。
## tab_key 沿用 bonus_page 里 TabItem 的 lazy_page_name（character/gallery/music/voice）。
## 这里才碰 bonus_page —— 表的构建不碰，所以开局不会把鉴赏页建出来
func open_bonus_tab(tab_key: StringName) -> void:
	var page := bonus_page
	var tab: TabItem = null
	match tab_key:
		&"character": tab = page.start_tab_item
		&"gallery": tab = page.tab_gallery
		&"music": tab = page.tab_music
		&"voice": tab = page.tab_voice
	if tab == null:
		push_warning("[Game] 找不到鉴赏 tab：%s" % tab_key)
		return
	tab.select()
	if current_page != page:
		switch_to_page(page, true, true)


## Esc：关闭各种菜单。
## 压在 page_stack 上的叠加页（设置/存档/书/回想/奖励/确认框）就是 go_back()——
## 它自带 loading 和「只剩底层页」的保护，所以主菜单按 Esc 什么都不会发生。
## 剧情页是所有东西的「底」，Esc 绝不能把它弹掉（弹掉会回标题并清空回想记录），
## 所以先单独处理盖在剧情页上、又不在 page_stack 里的那几样（手机/旅行/章节过场卡）。
func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if _handle_panel_hotkey(key_event):
		return
	if key_event.keycode != KEY_ESCAPE or loading:
		return
	var stage := get_page(&"stage")
	if stage != null and current_page == stage:
		if page_shown(&"travel") or (chapter_transition != null and chapter_transition.visible):
			# 这两个由剧情自己收（旅行页按确认、章节卡点一下就过），Esc 只吃掉不做事
			get_viewport().set_input_as_handled()
			return
		if page_shown(&"phone"):
			var phone: PhonePage = get_page(&"phone") as PhonePage
			# 剧情里的手机和「点背景」一样不让关
			if phone != null and not phone.story_mode:
				phone.close()
			get_viewport().set_input_as_handled()
			return
		return
	if page_stack.size() > 1:
		go_back()
		get_viewport().set_input_as_handled()


func go_back(_transition: bool = true):
	print("[Game] go_back transition=", _transition, " loading=", loading, " stack_size=", page_stack.size(), " current=", current_page.name if current_page else "<null>")
	if loading or page_stack.size() <= 1:
		print("[Game] go_back aborted loading=", loading, " stack_size=", page_stack.size())
		return

	loading = true

	var old_page = page_stack.pop_back()
	var use_alpha = page_stack.has(get_page(&"stage")) or old_page == get_page(&"confirm")

	if _transition:
		if use_alpha:
			await fade_alpha(old_page, false)
		else:
			await fade(false)

	old_page.visible = false

	current_page.show()
	update_audio()

	if _transition and not use_alpha:
		await fade(true)

	loading = false
	print("[UI] 返回 %s 完成 → %s" % [
		current_page.name if current_page else "<无>", describe_state()])

func update_audio():
	var stage := get_page(&"stage")
	if stage == null or not page_stack.has(stage):
		AudioManager.audio_player_voice.stop()
		# 页面没建就是没东西要清，不主动创建它们
		if stage != null:
			stage.cancel_auto_and_skip()
		var phone := get_page(&"phone")
		if phone != null:
			phone.clear_all()
		var logp := get_page(&"log")
		if logp != null:
			logp.clear_all()
		if page_stack.has(get_page(&"main_menu")):
			if not _defer_menu_bgm and AudioManager._music_source != AudioManager.MusicSource.THEME:
				AudioManager.play_theme()
		return
	# 回到剧情页：恢复进鉴赏前存档的剧情 BGM（鉴赏期间没动过则不打断）
	if current_page == stage:
		AudioManager.restore_story_music()
	if current_page == get_page(&"bonus"):
		return
	# 从主菜单进入 StagePage：停止主题音乐（游戏 BGM 由对话控制）
	if current_page == stage and AudioManager._music_source == AudioManager.MusicSource.THEME:
		AudioManager.audio_player_music.stop()
		AudioManager._music_source = AudioManager.MusicSource.NONE

func hide_all_pages() -> void:
	for page: CanvasLayer in page_pool.get_children():
		page.layer = 1
		page.visible = false

# 画面变黑过渡
func fade(fade_in: bool, duration: float = 0.4) -> void:
	var start_iteration = 1 if fade_in else 0
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	await tween.tween_method(
		func(value):
			var modifier = -1 if fade_in else 1
			sv_container.material.set_shader_parameter("iterations", start_iteration + (value * modifier)),
		0.0, 1.0, duration
	).finished

# alpha过渡（用于叠加页面）
func fade_alpha(page: CanvasLayer, fade_in: bool) -> void:
	var from_a = 0.0 if fade_in else 1.0
	var to_a = 1.0 if fade_in else 0.0
	var canvas_children: Array[CanvasItem] = []
	for child in page.get_children():
		if child is CanvasItem:
			canvas_children.append(child)
	for child in canvas_children:
		child.modulate.a = from_a
	var tween = create_tween()
	tween.set_parallel(true)
	for child in canvas_children:
		tween.tween_property(child, "modulate:a", to_a, 0.3)
	await tween.finished
	# 淡出后重置 alpha，避免下次非 alpha 方式打开时子节点不可见
	if not fade_in:
		for child in canvas_children:
			child.modulate.a = 1.0

func transition(callable: Callable):
	await fade(false)
	callable.call()
	await fade(true)
