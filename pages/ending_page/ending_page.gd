class_name EndingPage
extends CanvasLayer

## 剧本（序章）结束后的结局演出：PV（→ 感谢图 1 → 感谢图 2，demo 可选）。
## 由章节末尾的 `$> PlayEndingPV()`（Stage.PlayEndingPV）切入；感谢图之间点击切换。
## 演完停在全黑并 emit finished，之后回标题还是继续剧情由调用方决定。
##
## 转场统一走 Game.fade()（SubViewportContainer 上那个变黑的 shader），
## 和页面切换用的是同一套，所以从剧情切进 PV 不会有两套不同的黑场。
## PV → 感谢图是「淡到全黑 → 再从黑里亮起」，中间不留硬切；
## 感谢图 1 → 2 则是叠加交叉淡入，不打断画面的连续感。

signal finished

enum State { IDLE, PV, IMAGE_1, IMAGE_2, FINISHED }

@export_group("节点")
@export var video: VideoStreamPlayer
@export var image_1: TextureRect
@export var image_2: TextureRect
@export var thanks_bgm: AudioStreamPlayer
@export var click_catcher: Control

@export_group("时长")
## PV 播完到开始变黑之间留一点余韵
@export_range(0.0, 2.0, 0.1) var pv_end_hold: float = 0.4
## PV → 感谢图：先淡到全黑，再从黑里亮起
@export_range(0.1, 3.0, 0.1) var pv_fade_to_black: float = 1.2
@export_range(0.1, 3.0, 0.1) var reveal_fade_in: float = 1.6
## 感谢图 1 → 2 的交叉淡入
@export_range(0.1, 3.0, 0.1) var image_crossfade: float = 1.0
## 最后淡出到黑场的时长；之后去哪由调用方接管（见 Stage.PlayEndingPV）
@export_range(0.1, 3.0, 0.1) var return_fade: float = 1.2
## 感谢图亮起时的缓慢回缩（reveal_scale → 1.0），给静帧一点呼吸感
@export_range(1.0, 1.2, 0.01) var reveal_scale: float = 1.04
## PV 是否允许点击跳过。默认不跳过：这是剧本演完的奖励，误触不该跳过整段
@export var pv_skippable: bool = false
## 感谢图展示后自动切到下一张的间隔（秒）。默认 30 分钟；点击仍可立即切换。
@export var image_auto_advance_seconds: float = 1800.0
## 是否展示感谢图。由剧情命令决定（见 Stage.PlayEndingPV）：
## `$> PlayEndingPV(true)` = demo，PV 后接感谢图；`$> PlayEndingPV()` / false = 正式版，PV 播完直接回剧情。
var show_thanks_images: bool = false

var _state: State = State.IDLE
var _busy: bool = false
var _auto_advance_token: int = 0
var _bgm_fade_tween: Tween

func _ready() -> void:
	video.finished.connect(_on_video_finished)
	thanks_bgm.finished.connect(_on_thanks_bgm_finished)
	click_catcher.gui_input.connect(_on_click_catcher_gui_input)
	_reset_visuals()
	hide()

func play() -> void:
	_reset_visuals()
	_state = State.PV
	_busy = false

	# PV 的音频按「音乐音量」走，静音开关也一并尊重
	var volume: float = 0.0 if Main.setting_data.mute_all else Main.setting_data.music_volume
	video.volume_db = linear_to_db(volume) if volume > 0.0 else -80.0
	# 剧本最后一句通常已经 StopMusic，这里再兜一次底，免得 PV 和人声/音乐叠在一起
	AudioManager.audio_player_music.stop()
	AudioManager.audio_player_voice.stop()

	if video.stream == null:
		push_warning("[Ending] PV 资源为空，直接进感谢图")
		# Game.switch_to_page 的黑场淡入还在跑，等它结束再切，免得两个 tween 抢 iterations
		await get_tree().create_timer(0.6).timeout
		await _reveal_image(image_1, State.IMAGE_1)
		return
	video.play()
	print("[UI] 结局演出·PV 开始，感谢图=%s" % show_thanks_images)

func _reset_visuals() -> void:
	_auto_advance_token += 1
	_stop_thanks_bgm()
	video.stop()
	video.visible = true
	video.modulate.a = 1.0
	for image: TextureRect in [image_1, image_2]:
		image.visible = false
		image.modulate.a = 0.0
		image.scale = Vector2.ONE

func _on_video_finished() -> void:
	if _state != State.PV:
		return
	await get_tree().create_timer(pv_end_hold).timeout
	if _state != State.PV:
		return
	# 正式版不展示感谢图：PV 播完直接走结尾黑场
	if not show_thanks_images:
		await _finish()
		return
	await _reveal_image(image_1, State.IMAGE_1)

