# Shoal Tales — Project Manifest

A complete handoff for anyone (human or AI) picking up this codebase. It covers what the game
is, how the code is organised, how every system works, where to change things, and the
rules and gotchas learned so far.

---

## 1. What the game is

**Shoal Tales** is a cozy, relaxed dredging-and-sorting game, headed for **Steam** (desktop), built
in **Godot 4.7** with **GDScript only**.

- **Setting:** a sleepy modern seaside town where something is quietly supernatural. The items
  are ordinary modern junk; the *story* carries the strangeness.
- **Core loop:** drop a dredge basket → wait → the catch comes up → sort every item by hand
  (drag into bins, cool fish, clean curios, open bottles/crates, free animals) → process at
  workstations → sell to townsfolk → upgrade → repeat.
- **Feel:** relaxed. **No timers anywhere.** Accuracy is rewarded, not speed. Work is
  **tactile and hands-on**: dragging, one tap per fish/item at benches. There are deliberately
  **no "process all" buttons** at workstations.
- **Progression:** a first run is about a day of play (~7 hours by simulation) to grow the
  basket to 32 slots, then stations open one at a time, then the town's story leads to opening
  the **Emporium**, which ends the story. **Prestige** after that is a **sandbox** focused on
  bigger numbers, new depths, themed content packs and rarer relics.

---

## 2. Running it

