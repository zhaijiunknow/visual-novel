extends Node

@export var enabled: bool = true
@export var host: String = "127.0.0.1"
@export var port: int = 44712
@export var max_request_bytes: int = 65536
@export var allow_in_export: bool = true
# 默认不在启动时开服务，改成在主菜单敲作弊码启动（见 feed_cheat_key）
@export var auto_start_on_ready: bool = true
# 作弊码：在主菜单依次敲下这些字符即可开关服务。不写存档，仅本次运行有效
@export var cheat_code: String = "neko"

var _server: TCPServer = TCPServer.new()
var _connections: Dictionary = {}
var _listening: bool = false
var _busy: bool = false
var _last_action_result: Dictionary = {}
var _cheat_buffer: String = ""

func _ready() -> void:
	set_process(false)
	if auto_start_on_ready:
		start_server()

func _process(_delta: float) -> void:
	if not _listening:
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if peer:
			_connections[peer.get_instance_id()] = {
				"peer": peer,
				"buffer": PackedByteArray(),
			}

	var stale_ids: Array[int] = []
	for connection_id in _connections.keys():
		var state: Dictionary = _connections[connection_id]
		var peer: StreamPeerTCP = state["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			stale_ids.append(connection_id)
			continue

		var available_bytes := peer.get_available_bytes()
		if available_bytes <= 0:
			continue

		var read_result = peer.get_data(available_bytes)
		if read_result[0] != OK:
			stale_ids.append(connection_id)
			continue

		var buffer: PackedByteArray = state["buffer"]
		buffer.append_array(read_result[1])
		state["buffer"] = buffer
		_connections[connection_id] = state

		if buffer.size() > max_request_bytes:
			_send_json(peer, 413, {
				"ok": false,
				"error": "request too large",
			})
			stale_ids.append(connection_id)
			continue

		if _try_handle_request(connection_id, state):
			stale_ids.append(connection_id)

	for connection_id in stale_ids:
		_close_connection(connection_id)

func _exit_tree() -> void:
	stop_server()

func start_server() -> bool:
	if _listening:
		return true
	if not enabled:
		return false
	if not allow_in_export and not OS.has_feature("editor"):
		return false
	if host != "127.0.0.1":
		push_warning("LocalhostBridge: host must remain 127.0.0.1; forcing localhost binding")
		host = "127.0.0.1"

	var err := _server.listen(port, host)
	if err != OK:
		push_warning("LocalhostBridge: failed to listen on %s:%d (err=%d)" % [host, port, err])
		return false

	_listening = true
	set_process(true)
	print("[LocalhostBridge] Listening on http://%s:%d" % [host, port])
	return true

func stop_server() -> void:
	set_process(false)
	for connection_id in _connections.keys():
		_close_connection(connection_id)
	_connections.clear()
	if _listening:
		_server.stop()
		_listening = false

# 页面把玩家敲下的字符逐个喂进来；末尾凑齐 cheat_code 就切换服务开关
func feed_cheat_key(character: String) -> void:
	if cheat_code.is_empty() or character.is_empty():
		return
	# 只保留末尾 cheat_code.length() 个字符，缓冲区不会无限增长
	var window := cheat_code.length()
	_cheat_buffer = (_cheat_buffer + character).to_lower().right(window)
	if _cheat_buffer != cheat_code.to_lower():
		return
	_cheat_buffer = ""
	_toggle_by_cheat_code()

func _toggle_by_cheat_code() -> void:
	if _listening:
		stop_server()
		print("[LocalhostBridge] Cheat code accepted: server stopped")
		return
	if start_server():
		print("[LocalhostBridge] Cheat code accepted: listening on http://%s:%d" % [host, port])
	else:
		print("[LocalhostBridge] Cheat code accepted, but the server did not start (enabled=%s, allow_in_export=%s)"
			% [enabled, allow_in_export])

func _try_handle_request(connection_id: int, state: Dictionary) -> bool:
	var buffer: PackedByteArray = state["buffer"]
	if buffer.is_empty():
		return false

	var request_text := buffer.get_string_from_utf8()
	var header_end := request_text.find("\r\n\r\n")
	if header_end == -1:
		return false

	var header_text := request_text.substr(0, header_end)
	var header_lines := header_text.split("\r\n")
	if header_lines.is_empty():
		_send_json(state["peer"], 400, {"ok": false, "error": "invalid request line"})
		return true

	var request_line_parts := header_lines[0].split(" ")
	if request_line_parts.size() < 2:
		_send_json(state["peer"], 400, {"ok": false, "error": "invalid request line"})
		return true

	var method := request_line_parts[0].to_upper()
	var path := request_line_parts[1]
	var headers := _parse_headers(header_lines)
	var content_length := int(headers.get("content-length", "0"))
	var body_offset := header_end + 4
	if buffer.size() < body_offset + content_length:
		return false

	var body_text := ""
	if content_length > 0:
		body_text = buffer.slice(body_offset, body_offset + content_length).get_string_from_utf8()

	_handle_request(state["peer"], method, path, headers, body_text)
	return true

func _parse_headers(header_lines: Array[String]) -> Dictionary:
	var headers := {}
	for i in range(1, header_lines.size()):
		var line: String = header_lines[i]
		var separator := line.find(":")
		if separator == -1:
			continue
		var key := line.substr(0, separator).strip_edges().to_lower()
		var value := line.substr(separator + 1).strip_edges()
		headers[key] = value
	return headers

func _handle_request(peer: StreamPeerTCP, method: String, raw_path: String, headers: Dictionary, body_text: String) -> void:
	var path := raw_path.split("?")[0]
	match method:
		"GET":
			match path:
				"/healthz":
					_send_json(peer, 200, _build_health_payload())
				"/state":
					_send_json(peer, 200, _build_state_payload())
				_:
					_send_json(peer, 404, {"ok": false, "error": "route not found"})
		"POST":
			if path != "/action":
				_send_json(peer, 404, {"ok": false, "error": "route not found"})
				return
			if headers.get("content-type", "").find("application/json") == -1:
				_send_json(peer, 415, {"ok": false, "error": "content-type must be application/json"})
				return
			_handle_action_request(peer, body_text)
		_:
			_send_json(peer, 405, {"ok": false, "error": "method not allowed"})

func _handle_action_request(peer: StreamPeerTCP, body_text: String) -> void:
	var payload = JSON.parse_string(body_text)
	if typeof(payload) != TYPE_DICTIONARY:
		_send_json(peer, 400, {"ok": false, "error": "invalid JSON body"})
		return

	var action := str(payload.get("action", ""))
	var request_id := str(payload.get("request_id", ""))
	var params = payload.get("params", {})
	if action.is_empty():
		_send_json(peer, 400, {"ok": false, "error": "action is required"})
		return
	if typeof(params) != TYPE_DICTIONARY:
		_send_json(peer, 400, {"ok": false, "error": "params must be an object"})
		return
	if not _is_allowed_action(action):
		_send_json(peer, 400, {"ok": false, "error": "unknown action"})
		return
	if action == "stage.debug_dialogue_lines":
		_send_json(peer, 200, _handle_debug_dialogue_lines_query(params, request_id))
		return
	if _busy:
		_send_json(peer, 409, {"ok": false, "error": "bridge busy"})
		return

	_start_action(action, params, request_id)
	_send_json(peer, 202, {
		"ok": true,
		"accepted": true,
		"request_id": request_id,
		"action": action,
	})

func _is_allowed_action(action: String) -> bool:
	return action in [
		"game.switch_page",
		"game.go_back",
		"game.continue",
		"game.start_new",
		"game.save_quick",
		"game.open_panel",
		"dialogue.advance",
		"dialogue.skip_typing",
		"dialogue.set_mode",
		"dialogue.choose_response",
		"stage.start",
		"stage.start_at",
		"stage.debug_dialogue_lines",
		"stage.reset",
		"stage.show_phone",
		"stage.hide_phone",
		"stage.open_book",
		"stage.close_book",
		"stage.set_background",
		"stage.set_cg",
		"stage.hide_cg",
		"stage.set_date",
		"stage.set_music",
		"stage.stop_music",
		"stage.write_book",
	]

func is_busy() -> bool:
	return _busy

func get_last_action_result() -> Dictionary:
	return _last_action_result.duplicate(true)

func _start_action(action: String, params: Dictionary, request_id: String) -> void:
	_busy = true
	_last_action_result = {
		"request_id": request_id,
		"action": action,
		"status": "running",
		"error": "",
		"started_at_ms": _now_ms(),
		"finished_at_ms": 0,
	}
	call_deferred("_run_action", action, params, request_id)

func _run_action(action: String, params: Dictionary, request_id: String) -> void:
	var ok := true
	var error_message := ""

	match action:
		"game.switch_page":
			var page := _get_page_by_bridge_name(str(params.get("page", "")))
			if page == null:
				ok = false
				error_message = "unknown page"
			else:
				await Game.switch_to_page(page, _as_bool(params.get("transition", true), true), _as_bool(params.get("addition_mode", false), false))
		"game.go_back":
			await Game.go_back(_as_bool(params.get("transition", true), true))
		"game.continue":
			# 和「长按/右键 开始游戏」完全同一条路：按钮发信号 → main_menu._continue_game()
			# （有快速/手动存档就继续，没有就自动开新档）
			Game.main_menu.button_start.continue_requested.emit()
			ok = true
		"game.start_new":
			# 和左键点「开始游戏」同一条路（含 reset_notebook、清空已读记录）
			Game.main_menu.button_start.clicked.emit()
			ok = true
		"game.save_quick":
			# 和「每 20 句自动存档」「快速存档」调的是同一个函数
			Game.profile_page.save_quick_game()
			ok = true
		"game.open_panel":
			# 面板名见 Game._build_hotkeys 的表（save/load/character/gallery/music/voice/phone/book/settings）。
			# 走的是 Game.open_panel_by_name —— 和按快捷键完全同一条路，含门禁
			var panel := str(params.get("panel", ""))
			ok = Game.open_panel_by_name(panel)
			if not ok:
				error_message = "panel not available now: %s" % panel
		"dialogue.advance":
			ok = Game.stage_page.advance_from_bridge()
			if not ok:
				error_message = "dialogue cannot advance in current state"
		"dialogue.skip_typing":
			ok = Game.stage_page.skip_typing_from_bridge()
			if not ok:
				error_message = "dialogue is not typing"
		"dialogue.set_mode":
			ok = Game.stage_page.set_mode_from_bridge(str(params.get("mode", "")))
			if not ok:
				error_message = "invalid dialogue mode"
		"dialogue.choose_response":
			ok = await Game.stage_page.choose_response_from_bridge(int(params.get("index", -1)), str(params.get("next_id", "")))
			if not ok:
				error_message = "unable to choose response"
		"stage.start":
			var chapter_name := str(params.get("chapter_name", ""))
			if chapter_name.is_empty():
				ok = false
				error_message = "chapter_name is required"
			else:
				await Game.switch_to_page(Game.stage_page, _as_bool(params.get("transition", true), true), false)
				ok = await Game.stage_page.start_chapter_from_bridge(chapter_name)
				if not ok:
					error_message = "unknown chapter"
		"stage.start_at":
			var chapter_name := str(params.get("chapter_name", ""))
			var next_id := str(params.get("next_id", ""))
			if chapter_name.is_empty() or next_id.is_empty():
				ok = false
				error_message = "chapter_name and next_id are required"
			else:
				await Game.switch_to_page(Game.stage_page, _as_bool(params.get("transition", true), true), false)
				ok = await Game.stage_page.start_at_from_bridge(chapter_name, next_id)
				if not ok:
					error_message = "unknown chapter or next_id"
		"stage.reset":
			Game.stage_page.reset()
		"stage.show_phone":
			await Stage.ShowPhone()
		"stage.hide_phone":
			await Stage.HidePhone()
		"stage.open_book":
			await Stage.OpenBook()
		"stage.close_book":
			await Stage.CloseBook()
		"stage.set_background":
			var background_name := str(params.get("background_name", ""))
			var variation_name := str(params.get("variation_name", ""))
			if background_name.is_empty() or variation_name.is_empty():
				ok = false
				error_message = "background_name and variation_name are required"
			else:
				await Stage.SetBackground(
					background_name,
					variation_name,
					float(params.get("out_time", 1.2)),
					float(params.get("in_time", 1.2))
				)
		"stage.set_cg":
			var cg_name := str(params.get("cg_name", ""))
			var cg_variation := str(params.get("variation_name", ""))
			if cg_name.is_empty() or cg_variation.is_empty():
				ok = false
				error_message = "cg_name and variation_name are required"
			else:
				await Stage.SetCG(cg_name, cg_variation)
		"stage.hide_cg":
			await Stage.HideCG()
		"stage.set_date":
			var week_day := str(params.get("week_day", ""))
			var month := int(params.get("month", 0))
			var day := int(params.get("day", 0))
			if month <= 0 or day <= 0 or week_day.is_empty():
				ok = false
				error_message = "month, day, and week_day are required"
			else:
				await Stage.SetDate(month, day, week_day)
		"stage.set_music":
			var music_name := str(params.get("music_name", ""))
			if music_name.is_empty():
				ok = false
				error_message = "music_name is required"
			else:
				await Stage.SetMusic(music_name)
		"stage.stop_music":
			await Stage.StopMusic()
		"stage.write_book":
			var entry_id := str(params.get("entry_id", ""))
			var speaker := str(params.get("speaker", ""))
			var text := str(params.get("text", ""))
			if entry_id.is_empty() or speaker.is_empty() or text.is_empty():
				ok = false
				error_message = "entry_id, speaker, and text are required"
			else:
				await Stage.WriteBook(
					entry_id,
					speaker,
					text,
					str(params.get("side", "")),
					params.get("tags", [])
				)
		_:
			ok = false
			error_message = "unknown action"

	_busy = false
	var debug_payload = _last_action_result.get("debug_payload", {})
	_last_action_result = {
		"request_id": request_id,
		"action": action,
		"status": "ok" if ok else "error",
		"error": error_message,
		"started_at_ms": int(_last_action_result.get("started_at_ms", _now_ms())),
		"finished_at_ms": _now_ms(),
		"debug_payload": debug_payload,
	}

func _handle_debug_dialogue_lines_query(params: Dictionary, request_id: String) -> Dictionary:
	var started_at_ms := _now_ms()
	var debug_payload := Game.stage_page.get_bridge_dialogue_debug_lines(
		str(params.get("chapter_name", "")),
		str(params.get("text_query", "")),
		str(params.get("key_query", "")),
		int(params.get("limit", 50)),
		int(params.get("offset", 0)),
		_as_bool(params.get("include_total", false), false)
	)
	var ok := bool(debug_payload.get("ok", false))
	var error_message := "" if ok else str(debug_payload.get("error", "unable to inspect dialogue lines"))
	_last_action_result = {
		"request_id": request_id,
		"action": "stage.debug_dialogue_lines",
		"status": "ok" if ok else "error",
		"error": error_message,
		"started_at_ms": started_at_ms,
		"finished_at_ms": _now_ms(),
		"debug_payload": debug_payload,
		"result": debug_payload,
	}
	return debug_payload

func _get_page_by_bridge_name(page_name: String) -> CanvasLayer:
	match page_name:
		"main_menu":
			return Game.main_menu
		"stage":
			return Game.stage_page
		"profile":
			return Game.profile_page
		"travel":
			return Game.travel_page
		"book":
			return Game.book_page
		"log":
			return Game.log_page
		"phone":
			return Game.phone_page
		"setting":
			return Game.setting_page
		"confirm":
			return Game.confirm_page
		"bonus":
			return Game.bonus_page
		"loading":
			return Game.loading_page
		_:
			return null

func _build_health_payload() -> Dictionary:
	return {
		"ok": true,
		"service": "visual-novel-localhost-bridge",
		"listening": _listening,
		"host": host,
		"port": port,
		"busy": _busy,
	}

func _build_state_payload() -> Dictionary:
	return {
		"ok": true,
		"timestamp_ms": _now_ms(),
		"bridge": {
			"listening": _listening,
			"busy": _busy,
			"last_action": _last_action_result.duplicate(true),
		},
		"game": {
			"loading": Game.loading,
			"current_page": Game.current_page.name if Game.current_page else "",
			"page_stack": _get_page_stack_names(),
		},
		"stage": {
			"background": Stage.current_background,
			"date": Stage.current_date,
			"cg_name": Stage.current_cg,
			"cg_variation": Stage.current_cg_variation,
			"characters": _get_visible_character_states(),
		},
		"dialogue": Game.stage_page.get_bridge_dialogue_state(),
		"phone": Game.phone_page.get_bridge_phone_state(),
		"book": Game.book_page.get_bridge_book_state(),
		"audio": _build_audio_payload(),
		"dialogue_debug": _last_action_result.get("debug_payload", {}),
	}

func _get_page_stack_names() -> Array[String]:
	var names: Array[String] = []
	for page in Game.page_stack:
		names.append(page.name)
	return names

func _get_visible_character_states() -> Array[Dictionary]:
	var characters: Array[Dictionary] = []
	for character: Character in Stage.character_array:
		var data := character.get_character_data()
		if data.position == "":
			continue
		characters.append({
			"character_name": data.character_name,
			"body": data.body,
			"eyebrows": data.eyebrows,
			"eyes": data.eyes,
			"mouth": data.mouth,
			"optionals": data.optionals.duplicate(),
			"position": data.position,
			"expression": character.current_expression,
			"on_stage": true,
		})
	return characters

func _build_audio_payload() -> Dictionary:
	var music_player = AudioManager.audio_player_music
	var voice_player = AudioManager.audio_player_voice
	return {
		"music_source": _music_source_name(AudioManager._music_source),
		"music_path": music_player.stream.resource_path if music_player.stream else "",
		"music_playing": music_player.playing,
		"music_position": music_player.get_playback_position() if music_player.playing else 0.0,
		"voice_playing": voice_player.playing,
		"voice_name": Game.stage_page.voice_name,
	}

func _music_source_name(source: int) -> String:
	match source:
		AudioManager.MusicSource.NONE:
			return "none"
		AudioManager.MusicSource.THEME:
			return "theme"
		AudioManager.MusicSource.PLAYLIST:
			return "playlist"
		_:
			return "unknown"

func _send_json(peer: StreamPeerTCP, status_code: int, payload: Dictionary) -> void:
	var body := JSON.stringify(payload)
	var response := "HTTP/1.1 %d %s\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [
		status_code,
		_http_status_text(status_code),
		body.to_utf8_buffer().size(),
		body,
	]
	peer.put_data(response.to_utf8_buffer())

func _http_status_text(status_code: int) -> String:
	match status_code:
		200:
			return "OK"
		202:
			return "Accepted"
		400:
			return "Bad Request"
		404:
			return "Not Found"
		405:
			return "Method Not Allowed"
		409:
			return "Conflict"
		413:
			return "Payload Too Large"
		415:
			return "Unsupported Media Type"
		_:
			return "Internal Server Error"

func _close_connection(connection_id: int) -> void:
	if not _connections.has(connection_id):
		return
	var peer: StreamPeerTCP = _connections[connection_id]["peer"]
	if peer:
		peer.disconnect_from_host()
	_connections.erase(connection_id)

func _as_bool(value, default_value: bool) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return value != 0
		TYPE_FLOAT:
			return not is_zero_approx(value)
		TYPE_STRING:
			return value.to_lower() in ["1", "true", "yes", "on"]
		_:
			return default_value

func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
