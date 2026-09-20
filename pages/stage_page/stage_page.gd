class_name StagePage
extends CanvasLayer

signal next_line
signal skip_cancelled
signal auto_cancelled
## 跳过状态变化。跳过按钮的按下状态只跟信号走，所以 Ctrl 键切换跳过也必须发这个，
## 否则会出现「跳过开着但按钮没亮」的假象
signal skip_changed(skipping: bool)

@export var chapters: Array[DialogueResource]
var chapters_dict: Dictionary[String, DialogueResource]

@export var dialogue: DialogueResource
var chapter_name: String:
	get:
		return dialogue.resource_path.get_file().split(".")[0]

@export var normal_step_rate: float = 0.02
@export var skip_step_rate: float = 0.01
@export var auto_step_rate: float = 0.1

@export var dialogue_screen: Control
@export var dialogue_label: DialogueLabel
@export var label_character_name: RichTextLabel
@export var responses_menu: Control
@export var subviewport: SubViewport
@export var hbox_positions: HBoxContainer
@export var character_image_pool: Control
@export var texture_rect_background: TextureRect
@export var background_performance_mask: Control
@export var texture_rect_background_performance: TextureRect
@export var texture_rect_cg: TextureRect
@export var texture_rect_variation: TextureRect
@export var opening_blur_overlay: ColorRect
@export var texture_rect_blackscreen: ColorRect

@export var bg_common: TextureRect
@export var bg_character: TextureRect
@export var avatar: TextureRect

@export var button_replay: TextureButton
@export var button_favourite: TextureButton
@export var texture_rect_favourite: TextureRect

@export var voice_buttons: Control

@export var skip_tag: TextureRect
@export var auto_tag: TextureRect

@export var date: Control
@export var label_month: Label
@export var label_day: Label
@export var label_week_day: Label

enum AdvanceMode { MANUAL, SKIP, AUTO }
var _mode: AdvanceMode = AdvanceMode.MANUAL
var _idle: bool = false
var quick_save_progress_count: int = 0
var current_book_segment_start_id: String = ""
var _background_performance_tween: Tween
var _opening_reveal_tween: Tween
var _dialogue_ui_tween: Tween
var _dialogue_ui_hidden: bool = false
var _dialogue_ui_restore_enabled: bool = true
## 滚轮累计量：攒够一格才推进/开回顾，免得高精度滚轮一次滚动推进好几句
var _wheel_step: float = 0.0
## 收 CG/过场时约定「等下一句文本就位再显示」，期间跳过脚本里的 ShowDialogue
var _dialogue_ui_awaiting_text: bool = false
var _bridge_sorted_dialogue_keys_cache: Dictionary = {}
var _pending_end_expression: String = ""
var _pending_end_expression_character: String = ""

var skip: bool:
	get: return _mode == AdvanceMode.SKIP
	set(value):
		if value:
			_set_mode(AdvanceMode.SKIP)
		elif _mode == AdvanceMode.SKIP:
			_set_mode(AdvanceMode.MANUAL)

var autoplay: bool:
	get: return _mode == AdvanceMode.AUTO
	set(value):
		if value:
			_set_mode(AdvanceMode.AUTO)
		elif _mode == AdvanceMode.AUTO:
			_set_mode(AdvanceMode.MANUAL)

## 退出自动/快进，并通知 UI 把按钮弹起。
## 按钮的按下状态只跟着 skip_cancelled / auto_cancelled 走，直接改 _mode 不发信号会留下「按着」的假象。
func cancel_auto_and_skip() -> void:
	var was_skip := _mode == AdvanceMode.SKIP
	var was_auto := _mode == AdvanceMode.AUTO
	_set_mode(AdvanceMode.MANUAL)
	if was_skip: skip_cancelled.emit()
	if was_auto: auto_cancelled.emit()

func _set_mode(mode: AdvanceMode) -> void:
	var was_skipping := _mode == AdvanceMode.SKIP
	_mode = mode
	if skip_tag: skip_tag.visible = (_mode == AdvanceMode.SKIP)
	if auto_tag: auto_tag.visible = (_mode == AdvanceMode.AUTO)
	update_step_rate()
	if (_mode == AdvanceMode.SKIP) != was_skipping:
		skip_changed.emit(_mode == AdvanceMode.SKIP)
	if _mode == AdvanceMode.SKIP and _idle:
		next_line.emit()
	elif _mode == AdvanceMode.AUTO and _idle:
		_trigger_auto_advance()

func _trigger_auto_advance() -> void:
	if AudioManager.audio_player_voice.playing:
		while AudioManager.audio_player_voice.playing:
			await get_tree().process_frame
			if _mode != AdvanceMode.AUTO or not _idle: return
		# 语音播完后的停顿：下一句换人则长一点（1s），同一个人则短（0.2s）
		var pause_time := 1.0 if await _next_speaker_changed() else 0.2
		await get_tree().create_timer(pause_time).timeout
	if _idle and _mode == AdvanceMode.AUTO:
		next_line.emit()

# 下一句是否换了角色（用 get_line 预览，不触发 got_dialogue，避免污染对话日志）
func _next_speaker_changed() -> bool:
	if dialogue_line == null or dialogue == null:
		return false
	var next: DialogueLine = await DialogueManager.get_line(dialogue, dialogue_line.next_id, [self, Stage])
	var changed: bool = next != null and next.character != dialogue_line.character
	print("[自动播放] 当前=%s 下句=%s 停顿=%ss" % [
		dialogue_line.character,
		next.character if next else "<结束>",
		"1.0" if changed else "0.2"
	])
	return changed

