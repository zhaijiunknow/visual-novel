extends Node

@export var page_pool: Node
@export var main_menu: MainMenu
@export var loading_page: LoadingPage
@export var sv_container: SubViewportContainer

const PAGE_SCENES = {
	"bonus_page": "res://pages/bonus_page/bonus_page.tscn",
	"stage_page": "res://pages/stage_page/stage_page.tscn",
	"profile_page": "res://pages/profile_page/profile_page.tscn",
	"travel_page": "res://pages/travel_page/travel_page.tscn",
	"book_page": "res://pages/book_page/book_page.tscn",
	"log_page": "res://pages/log_page/log_page.tscn",
	"phone_page": "res://pages/phone_page/phone_page.tscn",
	"setting_page": "res://pages/setting_page/setting_page.tscn",
}

var _page_cache: Dictionary = {}

func _get_or_load_page(key: String) -> CanvasLayer:
	if not _page_cache.has(key):
		var path = PAGE_SCENES[key]
		var scene: PackedScene
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			scene = ResourceLoader.load_threaded_get(path)
		else:
			scene = load(path)
		var instance = scene.instantiate()
		instance.visible = false
		_page_cache[key] = instance
		page_pool.add_child(instance)
	return _page_cache[key]

var bonus_page: BonusPage:
	get: return _get_or_load_page("bonus_page")

var stage_page: StagePage:
	get: return _get_or_load_page("stage_page")

var profile_page: ProfilePage:
	get: return _get_or_load_page("profile_page")

var travel_page: TravelPage:
	get: return _get_or_load_page("travel_page")

var book_page: BookPage:
	get: return _get_or_load_page("book_page")

var log_page: LogPage:
	get: return _get_or_load_page("log_page")

var phone_page: PhonePage:
	get: return _get_or_load_page("phone_page")

var setting_page: SettingPage:
	get: return _get_or_load_page("setting_page")

var page_stack: Array[CanvasLayer] = []

var current_page: CanvasLayer:
	get:
		return page_stack.back() if page_stack.size() > 0 else null

var loading: bool:
	set(value):
		loading = value
		loading_page.visible = loading

func _ready() -> void:
	loading = false
	switch_to_page(main_menu, false, false)
	for path in PAGE_SCENES.values():
		ResourceLoader.load_threaded_request(path)

func switch_to_page(page: CanvasLayer, _transition: bool, addition_mode: bool, callable: Callable = func():pass):
	if _transition:
		await fade(false)

	if not addition_mode:
		hide_all_pages()
		page_stack.clear()

	page_stack.append(page)
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

func _is_cached_page(key: String) -> bool:
	return _page_cache.has(key) and current_page == _page_cache[key]

func update_audio():
	if _is_cached_page("bonus_page"):
		AudioManager.audio_player_music.stop()
		if not AudioManager.audio_player_bonus.playing:
			AudioManager.audio_player_bonus.play()
		AudioManager.audio_player_bonus.stream_paused = false
	else:
		AudioManager.audio_player_bonus.stream_paused = true
		if not _is_cached_page("stage_page"):
			AudioManager.play_theme()

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
