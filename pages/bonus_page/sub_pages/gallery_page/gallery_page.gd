class_name GalleryPage
extends Control

@export var gallery_card_pool: Control
@export var gallery_view: TextureRect
@export var gallery_view_variation: TextureRect
@export var gallery_view_frame: TextureRect
@export var option_variation: CharacterOption
@export var button_hide: TextureButton
@export var button_close: TextureButton

const TWEEN_DURATION: float = 0.3

var current_gallery_data: GalleryData
# 全屏图鉴当前可翻看的变体（整 CG 解锁后为完整 variation）
var gallery_view_variations: Array[Texture2D] = []
var variation_index: int:
	set(value):
		variation_index = value
		if not current_gallery_data or gallery_view_variations.is_empty():
			return
		variation_index = posmod(variation_index, gallery_view_variations.size())
		gallery_view_variation.texture = gallery_view_variations[variation_index]
		var raw_name = gallery_view_variations[variation_index].resource_path.get_file().get_basename()
		var dash_pos = raw_name.find("-")
		var display_name = raw_name.substr(dash_pos + 1) if dash_pos != -1 else raw_name
		option_variation.option_name = display_name
var _active_card: GalleryCard

func _ready() -> void:
	gallery_view.visible = false
	# 只显示已解锁的 CG，未解锁的不占位（网格随解锁进度紧凑排列）
	for gallery_data in Stage.gallery_data_pool:
		var cg_name: String = gallery_data.resource_path.get_file().get_basename()
		if not Main.has_unlocked_cg(cg_name):
			continue
		var gallery_card: GalleryCard = Prefabs.gallery_card.instantiate()
		gallery_card.variations = gallery_data.variation
		gallery_card.texture_rect_base.texture = gallery_data.base
		gallery_card.texture_rect_variation.texture = gallery_data.variation[0] if not gallery_data.variation.is_empty() else null
		gallery_card_pool.add_child(gallery_card)
		gallery_card.pressed.connect(open_gallery_view.bind(gallery_card, gallery_data))

	option_variation.previous_button.pressed.connect(func(): variation_index -= 1)
	option_variation.next_button.pressed.connect(func(): variation_index += 1)
	button_hide.pressed.connect(func(): gallery_view_frame.visible = false)
	button_close.pressed.connect(close_gallery_view)
	gallery_view.gui_input.connect(
		func(event: InputEvent):
			if not gallery_view_frame.visible and event is InputEventMouseButton:
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					gallery_view_frame.visible = true
	)


func open_gallery_view(card: GalleryCard, gallery_data: GalleryData) -> void:
	_active_card = card
	current_gallery_data = gallery_data

	# 设置纹理
	gallery_view_variations = card.variations
	gallery_view.texture = gallery_data.base
	variation_index = 0
	gallery_view_frame.visible = true

	# 从卡片位置过渡到全屏
	var card_rect = card.texture_rect_base.get_global_rect()
	gallery_view.visible = true
	gallery_view.global_position = card_rect.position
	gallery_view.size = card_rect.size

	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(gallery_view, "global_position", Vector2.ZERO, TWEEN_DURATION)
	tween.parallel().tween_property(gallery_view, "size", get_viewport_rect().size, TWEEN_DURATION)


func close_gallery_view() -> void:
	if not _active_card:
		return
	var card_rect = _active_card.texture_rect_base.get_global_rect()

	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(gallery_view, "global_position", card_rect.position, TWEEN_DURATION)
	tween.parallel().tween_property(gallery_view, "size", card_rect.size, TWEEN_DURATION)
	await tween.finished
	gallery_view.visible = false
	_active_card = null