func update_step_rate() -> void:
	apply_speed_settings()
	var rate = normal_step_rate
	match _mode:
		AdvanceMode.SKIP: rate = skip_step_rate
		AdvanceMode.AUTO: rate = auto_step_rate
	dialogue_label.seconds_per_step = rate

func apply_speed_settings() -> void:
	var s = Main.setting_data
	normal_step_rate = 0.05 - s.text_speed * 0.048
	auto_step_rate = 0.05 - s.auto_speed * 0.048
	finish_pause = 0.5 + (1.0 - s.auto_speed) * 3.0

func get_position_by_name(position_name: String) -> Vector2:
	var position_node: Control = hbox_positions.get_node(position_name + "/CenterPoint")
	return position_node.global_position

func get_bridge_dialogue_state() -> Dictionary:
	var current_line: Dictionary = {}
	if dialogue_line:
		current_line = {
			"id": dialogue_line.id,
			"next_id": dialogue_line.next_id,
			"character": dialogue_line.character,
			"text": dialogue_line.text,
			"tags": dialogue_line.tags.duplicate(),
			"responses": _serialize_dialogue_responses(dialogue_line.responses),
		}
	return {
		"chapter_name": chapter_name if dialogue else "",
		"current_line": current_line,
		"speaker_label": label_character_name.text,
		"mode": _bridge_mode_name(),
		"is_typing": dialogue_label.is_typing,
		"visible_characters": dialogue_label.visible_characters,
		"current_book_segment_start_id": current_book_segment_start_id,
		"can_advance": dialogue_line != null,
		# 右键隐藏没法从外面直接看出来，给调试桥留一个只读字段
		"dialogue_ui_hidden": _dialogue_ui_hidden,
	}

## 调试桥的「推进」：必须和玩家点击/空格走同一条路（对话框收着先放出来、快进自动先取消），
## 否则用它测出来的行为和真实操作不一致
func advance_from_bridge() -> bool:
	if Game.loading or dialogue_line == null:
		return false
	advance_input()
	return true


# ─── 输入（鼠标 / 键盘）─────────────────────────────
# 规范：左键推进 / 右键切换隐藏 / 滚轮上开历史回顾 / 滚轮下推进 / 空格推进 / Ctrl 切换跳过。
# 页面隐藏时仍然会收到输入（所有页面都挂在 Pages/* 下），所以每个入口都要门禁「自己是当前页」，
# 否则在主菜单点右键也会去切换对话框。

## 「玩家正在操作剧情」才吃输入：剧情页在栈顶，而且没有盖在它上面的演出浮层。
## 页面隐藏时仍然收得到输入，手机/旅行/章节过场卡又都不在 page_stack 上，
## 所以每个入口都得过这一关（否则在旅行页滚轮会既换地点又开历史回顾）
func is_input_active() -> bool:
	if Game.loading or Game.current_page != self:
		return false
	# 用 page_shown 而不是 Game.phone_page / Game.travel_page：这是每个输入事件都会走的路径，
	# 直接读会把还没建的页面建出来（惰性实例化就白做了）
	if Game.page_shown(&"phone") or Game.page_shown(&"travel") or Game.chapter_transition.visible:
		return false
	return true


func _on_dialogue_screen_gui_input(event: InputEvent) -> void:
	if not is_input_active():
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:
			advance_input()
		MOUSE_BUTTON_WHEEL_DOWN:
			# 一格滚轮 = 一次推进。高精度滚轮/触摸板一次滚动发好几个小事件，
			# 按 factor 攒够一格才算一次（factor 拿不到时按一格算）
			_wheel_step += mouse_event.factor if mouse_event.factor > 0.0 else 1.0
			if _wheel_step >= 1.0:
				_wheel_step = 0.0
				advance_input()
		MOUSE_BUTTON_WHEEL_UP:
			_wheel_step += mouse_event.factor if mouse_event.factor > 0.0 else 1.0
			if _wheel_step >= 1.0:
				_wheel_step = 0.0
				open_log_page()
		MOUSE_BUTTON_RIGHT:
			toggle_dialogue_ui()


## 键盘用 _unhandled_input：舞台页在 SubViewport 里，键盘事件进不到它的 _input（实测收不到），
## 只有 _unhandled_input 能收到。代价是「有焦点的按钮」会把空格当 ui_accept 先吃掉，
## 不过对话框上那排按钮是普通 Control（不抢焦点），只有选项/回放那类 TextureButton 会，属于窄边界
func _unhandled_input(event: InputEvent) -> void:
	if not is_input_active():
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		# 方向键上和下与滚轮等效：上 = 开历史回顾，下 = 推进
		KEY_SPACE, KEY_DOWN:
			advance_input()
		KEY_UP:
			open_log_page()
		KEY_CTRL:
			# 对话框收着的时候别开快进，不然看不见 UI 的剧情会自己跑掉
			if _dialogue_ui_hidden:
				return
			skip = not skip
		_:
			return
	get_viewport().set_input_as_handled()


## 「推进」的统一样子（左键 / 滚轮下 / 空格共用）：
## 对话框收着就先放出来；快进或自动时先取消、这一步不推进；打字中先补完；否则下一句
func advance_input() -> void:
	if _dialogue_ui_hidden:
		if _dialogue_ui_restore_enabled:
			show_dialogue_ui()
		return
	if _mode != AdvanceMode.MANUAL:
		var was_skip = (_mode == AdvanceMode.SKIP)
		_set_mode(AdvanceMode.MANUAL)
		if was_skip: skip_cancelled.emit()
		else: auto_cancelled.emit()
		return
	if dialogue_label.is_typing:
		dialogue_label.skip_typing()
	next_line.emit()


