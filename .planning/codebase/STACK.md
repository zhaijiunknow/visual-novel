# Technology Stack

**Analysis Date:** 2026-04-05

## Languages

**Primary:**
- GDScript (Godot Engine) - All game logic, UI systems, and custom components

**Secondary:**
- None (Pure GDScript implementation)

## Runtime

**Environment:**
- Godot Engine 4.6 - Core game engine
- Windows Desktop target (config/features: "4.6", "GL Compatibility")
- Resolution: 2560x1440 (custom window size 1200x600)

**Package Manager:**
- None (Godot handles asset imports and management internally)
- Lockfile: Not applicable (Godot .godot directory stores imported assets)

## Frameworks

**Core:**
- Godot Engine 4.6 - Game engine for all functionality
- CanvasLayer system - Page management and UI organization

**Game Systems:**
- Dialogue Manager 3.10.2 - Dialogue system and content management
- Custom state machine - Page navigation and game flow

**UI/UX:**
- Custom UI components - All UI built from Godot base nodes
- Shader effects - Post-processing transitions (fade effects)
- SubViewportContainer - Render layers with shader materials

**Build/Dev:**
- Resources Spreadsheet View - Resource management and organization
- Todo Manager - Task management in editor
- Kanban Tasks - Project board management
- TexturePacker Importer 4.3.0 - Sprite sheet management
- Custom build process - Direct Godot export

## Key Dependencies

**Critical:**
- Dialogue Manager 3.10.2 - Core dialogue system, timeline management
- TexturePacker Importer 4.3.0 - Asset import and sprite sheet handling

**Infrastructure:**
- Resources Spreadsheet View - Enhanced resource editing and organization
- Custom audio system - Multiple AudioStreamPlayer instances for different sound types

## Configuration

**Environment:**
- Project name: "visual-novel" (project.godot)
- Entry point: Main scene (uid://nixyr2xle2qo)
- Autoloads: Main, DialogueManager, AudioManager, Stage, Game, Prefabs, DebugPage
- Save encryption: enabled only for exports (save/encryption_on_exports_only=true)

**Build:**
- Custom Godot project configuration (project.godot)
- Editor plugins enabled for enhanced workflow
- Custom shader materials for visual effects

## Platform Requirements

**Development:**
- Godot 4.6 Editor
- Windows platform (development environment)

**Production:**
- Windows Desktop target
- OpenGL Compatibility rendering method
- Custom window sizing (1200x600)

---

*Stack analysis: 2026-04-05*
*Status: Godot Engine 4.6 project with custom game framework*
*Note: No external package managers - all dependencies managed via Godot's plugin system*
```