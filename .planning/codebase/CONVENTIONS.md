# Coding Conventions

**Analysis Date:** 2026-04-05

## Naming Patterns

**Files:**
- PascalCase for class/scene files: `Character.gd`, `ProfileData.gd`
- snake_case for scene-based components: `dialogue_data.gd`, `save_data.gd`
- Directory names are lowercase with underscores: `autoloads`, `scripts`, `characters`

**Functions:**
- Public functions use PascalCase: `FadeIn()`, `SetParts()`, `GetCharacterData()`
- Private functions use snake_case: `_ready()`, `_input()`, `save_collection_data()`
- Signal handlers use snake_case: `_on_dialogue_ended()`

**Variables:**
- Instance variables use snake_case: `clicked`, `dragged`, `current_expression`
- Exported variables use PascalCase or snake_case depending on type: `speaking_mouth`, `body_parts`
- Static constants use UPPER_SNAKE_CASE in Enums class
- Signal names use snake_case with underscores: `gallery_card_index_changed`

**Types:**
- Class names use PascalCase: `Character`, `DialogueData`, `ProfileData`
- Generic types follow Godot conventions: `Array[ProfileData]`, `Dictionary[String, AnimatedSprite2D]`
- Enum names use PascalCase: `ProfileMode`, `SenderType`, `SelectionButtonState`

## Code Style

**Formatting:**
- Editor configured with UTF-8 charset in `.editorconfig`
- 4-space indentation (standard Godot convention)
- No trailing whitespace
- Empty lines between logical sections

**Linting:**
- No formal linting configuration detected
- Manual code review appears to be the primary quality control method
- Code formatted with 4-space indentation

**Documentation:**
- Minimal documentation in comments
- Chinese comments used for some internal logic
- `@tool` annotation used for editor-only classes
- Region comments used for logical grouping in some files

## Import Organization

**Order:**
- No strict import ordering convention detected
- Relative imports used throughout: `load(DialogueSettings.get_user_value(...))`
- No explicit import statements (Godot uses preload/require pattern)

**Path Aliases:**
- No path aliases detected in this Godot project
- Resources loaded with absolute paths: `"user://save_data.tres"`

## Error Handling

**Patterns:**
- Minimal error handling detected
- Basic null checks: `if not character_image: return`
- Simple file existence checks: `if FileAccess.file_exists(save_path)`
- No try-catch blocks detected
- Error messages not consistently documented

## Logging

**Framework:** Godot's built-in print statements
- `print()` used for debugging in Character class
- No formal logging framework detected
- Console output appears to be primary debugging method

## Comments

**When to Comment:**
- Region comments used to group related functions: `#region Dialogue Commands`
- Chinese comments for feature-specific functionality
- Minimal documentation of public APIs

**JSDoc/TSDoc:**
- No documentation blocks detected
- Type annotations used: `-> void`, `-> bool`, `-> Dictionary[String, AnimatedSprite2D]`

## Function Design

**Size:**
- Functions vary in size, from simple getters to complex state management
- Some functions handle multiple responsibilities
- Region grouping helps organize related functions

**Parameters:** 
- Mixed naming conventions in parameters
- Type annotations consistently used for parameters
- Default parameters used for optional values: `duration: float = 0.5`

**Return Values:**
- Consistent type annotations for return values
- Some functions return void for side effects
- Complex data structures often returned via parameters (pass-by-reference pattern)

## Module Design

**Exports:**
- Extensive use of `@export` for editor-configurable properties
- Exported paths use `@export_file_path` for file selection
- Arrays of resources exported for collections

**Barrel Files:**
- No barrel files detected
- Each class is in its own file
- Static utilities collected in `autoloads/tools.gd`

**Signal Patterns:**
- Signals defined with snake_case naming
- Signals emitted after state changes: `emit_signal("gallery_card_index_changed")`
- Connection management in `Tools.clear_connections()` helper

---

*Convention analysis: 2026-04-05*