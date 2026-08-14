# CousinGame

**Concept:** You launch your own language model. Users give you two things: **Revenue** (they pay to use it, which funds infrastructure) and **Data** (their interactions are training signal, which funds new capabilities). Revenue is capped by two independent resources you build separately: **Datacenters** (server hardware — raises how many users you can actually serve at once) and **Power Plants** (the energy source that feeds those datacenters — without enough power, extra datacenters sit idle). Data is unlimited but only useful once you spend it unlocking **capabilities** — each one is a *permanent* upgrade to how fast your model attracts users (not a temporary buff; once trained in, it stays). Adoption spreads through distinct population segments (AI enthusiasts and developers first, skeptics last), and each new segment triggers a news-style notification. Goal: complete global spread. Idle/strategy game, a bit of Universal Paperclips × Plague Inc., with an AI theme.

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

## Current status (v6)

- [x] Concept defined
- [x] Core loop: name your model → users generate Revenue (capped by Datacenters × Power Plants) and Data (unlimited) → Data unlocks capabilities that **permanently** boost growth → Revenue funds infrastructure
- [x] Two distinct resources instead of one generic currency, matching what users actually give a real model: money and training data
- [x] Infrastructure split into two dependent resources: Datacenters (server capacity — how many users you can serve) and Power Plants (energy supply that feeds the datacenters) — building only one caps you on the other
- [x] Capabilities are permanent multipliers (not decaying temporary boosts) — each unlock durably strengthens the model, shown as a "Model strength ×N" stat
- [x] Users split into 8 adoption segments instead of geography, roughly grounded in real figures where they exist (e.g. ~30M professional developers worldwide, ~1B knowledge-worker jobs globally — see sources below; other segments like "AI Enthusiasts" or "Skeptics" are narrative estimates, not sourced counts). Segments unlock in realistic adoption order: AI Enthusiasts → Developers → Students → Knowledge Workers → Businesses → Everyday Consumers → Governments → Skeptics
- [x] Top-right news-style notifications pop up when a new segment starts adopting (e.g. "Developers are becoming fans of Athena-1"), dismissible or auto-fade after 8s
- [x] Story milestones that unlock at user-count thresholds (businesses, media, governments, robots, global takeover)
- [x] Tabbed UI: Dashboard (status/resources/segments) and Upgrades (capabilities + infrastructure), with a red notification dot on the Upgrades tab when something is affordable
- [x] Card-based visual layout with color-coded resources and live "+X/s" income readouts
- [x] Autosave (every 5s to `user://savegame.json`) + "Start new game" button
- [x] Fixed: user count no longer displays fractional people (e.g. "1.2 users")
- [ ] Real geographic/segment map visualization instead of bars
- [ ] Further balance tuning — the datacenter/power-plant split and growth pacing are a first pass, needs a real playtest
- [ ] Sound/music + icons per resource/capability/segment
- [ ] Test on a real Android device (Godot → Export → Android)

Savegame location on Windows: `%APPDATA%\Godot\app_userdata\CousinGame\savegame.json`. Delete that file (or use the "Start new game" button in-game) to reset.

## Game logic

Everything lives in `scripts/Main.gd` (UI is built in code, no separate `.tscn` nodes, to avoid merge conflicts). Key tunable data sits near the top of the script: `SEGMENT_DATA` (population per segment), `capabilities` (data cost + permanent growth multiplier per capability), `base_growth_rate`, `revenue_per_user`/`data_per_user`, `BASE_SERVING_CAPACITY`/`SERVING_CAPACITY_PER_DATACENTER`, and the datacenter/power-plant cost curves (`_datacenter_cost()`, `_power_cost()`). Adjust those to test balance.

### Sources for segment population figures

- Developer population estimates (~20-47M depending on methodology, we used ~30M): [Lemon.io software development statistics](https://lemon.io/blog/software-development-statistics/), [Springs — How Many Software Engineers Are There in 2025?](https://springsapps.com/knowledge/how-many-software-engineers-are-there-in-2025)
- Knowledge worker estimate (~1B+ jobs globally): [Forbes/Sisense — Who Are Knowledge Workers](https://www.forbes.com/sites/sisense/2021/12/01/who-are-knowledge-workers-and-how-do-we-enable-them/)
