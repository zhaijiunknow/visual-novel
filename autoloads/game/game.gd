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

var loading: bool:
	set(value):
		loading = value
		loading_page.visible = loading

func _ready() -> void:
	loading = false
	hide_all_pages()
	main_menu.show()
	
	bonus_page.music_page.audio_player.play()
	
	stage_page.visibility_changed.connect(bonus_page.music_page.update_pause)

func hide_all_pages() -> void:
	for page: CanvasLayer in page_pool.get_children():
		page.layer = 1
		page.visible = false

func fade(fade_in: bool) -> void:
	var start_value = 20 if fade_in else 1
	var end_value = 1 if fade_in else 20
	
	await create_tween().tween_method(
		func(value): sv_container.material.set_shader_parameter("iterations", value),
		start_value, end_value, 0.4
	).finished
