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

## What's in

Dredge timer, sorting into 6 bins with a streak multiplier, curio cleaning and rarity, Collector's Log, magic curios (permanent buffs, full-set bonus), crates, bottles (Lore Letters, community letters with voting, empty bottles), animals to set free, stations (Cutting Board, Oven, Crucible, Carpentry Bench, Recycling Machine), storage and selling, Work Table upgrades, Map depths, prestige with titles, letter-writing warning and rules, max 3 letters awaiting review.

## Not yet

- **Art and sound.** Emoji stand in for sprites; how they look depends on the player's system fonts.
- **Online features.** Guilds, parties, guild chat and shared letters need a server. Letters currently come from a local stand-in pool.
- **Your Lore Letters.** The five in `scripts/data.gd` (`LETTERS`) are placeholders.
- **Steam.** Export presets and the GodotSteam plugin (achievements, cloud saves, friends) come once there's a Steamworks app ID.
