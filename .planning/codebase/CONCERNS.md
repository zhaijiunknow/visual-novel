# Codebase Concerns

**Analysis Date:** 2025-01-03

## Tech Debt

**Unimplemented Base Classes:**
- Issue: `DMDialogueProcessor` and `KanbanResource` have empty `pass` statements for required methods
- Files: `addons/dialogue_manager/dialogue_processor.gd`, `addons/kanban_tasks/data/kanban_resource.gd`
- Impact: Child classes may inherit incomplete functionality
- Fix approach: Implement base methods or mark as abstract using `@abstract` annotation

**Large File Sizes:**
- Issue: `dialogue_manager.gd` (1,621 lines) violates single responsibility principle
- Files: `addons/dialogue_manager/dialogue_manager.gd`
- Impact: Difficult to maintain, test, and understand
- Fix approach: Split into focused classes (DialogueProcessor, DialogueState, DialogueUI)

## Known Bugs

**Missing Method Implementations:**
- Issue: `KanbanResource.to_json()` and `KanbanResource.from_json()` push errors instead of implementing functionality
- Files: `addons/kanban_tasks/data/kanban_resource.gd`
- Symptoms: Method calls fail silently at runtime
- Trigger: Any attempt to serialize/deserialize kanban data
- Workaround: Override in child classes, but base should provide defaults

## Security Considerations

**Hardcoded Paths in Export Presets:**
- Risk: Export paths contain hardcoded user-specific OneDrive location
- Files: `export_presets.cfg`
- Current mitigation: None
- Recommendations: Use relative paths or environment variables for export paths

**Debug Configuration in Release Builds:**
- Risk: Console wrapper enabled in debug export preset may expose debug functionality
- Files: `export_presets.cfg`
- Current mitigation: Separate debug/release presets
- Recommendations: Ensure debug features are disabled in release exports

## Performance Bottlenecks

**Dialogue Compilation:**
- Problem: `compilation.gd` processes entire dialogue files at once
- Files: `addons/dialogue_manager/compiler/compilation.gd` (1,054 lines)
- Cause: No lazy loading or incremental compilation
- Improvement path: Implement on-demand compilation with caching

**File I/O Operations:**
- Problem: `board.gd` loads/saves entire board data synchronously
- Files: `addons/kanban_tasks/data/board.gd` (305 lines)
- Cause: No async file operations
- Improvement path: Use `FileAccess.open_async()` for large files

## Fragile Areas

**Node Path Dependencies:**
- Files: Multiple files using `get_node()` with string paths
- Why fragile: Scene tree changes break references
- Safe modification: Use `@onready` or node groups
- Test coverage: Limited testing of scene tree changes

**Singleton Dependencies:**
- Files: 9 instances of `Engine.get_singleton()` calls
- Why fragile: Singleton names can change
- Safe modification: Store singleton references in `_ready()`
- Test coverage: Hard to mock singletons in unit tests

## Scaling Limits

**Memory Usage:**
- Current capacity: Limited by loading all dialogue resources at once
- Limit: Will degrade with large dialogue trees
- Scaling path: Implement streaming/dialogue chunking

## Dependencies at Risk

**External Addons:**
- Risk: Heavy reliance on multiple complex third-party addons
- Impact: Version conflicts or addon abandonment
- Migration plan: Build custom implementations for critical features

## Missing Critical Features

**Error Recovery:**
- Problem: No graceful degradation when dialogues fail
- Blocks: Production reliability
- Priority: High

## Test Coverage Gaps

**Unit Testing:**
- What's not tested: Core dialogue processing logic
- Files: `addons/dialogue_manager/compiler/`, `addons/dialogue_manager/dialogue_manager.gd`
- Risk: Regression errors in dialogue flow
- Priority: High

**Integration Testing:**
- What's not tested: Interaction between DialogueManager and game state
- Files: `autoloads/`
- Risk: State synchronization issues
- Priority: Medium

---

*Concerns audit: 2025-01-03*