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
- No unit test coverage
- Per-character voice volumes saved but not applied during gameplay

## Where to Add

- New page: `pages/new_page/`, register in `Game.gd` page_pool exports
- New autoload: `autoloads/new_system/`, add to project.godot
- New data model: `data/_models/`, extends Resource
- New UI prefab: `prefabs/component_name/`
- New dialogue command: method in `autoloads/stage/stage.gd`

## Detailed Docs

Full architecture analysis: `.planning/codebase/` (ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, STACK.md, CONCERNS.md)