1. Install Godot **4.7** (standard or .NET editor; the game is pure GDScript).
2. Godot → **Import** → select `project.godot` → **F5** to run.
3. Save file: `user://shoal_tales_save.json`
   (Windows: `%APPDATA%\Godot\app_userdata\Shoal Tales\`). Delete it for a fresh start.
4. Audio settings: `user://settings.cfg`.
5. **Dev menu:** press **`** (backtick, left of 1) or **Ctrl+Shift+D** while running from the
   editor. Only exists when `OS.is_debug_build()` is true, so it never ships in a release
   export. (Function keys are avoided: the Godot editor uses them to run/pause/stop.)

---

## 3. Project layout

```
project.godot          Engine config: 1280x720, canvas_items stretch, Compatibility renderer,
                       autoloads Data, Game, Sfx (in that order)
scenes/main.tscn       The only scene: a full-rect Control with scripts/main.gd
scripts/data.gd        (autoload "Data") ALL static content and tuning numbers
scripts/game.gd        (autoload "Game") ALL state, rules, saving; every player action
scripts/main.gd        The entire UI, built in code; redraws from Game state
scripts/sfx.gd         (autoload "Sfx") sound playback + volume settings
scripts/ui/drag_card.gd   Draggable tray card (junk/fish); emits `picked` to open the bin wheel
scripts/ui/drag_ghost.gd  The item under the cursor while dragging (sways, heavier = slower)
scripts/ui/bin_drop.gd    A bin / cooler drop target in the bin wheel
assets/sfx/*.wav       Placeholder synthesized sounds (replace with real ones, same names)
icon.svg               App icon
README.md              Short player/dev readme
MANIFEST.md            This file
```

---

## 4. Architecture

### 4.1 Data → Game → UI

- **`Data`** is read-only content: constants only (items, prices, NPCs, quests, letters, packs).
  Change content and numbers here.
- **`Game`** owns one dictionary, `Game.s`, containing *all* mutable state. Every player action
  is a method on `Game` (e.g. `sort_item`, `dress_fish`, `complete_quest`). Actions mutate
  `s`, then call `_commit()`, which **saves to disk and emits `changed`**.
- **`main.gd`** listens to `Game.changed` (connected **deferred**) and calls `refresh()`, which
  **rebuilds the current page from scratch** (clears `content`, rebuilds cards). There is no
  retained UI state for game data; the UI is a pure function of `Game.s` plus a few view-only
  variables (selected drink, inspected item, arcade state, the bin wheel).

### 4.2 Signals on `Game`

| Signal | Meaning / UI reaction |
| --- | --- |
| `changed` | State changed → `main.refresh()` (deferred) |
| `toast(msg)` | Show a toast bottom-right |
| `letter_opened(letter)` | Show a letter on a parchment modal |
| `sorted(bin, correct, weight, amount)` | Item landed in a bin/cooler → impact animation, sound, payout pop |
| `hauled` | A new catch arrived → splash sound, staggered fade-in of cards |
| `crow_arrived` | A story letter reached the Desk → crow caw |
| `quest_done(npc, text, reward)` | A townsperson request was fulfilled → parchment modal |

### 4.3 State: `Game.s`

`_fresh()` = per-run state (wiped on prestige). `_persistent()` = kept across prestige.

**Per run (`_fresh`)**: `coins`, `life` (lifetime coins this run), `goods` (`{key: {n, v}}`
stacks; `v` = total value), `tray` (current catch items), `sel` (click-selected uid),
`depth`, `up` (upgrade levels: speed/basket/clean/luck), `st` (installed stations),
`dredge_end`/`dredge_len` (unix-time dredge timer), `streak`/`best`, `tab`/`sub`, `uid`
(id counter), `hauls`, `cooler` (raw fish list), `stored` (whole junk kept for stations),
`dressed`, `since` (counts toward hidden station requirements), `town_sel`.
(`unlocked` is a legacy field, now unused: depths are gated by prestige.)

**Persistent (`_persistent`)**: `log` (Collector's Log: curio → best rarity), `magic`
(magic curio ids), `seen` (letter ids), `votes`, `outbox` (player-written letters), `tos`,
`prestige`, `empties` (saved empty bottles), `story` (story beats: letter ids and
`<id>_read`), `crow_unread`, `met` (townsfolk intros seen), `quests_done`, `orders`
(standing orders filled per NPC), `rares` (rare materials), `emporium` (owned), and all
Emporium state (`emp_tab`, `decor`, `slots`, `tickets`, `puzzles`, `puzzle`, `customers`,
`next_customer`, `board`, `board_done`), plus `looks` (equipped prestige cosmetics).

**Saving/loading:** JSON via `_save()`/`_load()`. JSON turns ints into floats, so `_load()`
converts known int fields back and **migrates old saves** (e.g. old `fish_raw` goods → cooler
fish, old `empty` items → glass junk, old `crow` story flag → `crow1`/`crow1_read`). When you
add state, add it to `_fresh` or `_persistent`, and add int-normalisation/migration in
`_load()` if needed.

### 4.4 Item model (entries in `s.tray`)

`{uid, kind, name, e (emoji), ...}` where `kind` is:
- `junk`: `bin` (default bin), `w` (weight 1–5), `base` value
- `fish`: `w`, `base`
- `curio`: `base`, `clicks`, `done`; after cleaning: `rar`, `value`; `magic: true` for magic curios
- `crate`, `bottle`, `animal`, `puzzle` (`rar`)

### 4.5 Goods keys

- `bin_<type>`: **sorted** goods (`bin_plastic`, `bin_metal`, `bin_glass`, `bin_wood`,
  `bin_electronics`, `bin_hazardous`, `bin_mixed`), shown as "Sorted wood", etc.
- `cooler`: raw fish (a list in `s.cooler`, not a goods stack)
- `stored_<type>`: stored whole junk for a station (a list in `s.stored`)
- `fish_dressed`, `meal`, `ingot`, `knick`, `material`, plus pack products (`chowder`,
  `carousel`, `bell`)
- `Game.holding(key)` returns `{n, v}` for any of these; `Game.goods_info(key)` gives
  `[name, emoji]` (including pack goods).

---

## 5. Game systems (how each works)

### 5.1 Dredging
- "Drop the dredge" starts a timer: `6s × 0.88^speed × (1 − min(0.5, 0.03 × prestige))`
  (× 0.95 with a magic curio). Stored as unix time, so it survives restarts.
- When it finishes: `hauls += 1`, the tray fills with `basket()` items rolled from the
  current depth's odds (`DEPTHS[d].w`). **The first haul always contains a fish.**
- You **must clear the tray** before dredging again.
- Basket = `3 + basket upgrades (+1 magic lantern)`, capped at **32**.
- Chances per item: junk / fish / curio / crate / bottle / animal by depth weights; magic
  curio ~0.6% scaled by depth and luck (until all 6 found); puzzle curio 3% once the Emporium
  is open.

### 5.2 Sorting (the core hook)
- Picking up junk or fish (drag, or click) opens the **bin wheel** around the cursor: 7 sorting
  bins + the cooler in a ring. Invalid targets are faded. Drop on a bin, or click a bin, or
  press **1–9**; **Esc**/click outside cancels.
- **Sorting destroys the item** and gives `1 + weight` units of `Sorted <type>`
  (`sort_units`). Total value = item base × streak multiplier × global multiplier (× 1.5 if a
  station rule changed its bin). Wrong bin: 40% value, streak resets, a toast says where it
  belonged.
- **Streak:** +5% per correct sort in a row, up to +100%.
- **Station sorting rules** (`Data.SORT_RULES`): owning a station changes some items' correct
  bin (e.g. with a Carpentry Bench, a skateboard goes in Wood).
- **🔍 Inspect** on junk shows a description that hints at its bin (`Data.DESCS`, pack junk
  has its own text), plus a station hint when a rule applies.
- **Impact feel:** heavier items (weight 1–5) make the bin squash harder, shake the screen
  (weight ≥ 3), and play lower/louder thuds; each bin has its own sound. The dragged item
  sways as you move it.

### 5.3 Storing whole junk
- Once you own the station for a material, junk of that (current) material shows
  **📦 Store**: Crucible ← metal, Carpentry Bench ← wood, Recycling Machine ← mixed
  (`Data.BIN_STATION`). Plastic/glass/electronics/hazardous have no station yet.
- Stored junk waits in `s.stored`; at the station you **tap each item** to process it into
  `1 + weight` units of the product (value × recipe factor).

### 5.4 Fish, cooler and Cutting Board
- Fish are dragged into the **cooler**. On **Stations → Cutting Board**, you **click each fish
  once** to dress it (value × 1.6). Fish types depend on depth (`Data.FISH_BY_DEPTH`, plus
  pack fish).
- The Oven (later) turns dressed fish into meals, **one tap per unit**.

### 5.5 Curios, magic curios, crates, bottles, animals
- **Curios:** click to clean (4 clicks, fewer with the Soft brush upgrade); cleaning rolls a
  rarity (common/uncommon/rare/epic). Then **To Log** (Collector's Log keeps your best of each)
  or **Sell**. Late game, a cleaned curio can become a **relic** (see 5.12).
- **Magic curios** (6): permanent buffs (+payout, −dredge time, +1 basket slot, +curio value,
  better rarity); all six give +25% payout.
- **Crates:** coins, more junk, or a curio.
- **Bottles:** a letter (Lore Letters from the dev, community letters) or an empty bottle.
  Empty bottles are **glass junk** and can also be **kept** for writing your own letter.
- **Animals:** set free (small coin).

### 5.6 Stations and hidden requirements
- Start: **Cutting Board** only.
- Other stations appear **only after the basket reaches 32**, **strictly in order**:
  **Oven → Carpentry Bench → Crucible → Recycling Machine** (`Data.STATION_ORDER`).
- Each has a **hidden requirement** (`STATIONS[k].needs`): a count handled since the last
  install (40 dressed fish; 150 wood; 200 metal; 200 mixed). Until it's met, the player only
  sees a flavour nudge (`tease`). Then they can install it for coins.
- Installing a station: resets `since`, may add sorting rules, and triggers a crow letter.

### 5.7 Upgrades (Work Table)
- **Bigger basket:** cost `20 + 13 × level²`, 29 levels (3 → 32). Tuned by simulation so a
  relaxed player reaches 32 in about 7 hours in the Shallows.
- **Faster winch** (speed, shows at basket 6), **Soft brush** (clean, basket 10), **Lucky charm**
  (luck, basket 16): geometric costs.
- Tabs and upgrades **reveal gradually** (`tab_unlocked`, `up_visible`); newly opened tabs
  toast "New: …".

### 5.8 Story, the crow and the Desk
- **Characters:** **Crow** was Walt's fish supplier (a shore dredger who went bankrupt). His
  companion crow **Zephyr** delivers Crow's letters (signed "— C."). Crow is guiding you toward
  opening the Emporium. The story is told **once**.
- **Letters** (`Data.STORY_LETTERS`) arrive at the **Desk → Crow** section (not as popups):
  first dressed fish → `crow1` (invitation ashore); each station install → `crow_<station>`;
  opening the Emporium → `crow_emporium` (the ending). Reading `crow1` opens the **Town**.
- **Desk** sections: Crow, Letters (bottle letters, voting, writing), Collector's Log, Magic
  Curios, Rules, Profile.
- **Letter writing:** needs a kept empty bottle; a first-time warning about moderation; max 3
  awaiting review; optional signature. (Currently local only; see Known gaps.)

### 5.9 Town (NPCs, selling, requests)
- The Town is a **menu of NPCs** (no walking). Each person buys **only their category**:
  - **Walt** (cook, Low Tide Diner): raw fish, dressed fish, meals (+ chowder from a pack)
  - **Dot** (salvage yard): **sorted goods only** (all `bin_*`), not processed products
  - **Rosalind** (antiques; opens with the Carpentry Bench): knick-knacks (+ carousel figures)
  - **Hank** (hardware; opens with the Crucible): ingots (+ fog bells)
  - **Priya** (makers' co-op; opens with the Recycling Machine): base materials
- The Town page lists **what you're holding and who buys it**, and each NPC card shows what
  they'd buy and whether a request is ready.
- First visit → an **introduction** (Walt's tells the supplier story).
- **Requests** (`Data.QUESTS`, plus pack quests): story requests in order per NPC (coins early,
  **rare materials** later), then endless **standing orders** that grow each time and pay the
  goods' value plus a bonus. Walt's first request reveals the name "Crow".

### 5.10 The Emporium
- Opens after **all stations are installed**, for **150,000 coins + rare materials** earned
  only from requests (2 stained glass, 3 old-growth timber, 3 brass fittings, 1 neon sign).
- Kept through prestige. Sections:
  - **🧾 Sell:** every category in one place, sold **stack by stack**, grouped as Food / Sorted
    goods / Crafts & antiques / Metalwork / Materials (`Data.EMPORIUM_CATEGORIES`).
  - **🌱 Shop floor:** place decorations for **permanent payout bonuses** by rarity (+0.5% /
    +1% / +2.5% / +5%); 6 spots to start, expand +2 at a time (cost doubles).
  - **☕ Counter:** customers wander in (every 25s, max 3). You build their drink from
    base + flavour + finish (drinks are endless); some also want a meal (from finite stock).
    Correct order = big tip. Customers are a mix of **townsfolk you've met, locals, travellers,
    tourists and rare event visitors** (`Data.CUSTOMER_PEOPLE`, `CUSTOMER_ODDS`).
  - **🧩 Puzzle bench:** stowed puzzle curios are "lights out" puzzles (3×3 or 4×4 by rarity);
    solving gives coins and a decoration.
  - **🕹️ Arcade:** "Tide Timer": stop a moving float in the centre for tickets; the prize
    counter sells decoration boxes by rarity odds.
  - **📌 Work orders:** 3 no-deadline orders that pay double, some with a decoration.

### 5.11 Prestige ("Retire the vessel")
- Available once all stations are installed and lifetime coins this run reach
  `1,000,000 × 2.2^prestige` (see Known gaps: likely needs tuning).
- Resets the run; keeps collections, letters, rares, Emporium. Each retirement: +10% payout,
  −3% dredge time (max −50%), a new **title**, and one each of **keychain, pet, profile border,
  chat badge** (choose them in **Desk → Profile**; the pet shows in the header, the keychain
  on the dredge card, the badge by the title; chat badges await a future chat).
- After the first retirement the game is **Sandbox**: no more story letters.
- **What each prestige unlocks:**
  - Prestige 1–3: the next **depth** (Coral Reef, Deep Trench, The Abyss). First run = Shallows
    only. Depth multiplies payouts and changes fish.
  - Prestige 4, 5, 6: a **themed pack** each (`Data.PACKS`): *The Lighthouse*, *The Sunken
    Carnival*, *The Night Ferry*. A pack adds junk (with Inspect text), curios, fish per depth,
    Lore Letters for bottles, a townsperson request, and a station recipe + its product + its
    buyer.
  - Prestige 7, 10, 13: a **relic tier** (`Data.RELIC_TIERS`: legendary, mythic, otherworldly):
    cleaned curios have a 4% chance to become a relic worth far more.

### 5.12 Content pools (how packs plug in)
Always read content through these, not the raw `Data` lists, so packs are included:
`junk_pool()`, `curio_pool()`, `fish_pool(depth)`, `letter_pool()`, `quest_pool()`,
`all_recipes()`, `goods_info(key)`, `npc_buys(npc)`, `can_make(good)`, `relic_tiers()`,
`packs_unlocked()`.

---

## 6. UI structure (`main.gd`)

- **Layout:** header (coins that count up, streak, multiplier, title/badge/pet, ⚙️ Sound
  button) → tab bar → scrolling content → toasts (bottom-right) → modals.
- **Tabs** (appear as unlocked): ⚓ Dredge, 📦 Storage, 🔨 Stations, 🗒️ Desk, 🏘️ Town,
  🏬 Emporium, 🛠️ Work Table, 🗺️ Map, 🤝 Guild (hidden stub).
- **Dredge page** sits in a centred 820px column (`DREDGE_WIDTH`) so items are never at the
  screen edge.
- **Building blocks:** `_card(title, parent, bg)` (bordered panel, returns its inner column),
  `_label`, `_para` (wrapping), `_button(text, action, disabled, sound)`, `_row`, `_grid`,
  `_box` (StyleBoxFlat), `_open_modal()` (parchment overlay), `_ask()` (confirm dialog).
- **Bin wheel:** `_open_wheel(kind, at, dragging)`, `_wheel_bin`, `_close_wheel(delay)`;
  `DragCard.picked` opens it; `BinDrop` handles drops/clicks; `_on_sorted` plays the impact on
  the wheel bin and closes the wheel after a short linger.
- **Sound menu:** Master and Sound-effects sliders (0–150%), saved to `settings.cfg`. Default
  (100%) is quiet on purpose (`Sfx.BASE_DB = -19.6`).
- **Dev menu:** `_show_dev()` → presets (fresh, town, basket 32, all stations, Emporium,
  sandbox, all depths, all packs, all relics) and tools (coins, basket size, fast dredging,
  fill tray by kind, goods, rares, magic, story letters, meet everyone, finish requests,
  stations, Emporium customers/puzzles/tickets/decor, retire now). Logic lives in
  `Game.dev_*`.

---

## 7. Where to change things

| To change… | Edit |
| --- | --- |
| Junk items, their bins, weights | `Data.JUNK` (+ `Data.DESCS` for Inspect text) |
| Fish per depth | `Data.FISH_BY_DEPTH` |
| Curios, rarities | `Data.CURIOS`, `Data.RARITY` |
| Magic curios | `Data.MAGIC` (effects are checked by id in `game.gd`) |
| Depth odds / multipliers / prestige gate | `Data.DEPTHS` |
| Upgrade costs | `Data.UPS` (basket uses `base + sq × level²`) |
| Stations, costs, hidden requirements, teases | `Data.STATIONS`, `STATION_ORDER`, `STATIONS_UNLOCK_BASKET` |
| Station recipes | `Data.RECIPES` (+ pack recipes) |
| Which bins change with stations | `Data.SORT_RULES` |
| Story letters (Crow/Zephyr) | `Data.STORY_LETTERS` |
| Bottle Lore Letters | `Data.LETTERS` (placeholders — the designer will write real ones) |
| Townsfolk, what they buy, intros, lines | `Data.NPCS`, `NPC_ORDER` |
| Requests and rewards | `Data.QUESTS` (standing orders are generated in `game.gd`) |
| Rare materials, Emporium price | `Data.RARES`, `EMPORIUM_RARES`, `EMPORIUM_COST` |
| Emporium content | `DECOR*`, `DRINK_*`, `CUSTOMER_*`, `PRIZE_BOXES`, `BOARD_SIZE`, `EMPORIUM_CATEGORIES` |
| Prestige rewards | `Data.TITLES`, `Data.COSMETICS` |
| Packs / relics | `Data.PACKS`, `Data.RELIC_TIERS`, `RELIC_CHANCE` |
| Sounds | replace `assets/sfx/<name>.wav` (same names); volume in `sfx.gd` |
| Colours / theme | constants at the top of `main.gd`, `_make_theme()` |

---

## 8. Coding rules and gotchas (learned the hard way)

1. **Target Godot 4.7**, GDScript only. Keep `config/features` at 4.7.
2. **No multi-line lambdas as function arguments.** Godot's parser rejected them in this
   project. Use a named method (and `.bind(...)` for arguments) instead. Single-line lambdas
   are fine.
3. **Don't use `:=` when the right-hand side is a Variant** (e.g. anything read from
   `Game.s`, a Dictionary, or `Data` dictionaries). Write an explicit type:
   `var n: int = s.up.basket`. `:=` on a Variant is a parse error.
4. **The UI rebuilds on every change.** `Game.changed` is connected **deferred**, so a button
   can trigger a redraw that frees it. If you call `refresh()` from a button handler yourself,
   use `refresh.call_deferred()`.
5. **Containers reset child `scale`/`rotation`.** To animate something (bins squashing), put
   it inside a plain `Control` (the bin wheel does this), not directly in a Box/Grid/Flow
   container.
6. **Emoji are placeholder art.** Use only emoji from **Unicode Emoji 12 or older**: newer
   ones (e.g. 🪵 🫙 🪣 🛟 🦭 🐦‍⬛) render as empty boxes on Windows 10 fonts.
7. **Avoid function keys** for game shortcuts (the editor uses them). Also avoid F12 (Steam
   screenshot key).
8. **All state changes go through `Game`** and end with `_commit()`. The UI never mutates
   `Game.s` directly (the only exception: falling back to the Dredge tab if the current tab
   is hidden).
9. **Read content through the pool functions** (5.12) so themed packs are included.
10. Keep it **relaxed and tactile**: no timers, no "process all", one tap/drag per unit of work.
11. Comments explain *why*, briefly; match the existing style.

---

## 9. Known gaps and next steps

- **Untested in the engine by the AI that wrote it.** The author could only syntax-check
  (gdtoolkit, Godot 4.5 grammar); the designer has been running builds on 4.7 and reporting
  errors by screenshot.
- **Prestige goal** (`1,000,000 × 2.2^p` lifetime coins) was set before the Shallows-only first
  run and price rebalance; it likely takes far longer than intended. Tune with a simulation.
- **Online features** need a server: Guild (guilds, parties, guild chat, guild/party
  collectibles), shared player letters with voting and a moderation queue (the designer must
  be able to see @handles; letters display anonymous; dev letters can't be voted on), chat (for
  chat badges).
- **Art:** everything is emoji. The designer plans AI art and/or free assets.
- **Audio:** sounds are synthesized placeholders; no music yet.
- **Lore:** Lore Letters and pack letters are placeholders for the designer to write.
- **Steam:** export presets, Steamworks app, GodotSteam (achievements, cloud saves) not set up.
- **Controller / Steam Deck** support not done.
- Unused leftovers that can be cleaned up: `s.unlocked`, `Data.CUSTOMERS`, `Game.sort_into`.

---

## 10. Working with the designer

- The designer gets **overwhelmed by long lists**: ask **three questions at a time**, let them
  answer, then build.
- After **every change**, send the **full project zip** plus **short step-by-step
  instructions** (close Godot, replace the folder, Import `project.godot`, F5; mention whether
  the save should be deleted).
- Design decisions made so far (keep them): relaxed and accuracy-over-speed; tactile drag and
  tap; a sorted item is destroyed into "Sorted <type>" units; Store keeps junk whole for its
  station; Dot buys only sorted goods; townsfolk buy only their category; the Emporium sells by
  category; the story is told once, then sandbox; depths, then packs, then relics per
  prestige.
