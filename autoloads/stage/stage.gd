extends Node

class MissingCharacter:
	var character_name: String

	func _init(name: String) -> void:
		character_name = name

	func FadeIn(_position_name: String, _duration: float = 0.5) -> void:
		pass

	func FadeOut(_duration: float = 0.5) -> void:
		pass

	func MoveTo(_position_name: String, _duration: float = 0.5) -> void:
		pass

	func SetParts(_parts_string: String) -> void:
		pass

	func SetBody(_body_name: String) -> void:
		pass

	func SetExpression(_expression_name: String) -> void:
		pass

	func ClearOptionals() -> void:
		pass

	func SetOptionals(_optionals_string: String) -> void:
		pass

@export var character_pool: Control
## 角色同样「用到才建」。原来是 6 个 Character 实例直接挂在 stage.tscn 里，
## 开局就把它们的立绘图集全拉进显存，而一屏通常只站 1~3 个。
## 这里只存 PackedScene：实测 6 个一起 load 只 +31 资源、+0.0 MB 显存
## （纹理要 instantiate 才会上传，单个角色约 10.5 MB），首次 Character() 时才实例化。
@export var character_scenes: Array[PackedScene]
## 背景/CG 一律「用到才 load」。
## 这两个原来是 Array[BackgroundData] / Array[GalleryData]，等于把 .tres 直接挂在场景里，
## 开局就把 10 个背景（各 3~5 张 4K 变体）+ 8 个 CG（63 个 AtlasTexture → 整张图集）
## 全拉进内存、永不释放；一屏其实只用得到背景 1 张 + CG 1 张。
## 现在只存路径（纯字符串，不触发加载），查名字时再 load。
## 不额外做缓存：贴图的引用由显示它的 TextureRect 持有，换背景/换 CG 时旧的自然释放。
@export var background_paths: PackedStringArray
@export var gallery_paths: PackedStringArray

## 查名字用的索引。构建它绝不能 load()——那会把 .tres 引用的贴图一起拉进来
var _background_path_by_title: Dictionary = {}
var _background_order: PackedStringArray = []
var _gallery_path_by_name: Dictionary = {}
var _gallery_order: PackedStringArray = []
var _character_scene_by_name: Dictionary = {}
## 手机页要的昵称/头像，直接从 PackedScene 的 SceneState 读，不实例化角色
var _phone_meta_by_name: Dictionary = {}

var current_background: String
var current_date: String
var current_cg: String
var current_cg_variation: String
## 当前章节在演出表里的「章节」与「标题」（由 ShowChapterInfo 写入），收藏语音时要用
var current_chapter_designation: String = ""
var current_chapter_title: String = ""

signal character_selection_name_changed
var character_selection_name: String:
	set(value):
		character_selection_name = value
		character_selection_name_changed.emit()

var character_dict: Dictionary[String, Character]
var _missing_character_dict: Dictionary[String, MissingCharacter]
var character_array: Array[Character]:
	get:
		var characters: Array[Character]
		for key in character_dict.keys():
			characters.append(character_dict[key])
		return characters

func _ready() -> void:
	# 防御：万一场景里还留着角色实例，先登记进来
	for character: Character in character_pool.get_children():
		character_dict[character.name] = character
	_build_character_index()
	_build_lookup_index()


## 建角色索引：名字 → PackedScene，外加手机页要的昵称/头像。
## 手机字段从 SceneState 里读，绝不 instantiate —— 实例化会把该角色的立绘图集拉进显存
func _build_character_index() -> void:
	for scene in character_scenes:
		if scene == null:
			continue
		var char_name := scene.resource_path.get_file().get_basename()
		# character_余洛琛.tscn → 余洛琛
		var underscore := char_name.find("_")
		if underscore > 0:
			char_name = char_name.substr(underscore + 1)
		_character_scene_by_name[char_name] = scene
		var meta := _read_phone_meta(scene)
		if not meta.is_empty():
			_phone_meta_by_name[char_name] = meta


func _read_phone_meta(scene: PackedScene) -> Dictionary:
	var state := scene.get_state()
	var meta := {}
	for i in state.get_node_property_count(0):
		var prop_name := state.get_node_property_name(0, i)
		if prop_name == "phone_nickname":
			meta["nickname"] = state.get_node_property_value(0, i)
		elif prop_name == "phone_avatar":
			meta["avatar"] = state.get_node_property_value(0, i)
	return meta


