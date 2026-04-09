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

var page_stack: Array[CanvasLayer] = []
var loading: bool = false

var current_page: CanvasLayer:
	get:
		return page_stack.back() if page_stack.size() > 0 else null

func _ready() -> void:
	switch_to_page(main_menu, false, false)

func switch_to_page(page, _transition: bool, addition_mode: bool, callable: Callable = func():pass):
	if loading:
		return
	loading = true

	var use_alpha = addition_mode and (stage_page in page_stack or page == confirm_page)

	# 叠加+在游戏中：无前置过渡；其他：画面变黑
	if _transition and not use_alpha:
		await fade(false)

	if not addition_mode:
		hide_all_pages()
		page_stack.clear()

	page_stack.append(page)
	page.layer = page_stack.size()
	page.show()
	update_audio()

	if _transition:
		callable.call()
		if use_alpha:
			await fade_alpha(page, true)
		else:
			await fade(true)
	else:
		callable.call()

	loading = false

func go_back(_transition: bool = true):
	if loading or page_stack.size() <= 1:
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

func update_audio():
	if stage_page not in page_stack:
		AudioManager.audio_player_voice.stop()
		stage_page._set_mode(stage_page.AdvanceMode.MANUAL)
		phone_page.clear_all()
		log_page.clear_all()
	if current_page == bonus_page:
		return
	if current_page == stage_page:
		AudioManager.audio_player_music.stop()
	elif main_menu in page_stack and stage_page not in page_stack:
		if AudioManager._music_source != AudioManager.MusicSource.THEME:
			AudioManager.play_theme()
	else:
		AudioManager.audio_player_music.stop()

func hide_all_pages() -> void:
	for page: CanvasLayer in page_pool.get_children():
		page.layer = 1
		page.visible = false

# 画面变黑过渡
func fade(fade_in: bool) -> void:
	var start_iteration = 1 if fade_in else 0
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	await tween.tween_method(
		func(value):
			var modifier = -1 if fade_in else 1
			sv_container.material.set_shader_parameter("iterations", start_iteration + (value * modifier)),
		0.0, 1.0, 0.4
	).finished

# alpha过渡（用于叠加页面）
func fade_alpha(page: CanvasLayer, fade_in: bool) -> void:
	var from_a = 0.0 if fade_in else 1.0
	var to_a = 1.0 if fade_in else 0.0
	for child: CanvasItem in page.get_children():
		child.modulate.a = from_a
	var tween = create_tween()
	tween.set_parallel(true)
	for child: CanvasItem in page.get_children():
		tween.tween_property(child, "modulate:a", to_a, 0.3)
	await tween.finished
	# 淡出后重置 alpha，避免下次非 alpha 方式打开时子节点不可见
	if not fade_in:
		for child: CanvasItem in page.get_children():
			child.modulate.a = 1.0

func transition(callable: Callable):
	await fade(false)
	callable.call()
	await fade(true)
