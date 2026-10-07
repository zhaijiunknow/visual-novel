class_name LoadingPage
extends CanvasLayer

## 全屏不透明遮盖，默认隐藏。
## 存档/读档只是"压暗 + 转圈提示"，用的还是那个半透明 Background；
## 但历史记录跳转要重放整章剧本，过程必须完全看不见 —— 半透明挡不住。
@export var cover: ColorRect

func set_cover(on: bool) -> void:
	if cover != null:
		cover.visible = on
