# WTFisThisAddon

![WoW Version](https://img.shields.io/badge/WoW-12.0%2B%20(Midnight)-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0.0-orange)

> **"What the hell is this UI from?"** — A developer/debug tool that instantly tells you which addon created any UI frame you hover over.

---

## 📸 Screenshot

<!-- Add screenshot here -->
> *Toggle inspect mode → hover over any frame → instantly see which addon owns it*

---

## ✨ Features

- 🔍 **Instant identification** — hover over any UI element to see which addon created it
- 🔷 **Blizzard UI detection** — correctly identifies native WoW frames
- 📦 **Addon name + source file + line number** — pinpoint exactly where the frame was created
- 🌲 **Parent chain analysis** — shows up to 6 levels of frame hierarchy
- ⚙️ **Multi-addon detection** — reveals when multiple addons are involved in one UI area
- 🖼️ **Highlight overlay** — cyan border + subtle tint shows exactly which frame is selected
- 📌 **Draggable minimap button** — position saved between sessions
- ⚡ **Zero dependencies** — no external libraries required

---

## 📦 Installation

### Manual
1. Download the latest release
2. Extract to:
   ```
   World of Warcraft/_retail_/Interface/AddOns/WTFisThisAddon/
   ```
3. Enable **WTFisThisAddon** in the AddOns list at the character select screen

### CurseForge *(coming soon)*

---

## 🚀 Usage

### First-time setup
The first time you run `/wita`, the addon will enable a required console variable and ask you to reload:
```
/wita
→ "[WITA] SourceLocation 기능을 켰습니다."
→ "[WITA] /reload 후 재시도해주세요."

/reload

/wita  ← Now works!
```
> This only needs to be done **once**. The setting persists across sessions.

### Controls

| Action | Result |
|--------|--------|
| `/wita` or `/wtfisthis` | Toggle inspect mode ON/OFF |
| **Left-click** minimap button | Toggle inspect mode |
| **Drag** minimap button | Reposition around the minimap |

### Reading the popup

```
⬡ WTF Is This?
───────────────────────────────
📦  WeakAuras
  파일  WeakAuras\WeakAuras.lua
  라인  2847

프레임  WeakAuras_Anchor_MainGroup

⚙  함께 관여 중인 애드온
   •  ElvUI

부모 체인
  └ WeakAuras_Container (WeakAuras)
    └ UIParent (Blizzard UI)
```

| Icon | Meaning |
|------|---------|
| 📦 | Third-party addon |
| 🔷 | Blizzard default UI |
| ❓ | Unknown (see Limitations) |
| ⚙ | Other addons also involved |

---

## ⚠️ Limitations

- **~80–90% accuracy** — some frames can't be identified
- Frames created via `loadstring()` or with no name may show as ❓ Unknown
- `GetSourceLocation()` requires `enableSourceLocationLookup = 1` (auto-enabled on first use + /reload)
- Font strings and textures created via Lua script report their *parent frame's* source location (WoW engine limitation)

---

## 🔧 How It Works

This addon uses WoW's `GetSourceLocation()` API (added in patch 9.2.5) to read the file path and line number where each frame was created. By parsing the path (e.g. `Interface\AddOns\WeakAuras\...`), it extracts the addon folder name. When `GetSourceLocation()` returns nothing useful, it falls back to guessing based on the frame's name prefix.

Key APIs used:
- `GetMouseFoci()` — detects which frame is under the cursor (WoW 12.0+)
- `ScriptRegion:GetSourceLocation()` — returns creation file + line
- `ScriptRegion:GetDebugName()` — fallback debug name
- `Frame:GetParent()` — walks the parent hierarchy

---

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md)

---

## 📄 License

[MIT](LICENSE) © 2026 kimgod1142
