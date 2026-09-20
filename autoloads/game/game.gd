extends Node

@export var page_pool: Node
@export var main_menu: MainMenu
@export var sv_container: SubViewportContainer
@export var bonus_page: BonusPage
@export var stage_page: StagePage
@export var profile_page: ProfilePage
@export var travel_page: TravelPage
@export var book_page: BookPage
@export var log_page: LogPage
@export var phone_page: PhonePage
@export var setting_page: SettingPage
@export var confirm_page: ConfirmPage
@export var loading_page: LoadingPage
@export var boot_splash: BootSplash
@export var chapter_transition: ChapterTransition

var page_stack: Array[CanvasLayer] = []
var loading: bool = false

# 启动过场（社团 logo 淡入淡出）期间暂不自动播放主菜单 BGM，等过场结束再播
var _defer_menu_bgm := true

var current_page: CanvasLayer:
	get:
		return page_stack.back() if page_stack.size() > 0 else null

func _ready() -> void:
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

	var use_alpha = addition_mode and (stage_page in page_stack or page == confirm_page)

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
	if page == bonus_page and stage_page in page_stack:
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
## 每次 UI 互动之后打一行，「我点了 X 之后就 Y 了」这种玩家反馈能直接对上号
func describe_state() -> String:
	var mode := "manual"
	if stage_page.skip:
		mode = "skip"
	elif stage_page.autoplay:
		mode = "auto"
	var overlays: PackedStringArray = []
	for pair in [[phone_page, "手机"], [book_page, "奇迹书"], [travel_page, "旅行"], [chapter_transition, "章节过场"]]:
		if pair[0] != null and pair[0].visible:
			overlays.append(pair[1])
	# 在场角色：和调试桥同一套判据（有站位的才算上场）
	var on_stage := 0
	for character: Character in Stage.character_array:
		if character.get_character_data().position != "":
			on_stage += 1
	# 语音：正在播的是哪一条（"点了 B 但还在唱 A"要靠它和 [UI] 回放日志对不上才看得出来）
	var voice := "无"
	if AudioManager.audio_player_voice.playing and AudioManager.audio_player_voice.stream:
		voice = AudioManager.audio_player_voice.stream.resource_path.get_file()
	return "page=%s stack=[%s] loading=%s 模式=%s 行=%s 浮层=%s 窗口=%s 对话框=%s 在场角色=%d 语音=%s" % [
		current_page.name if current_page else "<无>",
		" > ".join(_page_stack_names()),
		loading,
		mode,
		stage_page.dialogue_line.id if stage_page.dialogue_line else "<无>",
		"、".join(overlays) if overlays.size() > 0 else "无",
		Main.window_description(),
		"隐藏(%.2f)" % stage_page.dialogue_screen.modulate.a if stage_page.dialogue_screen.modulate.a < 0.99 else "显示",
		on_stage,
		voice,
	]

func _page_stack_names() -> Array[String]:
	var names: Array[String] = []
	for page in page_stack:
		names.append(page.name)
	return names


## Esc：关闭各种菜单。
## 压在 page_stack 上的叠加页（设置/存档/书/回想/奖励/确认框）就是 go_back()——
## 它自带 loading 和「只剩底层页」的保护，所以主菜单按 Esc 什么都不会发生。
## 剧情页是所有东西的「底」，Esc 绝不能把它弹掉（弹掉会回标题并清空回想记录），
## 所以先单独处理盖在剧情页上、又不在 page_stack 里的那几样（手机/旅行/章节过场卡）。
func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_ESCAPE or loading:
		return
	if current_page == stage_page:
		if travel_page.visible or chapter_transition.visible:
			# 这两个由剧情自己收（旅行页按确认、章节卡点一下就过），Esc 只吃掉不做事
			get_viewport().set_input_as_handled()
			return
		if phone_page.visible:
			# 剧情里的手机和「点背景」一样不让关
			if not phone_page.story_mode:
				phone_page.close()
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
	var use_alpha = stage_page in page_stack or old_page == confirm_page

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
	if stage_page not in page_stack:
		AudioManager.audio_player_voice.stop()
		stage_page.cancel_auto_and_skip()
		phone_page.clear_all()
		log_page.clear_all()
		if main_menu in page_stack:
			if not _defer_menu_bgm and AudioManager._music_source != AudioManager.MusicSource.THEME:
				AudioManager.play_theme()
		return
	# 回到剧情页：恢复进鉴赏前存档的剧情 BGM（鉴赏期间没动过则不打断）
	if current_page == stage_page:
		AudioManager.restore_story_music()
	if current_page == bonus_page:
		return
	# 从主菜单进入 StagePage：停止主题音乐（游戏 BGM 由对话控制）
	if current_page == stage_page and AudioManager._music_source == AudioManager.MusicSource.THEME:
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