## 建「名字 → 路径」索引。只解析文件名，绝不 load —— load 会把 .tres 引用的贴图一起拉进来
func _build_lookup_index() -> void:
	# 顺序按路径（也就是 01、02…）排，不能用 title 排 —— title 没有 NN_ 前缀，
	# 按它排会把旅行页/立绘鉴赏页的浏览顺序改掉
	var sorted_backgrounds := PackedStringArray(background_paths)
	sorted_backgrounds.sort()
	for path in sorted_backgrounds:
		var title := _background_title_of(path)
		if _background_path_by_title.has(title):
			push_error("[Stage] 背景标题重复：%s（%s）" % [title, path])
		_background_path_by_title[title] = path
		_background_order.append(title)
	var sorted_galleries := PackedStringArray(gallery_paths)
	sorted_galleries.sort()
	for path in sorted_galleries:
		var cg_name := path.get_file().get_basename()
		_gallery_path_by_name[cg_name] = path
		_gallery_order.append(cg_name)


## 背景标题 = 文件名去掉 "NN_" 前缀。约定 data/backgrounds/NN_标题.tres，
## 且 .tres 里的 title 与去前缀后的文件名一致（现有 10 个已逐个核对过）
func _background_title_of(path: String) -> String:
	var stem := path.get_file().get_basename()
	var underscore := stem.find("_")
	if underscore > 0 and stem.substr(0, underscore).is_valid_int():
		return stem.substr(underscore + 1)
	return stem


#region 背景 / CG 的按需加载

## 按标题找背景；找不到返回 null（调用方照旧只警告、不动画面）
func find_background(title: String) -> BackgroundData:
	var path: String = _background_path_by_title.get(title, "")
	if path == "":
		return null
	return load(path) as BackgroundData


## 背景总数。旅行页、立绘鉴赏页要按序号浏览，顺序按文件名（01、02…）
func background_count() -> int:
	return _background_order.size()


## 负数索引按 Godot 数组的语义从末尾取（旅行页的滚动列表依赖这一点）
func background_at(index: int) -> BackgroundData:
	var count := _background_order.size()
	if count == 0:
		return null
	if index < 0:
		index += count
	if index < 0 or index >= count:
		return null
	return load(_background_path_by_title[_background_order[index]]) as BackgroundData


## 按 CG 名找插画。SetCG 传的就是不带扩展名的文件名（如 "01_余洛琛房间"）
func find_gallery(cg_name: String) -> GalleryData:
	var path: String = _gallery_path_by_name.get(cg_name, "")
	if path == "":
		return null
	return load(path) as GalleryData


func gallery_count() -> int:
	return _gallery_order.size()


## 只取名字、不 load。插画鉴赏页判断「有没有解锁」只需要名字，
## 未解锁的槽位用一张公共占位图，不该为它把整张图集拉进内存
func gallery_name_at(index: int) -> String:
	if index < 0 or index >= _gallery_order.size():
		return ""
	return _gallery_order[index]


## 同 background_at，负数索引从末尾取
func gallery_at(index: int) -> GalleryData:
	var count := _gallery_order.size()
	if count == 0:
		return null
	if index < 0:
		index += count
	if index < 0 or index >= count:
		return null
	return load(_gallery_path_by_name[_gallery_order[index]]) as GalleryData

#endregion

func reset() -> void:
	if Game and Game.stage_page:
		Game.stage_page.stop_background_performance()
		Game.stage_page.stop_opening_effects()
		Game.stage_page.texture_rect_cg.scale = Vector2.ONE
		Game.stage_page.texture_rect_cg.pivot_offset = Vector2.ZERO
		Game.stage_page.texture_rect_cg.position = Vector2(0, 0)
	current_background = ""
	current_date = ""
	current_cg = ""
	current_cg_variation = ""
	clear_characters()

func start() -> void:
	Game.stage_page.start()

