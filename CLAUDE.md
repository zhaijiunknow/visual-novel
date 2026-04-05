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
                           profile/travel/confirm
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
