# Changelog

All notable changes to WTFisThisAddon will be documented here.

## [1.0.0] - 2026-03-25

### Added
- Mouseover inspection: hover any UI frame to identify its owning addon
- Cyan border + semi-transparent highlight overlay on hovered frame
- Info popup showing: addon name, source file, line number, parent chain, contributing addons
- `/wita` and `/wtfisthis` slash commands to toggle inspect mode
- Draggable minimap button with position saved to SavedVariables
- Blizzard default UI detection (FrameXML path detection)
- Frame name-based fallback guessing when source location is unavailable
- Parent chain traversal up to 6 levels deep
- Multi-addon contributor detection
- WoW 12.0 (Midnight) compatibility: migrated from `GetMouseFocus()` to `GetMouseFoci()`
- Auto-enables `enableSourceLocationLookup` CVar on first use
