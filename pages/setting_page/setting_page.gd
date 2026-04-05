class_name SettingPage
extends CanvasLayer

const CHARACTER_CARD_SCENE = preload("res://prefabs/character_voice_card/character_voice_card.tscn")

const CHAR_TEXTURES := {
	"余洛琛": {
		normal = preload("res://assets/sprites/ui/ui.sprites/chr_yu_normal.tres"),
		hover = preload("res://assets/sprites/ui/ui.sprites/chr_yu_hover.tres"),
		selected = preload("res://assets/sprites/ui/ui.sprites/chr_yu_seleted.tres"),
	},
	"常夏": {
		normal = preload("res://assets/sprites/ui/ui.sprites/chr_xia.tres"),
		hover = preload("res://assets/sprites/ui/ui.sprites/chr_xia.tres"),
		selected = preload("res://assets/sprites/ui/ui.sprites/chr_chang_selected.tres"),
	},
	"葛城": {
		normal = preload("res://assets/sprites/ui/ui.sprites/chr_ge_normal.tres"),
		hover = preload("res://assets/sprites/ui/ui.sprites/chr_ge_hover.tres"),
		selected = preload("res://assets/sprites/ui/ui.sprites/chr_ge_selected.tres"),
	},
	"辉夜奏": {
		normal = preload("res://assets/sprites/ui/ui.sprites/chr_kaguya_normal.tres"),
		hover = preload("res://assets/sprites/ui/ui.sprites/chr_kaguya_hover.tres"),
		selected = preload("res://assets/sprites/ui/ui.sprites/chr_kaguya_selected.tres"),
	},
	"其他": {
		normal = preload("res://assets/sprites/ui/ui.sprites/chr_others_normal.tres"),
		hover = preload("res://assets/sprites/ui/ui.sprites/chr_others_hover.tres"),
		selected = preload("res://assets/sprites/ui/ui.sprites/chr_others_selected.tres"),
	},
}

@export var start_tab_item: TabItem

# System page controls
@export var btn_screen_fullscreen: SelectionButton
@export var btn_screen_window: SelectionButton
@export var btn_skip_unread: SelectionButton
@export var btn_skip_after_choice: SelectionButton
@export var btn_skip_ignore_transitions: SelectionButton
@export var btn_confirmation_on: SelectionButton
@export var btn_confirmation_off: SelectionButton
@export var btn_skip_unread_text_on: SelectionButton
@export var btn_skip_unread_text_off: SelectionButton
@export var text_speed_preview: TextureRect
@export var auto_speed_preview: TextureRect

@export var slider_text_speed: SliderEx
@export var slider_auto_speed: SliderEx

# Audio page controls
@export var slider_music_volume: SliderEx
@export var slider_sound_volume: SliderEx
@export var slider_master_voice_volume: SliderEx
@export var slider_character_voice_volume: SliderEx
@export var character_voice_card_container: HBoxContainer
@export var btn_mute_on: SelectionButton
@export var btn_mute_off: SelectionButton

var selected_character: String = ""

func _ready() -> void:
	if not character_voice_card_container:
		character_voice_card_container = get_node_or_null("Pages/AudioPage/Controls/CharacterVoiceCards")
	_create_character_voice_cards()
	start_tab_item.select()
	_load_settings()
	_connect_signals()

func _create_character_voice_cards() -> void:
	for char_name in CHAR_TEXTURES:
		var card: CharacterVoiceCard = CHARACTER_CARD_SCENE.instantiate()
		card.character_name = char_name
		var tex = CHAR_TEXTURES[char_name]
		card.texture_normal_state = tex.normal
		card.texture_hover_state = tex.hover
		card.texture_selected_state = tex.selected
		character_voice_card_container.add_child(card)

func _load_settings() -> void:
	var s = Main.setting_data

	# System
	_select_exclusive(btn_screen_fullscreen, btn_screen_window, s.fullscreen)
	if s.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_select_exclusive(btn_confirmation_on, btn_confirmation_off, s.need_confirmation)
	_select_exclusive(btn_skip_unread_text_on, btn_skip_unread_text_off, s.skip_unread)
	btn_skip_unread.selected = s.skip_unread_text
	btn_skip_after_choice.selected = s.skip_after_choice
	btn_skip_ignore_transitions.selected = s.skip_ignore_transitions
	slider_text_speed.set_value_silent(s.text_speed)
	text_speed_preview.set_speed(0.05 - s.text_speed * 0.048)
	auto_speed_preview.set_speed(0.05 - s.auto_speed * 0.048)
	slider_auto_speed.set_value_silent(s.auto_speed)

	# Audio
	slider_music_volume.set_value_silent(s.music_volume)
	slider_sound_volume.set_value_silent(s.sound_volume)
	slider_master_voice_volume.set_value_silent(s.voice_volume)

	if s.mute_all:
		_select_exclusive(btn_mute_on, btn_mute_off, true)
	else:
		_select_exclusive(btn_mute_on, btn_mute_off, false)

	# Initialize character volumes with defaults
	var characters := ["余洛琛", "常夏", "葛城", "辉夜奏", "其他"]
	for char_name in characters:
		if not s.character_volumes.has(char_name):
			s.character_volumes[char_name] = 1.0

	# Select first character voice card
	if character_voice_card_container.get_child_count() > 0:
		var first_card = character_voice_card_container.get_child(0) as CharacterVoiceCard
		if first_card:
			_select_character_card(first_card)

	AudioManager.apply_settings(s)

