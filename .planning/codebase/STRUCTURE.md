# Codebase Structure

**Analysis Date:** 2026-04-05

## Directory Layout

```
visual-novel/
├── autoloads/              # Global singletons and systems
│   ├── audio_manager/     # Audio playback and playlist management
│   ├── enums.gd          # Global enumerations
│   ├── expressions.gd    # Expression parsing utilities
│   ├── game/             # UI navigation and page management
│   ├── main/             # Save data and game state
│   ├── prefabs/          # Shared prefabs and instances
│   ├── stage/            # Dialogue and scene management
│   └── tools.gd          # Utility functions
├── addons/               # Godot engine addons
│   ├── dialogue_manager/ # Third-party dialogue system
│   ├── codeandweb.texturepacker/ # Texture packing addon
│   └── ...               # Other editor extensions
├── assets/               # Game assets (art, audio, etc.)
├── characters/           # Character definitions and data
├── data/                 # Game data models
│   └── _models/          # Resource class definitions
├── dialogue_manager/     # Custom dialogue manager scenes
├── pages/                # UI pages and screens
│   ├── main_menu/        # Main menu screen
│   ├── stage_page/       # Core gameplay dialogue screen
│   ├── bonus_page/       # Bonus content with sub-pages
│   ├── book_page/        # Collection/gallery browser
│   ├── log_page/         # Game log and history
│   ├── phone_page/       # In-game phone interface
│   ├── profile_page/     # Profile selection and management
│   ├── travel_page/      # Travel/location screen
│   └── setting_page/     # Game settings
├── prefabs/              # Prefab definitions for reusable UI elements
├── scripts/              # Data class scripts (Resource extensions)
├── scenes/               # Main scene files
├── shaders/              # Custom shader materials
└── themes/               # UI themes and styles
```

## Directory Purposes

**autoloads/**:
- Purpose: Global game systems and singletons
- Contains: Autoloaded nodes for core functionality
- Key files: `game/game.gd`, `stage/stage.gd`, `audio_manager/audio_manager.gd`
- Usage: Accessed globally throughout the game

**pages/**:
- Purpose: Individual game screens and UI pages
- Contains: CanvasLayer nodes with unique functionality
- Key files: `stage_page/stage_page.tscn`, `main_menu/main_menu.tscn`
- Usage: Managed by Game singleton for navigation

**scripts/**:
- Purpose: Data model definitions for persistence
- Contains: Resource classes for game data
- Key files: `save_data.gd`, `profile_data.gd`
- Usage: Extended by game objects for data storage

**data/_models/**:
- Purpose: Data structure definitions
- Contains: Resource class scripts for game entities
- Key files: `background_data.gd`, `character_data.gd`
- Usage: Base classes for game data resources

**characters/**:
- Purpose: Character definitions and assets
- Contains: Character data and configuration
- Key files: `character.gd`, `character_data.gd`
- Usage: Character management and appearance system

**addons/**:
- Purpose: Third-party Godot extensions
- Contains: External tools and systems
- Key files: `dialogue_manager/compiler/compiler.gd`
- Usage: Enhanced editor functionality and systems

## Key File Locations

**Entry Points:**
- `autoloads/main/main.tscn`: Main autoload scene
- `autoloads/game/game.tscn`: Game UI management
- `autoloads/stage/stage.tscn`: Stage and dialogue system

**Configuration:**
- `project.godot`: Engine configuration and settings
- `export_presets.cfg`: Build configuration for exports

**Core Logic:**
- `autoloads/stage/stage.gd`: Dialogue command processing
- `pages/stage_page/stage_page.gd`: Main game UI logic
- `autoloads/audio_manager/audio_manager.gd`: Audio system

**Testing:**
- `pages/debug_page/`: Debug and development tools

## Naming Conventions

**Files:**
- PascalCase for classes and scene files: `StagePage.tscn`, `SaveData.gd`
- snake_case for variables and functions: `dialogue_line`, `process_line()`
- kebab-case for directories: `stage_page`, `bonus_page`

**Directories:**
- Lowercase with underscores: `data/_models`, `pages/main_menu`
- Plural form for collections: `characters`, `backgrounds`

**Variables:**
- camelCase for GDScript variables: `currentDialogue`, `playerStats`
- snake_case for JSON data: `voice_collections`, `character_datas`

## Where to Add New Code

**New Page/Screen:**
- Primary code: `pages/new_page/new_page.gd`
- Scene file: `pages/new_page/new_page.tscn`
- Register in `Game.gd` if needed for navigation

**New Game System:**
- Create autoload singleton in `autoloads/new_system/`
- Add to `project.godot` autoload section
- Implement as Node with exported properties

**New Data Model:**
- Create script in `scripts/new_data.gd` extending Resource
- Add to `data/_models/` for organization
- Implement save/load methods as needed

**New Dialogue Command:**
- Add method to `autoloads/stage/stage.gd`
- Document command syntax for designers
- Update command parsing if necessary

**New UI Component:**
- Create in `prefabs/` for reuse
- Reference via `Prefabs.component_name` in Game autoload
- Add to page scenes as needed

## Special Directories

**.planning/**:
- Purpose: Documentation and planning artifacts
- Generated: Yes
- Committed: Yes - important for team coordination

**addons/**:
- Purpose: Third-party Godot extensions
- Generated: No - vendor packages
- Committed: Yes - required for project functionality

**.godot/**:
- Purpose: Godot engine cache and settings
- Generated: Yes - auto-generated
- Committed: No - excluded from version control

---

*Structure analysis: 2026-04-05*