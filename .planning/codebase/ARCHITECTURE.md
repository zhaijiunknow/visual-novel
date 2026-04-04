# Architecture

**Analysis Date:** 2026-04-05

## Pattern Overview

**Overall:** Scene-based Event-Driven Architecture with Autoload Singletons

**Key Characteristics:**
- Godot Scene Tree as the primary structure
- Autoload singletons for global state and systems
- Page-based UI navigation system
- Dialogue-driven narrative gameplay
- Event-driven communication between systems

## Layers

**Application Layer (Autoloads):**
- Purpose: Global systems and state management
- Location: `autoloads/`
- Contains: Singleton nodes for core functionality
- Depends on: Lower layers (scenes, resources)
- Used by: All game systems and UI

**Presentation Layer (Pages):**
- Purpose: User interface and game pages
- Location: `pages/`
- Contains: CanvasLayer nodes for different screens
- Depends on: Application layer, Dialogue Manager
- Used by: Player interactions

**Dialogue Layer:**
- Purpose: Narrative content and dialogue processing
- Location: `dialogue_manager/`, `scripts/`
- Contains: Dialogue resources, processing logic
- Depends on: Presentation layer for display
- Used by: Stage page, dialogue interactions

**Data Layer:**
- Purpose: Game data models and resources
- Location: `data/_models/`, `scripts/`
- Contains: Resource classes for game entities
- Depends on: Godot Resource system
- Used by: All layers for data persistence

## Data Flow

**Game Flow:**

1. **Entry**: `Main` autoload initializes save/collection data
2. **Navigation**: `Game` singleton manages page stack with transitions
3. **Gameplay**: `Stage` singleton handles dialogue commands and scene changes
4. **Dialogue**: Dialogue Manager processes lines and displays via `StagePage`
5. **Audio**: `AudioManager` plays music, sound effects, and voice tracks
6. **Persistence**: `Main` saves game state to `user://` directory

**State Management:**
- Global state stored in autoload singletons
- Page state managed by individual page scripts
- Save data persisted as Godot Resources (.tres files)
- Collections data for unlocked content

## Key Abstractions

**Page System:**
- Purpose: Abstract navigation between different game screens
- Examples: `pages/main_menu/main_menu.tscn`, `pages/stage_page/stage_page.tscn`
- Pattern: Stack-based navigation with fade transitions

**Dialogue System:**
- Purpose: Handle narrative content and character interactions
- Examples: `addons/dialogue_manager/`, `pages/stage_page/stage_page.gd`
- Pattern: Event-driven with custom commands and tags

**Character System:**
- Purpose: Manage character appearances and expressions
- Examples: `characters/character.gd`, `characters/character_data.gd`
- Pattern: Component-based with modular parts

**Resource System:**
- Purpose: Data persistence and game assets
- Examples: `scripts/save_data.gd`, `scripts/profile_data.gd`
- Pattern: Godot Resource classes with export properties

## Entry Points

**Main Scene:**
- Location: `scenes/main_scene/main_scene.tscn` (autoloaded as `Main`)
- Triggers: Game initialization and save data loading
- Responsibilities: Global state management and scene switching

**Game Singleton:**
- Location: `autoloads/game/game.tscn`
- Triggers: Page navigation and transitions
- Responsibilities: UI management and game flow control

**Stage Singleton:**
- Location: `autoloads/stage/stage.tscn`
- Triggers: Dialogue execution and scene commands
- Responsibilities: Game content presentation and character management

## Error Handling

**Strategy:** Defensive programming with null checks and fallbacks

**Patterns:**
- Character existence checks before use
- Default backgrounds when not specified
- Graceful handling of missing voice files

## Cross-Cutting Concerns

**Logging:** Uses Godot's print() for debug information
**Validation:** Input validation in dialogue processing
**Audio:** Centralized audio management with multiple players for different types
**Save System:** Resource-based persistence with encryption on export

---

*Architecture analysis: 2026-04-05*