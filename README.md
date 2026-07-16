# Molten Lava Combo UI

A World of Warcraft addon that displays Holy Power with dynamic magenta and gold animations and visual feedback.

## Features
- Real-time Holy Power visualization with 5 animated stars
- Magenta to gold color scheme with dynamic color shifting
- Audio cue when reaching max power
- Smooth scaling and rotation effects
- Optimized performance
- Advanced color transitions between building and burst states
- **v2.0.1: Fixed target re-anchoring jitter for improved visual stability**

## Installation
1. Clone this repository to your WoW Addons folder
2. Reload your UI in-game with `/reload`

## Usage
The combo UI appears above your target's nameplate, or centered on screen if no target is selected.

## Requirements
- World of Warcraft (Season of Discovery or later)

## Author
jpanasuk-netizen

---

## Release Notes

### v2.0.1 — Target Re-anchoring Jitter Fix
- **Fixed**: Nameplate re-anchor jitter when cycling through same target
- **Improved**: Tracking uses target identity instead of per-frame re-anchoring
- Visual stability significantly improved in fast target-switching combat scenarios

### v2.0 — Radiant Sigil Rewrite
- 6-layer stars with advanced animations
- 4 visual modes (Normal, Wake of Ashes, Avenging Wrath, Both)
- Event-driven Dawnlight charge tracking
- Smart spender detection with Holy Power-drop fallback
- Bell chime on 5 Holy Power (once per transition)
