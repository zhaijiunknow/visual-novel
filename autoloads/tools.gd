class_name Tools
extends Node

static func clear_connections(target_signal: Signal) -> void:
	for connection in target_signal.get_connections():
		target_signal.disconnect(connection.callable)

static func clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func apply_texture_filters(node: Node) -> void:
	for child in node.get_children():
		if child is Label or child is RichTextLabel:
			child.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		elif child is CanvasItem:
			child.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		apply_texture_filters(child)
