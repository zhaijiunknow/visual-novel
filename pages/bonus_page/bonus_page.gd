class_name BonusPage
extends CanvasLayer

## 四个子页也「用到才建」：它们自带的纹理是全局最重的一处
## （角色 8 张 / 鉴赏 9 / 音乐 12 / 语音 14，合计 43 ✗），进来再看哪个 tab 才建哪个
const SUB_PAGES := {
	&"character": "res://pages/bonus_page/sub_pages/character_page/character_page.tscn",
	&"gallery": "res://pages/bonus_page/sub_pages/gallery_page/gallery_page.tscn",
	&"music": "res://pages/bonus_page/sub_pages/music_page/music_page.tscn",
	&"voice": "res://pages/bonus_page/sub_pages/voice_page/voice_page.tscn",
}

@export var tab_pages: Control
@export var start_tab_item: TabItem
@export var tab_gallery: TabItem
@export var tab_music: TabItem
@export var tab_voice: TabItem

var _sub_pages: Dictionary = {}

## 惰性 getter：TabItem 与 voice_card 都会读它们
var music_page: MusicPage:
	get: return ensure_sub_page(&"music") as MusicPage
var voice_page: VoicePage:
	get: return ensure_sub_page(&"voice") as VoicePage


func _ready() -> void:
	start_tab_item.select()


## 子页按需创建（TabItem 会沿着父链找到这里）
func ensure_sub_page(key: StringName) -> Control:
	if _sub_pages.has(key):
		return _sub_pages[key]
	var scene: PackedScene = load(SUB_PAGES[key])
	if scene == null:
		push_error("[BonusPage] 子页场景加载失败：%s" % SUB_PAGES[key])
		return null
	var page: Control = scene.instantiate()
	page.visible = false
	# 先登记再入树：子页的 _ready 里可能会再读回自己（同 Game._ensure_page 的理由）
	_sub_pages[key] = page
	tab_pages.add_child(page)
	return page
