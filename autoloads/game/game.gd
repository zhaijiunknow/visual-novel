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
@export var bgm_player: AudioStreamPlayer

@onready var eq: AudioEffectEQ = AudioServer.get_bus_effect(0, 0)

var loading: bool:
	set(value):
		loading = value
		loading_page.visible = loading

func _ready() -> void:
	loading = false
	hide_all_pages()
	main_menu.show()
	
	stage_page.visibility_changed.connect(update_pause)

func update_pause():
	bgm_player.stream_paused = stage_page.visible


func hide_all_pages() -> void:
	for page: CanvasLayer in page_pool.get_children():
		page.layer = 1
		page.visible = false


func fade(fade_in: bool) -> void:
	var start_iteration = 20 if fade_in else 1
	var start_db = -60 if fade_in else 0
	await create_tween().tween_method(
		func(value):
			var modifier = -1 if fade_in else 1
			var add = 19 * value * modifier
			var db_add = 60 * value * -modifier
			for i in range(2, 4):
				eq.set_band_gain_db(i, start_db + db_add)
			sv_container.material.set_shader_parameter("iterations", start_iteration + add),
		0.0, 1.0, 0.4
	).finished

func transition(callable: Callable):
	await fade(false)
	callable.call()
	await fade(true)
