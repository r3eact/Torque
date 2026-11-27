# TORQUE: Core Rush

An original Roblox action-collector. Smash robots, loot rare **Cores**, and display them in your **Garage** to build a passive-income empire. Then push into harder zones and team up on raid bosses.

The whole game is code: the map, the UI and every system build themselves at runtime. You don't need to model or place anything in Studio. Sync the scripts and press Play.

---

## 1. Three concepts considered

| # | Concept | Hook | Inspirations it borrows from |
|---|---------|------|------------------------------|
| A | **Torque: Core Rush** *(chosen)* | Punch robots → loot rarity-tiered Cores → equip one for power, display the rest in your Garage for income that keeps ticking while you're offline. | Blox Fruits (combat + zones), Anime Vanguards (rarity collecting), Steal a Brainrot (showing off a base that earns money) |
| B | **Sky Herders** | Lasso floating sky-creatures, breed them on your island, raid other islands' pens at night. | Steal a Brainrot, pet sims |
| C | **Rune Siege** | Wave-defense: drop summoned rune-golems on a lane, merge duplicates to evolve them, then fight bosses co-op. | Anime Vanguards, tower defense |

### Why A wins
* **Fun within 30 seconds.** You spawn, a beam points at a robot, you click, numbers pop, it explodes into coins. There are no menus to get through before the first reward.
* **Three reward loops stacked on one action.** Every punch gives XP (levels), coins (upgrades, crates) and a chance at a Core (collection). Combat feeds the economy, and the economy feeds combat.
* **A return hook baked into the core mechanic.** Garage income keeps building while you're offline, and the 7-day streak and daily quests add to it.
* **Social proof drives virality.** Server-wide "🌟 X found a LEGENDARY Storm Engine!" shouts, a visible Garage everyone walks past, a global leaderboard, an opt-in PvP ring, and co-op bosses that reward everyone who helped.
* **Works on every device.** One-button combat with aim assist is as good on a phone as on a keyboard. B and C need precise placement or aiming, which is harder on mobile.
* **Grows easily.** New zones, Cores, bosses, crates and events are data entries, not new systems. Garage *raiding* (the Steal-a-Brainrot twist) slots in later (see Roadmap).

---

## 2. Core gameplay loop

```
        ┌──────────── FIGHT bots (Strike / Slam / Overdrive) ◄──────────┐
        │                      │                                        │
        ▼                      ▼                                        │
   XP → LEVEL UP          COINS (+Fortune)  ──►  CRATES (pity @60)       │
   (abilities, HP,             │                     │                  │
    pedestals, zones)          ▼                     ▼                  │
        │               UPGRADES (Power/HP/      CORES (5 rarities)     │
        │                Speed/Fortune)          ├─ Equip → damage/crit ┤
        │                                        └─ Display → Garage $/s│
        ▼                                                   │           │
   UNLOCK ZONES (Lv10 Neon Foundry, Lv25 Storm Reactor) ────┴── harder bots,
   BOSSES every few minutes (co-op rewards)                    better drops
   DAILY: 3 quests + 7-day streak + offline Garage earnings  → come back tomorrow
```

**The first 2 minutes (tutorial, server-driven):** destroy 3 Scrap Bots → open a FREE crate → equip the Core → display it → collect Garage income → buy an upgrade. Each step pays coins, and a glowing beam always points to the next goal.

---

## 3. Project structure

```
Torque/
├── default.project.json        Rojo mapping (src → Studio)
├── src/
│   ├── shared/                 → ReplicatedStorage.Shared (both sides)
│   │   ├── Config.luau         every balance number + formulas
│   │   ├── ItemData.luau       Cores + crates + odds
│   │   ├── ZoneData.luau       zones, bots, bosses, world bounds
│   │   ├── QuestData.luau      tutorial, daily quests, login rewards
│   │   ├── Net.luau            creates / finds all remotes
│   │   ├── Signal.luau         tiny in-process event
│   │   └── Format.luau         1.2K / 1,234 / 1h 02m formatting
│   ├── server/                 → ServerScriptService.Server
│   │   ├── Main.server.luau    boots services (Init → Start)
│   │   └── Services/
│   │       ├── RateLimiter        token buckets per player
│   │       ├── NetService         single secure Action router + notify/effects
│   │       ├── DataService        DataStore load/save, session lock, autosave
│   │       ├── WorldBuilder       builds the entire map + lighting
│   │       ├── ProgressionService XP, levels, coins, leaderstats, char stats
│   │       ├── QuestService       tutorial + daily quests
│   │       ├── InventoryService   Cores: equip / display / sell
│   │       ├── ShopService        crate rolls (pity), upgrades, settings
│   │       ├── DailyService       7-day login streak
│   │       ├── ZoneService        gate unlocks, zone enforcement, speed check
│   │       ├── PlotService        Garages, passive + offline income
│   │       ├── EnemyService       bot rigs, AI, bosses, loot
│   │       ├── CombatService      server-side hit detection & damage, PvP ring
│   │       └── LeaderboardService global OrderedDataStore board
│   └── client/                 → StarterPlayer.StarterPlayerScripts.Client
│       ├── Main.client.luau    boots controllers
│       └── Controllers/
│           ├── ClientState        data snapshot + safe Action calls
│           ├── SoundController    SFX + optional music
│           ├── UIController       HUD, windows, notifications, scaling
│           ├── EffectsController  damage numbers, particles, shake…
│           ├── CombatController   input → abilities (PC/mobile/console)
│           ├── WorldController    spinning props, gates, prompts, banners
│           ├── TutorialController guide beam + arrow
│           └── UI/  UIKit, Menu, Inventory, Shop, Quests, Daily, Settings, CrateReveal
└── tests/
    ├── run.sh                  syntax check + logic tests (Luau CLI)
    └── TestRunner.luau         178 checks against the real modules
```

