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
		return AudioManager.audio_player_bonus

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
	play_button.pressed.connect(
		func ():
			AudioManager.audio_player_music.stop()
			if audio_player.stream_paused:
				audio_player.stream_paused = false
			else:
				audio_player.play()
	)
	pause_button.pressed.connect(
		func (): audio_player.stream_paused = true
	)
	next_button.pressed.connect(
		func ():
			AudioManager.audio_player_music.stop()
			AudioManager.track_index += 1
			audio_player.play()
	)
	previous_button.pressed.connect(
		func ():
			AudioManager.audio_player_music.stop()
			AudioManager.track_index -= 1
			audio_player.play()
	)
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

func _physics_process(_delta: float) -> void:
	var progress_ratio = audio_player.get_playback_position() \
	/ AudioManager.current_track.track.get_length()
	play_progress_line.set_progress(progress_ratio)
	
	progress_hint.global_position = play_progress_line_ghost \
	.endpoint.global_position \
	if progress_hovered else \
	play_progress_line.endpoint.global_position
	
	pause_button.visible = audio_player.playing
	play_button.visible = !audio_player.playing
	
	update_time_label(label_current_time, 
		AudioManager.audio_player_bonus.get_playback_position()
	)
	
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
