# CousinGame

**Concept:** You and a friend just finished training your own language model, and launch it with a small circle of 120 beta users on the day ChatGPT actually launched (Nov 30, 2022) — an in-game date counter ticks forward one day per real second. Users give you two things: **Revenue** (they pay to use it, which funds infrastructure) and **Data** (their interactions are training signal, which funds new capabilities). Revenue is capped by two independent resource chains you build up in realistic tiers: **Compute** (Personal Server → Server Rack → Server Farm → Small Datacenter → Hyperscale Datacenter — raises how many users you can actually serve at once) and **Power** (Backup Generator → Solar Panels → Wind Turbines → Small Power Plant → Grid-Scale Power Plant — the energy that feeds your compute). Data is unlimited but only useful once you spend it starting to **train a capability** — each one is a *permanent* upgrade to how fast your model attracts users (not a temporary buff; once trained in, it stays), but training isn't instant: it costs Data upfront, then draws on the same shared Energy pool as Revenue-serving over real time, so pushing a big training run competes directly with keeping your paying users served. Adoption spreads through distinct population segments (AI enthusiasts and developers first, skeptics last); a rotating 3D globe on the dashboard — textured with a real world map — lights up with glowing dots as segments adopt and as your user count crosses growth milestones. Goal: complete global spread. Idle/strategy game, a bit of Universal Paperclips × Plague Inc., with an AI theme.

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

## Current status (v10)

- [x] Every resource, section, segment, capability, and infrastructure tier now has an icon (emoji-based, no art pipeline needed) — Dashboard/Upgrades tabs, Users/Revenue/Data/Energy/Server capacity/Model strength, all 8 segments, all 8 capabilities, all 5 compute tiers, all 5 power tiers
- [x] A shared UI theme sets a bigger base text size (18px, up from Godot's default 16px) across every Label/Button/LineEdit, so body text reads clearly on a real phone instead of just a desktop preview
- [x] Touch targets enlarged throughout — buttons went from 44-48px to 52-56px minimum height (well above the 44px mobile minimum), progress bars from 24-26px to 32px, notification close button to 40×40px
- [x] Globe viewport enlarged (260→300px) to be a clearer focal point
- [x] Notification cards widened (360→420px) for more comfortable reading

## Previous status (v9)

- [x] Concept defined
- [x] Core loop: launch on Nov 30, 2022 with 120 beta users → generate Revenue (capped by Compute × Power) and Data (unlimited) → Data starts training capabilities that **permanently** boost growth once complete → Revenue funds infrastructure
- [x] In-game date counter — 1 real second = 1 in-game day, starting the day ChatGPT actually launched
- [x] Two distinct resources instead of one generic currency, matching what users actually give a real model: money and training data, both framed as "/day"
- [x] Revenue rescaled to a believable order of magnitude (~$0.02/user/day) instead of ~$1/s from 2 people
- [x] Infrastructure rebuilt as realistic tier chains instead of a single repeatable button: Compute (Personal Server → Server Rack → Server Farm → Small Datacenter → Hyperscale Datacenter) and Power (Backup Generator → Solar Panels → Wind Turbines → Small Power Plant → Grid-Scale Power Plant), each tier independently repeatable with its own cost curve
- [x] **Training is a real process now, not an instant unlock**: starting a capability costs Data upfront, then it trains over time by drawing Energy from the *same shared pool* that powers Revenue-serving — the two compete, so a big training run visibly slows down how many users you can serve, and vice versa. A capped max draw rate means even abundant energy can't make training instant; each capability shows live "Training... X%" progress
- [x] Energy usage is now visible: the Dashboard shows current pool, capacity, and a live breakdown of how much is going to serving vs. training vs. how much is available
- [x] Capabilities are permanent multipliers (not decaying temporary boosts) — each unlock durably strengthens the model, shown as a "Model strength ×N" stat
- [x] Users split into 8 adoption segments instead of geography, roughly grounded in real figures where they exist (e.g. ~30M professional developers worldwide, ~1B knowledge-worker jobs globally — see sources below; other segments like "AI Enthusiasts" or "Skeptics" are narrative estimates, not sourced counts). Segments unlock in realistic adoption order: AI Enthusiasts → Developers → Students → Knowledge Workers → Businesses → Everyday Consumers → Governments → Skeptics
- [x] Top-right news-style notifications pop up when a new segment starts adopting or a capability finishes training, and support an expandable "Read more" body; short ones auto-fade after 8s, longer ones stay until closed
- [x] Rotating 3D globe on the Dashboard (embedded via SubViewport), textured with a real licensed world map (via Adobe Stock — Dante's subscription) instead of a procedural approximation, with dots spawning both per-segment and as your user count crosses growth milestones (up to 60 growth dots, so the globe visibly fills in as you play instead of topping out at 8)
- [x] Story milestones that unlock at user-count thresholds (businesses, media, governments, robots, global takeover)
- [x] Tabbed UI: Dashboard (date/status/resources/globe/segments) and Upgrades (capabilities + compute + power), with a red notification dot on the Upgrades tab when something is affordable
- [x] Card-based visual layout with color-coded resources and live "+X/day" income readouts
- [x] Autosave (every 5s to `user://savegame.json`) + "Start new game" button
- [x] Fixed: user count no longer displays fractional people (e.g. "1.2 users"); money/rate values still show sensible decimals
- [ ] The 3D globe (rotation, world map texture, dots) is new and unverified — I couldn't run Godot to confirm it renders correctly; likely needs a debugging pass together
- [ ] The globe texture is a simple continent-silhouette illustration, not a scientific/political map — clean and game-appropriate, but worth another pass if you want a different visual style
- [ ] Real geographic/segment correlation instead of a flavor globe (dot placement is illustrative, not literal — segments are demographic, not geographic)
- [ ] Further balance tuning — training durations, energy draw rates, the rescaled economy, and tier costs are all a first pass, needs a real playtest
- [ ] Sound/music + icons per resource/capability/segment
- [ ] Test on a real Android device (Godot → Export → Android)

Savegame location on Windows: `%APPDATA%\Godot\app_userdata\CousinGame\savegame.json`. Delete that file (or use the "Start new game" button in-game) to reset. v9 saves stay compatible with v8 saves (training state just defaults to "none in progress" if missing).

## Game logic

Everything lives in `scripts/Main.gd` (UI is built in code, no separate `.tscn` nodes, to avoid merge conflicts). Key tunable data sits near the top of the script: `SEGMENT_DATA` (population per segment), `capabilities` (data cost + training energy + permanent growth multiplier per capability), `MAX_TRAINING_ENERGY_RATE` (training speed cap), `base_growth_rate`, `revenue_per_user`/`data_per_user`, `compute_tiers`/`power_tiers` (name/cost/growth/output per tier), and `BASE_SERVING_CAPACITY`/`BASE_ENERGY_REGEN`/`BASE_ENERGY_CAPACITY` (free baseline before buying anything). Adjust those to test balance. The globe texture is `assets/sprites/world_map.jpg` (licensed via Adobe Stock).

### Sources for segment population figures

- Developer population estimates (~20-47M depending on methodology, we used ~30M): [Lemon.io software development statistics](https://lemon.io/blog/software-development-statistics/), [Springs — How Many Software Engineers Are There in 2025?](https://springsapps.com/knowledge/how-many-software-engineers-are-there-in-2025)
- Knowledge worker estimate (~1B+ jobs globally): [Forbes/Sisense — Who Are Knowledge Workers](https://www.forbes.com/sites/sisense/2021/12/01/who-are-knowledge-workers-and-how-do-we-enable-them/)
