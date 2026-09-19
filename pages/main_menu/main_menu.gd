class_name MainMenu
extends CanvasLayer

@export var particle: GPUParticles2D
@export var button_start: MainMenuButton
@export var button_load: MainMenuButton
@export var button_bonus: MainMenuButton
@export var button_book: MainMenuButton
@export var button_setting: MainMenuButton
@export var button_quit: MainMenuButton

func _ready() -> void:
	visibility_changed.connect(
		func():
			particle.emitting = visible
			if visible:
				_update_start_button()
	)
	_update_start_button()

	button_start.clicked.connect(_start_new_game)
	button_start.continue_requested.connect(_continue_game)
	button_load.clicked.connect(
		func():
			Main.profile_mode = Main.ProfileMode.LOAD
			Game.switch_to_page(Game.profile_page, true, true)
	)
	button_bonus.clicked.connect(
		func():
			Game.switch_to_page(Game.bonus_page, true, true)
	)
	button_book.clicked.connect(
		func():
			Game.switch_to_page(Game.book_page, true, true)
	)
	button_setting.clicked.connect(
		func():
			Game.switch_to_page(Game.setting_page, true, true)
	)
	button_quit.clicked.connect(
		func(): get_tree().quit()
	)

func _unhandled_input(event: InputEvent) -> void:
	# 主菜单是唯一能敲作弊码的地方（LocalhostBridge 的调试服务由它开关）
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo or key_event.unicode < 32:
		return
	LocalhostBridge.feed_cheat_key(char(key_event.unicode))

func _start_new_game() -> void:
	var interact_sound := button_start.get_node("InteractSound") as InteractSound
	var sound_len: float = interact_sound.click_sound.get_length() if interact_sound and interact_sound.click_sound else 0.4
	var fade_dur: float = sound_len / 2.0
	Game.book_page.reset_notebook()
	Game.switch_to_page(Game.stage_page, true, false, Stage.start, fade_dur)

func _continue_game() -> void:
	if not Game.profile_page or not Game.profile_page.has_continue_save():
		_start_new_game()
		return
	Game.profile_page.load_continue_game()

func _update_start_button() -> void:
	if Game.profile_page and Game.profile_page.has_continue_save():
		button_start.set_titles("开始游戏", "Start / 右键继续")
	else:
		button_start.set_titles("开始游戏", "Start Game")
