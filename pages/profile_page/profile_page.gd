class_name ProfilePage
extends CanvasLayer

@export var profile_card_model: ProfileCard
@export var title_load: TextureRect
@export var title_save: TextureRect
@export var profile_card_pool: GridContainer

signal profile_index_changed
var profile_index: int:
	set(value):
		profile_index = value
		profile_index_changed.emit()

func _ready() -> void:	
	visibility_changed.connect(
		func ():
			title_load.visible = Main.profile_mode == Main.ProfileMode.LOAD
			title_save.visible = Main.profile_mode == Main.ProfileMode.SAVE
			if visible:
				update()
	)

var save_thread: Thread

func update() -> void:
	Main.clear_children(profile_card_pool)
	for profile in Main.save_data.profiles:
		var profile_card: ProfileCard = profile_card_model.duplicate()
		profile_card.texture_rect_preview.texture = profile.preview
		profile_card_pool.add_child(profile_card)
		profile_card.label_index.text = "NO.%02d" % [profile_card.get_index() + 1]
	if Main.profile_mode == Main.ProfileMode.SAVE:
		profile_card_pool.add_child(profile_card_model.duplicate())

func save_game() -> void:
	save_thread = Thread.new()
	Game.loading = true
	var _texture = Game.stage_page.subviewport.get_texture()
	var image = _texture.get_image()
	save_thread.start(
		func ():
			image.resize(470, 265, Image.INTERPOLATE_NEAREST)
			var resized_texture = ImageTexture.create_from_image(image)
			if Main.save_data.profiles.size() <= profile_index:
				Main.save_data.profiles.insert(profile_index, ProfileData.new())
			var profile = Main.save_data.profiles[profile_index]
			profile.preview = resized_texture
			profile.dialogue_id = Game.stage_page.dialogue_line.id
			for character: Character in Stage.character_array:
				print(character.name)
				print(character.body_part_dict["Body"].animation)
			profile.background_texture = Stage.current_background
			ResourceSaver.save(Main.save_data, Main.save_path)
			
			(
				func ():
					save_thread.wait_to_finish()
					save_thread = null
					Game.loading = false
					update()
			).call_deferred()
	)
