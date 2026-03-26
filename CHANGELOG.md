# Changelog

All notable changes to WTFisThisAddon will be documented here.

## [1.1.0] - 2026-03-26

### Added
- **Simple / Detail view** — simple view (default) shows just the addon name and affecting addons; detail view shows full debug info (file, line, parent chain, frame strata/level)
- **`/wtf detail`** — starts scan in detail view; no reaction when already scanning
- **Minimap Shift+click** — starts scan in detail view when idle; stops scan when scanning
- **Localization** — Korean (koKR) and English (enUS) supported; additional locales can be added in `Locales.lua`
- **LibDataBroker-1.1 + LibDBIcon-1.0** — minimap button now integrates with minimap button managers (e.g. Minimap Button Bag, ButtonBin)
- **`Blizzard_*` module detection** — folders prefixed with `Blizzard_` are now correctly identified as Default UI instead of third-party addons
- **Affecting addons** — shown in simple view for all frame types (previously detail-only)

### Changed
- **Commands** — `/wita` and `/wtfisthis` replaced by `/wtf` and `/what`
- **Scan toggle logic** — `StartWITA(detail)` / `StopWITA()` replaces the previous toggle model; mode is set at scan start, not as a persistent setting
- **Minimap button** — rebuilt on LibDBIcon standard (31×31, 50×50 border anchored TOPLEFT); removed manual drag/position code
- **Hint text** — simple view footer updated to accurately reflect available commands

### Fixed
- **Secret value Lua error** — `GetWidth()` / `GetHeight()` can return secret numbers on some frames (e.g. HP bars); now safely handled with double-`pcall` via `SafeNum()`
- **Minimap icon bleeding** — border texture was 54×54 anchored CENTER; corrected to 50×50 anchored TOPLEFT per LibDBIcon standard

## [1.0.1] - 2026-03-25

### Fixed
- `GetMouseFocus()` removed in WoW 12.0 — replaced with `GetMouseFoci()[1]`
- Mac path separator (`/`) not matched by addon detection pattern — `NormalizePath()` now converts `/` to `\`

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
