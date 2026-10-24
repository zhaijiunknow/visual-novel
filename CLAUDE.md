# Visual Novel - Godot 4.6 GDScript

## Architecture

Scene-based Event-Driven with Autoload Singletons.

```
Autoloads (singletons)     Pages (CanvasLayer)      Prefabs (reusable UI)
─────────────────────      ────────────────────      ─────────────────────
Main  → save/state/data    main_menu                 SelectionButton
Game  → page navigation    stage_page (core)         SliderEx
Stage → dialogue commands  bonus_page                TabItem
AudioManager → 4 players   setting_page              CharacterVoiceCard
Prefabs → shared refs      book/log/phone/           back_button/setting_label
                           profile/travel/confirm    InteractSound (component)
```

## Data Flow

1. `Main._ready()` loads SaveData, CollectionData, SettingData from `user://`
2. `Game.switch_to_page()` manages stack-based navigation with fade transitions
3. `Stage` processes dialogue commands, drives `StagePage` UI
4. `AudioManager` controls 4 AudioStreamPlayers (music, sound, voice, bonus)
5. Persistence: `ResourceSaver.save()` → `user://*.tres`

## 存档目录（测试 / 正式）

代码里的存档路径一律写成 `user://xxx`，实际落盘位置由 project.godot 的特性标签覆盖决定：

| 构建 | 触发条件 | user:// 实际指向 |
|------|----------|------------------|
| 测试 | 编辑器运行、**Debug 模板**导出 | `%APPDATA%\Godot\app_userdata\无言初雪与奇迹书` |
| 正式 | **Release 模板**导出 | `%APPDATA%\无言初雪与奇迹书` |

- 靠 `config/use_custom_user_dir.release` + `config/custom_user_dir_name.release` 实现，**判定依据是导出时选的模板，不是导出预设名**
- 测试目录里是测试人员多轮迭代出来的存档（格式可能互不通用），**不要删、不要迁移**，后续迭代继续用它
- 发给测试人员的包必须用 Debug 模板导出，否则会落到正式目录
- 诊断包（`autoloads/diagnostic/`）跟着 `user://` 走，两套目录都会自动收进去

## Key Files

| Purpose | Path |
|---------|------|
| Entry / State | `autoloads/main/main.gd` |
| Navigation | `autoloads/game/game.gd` |
| Dialogue | `autoloads/stage/stage.gd` |
| Audio | `autoloads/audio_manager/audio_manager.gd` |
| Interact Sound | `prefabs/components/interact_sound.gd` |
| Settings UI | `pages/setting_page/setting_page.gd` |
| Data models | `data/_models/*.gd` (Resource subclasses) |
| Save logic | `scripts/save_data.gd`, `scripts/profile_data.gd` |

## Autoloads Registration (project.godot)

Main → DialogueManager → AudioManager → Stage → Game → Prefabs → DebugPage

## Key Data Models

- **SettingData** (`data/_models/setting_data.gd`): fullscreen, text/auto speed, volumes, character_volumes dict, mute_all
- **SaveData** (`scripts/save_data.gd`): profiles, game progress
- **CollectionData** (`data/_models/collection_data.gd`): unlocked voice collections
- **MusicData** (`data/_models/music_data.gd`): playlist entries

## Conventions

- GDScript 4, tabs for indentation
- Pages extend CanvasLayer, managed by Game singleton's page_stack
- UI components use `@tool` + `@export` for editor configuration
- SelectionButton: click via `gui_input` signal, state via `selected` bool
- SliderEx: custom slider, `value` (0-1 float), `value_changed` signal
- TabItem: `select()` shows target_tab, hides siblings
- Persistence: `Resource` subclasses → `ResourceSaver.save()` / `load()`
- Bilingual labels: `title_zh` + `title_en` properties
- Chinese comments for domain-specific logic
- **DRY principle**: Never repeat yourself — extract shared logic into helpers, base classes, or autoloads
- **Component pattern**: Reusable behaviors as child Node prefabs (e.g. DragFilter, InteractSound) — attach to any Control without modifying its script

## Skip/Fast-Forward System

Three toggleable conditions stored in `SettingData`:

| Condition | Field | ON | OFF |
|-----------|-------|----|-----|
| 未读文本 (Skip Unread) | `skip_unread` | Skip ALL text incl. unread | Stop at unread text |
| 选项后继续 (After Choice) | `skip_after_choice` | Pause at choice → auto-resume after selecting | Return to normal after choice |
| 忽略转场 (Skip Transitions) | `skip_ignore_transitions` | Skip transition/performance animations | Play normally |

The skip unread ON/OFF toggle (`btn_skip_unread_text_on/off`) sets `skip_unread`.
The three multi-select buttons set `skip_unread_text`, `skip_after_choice`, `skip_ignore_transitions`.

## Sound System

### InteractSound Component (`prefabs/components/interact_sound.gd`)

Reusable Node prefab (like DragFilter) that adds click/hover sounds to any Control. Drop `interact_sound.tscn` as a child node — no code changes needed on the parent component.

- `@export var target: Control` — defaults to parent node
- `@export var click_sound: AudioStream` — played on left click
- `@export var hover_sound: AudioStream` — played on mouse enter
- Uses shared `AudioManager.audio_player_sound` (single AudioStreamPlayer, not per-instance)

### Music Ducking

When voice plays, music volume tween ducks to 50% over 0.3s, restores on voice finished. Handled globally in `AudioManager._duck_music()` / `_unduck_music()`. Voice page (`voice_page.gd`) additionally uses `pause_music()` / `resume_music()` for full music pause.

### Chat Message Effects

`phone_page.gd` `_add_chat_message()`: each ChatMessage fades in (modulate alpha 0→1, 0.3s) with 手机发消息音效.wav sound.

## Known Issues

- Node paths in .tscn files are fragile (use `@export` NodePaths)
- Large dialogue files loaded synchronously
- Per-character voice volumes saved but not applied during gameplay

## Testing

`tests/` holds a dependency-free regression suite (headless, exit code 0/1):

```powershell
Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe `
  --headless --path . res://tests/regression_test.tscn
```

It pins the 2026-10 crash chain (half-written `user://*.tres` → `null` global → diagnostic export
0xC0000005): corrupt-file recovery, atomic save, null-safe diagnostic snapshot. Run it before
exporting a build. See `tests/README.md` for coverage and the manual cold-start e2e recipe.

## Persistence Rules

- Global load paths must never yield `null`: go through `Main._read_resource()`, which backs a broken
  file up to `*.bad` and leaves the default value in place
- All disk writes go through `Main._save_resource_atomic()` (`.tmp.tres` + rename). Never call
  `ResourceSaver.save()` straight to a live save path — an interrupted write leaves a half file that
  blocks every later launch

## Where to Add

- New page: `pages/new_page/`, register in `Game.gd` page_pool exports
- New autoload: `autoloads/new_system/`, add to project.godot
- New data model: `data/_models/`, extends Resource
- New UI prefab: `prefabs/component_name/`
- New dialogue command: method in `autoloads/stage/stage.gd`

## Detailed Docs

Full architecture analysis: `.planning/codebase/` (ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, STACK.md, CONCERNS.md)