#region Dialogue Commands
## 这个角色是不是「已知角色」（在 character_scenes 里）。
## 用来替代以前拿 `character_dict.has()` 当「是不是真实角色」用的写法 ——
## 那个字典现在只装「已实例化」的角色，没上场的会被误判成不存在，
## 于是带 #语音 的句子会被静默静音（stage_page 的 character getter 就这么用的）
func has_character(character_name: String) -> bool:
	return character_dict.has(character_name) or _character_scene_by_name.has(character_name)


func Character(character_name: String):
	if character_dict.has(character_name):
		return character_dict[character_name]
	if _character_scene_by_name.has(character_name):
		return _instantiate_character(character_name)
	if not _missing_character_dict.has(character_name):
		_missing_character_dict[character_name] = MissingCharacter.new(character_name)
	return _missing_character_dict[character_name]


## 首次用到某个角色时才实例化并挂进 character_pool，之后一直复用
func _instantiate_character(character_name: String) -> Character:
	var scene: PackedScene = _character_scene_by_name[character_name]
	var character: Character = scene.instantiate()
	_apply_character_overrides(character_name, character)
	# 先登记再入树：角色的 _ready 里很可能又读 Stage.Character(...)，
	# 那时必须拿到同一个实例，否则会再建一个、无限递归
	character_dict[character_name] = character
	character_pool.add_child(character)
	return character


## 这 4 个角色在原来的 stage.tscn 里被逐实例覆盖成「左上角锚点 + END 生长」，
## 林凌铃、广播社老师 没被覆盖，保持 character.tscn 基类的中下对齐。
## 立绘鉴赏页用的是同一批角色场景、但覆盖集合不同（它覆盖了辉夜奏/常夏/余洛琛），
## 所以不能把这段烘进共享的 character_*.tscn，只能在这边按原样补回来
const CHARACTER_TOP_LEFT_ANCHORS: Array[String] = ["余洛琛", "常夏", "葛城", "辉夜奏"]

func _apply_character_overrides(character_name: String, character: Character) -> void:
	if character_name not in CHARACTER_TOP_LEFT_ANCHORS:
		return
	character.anchor_left = 0.0
	character.anchor_top = 0.0
	character.anchor_right = 0.0
	character.anchor_bottom = 0.0
	character.grow_horizontal = Control.GROW_DIRECTION_END
	character.grow_vertical = Control.GROW_DIRECTION_END


## 手机页用的昵称 / 头像。不需要实例化角色（见 _build_character_index）
func phone_nickname_of(character_name: String) -> String:
	var meta: Dictionary = _phone_meta_by_name.get(character_name, {})
	return meta.get("nickname", "")


func phone_avatar_of(character_name: String) -> Texture2D:
	var meta: Dictionary = _phone_meta_by_name.get(character_name, {})
	return meta.get("avatar", null)

# ─── 黑屏过渡 ───

## 转场前置：按 skip 状态决定这次过渡要不要被忽略。
## 返回 true 表示「忽略转场」已开，调用方应直接赋值、不补间。
func _begin_black_transition() -> bool:
	var is_skip: bool = Game.stage_page.skip
	var skip_trans: bool = is_skip and Main.setting_data.skip_ignore_transitions
	if is_skip and not skip_trans:
		Game.stage_page._set_mode(Game.stage_page.AdvanceMode.MANUAL)
		Game.stage_page.skip_cancelled.emit()
	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = 1
	return skip_trans

## 黑屏层淡到指定 alpha（1 = 全黑）；skip_trans 时直接赋值
func _fade_blackscreen_to(target_alpha: float, duration: float, skip_trans: bool) -> void:
	if skip_trans:
		Game.stage_page.texture_rect_blackscreen.modulate.a = target_alpha
		return
	await create_tween().tween_property(
		Game.stage_page.texture_rect_blackscreen,
		"modulate:a",
		target_alpha,
		duration
	).finished

## 换背景本体（不含过渡）；找不到背景只警告，不动画面
func _set_background_by_name(background_name: String, variation_name: String) -> void:
	var target_background: BackgroundData = find_background(background_name)
	if not target_background:
		push_warning("SetBackground: 未找到背景 %s" % background_name)
		return
	_apply_background(target_background, variation_name)

