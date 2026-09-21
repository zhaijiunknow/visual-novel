class_name MusicPage
extends Control

@export var track_item_scene: PackedScene
@export var play_progress_container: Control
@export var play_progress_line: PlayProgressLine
@export var play_progress_line_ghost: PlayProgressLine
@export var progress_hint: Control
@export var play_button: TextureButton
@export var pause_button: TextureButton
@export var next_button: TextureButton
@export var previous_button: TextureButton
@export var vbox_playlist: VBoxContainer
@export var label_title: Label
@export var richlabel_description: RichTextLabel
@export var label_current_time: Label
@export var label_total_time: Label

var audio_player: AudioStreamPlayer:
	get:
		return AudioManager.audio_player_music

var progress_hovered: bool:
	set(value):
		progress_hovered = value
		progress_hint.modulate.a = 1.0 if not progress_hovered else 0.6
		play_progress_line_ghost.visible = progress_hovered

var button_pressed: bool:
	set(value):
		button_pressed = value
		if button_pressed:
			progress_hovered = false

func _ready() -> void:
	set_process_input(false)
	set_physics_process(false)
	visibility_changed.connect(func():
		set_process_input(visible)
		set_physics_process(visible)
	)
	for music_data in AudioManager.playlist:
		var track_item: TrackItem = track_item_scene.instantiate()
		track_item.music_data = music_data
		vbox_playlist.add_child(track_item)
	
	AudioManager.track_index_changed.connect(update_track_info)
	# 这三个动作按钮和键盘（左右/空格）共用，见下面
	play_button.pressed.connect(_toggle_play)
	pause_button.pressed.connect(_toggle_play)
	next_button.pressed.connect(_next_track)
	previous_button.pressed.connect(_previous_track)
	play_progress_container.mouse_entered.connect(
		func (): progress_hovered = true
	)
	play_progress_container.mouse_exited.connect(
		func (): progress_hovered = false
	)
	play_progress_container.gui_input.connect(
		func (event: InputEvent):
			var ratio: float = event.position.x \
			/ play_progress_container.size.x
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if event.is_pressed():
						button_pressed = true
						AudioManager.set_track_position_by_ratio(ratio)
			
			if event is InputEventMouseMotion:
				if button_pressed:
					AudioManager.set_track_position_by_ratio(ratio)
					progress_hovered = false
					progress_hint.global_position = play_progress_line.endpoint.global_position
				else:
					progress_hovered = true
					play_progress_line_ghost.set_progress(ratio)
	)
	progress_hovered = false
	update_track_info()

var music_tab_selected: bool:
	get:
		return Main.bonus_tab_index == get_index()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_released():
				button_pressed = false


## 上一首 / 下一首（按钮和左右键共用）。track_index 的 setter 自带循环，越界会绕回去
func _previous_track() -> void:
	AudioManager.track_index -= 1
	AudioManager.play_track()

func _next_track() -> void:
	AudioManager.track_index += 1
	AudioManager.play_track()


## 播放/暂停切换（播放键、暂停键、空格共用）。
## 播放键只在没播时可见、暂停键只在播着时可见，所以两个按钮在这里都等价于各自的语义
func _toggle_play() -> void:
	if is_playlist_playing and audio_player.playing:
		AudioManager.pause_playlist()
	elif AudioManager._playlist_paused:
		AudioManager.resume_playlist()
	else:
		AudioManager.resume_or_play_track()


## 键盘：左右切曲、空格暂停/继续。
## 必须用 _unhandled_input —— 页面在 SubViewport 里，键盘事件进不到 _input（实测收不到）
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_LEFT: _previous_track()
		KEY_RIGHT: _next_track()
		KEY_SPACE: _toggle_play()
		_: return
	get_viewport().set_input_as_handled()

var is_playlist_playing: bool:
	get:
		return AudioManager._music_source == AudioManager.MusicSource.PLAYLIST

func _physics_process(_delta: float) -> void:
	var playing = is_playlist_playing and audio_player.playing
	if playing:
		var progress_ratio = audio_player.get_playback_position() \
		/ AudioManager.current_track.track.get_length()
		play_progress_line.set_progress(progress_ratio)
		update_time_label(label_current_time, audio_player.get_playback_position())

	progress_hint.global_position = play_progress_line_ghost \
	.endpoint.global_position \
	if progress_hovered else \
	play_progress_line.endpoint.global_position

	pause_button.visible = playing
	play_button.visible = !playing
	
func update_track_info() -> void:
	label_title.text = AudioManager.current_track.title
	richlabel_description.text = AudioManager.current_track.description
	update_time_label(label_total_time, 
		AudioManager.current_track.track.get_length()
	)

func update_time_label(label: Label, total_second: float) -> void:
	var minutes = total_second / 60
	var seconds = int(total_second) % 60
	label.text = "%02d:%02d" % [minutes, seconds]