## 右键：切换对话框的隐藏 / 显示
func toggle_dialogue_ui() -> void:
	if _dialogue_ui_hidden:
		if _dialogue_ui_restore_enabled:
			show_dialogue_ui()
		return
	# 脚本刚收过对话框、正在等下一句文本就位时别放出来，免得露出上一句的角色名 + 空文本
	if is_dialogue_ui_awaiting_text():
		return
	# 和「隐藏对话框」按钮一致：先把快进/自动停掉，否则会藏着一个还在自己跑的剧情
	cancel_auto_and_skip()
	hide_dialogue_ui()


## 打开历史回顾（对话框上的「回想」按钮和滚轮上共用）。
## 必须自己先停掉快进/自动：按钮那条路有 dialogue_button_controller 统一清，
## 滚轮这条路没有——不停的话剧情会在历史回顾背后继续推进
func open_log_page() -> void:
	cancel_auto_and_skip()
	Game.switch_to_page(Game.log_page, true, true)

func hide_dialogue_ui(duration: float = 0.2) -> void:
	if dialogue_line == null or _dialogue_ui_hidden:
		return
	_set_dialogue_ui_hidden(true, duration)
	_dialogue_ui_restore_enabled = false
	_enable_dialogue_ui_restore.call_deferred()

func show_dialogue_ui(duration: float = 0.2) -> void:
	if not _dialogue_ui_hidden:
		return
	_set_dialogue_ui_hidden(false, duration)

func reset_dialogue_ui_hidden() -> void:
	_dialogue_ui_hidden = false
	_dialogue_ui_restore_enabled = true
	_dialogue_ui_awaiting_text = false
	_kill_dialogue_ui_tween()

## 清空对话框里的文本（角色名 + 正文）
func clear_dialogue_text() -> void:
	label_character_name.text = ""
	dialogue_label.text = ""
	dialogue_label.visible_characters = 0

## 收起对话框后调用：擦掉旧文本，并约定等下一句文本就位再显示。
## 期间 Stage.ShowDialogue 会被跳过，免得把上一句的名字/空框先露出来。
func begin_dialogue_ui_awaiting_text() -> void:
	clear_dialogue_text()
	_dialogue_ui_awaiting_text = true

func is_dialogue_ui_awaiting_text() -> bool:
	return _dialogue_ui_awaiting_text

## 下一句开始处理：解除等待（随后 process_dialogue_line 里的 ShowDialogue 才会真的显示）
func release_dialogue_ui_awaiting_text() -> void:
	_dialogue_ui_awaiting_text = false

func _enable_dialogue_ui_restore() -> void:
	_dialogue_ui_restore_enabled = true

func _kill_dialogue_ui_tween() -> void:
	if _dialogue_ui_tween and is_instance_valid(_dialogue_ui_tween):
		_dialogue_ui_tween.kill()
	_dialogue_ui_tween = null