What Studio's **Explorer** looks like after syncing:

```
ReplicatedStorage
└── Shared (Folder)            ← ModuleScripts: Config, ItemData, ZoneData, QuestData, Net, Signal, Format
ServerScriptService
└── Server (Folder)
    ├── Main (Script)
    └── Services (Folder)      ← 14 ModuleScripts listed above
StarterPlayer
└── StarterPlayerScripts
    └── Client (Folder)
        ├── Main (LocalScript)
        └── Controllers (Folder) ← 7 ModuleScripts
            └── UI (Folder)      ← 8 ModuleScripts
```
At runtime the server adds `ReplicatedStorage.Remotes` and `Workspace.World`, so don't create those yourself.

---

## 4. Setup in Roblox Studio

### Step 1: Create the place
1. Open Roblox Studio → **New** → **Baseplate**. (The game deletes the baseplate and builds its own map.)
2. **File → Publish to Roblox** (needed for DataStores).
3. **Home → Game Settings**:
   * **Security** → turn on **Enable Studio Access to API Services** (lets you test saving in Studio).
   * **Avatar** → Avatar type **R15** (the attack animations use R15. R6 works too, with fallback animations).
   * **Places → (your place) → Max Players** → **6**. There are 6 Garages per server. A 7th player can still play, but gets no Garage income.
4. Save.

### Step 2a: Sync with Rojo (recommended)
1. Install Rojo 7: the **Rojo** VS Code extension, or `rokit add rojo-rbx/rojo` / `aftman add rojo-rbx/rojo`.
2. Install the Rojo Studio plugin (the VS Code extension offers to do this, or get "Rojo" from the Creator Store plugins).
3. In this folder run `rojo serve`.
4. In Studio: **Plugins → Rojo → Connect**. Every file appears in the right place automatically.

### Step 2b: Manual copy-paste (no tools)
Create each object with **right-click → Insert Object**, name it exactly as below (drop the `.luau`, `.server` and `.client` suffixes), and paste the file's contents in:

| Studio object | Type | Parent | File |
|---|---|---|---|
| `Shared` | Folder | ReplicatedStorage | - |
| `Config`, `ItemData`, `ZoneData`, `QuestData`, `Net`, `Signal`, `Format` | ModuleScript | ReplicatedStorage.Shared | `src/shared/<Name>.luau` |
| `Server` | Folder | ServerScriptService | - |
| `Main` | **Script** | ServerScriptService.Server | `src/server/Main.server.luau` |
| `Services` | Folder | ServerScriptService.Server | - |
| each service | ModuleScript | ServerScriptService.Server.Services | `src/server/Services/<Name>.luau` |
| `Client` | Folder | StarterPlayer.StarterPlayerScripts | - |
| `Main` | **LocalScript** | …StarterPlayerScripts.Client | `src/client/Main.client.luau` |
| `Controllers` | Folder | …Client | - |
| each controller | ModuleScript | …Client.Controllers | `src/client/Controllers/<Name>.luau` |
| `UI` | Folder | …Client.Controllers | - |
| `UIKit`, `Menu`, `Inventory`, `Shop`, `Quests`, `Daily`, `Settings`, `CrateReveal` | ModuleScript | …Controllers.UI | `src/client/Controllers/UI/<Name>.luau` |

### Step 3: Play
Press **Play** (F5). The Output window should show `[Torque] Server started`. If API access is off you'll see a yellow *running OFFLINE* warning. The game still works, it just won't save.

For multiplayer testing: **Test → Clients and Servers → 2 Players → Start**.

### Optional polish
* **Music:** set `Config.Sounds.Music` to a music asset id from the Creator Store.
* **Sounds and animations:** `Config.Sounds` and `Config.Animations` use built-in Roblox assets, so they work right away. Swap in your own uploads any time.

---

## 5. Test checklist (in Studio)

