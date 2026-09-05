class_name GalleryCard
extends TextureButton

@export var texture_rect_base: TextureRect
@export var texture_rect_variation: TextureRect

# 该卡可翻看的变体贴图（整 CG 解锁后为完整 variation），由 GalleryPage 读取
var variations: Array[Texture2D] = []
