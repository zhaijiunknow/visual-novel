class_name GalleryData
extends Resource

@export var base: Texture2D
@export var variation: Array[Texture2D]
@export var cg_variations: Array[Texture2D]
# 舞台中显示时的缩放倍率：Q版等小CG设为小于1，居中显示（柚子社式）；1.0=原始全屏
@export var cg_scale: float = 1.0
# 以屏幕中心为基准的垂直偏移（像素）：负值向上，正值向下，用于小CG上移避开 UI；0=居中
@export var cg_offset_y: float = 0.0
