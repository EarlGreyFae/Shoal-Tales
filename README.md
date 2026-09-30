# Shoal Tales

A cozy dredging, sorting and crafting game, built in **Godot 4** for release on Steam.

## Playing it

1. Install Godot 4.4 or newer: <https://godotengine.org/download>. Pick the standard **Godot Engine** build, not the .NET one.
2. Open Godot, click **Import**, and choose this folder's `project.godot`.
3. Press **F5** (or the ▶ button, top right) to play.

Saves go to Godot's user folder (`%APPDATA%\Godot\app_userdata\Shoal Tales` on Windows).

## Layout

| Path | What it is |
| --- | --- |
| `project.godot` | Project settings: window size, autoloads, renderer. |
| `scenes/main.tscn` | The one scene; its script builds the UI. |
| `scripts/data.gd` | All game content: junk, fish, curios, magic curios, depths, upgrades, stations, recipes, letters. |
| `scripts/game.gd` | Rules, state and saving. Every player action is a method here. |
| `scripts/main.gd` | The UI: tabs, item cards, bins, letter reader and writer, toasts. |
| `scripts/ui/` | Drag-and-drop: the draggable tray card, the item under the cursor, the bins. |
| `scripts/sfx.gd` | Plays sounds from `assets/sfx/`. |
| `assets/sfx/` | Placeholder sounds I synthesized. Replace any of them with a real sound of the same name (`drop_metal.wav`, `pickup.wav`, …). |

## Dev menu

Press the **`** key (left of 1) or **Ctrl+Shift+D** while running from the Godot editor to open a hidden developer menu: jump to any
point in the game (town, basket 32, all stations, Emporium, sandbox, packs, relics), give
coins/goods/rare materials, fill the tray with specific catches, trigger story letters,
customers and decorations, toggle fast dredging, or retire instantly. It never appears in a
release export (`OS.is_debug_build()` is false there), so it won't ship on Steam.

## What's in

Dredge timer, drag-and-drop sorting into 6 bins with a streak multiplier, Inspect hints, a cooler for fish and a click-to-dress Cutting Board, hidden requirements that unlock stations in order, crow letters delivered to the Desk, a town of people who each buy different goods (starting with Walt at the diner and Dot at the salvage yard), fish that change with depth, the Emporium (decorations with permanent payout bonuses, a drinks-and-meals counter, a lights-out puzzle bench, an arcade with a prize counter, and a no-deadline work order board), prestige that opens deeper water, then themed packs (The Lighthouse, The Sunken Carnival, The Night Ferry), then rarer relic curios; counter customers drawn from townsfolk, locals, travellers, tourists and event visitors; prestige cosmetics (keychains, pets, profile borders, chat badges), a sound settings menu, curio cleaning and rarity, Collector's Log, magic curios (permanent buffs, full-set bonus), crates, bottles (Lore Letters, community letters with voting, empty bottles), animals to set free, stations (Cutting Board, Oven, Crucible, Carpentry Bench, Recycling Machine), storage and selling, Work Table upgrades, Map depths, prestige with titles, letter-writing warning and rules, max 3 letters awaiting review.

## Not yet

- **Art.** Emoji stand in for sprites; how they look depends on the player's system fonts.
- **Real sounds.** The ones in `assets/sfx/` are synthesized stand-ins.
- **Online features.** Guilds, parties, guild chat and shared letters need a server. Letters currently come from a local stand-in pool.
- **Your Lore Letters.** The five in `scripts/data.gd` (`LETTERS`) are placeholders.
- **Steam.** Export presets and the GodotSteam plugin (achievements, cloud saves, friends) come once there's a Steamworks app ID.