Automated: `LUAU_BIN=<folder with luau + luau-compile> tests/run.sh` syntax-checks every file and runs 178 logic checks: formatting, balance curves, data integrity, crate odds and pity, the full tutorial flow, shop and upgrade validation, inventory cap, leveling, daily streaks, quests and settings validation.

Manual, one system at a time:

| System | Do this | Expect |
|---|---|---|
| Menu | Press Play in Studio | Orbiting camera, TORQUE title, PLAY button. Clicking it shows the HUD and a welcome banner |
| Tutorial | Follow the beam | Steps advance in the tracker (top right), each with a coin reward |
| Combat | Click / tap Strike on a Scrap Bot | Swing, damage numbers, knockback, explosion, coins flying to you, "+XP" |
| Abilities | Reach Lv3 → Q (Slam), Lv8 → R (Overdrive) | Unlock notifications, cooldown sweep on the buttons, shockwave / golden aura |
| Crates | Shop → open the free crate | Roulette reveal. The Core appears in Inventory (F) |
| Garage | Inventory → Display → walk onto the green pad | A spinning gem appears on a pedestal, the 💰 counter rises, stepping on the pad banks it |
| Zones | Walk to the Neon Foundry gate below Lv10 | Prompt refuses with a reason. Exploiting past it teleports you back |
| Bosses | Junk Titan at the far end of the Scrapyard | Red telegraph circle, then a slam. Everyone with ≥3% damage gets rewards and a guaranteed drop |
| PvP | Two clients inside the red arena ring | Strikes damage each other. KOs are announced server-wide |
| Saving | Level up, stop, Play again (API access on) | Level, coins, Cores and quests persist |
| Offline income | Display Cores, leave, rejoin a few minutes later | "Your Garage earned X while you were away!" |
| Mobile | Test → Device emulator → a phone | Big thumb buttons bottom right, scaled UI, aim assist faces bots |
| Console | Plug in a gamepad | R2/R1/L1 abilities, D-pad opens menus, B closes |

---

## 6. Security model (exploit prevention)

* **Server-authoritative everything:** damage, hits, cooldowns, loot rolls, prices, XP, unlocks and income are all computed on the server. The client only *displays* data it receives via `DataSync`.
* **Two inbound remotes only.** `Ability` carries `(abilityId, aimDir)`. `Action` carries `(actionName, args...)` and goes through `NetService`, which checks that the player is loaded and rate-limits them. Every handler type-checks its own arguments, and the tests cover malformed input.
* **No client-chosen targets:** `CombatService` finds targets from server positions. Aim is validated (unit vector, NaN-checked) and can't extend range.
* **Cooldowns are enforced on the server**, with a 15% latency tolerance, plus a per-player token-bucket rate limiter.
* **Zone locks are enforced on the server.** Gates are only made passable locally for players who unlocked them, and the server teleports trespassers out.
* **Movement sanity check:** horizontal-speed check with rubber-banding, and a kick after sustained violations. Server teleports get a grace window.
* **Data safety:** session-locked `UpdateAsync`, retries with backoff, a kick instead of loading an empty profile, autosave every 120s, and `BindToClose`.
* **Bots are server-owned** (`SetNetworkOwner(nil)`), so clients can't fling or freeze them.

## 7. Performance notes
* One 5 Hz AI loop for all bots. Bots are a single root part with welded visuals and no joints.
* Effects are client-only and short-lived (Debris), and damage numbers are capped at 40 on screen.
* Data sync is coalesced to at most one packet per player per frame, and only when something changed.
* The map is built once, fully anchored, and props sit outside the combat lane.

---

## 8. Tuning cheat-sheet
| Want to change… | Edit |
|---|---|
| Leveling speed | `Config.XPForLevel` |
| Damage / HP / speed scaling | `Config.Player`, `Config.Upgrades` |
| Crate prices and odds, pity | `ItemData.Crates`, `Config.Pity` |
| Bot stats, rewards, spawn mix, bosses | `ZoneData.Enemies`, `ZoneData.Zones` |
| Quests, tutorial, login rewards | `QuestData` |
| Add a zone | Append to `ZoneData.Zones`. The map, gate, spawns and banner are generated automatically |

## 9. Roadmap (after the MVP)
1. **Garage raids**, the Steal-a-Brainrot twist: while an owner is offline-protected or AFK, other players can grab one displayed Core and must carry it back to their own Garage before being tagged. Server-side carry state, with a lock and shield gamepass.
2. **Monetization** via `MarketplaceService.ProcessReceipt`: 2× coins gamepass, extra pedestal, crate bundles, an auto-collect Garage.
3. **Rebirth / Prestige:** reset level for a permanent multiplier and an exclusive Core tier.
4. **Trading** with a two-sided confirmation UI and a server-validated swap.
5. **Weekly events and limited Cores** (FOMO + return), plus a boss-damage leaderboard.
6. Custom uploaded animations, music, and a hand-built map on top of the generated layout.
