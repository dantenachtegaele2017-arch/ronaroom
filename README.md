# CousinGame

**Concept:** You launch your own language model. Users give you two things: **Revenue** (they pay to use it, which funds infrastructure) and **Data** (their interactions are training signal, which funds new capabilities). Revenue is energy-limited (serving queries at scale costs power — build datacenters and upgrade your power grid to raise the ceiling). Data is unlimited but only useful once you spend it unlocking capabilities, each of which gives your model a temporary burst of faster user growth before decaying back to a slow baseline. Goal: complete global spread. Idle/strategy game, a bit of Universal Paperclips × Plague Inc., with an AI theme.

Built with [Godot 4](https://godotengine.org/) (GDScript, portrait, UI-based, all code and content in English).

## Setup (one-time, for both of you)

1. **Install Godot**
   - Download Godot 4 (stable, .NET version not needed) from https://godotengine.org/download/windows/
   - Pick the "Standard" version (64-bit .zip), unzip, run `Godot_v4.x-stable_win64.exe`. No installer needed.

2. **Clone the repo**
   ```bash
   git clone https://github.com/dantenachtegaele2017-arch/ronaroom.git
   ```

3. **Open the project**
   - Start Godot → "Import" → point it at `project.godot` in this folder.

## Collaborating via Git

- Don't both work in the same scene (`.tscn`) file at the same time — those files are text but merge conflicts are painful to resolve. Agree on who works on which scene/script, or use feature branches.
- Commit often, in small steps:
  ```bash
  git add .
  git commit -m "short description"
  git push
  ```
- Pull the other person's changes before you start:
  ```bash
  git pull
  ```
- `.godot/` and import files are in `.gitignore` — no need to share those, Godot regenerates them locally.

## Project structure

```
scenes/     # .tscn scene files (levels, UI, characters)
scripts/    # .gd scripts
assets/
  sprites/  # images
  audio/    # sound/music
```

## Current status (v4)

- [x] Concept defined
- [x] Core loop: name your model → users generate Revenue (energy-limited) and Data (unlimited) → Data unlocks capabilities that temporarily boost growth → Revenue funds infrastructure
- [x] Two distinct resources instead of one generic currency, matching what users actually give a real model: money and training data
- [x] Regional spread grounded in approximate real internet-user counts per region (~5.4B total), regions fill up one after another
- [x] Story milestones that unlock at user-count thresholds (businesses, media, governments, robots, global takeover)
- [x] Capabilities system: unlock a capability → temporary strong growth boost that decays back to a slow baseline, forcing a deliberate "buildup" rhythm instead of smooth exponential growth
- [x] Tabbed UI: Dashboard (status/resources/regions) and Upgrades (capabilities + infrastructure), with a red notification dot on the Upgrades tab when something is affordable
- [x] Card-based visual layout with color-coded resources and live "+X/s" income readouts
- [x] Autosave (every 5s to `user://savegame.json`) + "Start new game" button
- [ ] Real geographic world map instead of region bars
- [ ] Further balance tuning — growth pacing was raised in v4, still needs a real playtest pass
- [ ] Sound/music + icons per resource/capability
- [ ] Test on a real Android device (Godot → Export → Android)

Savegame location on Windows: `%APPDATA%\Godot\app_userdata\CousinGame\savegame.json`. Delete that file (or use the "Start new game" button in-game) to reset. Note: saves from before v4 (the Revenue/Data split) are automatically ignored — the game will show the name screen instead of loading them, since the old format doesn't map cleanly to the new resources.

## Game logic

Everything lives in `scripts/Main.gd` (UI is built in code, no separate `.tscn` nodes, to avoid merge conflicts). Key tunable data sits near the top of the script: `REGION_DATA` (population per region), `capabilities` (data cost/boost/duration per capability), `base_growth_rate`, `revenue_per_user`/`data_per_user`, and the datacenter/power-grid cost curves. Adjust those to test balance.
