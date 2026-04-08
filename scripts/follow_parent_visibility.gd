## 让 CanvasLayer.visible 跟随父级可见性。
## 解决 Godot 中 CanvasLayer 不自动跟随父节点可见性的问题。
## 将此脚本附加到任何 CanvasLayer 节点即可生效。
extends CanvasLayer


func _ready() -> void:
	_connect_ancestors()
	_sync()


func _connect_ancestors() -> void:
	var node := get_parent()
	while node:
		if node is CanvasItem or node is CanvasLayer:
			node.visibility_changed.connect(_sync)
		node = node.get_parent()


func _sync() -> void:
	var node := get_parent()
	while node:
		if (node is CanvasItem or node is CanvasLayer) and not node.visible:
			visible = false
			return
		node = node.get_parent()
	visible = true