## PV → 感谢图：全黑之后再把静帧从黑里亮起，同时缓慢回缩
func _reveal_image(target: TextureRect, next_state: State) -> void:
	_busy = true
	await Game.fade(false, pv_fade_to_black)
	video.stop()
	video.visible = false
	_start_thanks_bgm()

	target.visible = true
	# 此时整屏还是黑的（Game.fade 已经把 iterations 拉到 1），
	# 所以直接把图放成不透明，亮度完全交给黑场淡出来控制 —— 不要再叠一层 alpha 淡入
	target.modulate.a = 1.0
	target.scale = Vector2(reveal_scale, reveal_scale)

	# 回缩和黑场淡出并行，画面像慢慢从黑里浮出来
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(target, "scale", Vector2.ONE, reveal_fade_in * 4.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await Game.fade(true, reveal_fade_in)
	_state = next_state
	_busy = false
	print("[UI] 结局演出·感谢图 1" if next_state == State.IMAGE_1 else "[UI] 结局演出·感谢图 2")
	_schedule_auto_advance()

## 感谢图 1 → 2：不经过黑场，直接把第二张叠上来交叉淡入
func _crossfade_to_second() -> void:
	_busy = true
	image_2.visible = true
	image_2.modulate.a = 0.0
	image_2.scale = Vector2(reveal_scale, reveal_scale)

	var tween := create_tween().set_parallel(true)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(image_2, "modulate:a", 1.0, image_crossfade)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(image_2, "scale", Vector2.ONE, image_crossfade * 3.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 只等淡入完成（回缩还在继续），期间挡住连点
	await get_tree().create_timer(image_crossfade).timeout
	image_1.visible = false
	_state = State.IMAGE_2
	_busy = false
	print("[UI] 结局演出·感谢图 2")
	_schedule_auto_advance()

func _finish() -> void:
	_busy = true
	_state = State.FINISHED
	_auto_advance_token += 1
	_stop_thanks_bgm(return_fade * 0.7)
	await Game.fade(false, return_fade)

	video.stop()
	_busy = false
	print("[UI] 结局演出结束")
	# 画面停在全黑；下一步去哪由调用方决定（见 Stage.PlayEndingPV）：
	# 回到剧情页接着演后面的内容，后面是 => END 就由 dialogue_ended 回标题。
	finished.emit()

# ─── 交互 ──────────────────────────────────────────────

func _on_click_catcher_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	_advance()

func _advance() -> void:
	if _busy:
		return
	match _state:
		State.PV:
			if pv_skippable:
				if show_thanks_images:
					await _reveal_image(image_1, State.IMAGE_1)
				else:
					await _finish()
		State.IMAGE_1:
			await _crossfade_to_second()
		State.IMAGE_2:
			await _finish()

## 长时间没人点击时自动切到下一张（默认 30 分钟），点击仍可立即切换。
## token 用来作废旧定时器：手动切换或重播时 token 会变，旧定时器醒来直接退出。
func _schedule_auto_advance() -> void:
	_auto_advance_token += 1
	var token := _auto_advance_token
	await get_tree().create_timer(image_auto_advance_seconds).timeout
	if token != _auto_advance_token or _busy:
		return
	match _state:
		State.IMAGE_1:
			await _crossfade_to_second()
		State.IMAGE_2:
			await _finish()

# ─── 感言图配乐 ──────────────────────────────────────

## 配乐跟随音乐音量/静音设置；曲目播完自动从头再来（感谢图可以停留很久）
func _start_thanks_bgm() -> void:
	if thanks_bgm == null:
		return
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	var volume: float = 0.0 if Main.setting_data.mute_all else Main.setting_data.music_volume
	thanks_bgm.volume_db = linear_to_db(volume) if volume > 0.0 else -80.0
	if not thanks_bgm.playing:
		thanks_bgm.play()

func _on_thanks_bgm_finished() -> void:
	if _state == State.IMAGE_1 or _state == State.IMAGE_2:
		thanks_bgm.play()

## fade_duration = 0 时立即停
func _stop_thanks_bgm(fade_duration: float = 0.0) -> void:
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	if thanks_bgm == null or not thanks_bgm.playing:
		return
	if fade_duration <= 0.0:
		thanks_bgm.stop()
		return
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_bgm_fade_tween.tween_property(thanks_bgm, "volume_db", -80.0, fade_duration)
	_bgm_fade_tween.finished.connect(thanks_bgm.stop)