## 收掉 CG 本体（不含过渡）
func _clear_cg_now() -> void:
	Game.stage_page.texture_rect_cg.visible = false
	Game.stage_page.texture_rect_cg.texture = null
	Game.stage_page.texture_rect_cg.scale = Vector2.ONE
	Game.stage_page.texture_rect_cg.pivot_offset = Vector2.ZERO
	Game.stage_page.texture_rect_cg.position = Vector2(0, 0)
	Game.stage_page.texture_rect_variation.texture = null
	current_cg = ""
	current_cg_variation = ""

## 收 CG 的同时换背景：两个改动合进同一次黑屏过渡。
## 拆成 SetBackground + HideCG 两条会连出两次转场，而第一次换的背景被 CG 盖着看不见，看着像没反应。
func HideCGWithBackground(background_name: String, variation_name: String,
		out_time: float = 1.2, in_time: float = 1.2) -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects()
	var skip_trans := _begin_black_transition()
	await _fade_blackscreen_to(1.0, out_time, skip_trans)
	_set_background_by_name(background_name, variation_name)
	_clear_cg_now()
	# 同上：收 CG 的这条合并命令也自己负责收对话框
	await HideDialogue(0)
	await _fade_blackscreen_to(0.0, in_time, skip_trans)

func SetBackground(background_name: String, variation_name: String,
		out_time: float = 1.2, in_time: float = 1.2) -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects()
	var skip_trans := _begin_black_transition()
	await _fade_blackscreen_to(1.0, out_time, skip_trans)
	_set_background_by_name(background_name, variation_name)
	await _fade_blackscreen_to(0.0, in_time, skip_trans)

func _apply_background(target_background: BackgroundData, variation_name: String) -> void:
	var target_texture: Texture2D = target_background.variations[variation_name]
	current_background = "%s-%s" % [target_background.title, variation_name]
	Game.phone_page.label_location.text = target_background.location
	Game.stage_page.texture_rect_background.texture = target_texture
	clear_characters()
	HideDialogue(0)

func PrepareBackground(background_name: String, variation_name: String) -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects(false)
	var target_background: BackgroundData = find_background(background_name)
	if not target_background:
		push_warning("PrepareBackground: 未找到背景 %s" % background_name)
		return
	_apply_background(target_background, variation_name)
	Game.stage_page.texture_rect_blackscreen.modulate.a = 1.0

func SetCG(cg_name: String, variation_name: String) -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects()
	var target_gallery: GalleryData = find_gallery(cg_name)
	if not target_gallery:
		push_warning("SetCG: 未找到 gallery %s" % cg_name)
		return
	Main.unlock_cg(cg_name)

	# 同一CG切换差分：直接换贴图，不走过渡
	if current_cg == cg_name:
		var var_texture: Texture2D
		for v in target_gallery.variation:
			if v.resource_path.get_file().replace(".tres", "") == variation_name:
				var_texture = v
				break
		Game.stage_page.texture_rect_variation.texture = var_texture
		current_cg_variation = variation_name
		return

	# 切换到不同CG：黑屏过渡
	var skip_trans := _begin_black_transition()
	await _fade_blackscreen_to(1.0, 1.2, skip_trans)

	current_cg = cg_name
	current_cg_variation = variation_name
	Game.stage_page.texture_rect_cg.texture = target_gallery.base
	var var_texture: Texture2D
	for v in target_gallery.variation:
		if v.resource_path.get_file().replace(".tres", "") == variation_name:
			var_texture = v
			break
	Game.stage_page.texture_rect_variation.texture = var_texture
	Game.stage_page.texture_rect_cg.visible = true
	# Q版等小CG按数据里的倍率缩小、居中，并可上移避开 UI（base 与差分同属一节点，会一起变换）
	_apply_cg_transform(target_gallery.cg_scale, target_gallery.cg_offset_y)
	clear_characters()
	HideDialogue(0)

	await _fade_blackscreen_to(0.0, 1.2, skip_trans)

func _apply_cg_transform(cg_scale: float, offset_y: float) -> void:
	var cg_rect: TextureRect = Game.stage_page.texture_rect_cg
	cg_rect.pivot_offset = cg_rect.size * 0.5
	cg_rect.scale = Vector2.ONE if cg_scale <= 0.0 else Vector2(cg_scale, cg_scale)
	# 在缩放居中基础上整体垂直偏移（负值向上），保持水平居中
	cg_rect.position = Vector2(0.0, offset_y)

