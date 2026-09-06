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
# 未解锁 CG 的占位格底图（复用空存档预览样式）
const EMPTY_SLOT_TEXTURE: Texture2D = preload("res://assets/sprites/ui/ui.sprites/dataimage_empty.tres")

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
	refresh()
	# 每次进入图鉴 tab 都按当前解锁进度重建网格，避免同一会话内新解锁的 CG 不显示
	visibility_changed.connect(
		func():
			if visible:
				refresh()
	)

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


func refresh() -> void:
	_active_card = null
	# 若正打开全屏视图，先收起，避免下次关闭时引用已释放的卡
	if gallery_view.visible:
		gallery_view.visible = false
		gallery_view_frame.visible = false
	# 清空旧卡，按当前解锁进度重建
	for child in gallery_card_pool.get_children():
		child.queue_free()
	# 固定槽位：已解锁的 CG 卡排在前，未解锁的空白占位格排在后（占位格不可点击，样式参考空存档）
	var unlocked: Array[GalleryData] = []
	var locked: Array[GalleryData] = []
	for gallery_data in Stage.gallery_data_pool:
		var cg_name: String = gallery_data.resource_path.get_file().get_basename()
		if Main.has_unlocked_cg(cg_name):
			unlocked.append(gallery_data)
		else:
			locked.append(gallery_data)

	for gallery_data in unlocked:
		var gallery_card: GalleryCard = Prefabs.gallery_card.instantiate()
		gallery_card.variations = gallery_data.variation
		gallery_card.texture_rect_base.texture = gallery_data.base
		gallery_card.texture_rect_variation.texture = gallery_data.variation[0] if not gallery_data.variation.is_empty() else null
		gallery_card_pool.add_child(gallery_card)
		gallery_card.pressed.connect(open_gallery_view.bind(gallery_card, gallery_data))

	for gallery_data in locked:
		var placeholder: GalleryCard = Prefabs.gallery_card.instantiate()
		placeholder.disabled = true
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.texture_rect_variation.texture = null
		placeholder.texture_rect_base.texture = EMPTY_SLOT_TEXTURE
		gallery_card_pool.add_child(placeholder)


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