func _connect_signals() -> void:
	# Screen
	_connect_selection_pair(btn_screen_fullscreen, btn_screen_window,
		func(): _set_fullscreen(true),
		func(): _set_fullscreen(false)
	)

	# Confirmation
	_connect_selection_pair(btn_confirmation_on, btn_confirmation_off,
		func(): _set_setting("need_confirmation", true),
		func(): _set_setting("need_confirmation", false)
	)

	# Skip unread text
	_connect_selection_pair(btn_skip_unread_text_on, btn_skip_unread_text_off,
		func(): _set_setting("skip_unread", true),
		func(): _set_setting("skip_unread", false)
	)

	# Skip conditions (multi-select)
	_connect_selection_click(btn_skip_unread, func(): _toggle_skip_condition("skip_unread_text", btn_skip_unread))
	_connect_selection_click(btn_skip_after_choice, func(): _toggle_skip_condition("skip_after_choice", btn_skip_after_choice))
	_connect_selection_click(btn_skip_ignore_transitions, func(): _toggle_skip_condition("skip_ignore_transitions", btn_skip_ignore_transitions))

	# Sliders
	slider_text_speed.value_changed.connect(func(_v): _set_setting("text_speed", slider_text_speed.value); text_speed_preview.set_speed(0.05 - slider_text_speed.value * 0.048); Main.speed_settings_changed.emit())
	slider_auto_speed.value_changed.connect(func(_v): _set_setting("auto_speed", slider_auto_speed.value); auto_speed_preview.set_speed(0.05 - slider_auto_speed.value * 0.048); Main.speed_settings_changed.emit())
	slider_music_volume.value_changed.connect(func(_v): _apply_audio())
	slider_sound_volume.value_changed.connect(func(_v): _apply_audio())
	slider_master_voice_volume.value_changed.connect(func(_v): _apply_audio())
	slider_character_voice_volume.value_changed.connect(func(_v): _apply_character_volume())

	# Mute
	_connect_selection_pair(btn_mute_on, btn_mute_off,
		func(): _set_setting("mute_all", true); _apply_audio(),
		func(): _set_setting("mute_all", false); _apply_audio()
	)

	# Character voice cards
	for card in character_voice_card_container.get_children():
		if card is CharacterVoiceCard:
			card.character_selected.connect(_select_character_card)

	# Reset
	var reset_btn: TextureButton = get_node_or_null("Pages/AudioPage/Controls/ResetButton")
	if reset_btn:
		reset_btn.pressed.connect(_reset_settings)

#region Helpers

func _select_exclusive(btn_on: SelectionButton, btn_off: SelectionButton, value: bool) -> void:
	btn_on.selected = value
	btn_off.selected = not value

func _connect_selection_click(btn: SelectionButton, fn: Callable) -> void:
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			fn.call()
	)

func _connect_selection_pair(btn_on: SelectionButton, btn_off: SelectionButton, on_fn: Callable, off_fn: Callable) -> void:
	_connect_selection_click(btn_on, func():
		_select_exclusive(btn_on, btn_off, true)
		on_fn.call()
	)
	_connect_selection_click(btn_off, func():
		_select_exclusive(btn_on, btn_off, false)
		off_fn.call()
	)

func _toggle_skip_condition(key: String, btn: SelectionButton) -> void:
	btn.selected = not btn.selected
	Main.setting_data.set(key, btn.selected)
	Main.save_setting_data()

func _set_setting(key: String, value) -> void:
	Main.setting_data.set(key, value)
	Main.save_setting_data()

func _set_fullscreen(fullscreen: bool) -> void:
	_set_setting("fullscreen", fullscreen)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_audio() -> void:
	var s = Main.setting_data
	s.music_volume = slider_music_volume.value
	s.sound_volume = slider_sound_volume.value
	s.voice_volume = slider_master_voice_volume.value
	Main.save_setting_data()
	AudioManager.apply_settings(s)

func _apply_character_volume() -> void:
	if selected_character == "": return
	Main.setting_data.character_volumes[selected_character] = slider_character_voice_volume.value
	Main.save_setting_data()
	AudioManager.apply_settings(Main.setting_data)

func _select_character_card(card: CharacterVoiceCard) -> void:
	for c in character_voice_card_container.get_children():
		if c is CharacterVoiceCard:
			c.selected = (c == card)
	selected_character = card.character_name
	var vol = Main.setting_data.character_volumes.get(selected_character, 1.0)
	slider_character_voice_volume.set_value_silent(vol)

func _reset_settings() -> void:
	Main.setting_data = SettingData.new()
	Main.save_setting_data()
	_load_settings()

#endregion