func _set_dialogue_ui_hidden(hidden: bool, duration: float = 0.2) -> void:
	_dialogue_ui_hidden = hidden
	_kill_dialogue_ui_tween()
	var target_alpha := 0.0 if hidden else 1.0
	if duration <= 0.0:
		dialogue_screen.modulate.a = target_alpha
		return
	_dialogue_ui_tween = create_tween()
	_dialogue_ui_tween.tween_property(
		dialogue_screen,
		"modulate:a",
		target_alpha,
		duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_dialogue_ui_tween.finished.connect(func(): _dialogue_ui_tween = null)

func skip_typing_from_bridge() -> bool:
	if not dialogue_label.is_typing:
		return false
	dialogue_label.skip_typing()
	return true

## 调试桥的「切模式」：和对话框上那个快进/自动按钮一样走 skip / autoplay 属性，
## 这样按钮的按下状态、skip_changed 日志都跟真实操作一致
func set_mode_from_bridge(mode_name: String) -> bool:
	match mode_name.to_lower():
		"manual":
			cancel_auto_and_skip()
			return true
		"skip":
			skip = true
			return true
		"auto":
			autoplay = true
			return true
		_:
			return false

func choose_response_from_bridge(index: int = -1, next_id: String = "") -> bool:
	if dialogue_line == null or dialogue_line.responses.is_empty():
		return false

	if "手机" in dialogue_line.tags:
		return await Game.phone_page.choose_reply_from_bridge(index, next_id)
	if "奇迹书" in dialogue_line.tags:
		return await Game.book_page.choose_reply_from_bridge(index, next_id)

	# 走玩家那条路：按下 responses_menu 里对应那个选项按钮，和手点完全同一条逻辑
	var target := _find_response_selection(index, next_id)
	if target == null:
		return false
	target.pressed.emit()
	return true


## 找到要按的选项按钮：给了 index 就按下标（responses_menu 的子节点顺序 == responses 顺序），
## 否则按 next_id 在该句的 responses 里定位
func _find_response_selection(index: int, next_id: String) -> DialogueSelection:
	var selections := responses_menu.get_children()
	if index >= 0 and index < selections.size():
		return selections[index] as DialogueSelection
	if next_id != "":
		for i in dialogue_line.responses.size():
			if dialogue_line.responses[i].next_id == next_id and i < selections.size():
				return selections[i] as DialogueSelection
	return null

func start_chapter_from_bridge(chapter_name_from_bridge: String) -> bool:
	var target_dialogue := _resolve_bridge_chapter_dialogue(chapter_name_from_bridge)
	if target_dialogue == null:
		return false
	dialogue = target_dialogue
	await start()
	return true

func start_at_from_bridge(chapter_name_from_bridge: String, next_id: String) -> bool:
	if next_id.is_empty():
		return false
	var target_dialogue := _resolve_bridge_chapter_dialogue(chapter_name_from_bridge)
	if target_dialogue == null:
		return false
	var resolved_next_id := _resolve_bridge_next_id(target_dialogue, next_id)
	if resolved_next_id.is_empty():
		return false
	dialogue = target_dialogue
	reset()
	dialogue_line = await DialogueManager.get_line(dialogue, resolved_next_id, [self, Stage])
	return dialogue_line != null

func _resolve_bridge_chapter_dialogue(chapter_name_from_bridge: String) -> DialogueResource:
	if chapters_dict.has(chapter_name_from_bridge):
		return chapters_dict[chapter_name_from_bridge]
	if dialogue and chapter_name == chapter_name_from_bridge:
		return dialogue
	return null

func _resolve_bridge_next_id(target_dialogue: DialogueResource, next_id: String) -> String:
	var candidate := next_id.strip_edges()
	if target_dialogue.lines.has(candidate) or target_dialogue.titles.has(candidate):
		return candidate
	var static_line_id := _extract_bridge_static_line_id(candidate)
	if static_line_id.is_empty():
		return ""
	return DialogueManager.static_id_to_line_id(target_dialogue, static_line_id)

func _extract_bridge_static_line_id(value: String) -> String:
	var start := value.find("[ID:")
	if start == -1:
		return value if value.ends_with(".line") or value.ends_with(".opt") else ""
	var id_start := start + 4
	var id_end := value.find("]", id_start)
	if id_end == -1:
		return ""
	return value.substr(id_start, id_end - id_start).strip_edges()

func get_bridge_dialogue_debug_lines(chapter_name_from_bridge: String = "", text_query: String = "", key_query: String = "", limit: int = 50, offset: int = 0, include_total: bool = false) -> Dictionary:
	var target_dialogue := _resolve_bridge_debug_target_dialogue(chapter_name_from_bridge)
	if target_dialogue == null:
		return {
			"ok": false,
			"error": "unknown chapter",
		}

	var normalized_text_query := text_query.strip_edges().to_lower()
	var normalized_key_query := key_query.strip_edges().to_lower()
	var safe_limit: int = clampi(limit, 1, 200)
	var safe_offset: int = maxi(offset, 0)
	var keys := _get_bridge_sorted_dialogue_keys(target_dialogue)
	var lines: Array[Dictionary] = []
	var total_matches := 0
	var has_more := false

	for key_variant in keys:
		var line_key := str(key_variant)
		var data: Dictionary = target_dialogue.lines.get(line_key, {})
		if not _matches_bridge_dialogue_debug_query(line_key, data, normalized_text_query, normalized_key_query):
			continue
		total_matches += 1
		if total_matches <= safe_offset:
			continue
		if lines.size() < safe_limit:
			lines.append(_serialize_bridge_dialogue_debug_line(line_key, data))
		else:
			has_more = true
			if not include_total:
				break

	var next_offset := safe_offset + lines.size()
	var resolved_chapter_name := target_dialogue.resource_path.get_file().trim_suffix(".dialogue")
	if resolved_chapter_name.is_empty() and target_dialogue == dialogue:
		resolved_chapter_name = chapter_name
	var pagination := {
		"offset": safe_offset,
		"limit": safe_limit,
		"returned": lines.size(),
		"has_more": has_more,
		"next_offset": next_offset,
		"include_total": include_total,
	}
	if include_total:
		pagination["total_matches"] = total_matches

	var result := {
		"ok": true,
		"chapter_name": resolved_chapter_name,
		"requested_chapter_name": chapter_name_from_bridge,
		"resource_path": target_dialogue.resource_path,
		"text_query": text_query,
		"key_query": key_query,
		"offset": safe_offset,
		"limit": safe_limit,
		"returned": lines.size(),
		"has_more": has_more,
		"next_offset": next_offset,
		"include_total": include_total,
		"query": {
			"chapter_name": chapter_name_from_bridge,
			"text_query": text_query,
			"key_query": key_query,
		},
		"pagination": pagination,
		"lines": lines,
	}
	if include_total:
		result["total_matches"] = total_matches
	return result

func _resolve_bridge_debug_target_dialogue(chapter_name_from_bridge: String) -> DialogueResource:
	if not chapter_name_from_bridge.is_empty():
		return _resolve_bridge_chapter_dialogue(chapter_name_from_bridge)
	if dialogue:
		return dialogue
	if chapters_dict.is_empty():
		return null
	var chapter_keys: Array = chapters_dict.keys()
	chapter_keys.sort()
	return chapters_dict[chapter_keys[0]]

func _get_bridge_sorted_dialogue_keys(target_dialogue: DialogueResource) -> Array:
	var cache_key := target_dialogue.resource_path
	if cache_key.is_empty():
		cache_key = str(target_dialogue.get_instance_id())
	var cached: Dictionary = _bridge_sorted_dialogue_keys_cache.get(cache_key, {})
	if int(cached.get("size", -1)) != target_dialogue.lines.size():
		var keys: Array = target_dialogue.lines.keys()
		keys.sort()
		cached = {
			"size": target_dialogue.lines.size(),
			"keys": keys,
		}
		_bridge_sorted_dialogue_keys_cache[cache_key] = cached
	return cached.get("keys", [])

func _serialize_bridge_dialogue_debug_line(line_key: String, data: Dictionary) -> Dictionary:
	var responses = data.get("responses", [])
	var tags = data.get("tags", [])
	var static_id := str(data.get("translation_key", ""))
	return {
		"key": line_key,
		"id": str(data.get("id", line_key)),
		"static_id": static_id,
		"jump_id": "[ID:%s]" % [static_id] if not static_id.is_empty() else line_key,
		"type": str(data.get("type", "")),
		"character": str(data.get("character", "")),
		"text": str(data.get("text", "")),
		"next_id": str(data.get("next_id", "")),
		"response_count": responses.size() if typeof(responses) == TYPE_ARRAY else 0,
		"tags": tags.duplicate() if typeof(tags) == TYPE_ARRAY else [],
	}

func _matches_bridge_dialogue_debug_query(line_key: String, data: Dictionary, normalized_text_query: String, normalized_key_query: String) -> bool:
	if not normalized_key_query.is_empty() and not line_key.to_lower().contains(normalized_key_query):
		return false
	if normalized_text_query.is_empty():
		return true
	for value in [
		str(data.get("id", line_key)),
		str(data.get("translation_key", "")),
		str(data.get("type", "")),
		str(data.get("character", "")),
		str(data.get("text", "")),
		str(data.get("next_id", "")),
		str(data.get("tags", [])),
	]:
		if value.to_lower().contains(normalized_text_query):
			return true
	return false

func _serialize_dialogue_responses(responses: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for i in responses.size():
		var response: DialogueResponse = responses[i]
		serialized.append({
			"index": i,
			"text": response.text,
			"next_id": response.next_id,
		})
	return serialized

func _bridge_mode_name() -> String:
	match _mode:
		AdvanceMode.SKIP:
			return "skip"
		AdvanceMode.AUTO:
			return "auto"
		_:
			return "manual"

func _resolve_response_next_id(index: int, next_id: String) -> String:
	if next_id != "":
		for response: DialogueResponse in dialogue_line.responses:
			if response.next_id == next_id:
				return response.next_id
	if index >= 0 and index < dialogue_line.responses.size():
		return dialogue_line.responses[index].next_id
	return ""

func _kill_background_performance_tween() -> void:
	if _background_performance_tween and is_instance_valid(_background_performance_tween):
		_background_performance_tween.kill()
	_background_performance_tween = null

func _set_opening_blur(amount: float, tint_alpha: float) -> void:
	var material := opening_blur_overlay.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("blur_amount", amount)
	material.set_shader_parameter("tint_color", Color(0, 0, 0, tint_alpha))

func _kill_opening_reveal_tween() -> void:
	if _opening_reveal_tween and is_instance_valid(_opening_reveal_tween):
		_opening_reveal_tween.kill()
	_opening_reveal_tween = null

func stop_opening_effects(stop_sound: bool = true) -> void:
	_kill_opening_reveal_tween()
	opening_blur_overlay.visible = false
	_set_opening_blur(0.0, 0.0)
	texture_rect_blackscreen.modulate.a = 0.0
	if stop_sound:
		AudioManager.stop_sound()

func stop_background_performance(clear_texture: bool = true, fade_duration: float = 0.0) -> void:
	_kill_background_performance_tween()
	if fade_duration > 0.0 and background_performance_mask.visible:
		var fade_tween := create_tween()
		fade_tween.tween_property(
			background_performance_mask,
			"modulate:a",
			0.0,
			fade_duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await fade_tween.finished
	background_performance_mask.visible = false
	background_performance_mask.modulate.a = 1.0
	texture_rect_background_performance.position = Vector2.ZERO
	texture_rect_background_performance.size = Vector2.ZERO
	texture_rect_background_performance.scale = Vector2.ONE
	if clear_texture:
		texture_rect_background_performance.texture = null

func prepare_background_hidden(texture: Texture2D) -> void:
	stop_background_performance()
	stop_opening_effects(false)
	texture_rect_background.texture = texture
	texture_rect_blackscreen.modulate.a = 1.0

func play_blur_reveal(black_fade_time: float = 0.8, blur_fade_time: float = 1.2, blur_amount: float = 8.0) -> void:
	stop_opening_effects(false)
	opening_blur_overlay.visible = true
	texture_rect_blackscreen.modulate.a = 1.0
	_set_opening_blur(blur_amount, 0.5)
	var material := opening_blur_overlay.material as ShaderMaterial
	if material == null:
		texture_rect_blackscreen.modulate.a = 0.0
		opening_blur_overlay.visible = false
		return
	_opening_reveal_tween = create_tween()
	_opening_reveal_tween.set_parallel(true)
	_opening_reveal_tween.tween_property(texture_rect_blackscreen, "modulate:a", 0.0, black_fade_time)
	_opening_reveal_tween.tween_property(material, "shader_parameter/blur_amount", 0.0, blur_fade_time)
	_opening_reveal_tween.tween_property(material, "shader_parameter/tint_color", Color(0, 0, 0, 0), blur_fade_time)
	await _opening_reveal_tween.finished
	_opening_reveal_tween = null
	opening_blur_overlay.visible = false
	_set_opening_blur(0.0, 0.0)

func _get_background_performance_size(texture: Texture2D, scale_multiplier: float) -> Dictionary:
	if texture == null:
		return {}
	var viewport_size: Vector2 = background_performance_mask.size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(subviewport.size)
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0 or texture_size.y <= 0:
		return {}
	var cover_scale: float = max(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
	var drawn_size: Vector2 = texture_size * cover_scale * max(scale_multiplier, 1.0)
	var base_position: Vector2 = (viewport_size - drawn_size) / 2.0
	return {
		"viewport_size": viewport_size,
		"drawn_size": drawn_size,
		"base_position": base_position,
		"min_position": viewport_size - drawn_size,
		"max_position": Vector2.ZERO,
	}

func prepare_background_performance(texture: Texture2D, scale_multiplier: float) -> Dictionary:
	stop_background_performance(false)
	var layout: Dictionary = _get_background_performance_size(texture, scale_multiplier)
	if layout.is_empty():
		return {}
	texture_rect_background_performance.texture = texture
	texture_rect_background_performance.position = layout["base_position"]
	texture_rect_background_performance.size = layout["drawn_size"]
	texture_rect_background_performance.scale = Vector2.ONE
	background_performance_mask.modulate.a = 1.0
	background_performance_mask.visible = true
	return layout

func _get_background_performance_target(layout: Dictionary, segment: Dictionary) -> Vector2:
	var base_position: Vector2 = layout["base_position"]
	var min_position: Vector2 = layout["min_position"]
	var max_position: Vector2 = layout["max_position"]
	var normalized_x: float = clamp(float(segment.get("x", 0.0)), -1.0, 1.0)
	var normalized_y: float = clamp(float(segment.get("y", 0.0)), -1.0, 1.0)
	var target_x: float = base_position.x + normalized_x * ((base_position.x - min_position.x) if normalized_x < 0 else (max_position.x - base_position.x))
	var target_y: float = base_position.y + normalized_y * ((base_position.y - min_position.y) if normalized_y < 0 else (max_position.y - base_position.y))
	return Vector2(
		clamp(target_x, min_position.x, max_position.x),
		clamp(target_y, min_position.y, max_position.y)
	)

func play_background_performance(scale_multiplier: float, segments: Array) -> void:
	var texture: Texture2D = texture_rect_background.texture
	if texture == null:
		push_warning("PerformBackgroundPan: 当前没有背景贴图可用于演出")
		return
	var base_layout: Dictionary = prepare_background_performance(texture, scale_multiplier)
	if base_layout.is_empty():
		push_warning("PerformBackgroundPan: 背景演出层布局失败")
		return
	if segments.is_empty():
		stop_background_performance()
		return
	for raw_segment in segments:
		if typeof(raw_segment) != TYPE_DICTIONARY:
			continue
		var segment: Dictionary = raw_segment
		var segment_scale: float = float(segment.get("scale", scale_multiplier))
		var layout: Dictionary = _get_background_performance_size(texture, segment_scale)
		if layout.is_empty():
			continue
		texture_rect_background_performance.size = layout["drawn_size"]
		var hold: float = float(segment.get("hold", 0.0))
		var target: Vector2 = _get_background_performance_target(layout, segment)
		var duration: float = float(segment.get("duration", -1.0))
		if duration <= 0.0:
			var speed: float = float(segment.get("speed", 0.0))
			if speed > 0.0:
				duration = texture_rect_background_performance.position.distance_to(target) / speed
			elif not segment.has("duration"):
				push_warning("PerformBackgroundPan: 分段缺少有效 duration 或 speed")
				continue
		if duration <= 0.0:
			texture_rect_background_performance.position = target
		else:
			var tween: Tween = create_tween()
			_background_performance_tween = tween
			tween.set_parallel(true)
			tween.tween_property(
				texture_rect_background_performance,
				"position",
				target,
				duration
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(
				texture_rect_background_performance,
				"size",
				layout["drawn_size"],
				duration
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			while _background_performance_tween == tween and tween.is_valid() and tween.is_running():
				await get_tree().process_frame
			if _background_performance_tween != tween:
				return
			_background_performance_tween = null
		if hold > 0.0:
			var timer: SceneTreeTimer = get_tree().create_timer(hold)
			while timer.time_left > 0.0:
				await get_tree().process_frame
				if background_performance_mask.visible == false:
					return

var dialogue_line: DialogueLine:
	set(value):
		dialogue_line = value
		if value:
			process_line()

var finish_pause: float = 1

var voice_name: String:
	get:
		if dialogue_line and dialogue_line.has_tag("语音"):
			return dialogue_line.get_tag_value("语音")
		return ""

var character: Character:
	get:
		# 判「是不是已知角色」，不能读 character_dict —— 它现在只装已实例化的角色，
		# 还没上场的说话人会被判成 null，于是 #语音 被静音、头像也不显示
		if Stage.has_character(dialogue_line.character):
			return Stage.Character(dialogue_line.character)
		return null


var scene: String:
	get:
		if dialogue_line:
			return dialogue_line.get_tag_value("场景")
		return ""

# ─── 对话处理 ───

func process_line() -> void:
	var current = dialogue_line
	if dialogue_line and "奇迹书" in dialogue_line.tags and current_book_segment_start_id == "":
		current_book_segment_start_id = dialogue_line.id
	elif dialogue_line and "奇迹书" not in dialogue_line.tags:
		current_book_segment_start_id = ""
	if not dialogue_line.text:
		pass
	else:
		if dialogue_line.has_tag("延迟"):
			await get_tree().create_timer(float(dialogue_line.get_tag_value("延迟"))).timeout
			if dialogue_line != current: return

		if "手机" in dialogue_line.tags:
			await process_phone_line()
			if dialogue_line != current: return
			if dialogue_line.responses:
				return
		elif "奇迹书" in dialogue_line.tags:
			await process_book_line()
			if dialogue_line != current: return
			if dialogue_line.responses:
				return
		else:
			await process_dialogue_line()
			if dialogue_line != current: return
			if dialogue_line.responses:
				return

	# 标记已读（在skip检查之后）
	var line_id := dialogue_line.id.to_int()
	var should_count_quick_save := _should_count_for_quick_save(dialogue_line, line_id)
	Main.save_data.mark_read(chapter_name, line_id)
	if should_count_quick_save:
		_register_quick_save_progress()
	dialogue_line = await dialogue.get_next_dialogue_line(dialogue_line.next_id, [ self , Stage])


func process_phone_line() -> void:
	await Game.phone_page.show_dialogue_message(dialogue_line.character, dialogue_line.text)

	if dialogue_line.responses:
		if skip and not Main.setting_data.skip_after_choice:
			_set_mode(AdvanceMode.MANUAL)
			skip_cancelled.emit()
		Game.phone_page.show_reply_options(dialogue_line.responses)
		var next_id: String = await Game.phone_page.reply_selected
		dialogue_line = await dialogue.get_next_dialogue_line(next_id, [self, Stage])

func process_book_line() -> void:
	print("[BookChoice] line id=", dialogue_line.id, " next_id=", dialogue_line.next_id, " tags=", dialogue_line.tags, " responses=", dialogue_line.responses.size(), " text=", dialogue_line.text)
	var side := "right" if dialogue_line.character == "周腾" else "left"
	await Game.book_page.append_story_entry(
		str(dialogue_line.id),
		dialogue_line.character,
		dialogue_line.text,
		side,
		[]
	)
	if dialogue_line.responses:
		print("[BookChoice] show_reply_options count=", dialogue_line.responses.size())
		if skip and not Main.setting_data.skip_after_choice:
			_set_mode(AdvanceMode.MANUAL)
			skip_cancelled.emit()
		Game.book_page.show_reply_options(dialogue_line.responses)
		var next_id: String = await Game.book_page.reply_selected
		print("[BookChoice] selected next_id=", next_id)
		var selected_next_line: DialogueLine = await dialogue.get_next_dialogue_line(next_id, [self, Stage])
		if selected_next_line and "奇迹书" not in selected_next_line.tags:
			await Game.book_page.wait_for_story_close()
		dialogue_line = selected_next_line
		return
	print("[BookChoice] no responses on current book line")
	var next_line: DialogueLine = await dialogue.get_next_dialogue_line(dialogue_line.next_id, [self, Stage])
	if next_line and "奇迹书" not in next_line.tags:
		await Game.book_page.wait_for_story_close()

var expression: String:
	get:
		return dialogue_line.get_tag_value("表情")

func _should_count_for_quick_save(line: DialogueLine, line_id: int) -> bool:
	if line == null or line.text == "" or line_id <= 0:
		return false
	return not Main.save_data.is_line_read(chapter_name, line_id)

func _register_quick_save_progress() -> void:
	quick_save_progress_count += 1
	if quick_save_progress_count < 20:
		return
	quick_save_progress_count = 0
	Game.profile_page.save_quick_game()

func process_dialogue_line() -> void:
	# 新的一句开始处理：解除「等文本」状态，下面的 ShowDialogue 才会真的显示
	release_dialogue_ui_awaiting_text()
	AudioManager.audio_player_voice.stop()

	# 上一句的结束表情：在下一句话开始时应用到对应人物
	if _pending_end_expression and _pending_end_expression_character:
		if Stage.has_character(_pending_end_expression_character):
			Stage.Character(_pending_end_expression_character).SetExpression(_pending_end_expression)
		_pending_end_expression = ""
		_pending_end_expression_character = ""

	var has_avatar = character != null

	# 角色表情/身体（在对话框出现前准备好）
	if has_avatar:
		if dialogue_line.has_tag("身体"):
			character.SetBody(dialogue_line.get_tag_value("身体"))
		if dialogue_line.has_tag("附加"):
			character.ClearOptionals()
			character.SetOptionals(dialogue_line.get_tag_value("附加"))
		if expression:
			character.SetExpression(expression)

		# 存储本句的结束表情，在下一句开始时应用
		if dialogue_line.has_tag("结束表情"):
			_pending_end_expression = dialogue_line.get_tag_value("结束表情")
			_pending_end_expression_character = dialogue_line.character
		elif expression:
			# 如果没有结束表情但有普通表情，清除遗留的结束表情
			_pending_end_expression = ""
			_pending_end_expression_character = ""

	# 角色头像
	avatar.texture = null
	if has_avatar and not "隐藏头像" in dialogue_line.tags:
		avatar.texture = character.dialogue_box.preview_texture
	avatar.modulate.a = 1 if has_avatar else 0

	# 对话框淡入（ShowDialogue 内部会更新角色名、清空文字、设语音按钮）
	await Stage.ShowDialogue()

	# 语音
	if dialogue_line.has_tag("语音") and character:
		update_favourite()
		# 先设音量，再 await 语音加载完成，避免未缓存语音异步加载时自动播放抢跑/语音被切掉
		AudioManager.apply_character_volume(dialogue_line.character)
		await AudioManager.play_voice(voice_name, true)
	else:
		AudioManager.audio_player_voice.stop()

	# 打字（fade in 完成后才开始）
	responses_menu.visible = dialogue_line.responses.size() > 0
	dialogue_label.dialogue_line = dialogue_line
	dialogue_label.type_out()
	while dialogue_label.is_typing:
		await get_tree().process_frame

	# 分支或前进
	if dialogue_line.responses:
		if skip and not Main.setting_data.skip_after_choice:
			_set_mode(AdvanceMode.MANUAL)
			skip_cancelled.emit()
		show_dialogue_responses()
	else:
		await wait_for_advance()


func show_dialogue_responses() -> void:
	for child in responses_menu.get_children():
		child.queue_free()
	for response: DialogueResponse in dialogue_line.responses:
		var selection: DialogueSelection = Prefabs.dialogue_selection.instantiate()
		selection.text = response.text
		selection.pressed.connect(
			func():
				dialogue_line = await dialogue.get_next_dialogue_line(response.next_id, [ self , Stage])
		)
		responses_menu.add_child(selection)


func wait_for_advance() -> void:
	match _mode:
		AdvanceMode.SKIP:
			var is_read = Main.save_data.is_line_read(chapter_name, dialogue_line.id.to_int())
			if not Main.setting_data.skip_unread_text and not is_read:
				_set_mode(AdvanceMode.MANUAL)
				skip_cancelled.emit()
				_idle = true
				await next_line
				_idle = false
			else:
				next_line.emit()
		AdvanceMode.AUTO:
			# 被设置等覆盖页面盖住时挂起自动推进（对白语音也已被暂停），
			# 否则语音被暂停/替换会误触发跳下一句
			var advance_ready := false
			while _mode == AdvanceMode.AUTO and not advance_ready:
				if Game.current_page != self:
					await get_tree().process_frame
					continue
				if dialogue_line.has_tag("语音"):
					while AudioManager.audio_player_voice.playing:
						await get_tree().process_frame
						if _mode != AdvanceMode.AUTO: break
					if _mode != AdvanceMode.AUTO:
						break
					if Game.current_page != self:
						continue
					# 语音播完后的停顿：下一句换人则长一点（1s），同一个人则短（0.2s）
					var pause_time := 1.0 if await _next_speaker_changed() else 0.2
					await get_tree().create_timer(pause_time).timeout
					if _mode != AdvanceMode.AUTO:
						break
					if Game.current_page != self:
						continue
					advance_ready = true
				else:
					await get_tree().create_timer(finish_pause).timeout
					if Game.current_page != self:
						continue
					advance_ready = true
			if _mode == AdvanceMode.AUTO:
				next_line.emit()
			else:
				_idle = true
				await next_line
				_idle = false
		_:
			_idle = true
			await next_line
			_idle = false


# ─── 初始化 ───

func _ready() -> void:
	date.modulate.a = 0
	opening_blur_overlay.visible = false
	_set_opening_blur(0.0, 0.0)
	dialogue_label.visible_characters = 0
	Main.speed_settings_changed.connect(update_step_rate)
	DialogueManager.dialogue_ended.connect(_on_dialogue_end)
	for chapter in chapters:
		var _chapter_name = chapter.resource_path.get_file().split(".")[0]
		chapters_dict[_chapter_name] = chapter

	dialogue_screen.gui_input.connect(_on_dialogue_screen_gui_input)

	button_replay.pressed.connect(AudioManager.replay_voice)
	button_favourite.pressed.connect(
		func():
			if favourite:
				Main.collection_data.voice_collections.erase(current_collection)
				Main.save_collection_data()
				Main.voice_collection_changed.emit(voice_name)
			else:
				# 章节号/章节名取演出表的值，collect_voice 内部已存档并广播
				Main.collect_voice(dialogue_line.character, dialogue_line.text, voice_name, chapter_name)
			update_favourite()
	)
	Main.voice_collection_changed.connect(
		func(vf: String):
			if vf == voice_name:
				update_favourite()
	)

func reset() -> void:
	# 走 cancel_auto_and_skip 而不是直接写 _mode：否则快进/自动按钮会停在按下态（读档后就露出来）
	cancel_auto_and_skip()
	_idle = false
	reset_dialogue_ui_hidden()
	dialogue_line = null
	dialogue_screen.modulate.a = 0
	clear_dialogue_text()
	date.modulate.a = 0
	texture_rect_blackscreen.modulate.a = 0
	texture_rect_cg.texture = null
	texture_rect_cg.visible = false
	texture_rect_variation.texture = null
	avatar.texture = null
	responses_menu.visible = false
	voice_buttons.visible = false
	AudioManager.audio_player_voice.stop()
	stop_background_performance()
	stop_opening_effects()
	Stage.reset()
	quick_save_progress_count = 0
	current_book_segment_start_id = ""

func start() -> void:
	Main.save_data.read_data_list.clear()
	Main.save_save_data()
	reset()
	dialogue_line = await dialogue.get_next_dialogue_line("start", [ self , Stage])
	if not Game.profile_page.has_quick_save():
		Game.profile_page.save_quick_game()


# ─── 收藏 ───

var favourite: bool:
	get: return current_collection != null

var current_collection: VoiceCollection:
	get:
		for collection in Main.collection_data.voice_collections:
			if collection.voice_filename == voice_name:
				return collection
		return null

func update_favourite() -> void:
	texture_rect_favourite.texture = \
		Prefabs.texture_cancel_favourite if favourite else Prefabs.texture_set_favourite

# ─── 对话结束 ───

func _on_dialogue_end(_resource: DialogueResource) -> void:
	if _resource != dialogue:
		return
	AudioManager.audio_player_voice.stop()
	responses_menu.visible = false
	Stage.reset()
	reset()
	Game.switch_to_page(Game.main_menu, true, false)
