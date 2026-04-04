extends Node

@export var page_pool: Node

@export var main_menu: MainMenu
@export var bonus_page: BonusPage
@export var stage_page: StagePage
@export var profile_page: ProfilePage
@export var travel_page: TravelPage
@export var book_page: BookPage
@export var log_page: LogPage
@export var phone_page: PhonePage
@export var setting_page: SettingPage
@export var loading_page: LoadingPage
@export var sv_container: SubViewportContainer

var current_page: CanvasLayer

var loading: bool:
	set(value):
		loading = value
		loading_page.visible = loading

func _ready() -> void:
	loading = false
	switch_to_page(main_menu, false, false)
	AudioManager.update_play()

# TASK
func switch_to_page(page: CanvasLayer, _transition: bool, addition_mode: bool, callable: Callable = func():pass):
	match page:
		_:
			if current_page != page:
				AudioManager.audio_player_bonus.playing = false
				AudioManager.play_theme()
	AudioManager.audio_player_bonus.playing = page == bonus_page
	AudioManager.audio_player_music.playing = page != bonus_page
	current_page = page
	if _transition:
		await fade(false)
		if not addition_mode:
			hide_all_pages()
		current_page.show()
		await fade(true)
		callable.call()
	
	

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
