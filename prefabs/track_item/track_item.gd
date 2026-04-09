class_name TrackItem
extends TextureButton

@export var drag_filter: DragFilter
@export var label_title: Label

var selected: bool:
	get:
		return AudioManager.track_index == get_index()

var music_data: MusicData:
	set(value):
		music_data = value
		label_title.text = music_data.title

func _ready() -> void:
	drag_filter.execute.connect(
		func ():
			AudioManager.track_index = get_index()
			AudioManager.play_track()
	)
	AudioManager.track_index_changed.connect(update)
	update()
	button_up.connect(
		func ():
			update()
	)

func update() -> void:
	button_pressed = selected
