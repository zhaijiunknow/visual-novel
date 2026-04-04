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

var page_stack: Array[CanvasLayer] = []
var loading: bool = false

var current_page: CanvasLayer:
	get:
		return page_stack.back() if page_stack.size() > 0 else null

func _ready() -> void:
	switch_to_page(main_menu, false, false)
	AudioManager.play_theme()

func switch_to_page(page, _transition: bool, addition_mode: bool, callable: Callable = func():pass):
	if _transition:
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
		await fade(true)
	else:
		callable.call()

func go_back(_transition: bool = true):
	if page_stack.size() <= 1:
		return

	if _transition:
		await fade(false)

	var old_page = page_stack.pop_back()
	old_page.visible = false

	current_page.show()
	update_audio()

	if _transition:
		await fade(true)

func update_audio():
	var came_from_menu: bool = page_stack.size() >= 2 and page_stack[-2] == main_menu

	if current_page == bonus_page:
		AudioManager.audio_player_music.stop()
		if AudioManager.audio_player_bonus.stream_paused:
			AudioManager.audio_player_bonus.stream_paused = false
		elif not AudioManager.audio_player_bonus.playing:
			AudioManager.audio_player_bonus.play()
	else:
		AudioManager.audio_player_bonus.stream_paused = true
		if current_page == stage_page:
			AudioManager.audio_player_music.stop()
		elif came_from_menu:
			if AudioManager.audio_player_music.stream != AudioManager.theme_music or not AudioManager.audio_player_music.playing:
				AudioManager.play_theme()
		else:
			AudioManager.audio_player_music.stop()

func hide_all_pages() -> void:
	for page: CanvasLayer in page_pool.get_children():
		page.layer = 1
		page.visible = false

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

func transition(callable: Callable):
	await fade(false)
	callable.call()
	await fade(true)
