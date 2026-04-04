# External Integrations

**Analysis Date:** 2026-04-05

## APIs & External Services

**Game-specific:**
- Dialogue Manager - Custom dialogue system with timeline support
  - Implementation: Internal plugin, no external API calls
  - Timeline format: .dtl files stored locally

**Asset Management:**
- TexturePacker Integration - Sprite sheet import system
  - SDK/Client: CodeAndWeb.TexturePacker importer plugin
  - Asset format: JSON-based sprite definitions
  - Purpose: Character animations and UI sprites

## Data Storage

**Databases:**
- None detected (File-based storage only)

**File Storage:**
- Local filesystem - Primary storage for:
  - Dialogue files (.dialogue format)
  - Music files (MP3 for theme, WAV for voices)
  - Texture assets (PNG, imported sprite sheets)
  - Scene files (.tscn format)
  - Resource files (.tres format)

**Caching:**
- Godot .godot directory - Stores imported assets and metadata
- No external caching services detected

## Authentication & Identity

**Auth Provider:**
- None detected (Single-player experience)
  - Implementation: Not applicable

## Monitoring & Observability

**Error Tracking:**
- None detected
- Custom error handling via Dialogue Manager's error panel

**Logs:**
- Console output only
- No logging framework detected

## CI/CD & Deployment

**Hosting:**
- Self-hosted (Direct Godot export to Windows executable)

**CI Pipeline:**
- None detected
- Manual build process via Godot editor

## Environment Configuration

**Required env vars:**
- None detected (All configuration stored in project.godot)

**Secrets location:**
- None required (No external API keys)

## Webhooks & Callbacks

**Incoming:**
- None detected (No external API endpoints)

**Outgoing:**
- None detected (No external API calls)

## Asset Pipeline

**Audio:**
- WAV format for voice files (stored locally)
- MP3 format for background music
- Multiple AudioStreamPlayer instances for different sound types

**Graphics:**
- PNG format for static assets
- TexturePacker for sprite sheet management
- Custom shader materials for visual effects

**Localization:**
- Multiple language support (Chinese and English dialogue files)
- Translation system: Built-in Godot internationalization
  - Files: .dialogue files with Chinese content
  - Translation folder: Not configured (disabled)

---

*Integration audit: 2026-04-05*
*Status: Self-contained game with no external dependencies*
*Note: All game assets and data stored locally, no external APIs or services*
```