func HideCG() -> void:
	Game.stage_page.stop_background_performance()
	Game.stage_page.stop_opening_effects()
	var skip_trans := _begin_black_transition()
	await _fade_blackscreen_to(1.0, 1.2, skip_trans)
	_clear_cg_now()
	# 收 CG 由 CG 自己负责对话框：先收起来 + 清空文本，等下一句文本就位后再显示
	await HideDialogue(0)
	await _fade_blackscreen_to(0.0, 1.2, skip_trans)

func clear_characters() -> void:
	Tools.clear_children(Game.stage_page.character_image_pool)
	for character in character_array:
		character.character_image = null
		character.current_position = ""

func Travel() -> void:
	Game.travel_page.visible = true
	await Game.travel_page.visibility_changed

func SetDate(month: int, day: int, week_day: String) -> void:
	var date_key := "%02d-%02d-%s" % [month, day, week_day]
	if current_date == date_key:
		return
	current_date = date_key
	var month_str = str(month).pad_zeros(2)
	var day_str = str(day).pad_zeros(2)
	Game.phone_page.label_phone_date.text = "%s/%s" % [month_str, day_str]
	Game.phone_page.label_time.text = week_day
	Game.stage_page.label_month.text = month_str
	Game.stage_page.label_day.text = day_str
	Game.stage_page.label_week_day.text = week_day
	var date_control = Game.stage_page.date
	date_control.modulate.a = 0
	await create_tween().tween_property(date_control, "modulate:a", 1, 1).finished
	await get_tree().create_timer(3.0).timeout
	await create_tween().tween_property(date_control, "modulate:a", 0, 1).finished

## 章节过场：由导出脚本写在每章第一句之前（`$> ShowChapterInfo("章节1", "初雪")`）。
## 预制体没挂上时直接返回，保证对话不会卡在这里。
func ShowChapterInfo(chapter: String, chapter_title: String) -> void:
	# 先记下来：语音收藏的章节号/章节名要用（过场缺失时也得记）
	current_chapter_designation = chapter
	current_chapter_title = chapter_title
	if Game.chapter_transition == null:
		push_warning("[Stage] chapter_transition 未挂载，跳过章节过场")
		return
	await Game.chapter_transition.play(chapter, chapter_title)

