class_name Tools
extends Node

static func clear_connections(target_signal: Signal) -> void:
	for connection in target_signal.get_connections():
		target_signal.disconnect(connection.callable)

static func clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
