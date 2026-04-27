@tool
class_name DialogueBox
extends Control

@export var preview_texture: Texture2D:
	set(value):
		preview_texture = value
		avatar.texture = preview_texture

@export var avatar: TextureRect