func SetMusic(music_name: String) -> void:
	var track_data: MusicData = AudioManager.playlist.filter(
		func(m: MusicData): return m.title == music_name
	).front()
	if not track_data:
		return
	# 如果已经在播同一首就不重复
	if AudioManager._music_source == AudioManager.MusicSource.PLAYLIST \
		and AudioManager.audio_player_music.stream == track_data.track \
		and AudioManager.audio_player_music.playing:
		return
	# fade out 当前音乐（3 秒），但不阻塞对话推进
	if AudioManager.audio_player_music.playing:
		var saved_db := AudioManager.audio_player_music.volume_db
		var tween := create_tween()
		tween.tween_property(
			AudioManager.audio_player_music, "volume_db", -80.0, 3.0
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		tween.tween_callback(
			func():
				AudioManager.audio_player_music.stop()
				AudioManager.audio_player_music.volume_db = saved_db
				AudioManager.track_index = AudioManager.playlist.find(track_data)
				AudioManager.play_track()
		)
		return
	AudioManager.track_index = AudioManager.playlist.find(track_data)
	AudioManager.play_track()

func StopMusic() -> void:
	if not AudioManager.audio_player_music.playing:
		return
	var saved_db := AudioManager.audio_player_music.volume_db
	var tween := create_tween()
	tween.tween_property(
		AudioManager.audio_player_music, "volume_db", -80.0, 2.0
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(
		func():
			AudioManager.audio_player_music.stop()
			AudioManager.audio_player_music.volume_db = saved_db
	)

func HideDialogue(duration: float = 0.4) -> void:
	AudioManager.audio_player_voice.stop()
	Game.stage_page.reset_dialogue_ui_hidden()
	if Game.stage_page.dialogue_screen.modulate.a > 0:
		if duration > 0:
			await create_tween().tween_property(
				Game.stage_page.dialogue_screen, "modulate:a", 0.0, duration
			).finished
		else:
			Game.stage_page.dialogue_screen.modulate.a = 0
	Game.stage_page.avatar.texture = null  # 淡出后再清头像，防止下次显示时闪现旧头像
	# 收起对话框时顺手擦掉旧文本，并约定「等下一句文本就位再显示」：
	# 否则脚本里稍后的 ShowDialogue() 会把上一句的角色名 + 空文本先露出来
	Game.stage_page.begin_dialogue_ui_awaiting_text()

func ShowDialogue(duration: float = 0.4) -> void:
	var sp = Game.stage_page
	# 刚收过 CG/过场，约定等下一句文本就位再显示：这次先不放出来（下一句
	# process_dialogue_line 会再调一次），免得露出上一句的角色名和空文本
	if sp.is_dialogue_ui_awaiting_text():
		return
	sp.reset_dialogue_ui_hidden()
	# 先更新状态再呈现
	sp.label_character_name.text = sp.dialogue_line.get_tag_value("昵称") \
		if sp.dialogue_line.has_tag("昵称") else sp.dialogue_line.character
	sp.dialogue_label.text = ""
	sp.dialogue_label.visible_characters = 0
	sp.voice_buttons.visible = sp.dialogue_line.has_tag("语音")
	if sp.dialogue_screen.modulate.a < 1:
		if duration > 0:
			await create_tween().tween_property(
				sp.dialogue_screen, "modulate:a", 1.0, duration
			).finished
		else:
			sp.dialogue_screen.modulate.a = 1

func PlaySFX(sound_name: String, wait_for_finish: bool = false) -> void:
	await AudioManager.play_sound_by_name(sound_name, wait_for_finish)

func RevealBackgroundWithBlur(black_fade_time: float = 0.8,
		blur_fade_time: float = 1.2, blur_amount: float = 8.0) -> void:
	var is_skip: bool = Game.stage_page.skip
	var skip_trans: bool = is_skip and Main.setting_data.skip_ignore_transitions
	if skip_trans:
		Game.stage_page.stop_opening_effects()
		Game.stage_page.texture_rect_blackscreen.modulate.a = 0.0
		return
	if is_skip:
		Game.stage_page._set_mode(Game.stage_page.AdvanceMode.MANUAL)
		Game.stage_page.skip_cancelled.emit()
	await Game.stage_page.play_blur_reveal(black_fade_time, blur_fade_time, blur_amount)

func PerformBackgroundPan(scale_multiplier: float, segments: Array) -> void:
	if segments.is_empty():
		Game.stage_page.stop_background_performance()
		return
	var is_skip: bool = Game.stage_page.skip
	var skip_trans: bool = is_skip and Main.setting_data.skip_ignore_transitions
	if skip_trans:
		Game.stage_page.stop_background_performance()
		return
	if is_skip:
		Game.stage_page._set_mode(Game.stage_page.AdvanceMode.MANUAL)
		Game.stage_page.skip_cancelled.emit()
	Game.stage_page.play_background_performance.call_deferred(scale_multiplier, segments)

func StopBackgroundPerformance(fade_duration: float = 0.8) -> void:
	await Game.stage_page.stop_background_performance(true, fade_duration)

func ShowPhone() -> void:
	var initial_chat_character := ""
	if Game.stage_page.dialogue_line:
		var next_line = await Game.stage_page.dialogue.get_next_dialogue_line(
			Game.stage_page.dialogue_line.next_id,
			[Game.stage_page, Stage],
			DMConstants.MutationBehaviour.Skip
		)
		if next_line and "手机" in next_line.tags and next_line.character != "周腾":
			initial_chat_character = next_line.character
	await Game.phone_page.open(true, initial_chat_character)

func HidePhone() -> void:
	await Game.phone_page.close()

func OpenBook() -> void:
	await Game.switch_to_page(Game.book_page, true, true)

func CloseBook() -> void:
	if Game.book_page.visible:
		await Game.go_back()

func WriteBook(entry_id: String, speaker: String, text: String, side: String = "", tags: Array[String] = []) -> void:
	await Game.book_page.append_entry(entry_id, speaker, text, side, tags)

#endregion
