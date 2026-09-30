extends Node
## Game state, rules and saving. The UI calls the action methods and redraws on `changed`.

signal changed
signal toast(msg: String)
signal letter_opened(letter: Dictionary)
## A junk item landed in a bin. The UI uses this for the impact, sound and payout pop.
signal sorted(bin: String, correct: bool, weight: int, amount: float)
## A fresh catch just came up.
signal hauled
## The crow dropped a new letter at the Desk.
signal crow_arrived
## A townsperson's request was fulfilled.
signal quest_done(npc: String, text: String, reward: String)

const SAVE_PATH := "user://shoal_tales_save.json"
const MAX_PENDING_LETTERS := 3
const LETTER_MAX_CHARS := 400

var s: Dictionary = {}
## Dev menu: near-instant dredging. Not saved.
var dev_fast := false


func _ready() -> void:
	s = _fresh()
	s.merge(_persistent())
	_load()


func _process(_delta: float) -> void:
	if dredging() and _now() >= s.dredge_end:
		s.dredge_end = 0.0
		s.hauls += 1
		s.tray = _haul()
		s.sel = -1
		_commit()
		hauled.emit()
	_customer_tick()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


# ---------- state ----------


## Per-run state, wiped on prestige.
func _fresh() -> Dictionary:
	return {
		"coins": 0.0,
		"life": 0.0,
		"goods": {},
		"tray": [],
		"sel": -1,
		"depth": 0,
		"unlocked": [true, false, false, false],
		"up": {"speed": 0, "basket": 0, "clean": 0, "luck": 0},
		"st": {},
		"dredge_end": 0.0,
		"dredge_len": 0.0,
		"streak": 0,
		"best": 0,
		"tab": "dredge",
		"sub": "crow",
		"uid": 1,
		"hauls": 0,
		"cooler": [],  # raw fish waiting for the Cutting Board
		"dressed": 0,
		"since": {},  # handled since the last station install; drives hidden station unlocks
		"town_sel": "",
	}


## State kept across prestige.
func _persistent() -> Dictionary:
	return {
		"log": {},
		"magic": [],
		"seen": [],
		"votes": {},
		"outbox": [],
		"tos": false,
		"prestige": 0,
		"empties": 0,
		"story": {},  # story beats that have happened: letter ids, and "<id>_read"
		"crow_unread": [],  # letters waiting at the Desk
		"met": {},  # townsfolk whose introduction you've seen
		"quests_done": {},  # story requests, done once ever
		"orders": {},  # standing orders filled, per person; they grow with each one
		"rares": {},  # materials that can't be dredged
		"emporium": false,  # once opened, it stays yours through prestige
		# Emporium state, also kept through prestige.
		"emp_tab": "floor",
		"decor": [],  # {id, n, e, rar, placed}
		"slots": Data.DECOR_START_SLOTS,
		"tickets": 0,
		"puzzles": [],  # stowed puzzle curios, by rarity
		"puzzle": {},  # the one on the workbench: {n, cells, rar}
		"customers": [],
		"next_customer": 0.0,
		"board": [],
		"board_done": 0,
		# Prestige cosmetics on show; -1 = none.
		"looks": {"keychain": -1, "pet": -1, "border": -1, "badge": -1},
	}


func _commit() -> void:
	_save()
	changed.emit()


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	s.merge(data, true)
	# JSON turns every number into a float; restore the ints.
	for k in ["sel", "depth", "streak", "best", "uid", "hauls", "prestige", "empties"]:
		s[k] = int(s[k])
	for k in s.up:
		s.up[k] = int(s.up[k])
	for k in s.votes:
		s.votes[k] = int(s.votes[k])
	for g in s.goods:
		s.goods[g].n = int(s.goods[g].n)
	for it in s.tray:
		it.uid = int(it.uid)
		if it.has("clicks"):
			it.clicks = int(it.clicks)
	for it in s.tray:
		# Empty bottles used to be their own kind; now they're glass junk.
		if it.kind == "empty":
			it.merge(_empty_bottle(), true)
	for it in s.cooler:
		it.uid = int(it.uid)
	for k in s.orders:
		s.orders[k] = int(s.orders[k])
	for k in s.rares:
		s.rares[k] = int(s.rares[k])
	for k in ["slots", "tickets", "board_done"]:
		s[k] = int(s[k])
	for k in s.looks:
		s.looks[k] = int(s.looks[k])
	for o in s.board:
		o.n = int(o.n)
	for c in s.customers:
		c.drink = c.drink.map(func(x): return int(x))
	s.dressed = int(s.dressed)
	for k in s.since:
		s.since[k] = int(s.since[k])
	# Older saves had the crow's letter pop up instead of waiting at the Desk.
	if s.story.has("crow"):
		s.story.crow1 = true
		s.story.crow1_read = true
		s.story.erase("crow")
	# Older saves kept raw fish as one lump; turn it into individual fish.
	if s.goods.has("fish_raw"):
		var lump: Dictionary = s.goods["fish_raw"]
		for i in int(lump.n):
			s.cooler.append(
				{"uid": _next_uid(), "name": "Fish", "e": "🐟", "v": lump.v / maxf(1.0, lump.n)}
			)
		s.goods.erase("fish_raw")


# ---------- derived values ----------


func has_magic(id: String) -> bool:
	return s.magic.has(id)


func complete() -> bool:
	return s.magic.size() == Data.MAGIC.size()


func luck() -> int:
	return int(s.up.luck) + (2 if has_magic("compass") else 0)


## Payout multiplier from depth, prestige and magic curios.
func g_mult() -> float:
	var bonus := 1.0
	bonus += 0.05 if has_magic("pearl") else 0.0
	bonus += 0.1 if has_magic("heart") else 0.0
	bonus += 0.25 if complete() else 0.0
	bonus += decor_bonus()
	return (1.0 + 0.1 * s.prestige) * Data.DEPTHS[s.depth].m * bonus


func streak_mult() -> float:
	return 1.0 + 0.05 * mini(s.streak, 20)


func dredge_secs() -> float:
	if dev_fast:
		return 0.3
	var t: float = 6.0 * pow(0.88, s.up.speed)
	t *= 1.0 - minf(0.5, 0.03 * s.prestige)
	return t * (0.95 if has_magic("tooth") else 1.0)


func basket() -> int:
	return mini(Data.MAX_BASKET, 3 + int(s.up.basket) + (1 if has_magic("lantern") else 0))


func clean_clicks() -> int:
	return maxi(1, 4 - int(s.up.clean))


func up_cost(k: String) -> int:
	var u: Dictionary = Data.UPS[k]
	var lv: int = s.up[k]
	if u.has("sq"):
		return roundi(u.base + u.sq * lv * lv)
	return roundi(u.base * pow(u.g, lv))


func up_visible(k: String) -> bool:
	return basket() >= Data.UP_REVEAL[k] or s.up[k] > 0


func stations_open() -> bool:
	return basket() >= Data.STATIONS_UNLOCK_BASKET


## The next station the player can install, or "" once all are built.
func next_station() -> String:
	for k in Data.STATION_ORDER:
		if not s.st.has(k):
			return k
	return ""


func tab_unlocked(t: String) -> bool:
	match t:
		"work":
			return s.life > 0.0 or s.up.basket > 0
		"desk":
			return (
				not s.seen.is_empty() or not s.log.is_empty() or s.empties > 0
				or not s.story.is_empty()
			)
		"map":
			return s.prestige >= 1
		"guild":
			return false  # needs the online server
		"town":
			return s.story.has("crow1_read")
		"emporium":
			return s.emporium
	return true


## The bin an item belongs in right now, given the stations on the ship.
func correct_bin(it: Dictionary) -> String:
	var bin: String = it.bin
	for r in Data.SORT_RULES:
		if r.item == it.name and s.st.has(r.st):
			bin = r.bin
	return bin


func prestige_goal() -> int:
	return roundi(1000000.0 * pow(2.2, s.prestige))


func title() -> String:
	return Data.TITLES[mini(s.prestige, Data.TITLES.size() - 1)]


func dredging() -> bool:
	return s.dredge_end > 0.0


func dredge_progress() -> float:
	if not dredging():
		return 0.0
	return clampf(1.0 - (s.dredge_end - _now()) / s.dredge_len, 0.0, 1.0)


func score(letter: Dictionary) -> int:
	return int(letter.get("score", 0)) + int(s.votes.get(letter.id, 0))


func pending_letters() -> int:
	return s.outbox.filter(func(o): return not o.approved).size()


func _now() -> float:
	return Time.get_unix_time_from_system()


func _rank(rarity: String) -> int:
	for i in Data.RARITY.size():
		if Data.RARITY[i][0] == rarity:
			return i
	return -1


# ---------- loot ----------


func _pick_kind() -> String:
	var w: Dictionary = Data.DEPTHS[s.depth].w
	var total := 0.0
	for k in w:
		total += w[k]
	var t := randf() * total
	for k in w:
		t -= w[k]
		if t < 0.0:
			return k
	return "junk"


func _next_uid() -> int:
	var u: int = s.uid
	s.uid += 1
	return u


func _new_item(kind: String) -> Dictionary:
	var it := {"uid": _next_uid(), "kind": kind}
	match kind:
		"junk":
			var j: Array = junk_pool().pick_random()
			var base: float = Data.BINS[j[2]].p * randf_range(1.0, 1.5)
			it.merge({"name": j[0], "e": j[1], "bin": j[2], "w": j[3], "base": base})
		"fish":
			var f: Array = fish_pool(s.depth).pick_random()
			it.merge({"name": f[0], "e": f[1], "w": f[3], "base": f[2] * randf_range(0.8, 1.4)})
		"curio":
			var c: Array = curio_pool().pick_random()
			it.merge(
				{"name": c[0], "e": c[1], "base": randf_range(12.0, 22.0), "clicks": 0, "done": false}
			)
		"crate":
			it.merge({"name": "Crate", "e": "📦"})
		"bottle":
			it.merge({"name": "Bottle", "e": "🍾"})
		"animal":
			var a: Array = Data.ANIMALS.pick_random()
			it.merge({"name": a[0], "e": a[1]})
	return it


func _haul() -> Array:
	var out := []
	for _i in basket():
		var magic_odds: float = 0.006 * (1 + s.depth) * (1.0 + luck() * 0.4)
		if randf() < magic_odds and not complete():
			out.append(
				{
					"uid": _next_uid(),
					"kind": "curio",
					"magic": true,
					"name": "Strange glowing curio",
					"e": "✨",
					"base": 0.0,
					"clicks": 0,
					"done": false,
				}
			)
		elif s.emporium and randf() < Data.PUZZLE_CHANCE:
			out.append(
				{"uid": _next_uid(), "kind": "puzzle", "name": "Puzzle curio", "e": "🧩", "rar": _roll_rarity()}
			)
		else:
			out.append(_new_item(_pick_kind()))
	# The very first catch always has a fish, so the Cutting Board (and the crow) come early.
	if s.hauls == 1 and not out.any(func(i): return i.kind == "fish"):
		out[out.size() - 1] = _new_item("fish")
	return out


func _item(uid: int) -> Dictionary:
	for it in s.tray:
		if it.uid == uid:
			return it
	return {}


func _drop(it: Dictionary) -> void:
	s.tray.erase(it)
	if s.sel == it.uid:
		s.sel = -1


func _earn(n: float) -> void:
	s.coins += n
	s.life += n


func _add(g: String, n: int, v: float) -> void:
	if not s.goods.has(g):
		s.goods[g] = {"n": 0, "v": 0.0}
	s.goods[g].n += n
	s.goods[g].v += v


# ---------- actions (called by the UI) ----------


func set_tab(t: String) -> void:
	s.tab = t
	_commit()


func set_sub(t: String) -> void:
	s.sub = t
	_commit()


func start_dredge() -> void:
	if dredging() or not s.tray.is_empty():
		return
	s.dredge_len = dredge_secs()
	s.dredge_end = _now() + s.dredge_len
	_commit()


func select(uid: int) -> void:
	s.sel = uid
	_commit()


## Click-then-click fallback for the drag-and-drop sort.
func sort_into(bin: String) -> void:
	if _item(s.sel).is_empty():
		toast.emit("Pick up a piece of junk first.")
		return
	sort_item(s.sel, bin)


## No timer: accuracy is what pays. Each correct sort in a row raises the streak bonus.
func sort_item(uid: int, bin: String) -> void:
	var it := _item(uid)
	if it.is_empty() or it.kind != "junk":
		return
	var right := correct_bin(it)
	var amount: float
	if bin == right:
		amount = it.base * streak_mult() * g_mult()
		if right != it.bin:
			amount *= Data.STATION_RULE_BONUS
		s.streak += 1
		s.best = maxi(s.best, s.streak)
		_count(right)
	else:
		amount = it.base * 0.4 * g_mult()
		s.streak = 0
		toast.emit("%s belongs in %s. Streak reset." % [it.name, Data.BINS[right].n])
	_add("bin_" + bin, 1, amount)
	_drop(it)
	_commit()
	sorted.emit(bin, bin == right, int(it.get("w", 2)), amount)


func clean(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty() or it.done:
		return
	it.clicks += 1
	if it.clicks < clean_clicks():
		_commit()
		return
	it.done = true
	if it.get("magic", false):
		var left: Array = Data.MAGIC.filter(func(m): return not has_magic(m.id))
		var m: Dictionary = left.pick_random()
		s.magic.append(m.id)
		toast.emit("✨ MAGIC CURIO: %s — %s" % [m.n, m.d])
		if complete():
			toast.emit("🏆 Full magic set! +25% payout forever.")
		_drop(it)
		_commit()
		return
	var roll := randf() * 100.0 - luck() * 3.0
	var r: Array = Data.RARITY[0]
	# Walk from rarest down; each tier's threshold is its weight plus every rarer tier's.
	var threshold := 0.0
	for i in range(Data.RARITY.size() - 1, -1, -1):
		threshold += Data.RARITY[i][2]
		if roll < threshold:
			r = Data.RARITY[i]
			break
	it.rar = r[0]
	it.value = it.base * r[1] * (1.15 if has_magic("crown") else 1.0)
	# Late-game relics: a rarer curio from one of the unlocked relic tiers.
	var tiers := relic_tiers()
	if not tiers.is_empty() and randf() < Data.RELIC_CHANCE:
		var tier: Dictionary = tiers.pick_random()
		var relic: Array = tier.items.pick_random()
		it.name = relic[0]
		it.e = relic[1]
		it.rar = tier.rar
		it.value = it.base * tier.mult
		toast.emit("A %s relic: %s!" % [tier.rar, relic[0]])
	_commit()


func curio_sell(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty():
		return
	var v: float = it.value * g_mult()
	_earn(v)
	toast.emit("Sold %s for %d" % [it.name, roundi(v)])
	_drop(it)
	_commit()


func curio_keep(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty():
		return
	var had: String = s.log.get(it.name, "")
	if had == "" or _rank(it.rar) > _rank(had):
		s.log[it.name] = it.rar
		_earn(it.value * 0.25)
		toast.emit("Added to Collector's Log: %s %s" % [it.rar, it.name])
	else:
		var v: float = it.value * g_mult()
		_earn(v)
		toast.emit("You already have that or better — sold for %d" % roundi(v))
	_drop(it)
	_commit()


func _count(stat: String) -> void:
	s.since[stat] = int(s.since.get(stat, 0)) + 1


## What Inspect says: a hint at the default bin, plus any station that changes it.
func inspect_text(it: Dictionary) -> String:
	var text: String = Data.DESCS.get(it.name, _pack_desc(it.name))
	for r in Data.SORT_RULES:
		if r.item == it.name and s.st.has(r.st):
			text += " " + r.hint
	return text


## Drag a fish into the cooler to keep it for the Cutting Board.
func stash_fish(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty() or it.kind != "fish":
		return
	var v: float = it.base * g_mult()
	s.cooler.append({"uid": it.uid, "name": it.name, "e": it.e, "v": v})
	_drop(it)
	_commit()
	sorted.emit("cooler", true, int(it.get("w", 1)), v)


func cooler_value() -> float:
	var total := 0.0
	for f in s.cooler:
		total += f.v
	return total


func sell_cooler() -> void:
	if s.cooler.is_empty():
		return
	var total := cooler_value()
	_earn(total)
	toast.emit("Sold %d raw fish for %d" % [s.cooler.size(), roundi(total)])
	s.cooler = []
	_commit()


## The Cutting Board: one click dresses one fish.
func dress_fish(uid: int) -> void:
	var fish: Dictionary = {}
	for f in s.cooler:
		if f.uid == uid:
			fish = f
	if fish.is_empty():
		return
	s.cooler.erase(fish)
	_add("fish_dressed", 1, fish.v * Data.DRESS_MULT)
	s.dressed += 1
	_count("dressed")
	_commit()
	deliver_letter("crow1")


func open_crate(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty():
		return
	_drop(it)
	var r := randf()
	if r < 0.5:
		var c: float = randf_range(20.0, 80.0) * (1 + s.depth)
		_earn(c)
		toast.emit("Crate: %d coins!" % roundi(c))
	elif r < 0.85:
		s.tray.append(_new_item("junk"))
		s.tray.append(_new_item("junk"))
		toast.emit("Crate: two more pieces of junk.")
	else:
		s.tray.append(_new_item("curio"))
		toast.emit("Crate: a curio!")
	_commit()


func open_bottle(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty():
		return
	if randf() < 0.3:
		it.merge(_empty_bottle(), true)
		_commit()
		return
	var unseen: Array = letter_pool().filter(func(l): return not s.seen.has(l.id))
	var comm: Array = community_pool().filter(func(l): return _unread_ok(l))
	var letter: Dictionary
	if not unseen.is_empty() and (randf() < 0.5 or comm.is_empty()):
		letter = unseen.pick_random()
	elif not comm.is_empty():
		letter = comm.pick_random()
	else:
		letter = letter_pool().pick_random()
	if not s.seen.has(letter.id):
		s.seen.append(letter.id)
	_drop(it)
	_commit()
	letter_opened.emit(letter)


func _unread_ok(l: Dictionary) -> bool:
	return not s.seen.has(l.id) and score(l) > -3


func empty_keep(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty():
		return
	s.empties += 1
	toast.emit("Saved an empty bottle for the Desk.")
	_drop(it)
	_commit()


## A message bottle with nothing inside becomes glass junk (or a bottle for your own letter).
func _empty_bottle() -> Dictionary:
	return {
		"kind": "junk", "name": "Empty bottle", "e": "🍶", "bin": "glass", "w": 1,
		"base": Data.BINS.glass.p * randf_range(1.0, 1.5),
	}


func free_animal(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty():
		return
	_earn(3.0)
	toast.emit("The %s swims off happily." % it.name)
	_drop(it)
	_commit()


func has_station(st: String) -> bool:
	return st == "cut" or s.st.has(st)


func process_recipe(i: int) -> void:
	var r: Dictionary = all_recipes()[i]
	if not has_station(r.st) or not s.goods.has(r.inp):
		return
	var o: Dictionary = s.goods[r.inp]
	_add(r.out, o.n, o.v * r.f)
	s.goods.erase(r.inp)
	toast.emit("Processed into %s" % goods_info(r.out)[0])
	_commit()


func sell(g: String) -> void:
	if not s.goods.has(g):
		return
	var o: Dictionary = s.goods[g]
	_earn(o.v)
	toast.emit("Sold %d for %d" % [o.n, roundi(o.v)])
	s.goods.erase(g)
	_commit()


func sell_all() -> void:
	if not s.emporium:
		return
	var total := 0.0
	for g in s.goods:
		total += s.goods[g].v
	total += cooler_value()
	_earn(total)
	s.goods = {}
	s.cooler = []
	toast.emit("Sold everything for %d" % roundi(total))
	_commit()


func upgrade(k: String) -> void:
	var c := up_cost(k)
	if s.coins < c or s.up[k] >= Data.UPS[k].max:
		return
	s.coins -= c
	s.up[k] += 1
	_commit()


## True once the station's hidden requirement is met. Stations still come strictly in order.
func station_ready(k: String) -> bool:
	if not stations_open() or next_station() != k:
		return false
	var needs: Dictionary = Data.STATIONS[k].needs
	return int(s.since.get(needs.stat, 0)) >= int(needs.count)


func build_station(k: String) -> void:
	var st: Dictionary = Data.STATIONS[k]
	if s.coins < st.cost or not station_ready(k):
		return
	s.coins -= st.cost
	s.st[k] = true
	s.since = {}
	deliver_letter("crow_" + k)
	toast.emit("Installed the %s" % st.n)
	for r in Data.SORT_RULES:
		if r.st == k:
			toast.emit("New sorting rule: %s now goes in %s." % [r.item, Data.BINS[r.bin].n])
	_commit()


## Depths open one per retirement: the first run is Shallows only.
func depth_unlocked(i: int) -> bool:
	return s.prestige >= int(Data.DEPTHS[i].prestige)


func set_depth(i: int) -> void:
	if depth_unlocked(i):
		s.depth = i
	_commit()


## Prestige: reset the run, keep collections, gain permanent bonuses.
func retire() -> void:
	if s.life < prestige_goal():
		return
	_do_retire()


func _do_retire() -> void:
	var keep := {}
	for k in _persistent():
		keep[k] = s[k]
	keep.prestige = s.prestige + 1
	s = _fresh()
	s.merge(keep, true)
	s.depth = mini(s.prestige, Data.DEPTHS.size() - 1)
	var pack := _pack_at(s.prestige)
	if not pack.is_empty():
		toast.emit("New in the bay: %s" % pack.n)
	# Show off the newest prestige rewards straight away.
	for kind in s.looks:
		s.looks[kind] = mini(s.prestige, Data.COSMETICS[kind].size()) - 1
	s.tab = "work"
	toast.emit("A new tide begins. You are now a %s." % title())
	_commit()


func community_pool() -> Array:
	return Data.SEED_COMMUNITY + s.outbox.filter(func(o): return o.approved)


func accept_tos() -> void:
	s.tos = true
	_commit()


## Returns true if the letter was sent.
func send_letter(text: String, signed: bool) -> bool:
	text = text.strip_edges()
	if text.is_empty():
		return false
	if pending_letters() >= MAX_PENDING_LETTERS:
		toast.emit("You can only have %d letters awaiting review." % MAX_PENDING_LETTERS)
		return false
	if s.empties <= 0:
		toast.emit("You need an empty bottle from the sea first.")
		return false
	s.empties -= 1
	s.outbox.append(
		{
			"id": "u%d" % int(_now() * 1000.0),
			"from": "You" if signed else "Anonymous",
			"t": text.left(LETTER_MAX_CHARS),
			"score": 0,
			"approved": false,
			"mine": true,
		}
	)
	toast.emit("Bottle sent to the review queue.")
	_commit()
	return true


func vote(id: String, v: int) -> void:
	s.votes[id] = 0 if int(s.votes.get(id, 0)) == v else v
	_commit()


# ---------- the crow ----------


## The crow brings a story letter to the Desk, once per letter ever.
func deliver_letter(id: String, force := false) -> void:
	# The story is told once; after prestige the game is a sandbox.
	if (sandbox() and not force) or s.story.has(id) or not Data.STORY_LETTERS.has(id):
		return
	s.story[id] = true
	s.crow_unread.append(id)
	toast.emit("A crow landed on your Desk with a letter.")
	_commit()
	crow_arrived.emit()


func read_letter(id: String) -> void:
	var letter: Dictionary = Data.STORY_LETTERS[id]
	s.crow_unread.erase(id)
	s.story[id + "_read"] = true
	if not s.seen.has(id):
		s.seen.append(id)
	_commit()
	letter_opened.emit(letter)


# ---------- town ----------


func npc_unlocked(id: String) -> bool:
	var u: Dictionary = Data.NPCS[id].unlock
	if u.has("story"):
		return s.story.has(u.story)
	return s.st.has(u.station)


func visit(id: String) -> void:
	s.town_sel = id
	_commit()


func meet(id: String) -> void:
	s.met[id] = true
	_commit()


## How much of a good you're holding and what it's worth. "cooler" is raw fish.
func holding(good: String) -> Dictionary:
	if good == "cooler":
		return {"n": s.cooler.size(), "v": cooler_value()}
	return s.goods.get(good, {"n": 0, "v": 0.0})


func sell_to(npc: String, good: String) -> void:
	if not npc_unlocked(npc) or not npc_buys(npc).has(good):
		return
	if good == "cooler":
		sell_cooler()
	else:
		sell(good)


func can_open_emporium() -> bool:
	return next_station() == "" and not s.emporium


func emporium_affordable() -> bool:
	if s.coins < Data.EMPORIUM_COST:
		return false
	for r in Data.EMPORIUM_RARES:
		if int(s.rares.get(r, 0)) < Data.EMPORIUM_RARES[r]:
			return false
	return true


func open_emporium() -> void:
	if not can_open_emporium() or not emporium_affordable():
		return
	s.coins -= Data.EMPORIUM_COST
	for r in Data.EMPORIUM_RARES:
		s.rares[r] = int(s.rares[r]) - Data.EMPORIUM_RARES[r]
	s.emporium = true
	board_fill()
	toast.emit("Your Emporium is open. You can sell everything at once from Storage.")
	_commit()
	deliver_letter("crow_emporium")



func sandbox() -> bool:
	return s.prestige > 0


# ---------- requests ----------


func _quest_open(q: Dictionary) -> bool:
	var req: Dictionary = q.get("requires", {})
	if req.has("depth") and not depth_unlocked(int(req.depth)):
		return false
	if req.has("station") and not s.st.has(req.station):
		return false
	if req.has("quest") and not s.quests_done.has(req.quest):
		return false
	return true


## What this person is asking for right now, or {} if nothing.
## Story requests come first, in order; after those, endless standing orders.
func quest_for(npc: String) -> Dictionary:
	for q in quest_pool():
		if q.npc != npc or s.quests_done.has(q.id):
			continue
		return q if _quest_open(q) else {}
	return _standing_order(npc)


## A repeatable order that grows each time. Pays the goods' value plus a bonus.
func _standing_order(npc: String) -> Dictionary:
	var done: int = int(s.orders.get(npc, 0))
	var options: Array = npc_buys(npc).filter(
		func(g): return can_make(g)
	)
	if options.is_empty():
		return {}
	var good: String = options[done % options.size()]
	var n := mini(5 + 3 * done, 80)
	return {
		"id": "order", "npc": npc, "title": "Standing order #%d" % (done + 1),
		"needs": {"good": good, "n": n}, "reward": {"bonus": 0.5 + 0.05 * mini(done, 10)},
		"ask": "\"Same as always, if you've got it: %d × %s.\"" % [n, good_label(good)],
		"done": "\"Pleasure doing business.\"",
	}


func good_label(g: String) -> String:
	if g == "cooler":
		return "raw fish"
	if g.begins_with("bin_"):
		return "sorted " + Data.BINS[g.substr(4)].n.to_lower()
	return goods_info(g)[0].to_lower()


## How many of what a request needs you're holding.
func quest_have(q: Dictionary) -> int:
	var needs: Dictionary = q.needs
	if needs.has("fish"):
		return s.cooler.filter(func(f): return f.name == needs.fish).size()
	return int(holding(needs.good).n)


## Removes n of a good and returns the value removed.
func _take(good: String, n: int) -> float:
	if good == "cooler":
		var taken := 0.0
		for i in n:
			taken += s.cooler.pop_front().v
		return taken
	var o: Dictionary = s.goods[good]
	var each: float = o.v / maxf(1.0, o.n)
	o.n -= n
	o.v -= each * n
	if o.n <= 0:
		s.goods.erase(good)
	return each * n


func _take_fish(fish_name: String, n: int) -> float:
	var taken := 0.0
	for f in s.cooler.filter(func(x): return x.name == fish_name).slice(0, n):
		taken += f.v
		s.cooler.erase(f)
	return taken


func complete_quest(npc: String) -> void:
	var q := quest_for(npc)
	if q.is_empty() or quest_have(q) < int(q.needs.n):
		return
	var n: int = q.needs.n
	var value: float = (
		_take_fish(q.needs.fish, n) if q.needs.has("fish") else _take(q.needs.good, n)
	)
	var rw: Dictionary = q.reward
	var coins: float = rw.get("coins", 0) + value * rw.get("bonus", 0.0)
	if not rw.has("bonus"):
		coins += value  # story requests pay the goods' value on top of the reward
	_earn(coins)
	var parts: PackedStringArray = ["%d coins" % roundi(coins)]
	for r in rw.get("rares", {}):
		s.rares[r] = int(s.rares.get(r, 0)) + int(rw.rares[r])
		parts.append("%s %s ×%d" % [Data.RARES[r].e, Data.RARES[r].n, rw.rares[r]])
	if q.id == "order":
		s.orders[npc] = int(s.orders.get(npc, 0)) + 1
	else:
		s.quests_done[q.id] = true
	_commit()
	quest_done.emit(npc, q.done, ", ".join(parts))



# ---------- Emporium: decorations ----------


func _roll_rarity() -> String:
	var roll := randf() * 100.0
	var threshold := 0.0
	for i in range(Data.RARITY.size() - 1, -1, -1):
		threshold += Data.RARITY[i][2]
		if roll < threshold:
			return Data.RARITY[i][0]
	return "common"


func decor_bonus() -> float:
	var total := 0.0
	for d in s.decor:
		if d.placed:
			total += Data.DECOR_BONUS[d.rar]
	return total


func placed_count() -> int:
	return s.decor.filter(func(d): return d.placed).size()


## A new decoration. It goes straight onto the floor if there's room.
func _grant_decor(rar: String) -> void:
	var pick: Array = Data.DECOR[rar].pick_random()
	var d := {"id": pick[0], "n": pick[1], "e": pick[2], "rar": rar, "placed": false}
	d.placed = placed_count() < s.slots
	s.decor.append(d)
	toast.emit("New decoration: %s %s (%s)" % [d.e, d.n, rar])


func toggle_decor(i: int) -> void:
	var d: Dictionary = s.decor[i]
	if not d.placed and placed_count() >= s.slots:
		toast.emit("No room on the floor. Put something away or expand the shop.")
		return
	d.placed = not d.placed
	_commit()


func slot_cost() -> int:
	return roundi(Data.DECOR_SLOT_BASE_COST * pow(2.0, (s.slots - Data.DECOR_START_SLOTS) / 2.0))


func expand_slots() -> void:
	var c := slot_cost()
	if s.coins < c:
		return
	s.coins -= c
	s.slots += 2
	toast.emit("The Emporium has room for %d decorations now." % s.slots)
	_commit()


# ---------- Emporium: puzzle curios ----------


func stow_puzzle(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty():
		return
	s.puzzles.append(it.rar)
	toast.emit("Stowed a %s puzzle curio for the Emporium." % it.rar)
	_drop(it)
	_commit()


## Puzzles are "lights out": pressing a tile flips it and its neighbours. Clear them all.
func start_puzzle() -> void:
	if not s.puzzle.is_empty() or s.puzzles.is_empty():
		return
	var rar: String = s.puzzles.pop_front()
	var n := 3 if rar == "common" or rar == "uncommon" else 4
	var cells := []
	cells.resize(n * n)
	cells.fill(false)
	s.puzzle = {"n": n, "cells": cells, "rar": rar}
	# Scramble by pressing from the solved state, so it's always solvable.
	while not s.puzzle.cells.has(true):
		for i in n + 2 + _rank(rar) * 2:
			_flip(randi() % (n * n))
	_commit()


func _flip(i: int) -> void:
	var n: int = s.puzzle.n
	var x := i % n
	var y := i / n
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx >= 0 and nx < n and ny >= 0 and ny < n:
			s.puzzle.cells[ny * n + nx] = not s.puzzle.cells[ny * n + nx]


func press_cell(i: int) -> void:
	if s.puzzle.is_empty():
		return
	_flip(i)
	if not s.puzzle.cells.has(true):
		var rar: String = s.puzzle.rar
		s.puzzle = {}
		var coins: float = 200.0 * (1 + _rank(rar)) * g_mult()
		_earn(coins)
		toast.emit("The curio clicks open! %d coins inside." % roundi(coins))
		_grant_decor(rar)
	_commit()


# ---------- Emporium: the counter ----------


func _customer_tick() -> void:
	if not s.emporium or s.customers.size() >= Data.MAX_CUSTOMERS:
		return
	if _now() < s.next_customer:
		return
	s.next_customer = _now() + Data.CUSTOMER_EVERY
	add_customer()


## Someone walks in: a friend from town, a local, a traveller, a tourist, or an event visitor.
func add_customer() -> void:
	var person := _pick_person()
	s.customers.append(
		{
			"id": _next_uid(),
			"e": person[1],
			"who": person[0],
			"line": person[2],
			"drink": [
				randi() % Data.DRINK_BASES.size(),
				randi() % Data.DRINK_FLAVORS.size(),
				randi() % Data.DRINK_FINISHES.size(),
			],
			"food": randf() < 0.5,
		}
	)
	_commit()


func drink_name(d: Array) -> String:
	return "%s with %s, %s" % [
		Data.DRINK_BASES[d[0]], Data.DRINK_FLAVORS[d[1]].to_lower(), Data.DRINK_FINISHES[d[2]].to_lower()
	]


## Drinks are endless; food comes out of your finite stock of meals.
func serve(cid: int, drink: Array) -> void:
	var c: Dictionary = {}
	for x in s.customers:
		if x.id == cid:
			c = x
	if c.is_empty():
		return
	var right: bool = drink == c.drink
	var pay: float = Data.DRINK_PRICE * g_mult() * (1.5 if right else 0.4)
	var note := "Perfect order! Big tip." if right else "Not quite what they asked for."
	if c.food:
		if int(holding("meal").n) > 0:
			pay += _take("meal", 1) * 1.5
			note += " They loved the meal."
		else:
			note += " They wanted food, but you're out of meals."
	_earn(pay)
	s.customers.erase(c)
	toast.emit("%s +%d coins. %s" % [c.e, roundi(pay), note])
	_commit()


# ---------- Emporium: arcade ----------


## score is 0..1: how close to the centre the lever stopped.
func arcade_result(score: float) -> int:
	var t := 1 + roundi(9.0 * score * score)
	s.tickets += t
	_commit()
	return t


func buy_prize(i: int) -> void:
	var box: Dictionary = Data.PRIZE_BOXES[i]
	if s.tickets < box.cost:
		return
	s.tickets -= box.cost
	var odds: Dictionary = box.odds
	var roll := randf() * 100.0
	var rar := "common"
	for r in odds:
		roll -= odds[r]
		if roll < 0.0:
			rar = r
			break
	_grant_decor(rar)
	_commit()


# ---------- Emporium: work order board ----------


func _board_goods() -> Array:
	var goods := ["cooler", "fish_dressed"]
	for k in Data.BIN_KEYS:
		goods.append("bin_" + k)
	for g in Data.GOOD_STATION:
		if can_make(g):
			goods.append(g)
	for p in packs_unlocked():
		for g in p.goods:
			if can_make(g):
				goods.append(g)
	return goods


## Keeps the board topped up. Orders never expire.
func board_fill() -> void:
	while s.board.size() < Data.BOARD_SIZE:
		var good: String = _board_goods().pick_random()
		var n := roundi(randf_range(10, 30) * (1.0 + 0.1 * mini(s.board_done, 30)))
		s.board.append({"good": good, "n": n, "decor": randf() < 0.3})


func complete_board(i: int) -> void:
	var o: Dictionary = s.board[i]
	if int(holding(o.good).n) < int(o.n):
		return
	var pay: float = _take(o.good, o.n) * 2.0
	_earn(pay)
	toast.emit("Work order filled: +%d coins" % roundi(pay))
	if o.decor:
		_grant_decor(["common", "uncommon", "rare"].pick_random())
	s.board.remove_at(i)
	s.board_done += 1
	board_fill()
	_commit()


func set_emp_tab(t: String) -> void:
	s.emp_tab = t
	_commit()


# ---------- prestige cosmetics ----------


## How many of each cosmetic are unlocked (one per retirement).
func looks_unlocked(kind: String) -> int:
	return mini(s.prestige, Data.COSMETICS[kind].size())


func set_look(kind: String, i: int) -> void:
	if i < looks_unlocked(kind):
		s.looks[kind] = i
		_commit()


## The equipped cosmetic as [name, value], or [] if none.
func look(kind: String) -> Array:
	var i: int = s.looks[kind]
	if i < 0 or i >= looks_unlocked(kind):
		return []
	return Data.COSMETICS[kind][i]



func _pick_person() -> Array:
	var friends := []
	for id in Data.NPC_ORDER:
		if s.met.has(id):
			var npc: Dictionary = Data.NPCS[id]
			friends.append(["%s (%s)" % [npc.n, npc.role], npc.e, Data.FRIEND_LINES.pick_random()])
	var roll := randf() * 100.0
	for kind in Data.CUSTOMER_ODDS:
		roll -= Data.CUSTOMER_ODDS[kind]
		if roll < 0.0:
			if kind == "friend":
				if not friends.is_empty():
					return friends.pick_random()
			else:
				return Data.CUSTOMER_PEOPLE[kind].pick_random()
	return Data.CUSTOMER_PEOPLE.citizen.pick_random()


# ---------- prestige content: packs and relics ----------


func packs_unlocked() -> Array:
	return Data.PACKS.filter(func(p): return s.prestige >= int(p.prestige))


func _pack_at(prestige: int) -> Dictionary:
	for p in Data.PACKS:
		if int(p.prestige) == prestige:
			return p
	return {}


func relic_tiers() -> Array:
	return Data.RELIC_TIERS.filter(func(t): return s.prestige >= int(t.prestige))


func junk_pool() -> Array:
	var out: Array = Data.JUNK.duplicate()
	for p in packs_unlocked():
		out.append_array(p.junk)
	return out


func curio_pool() -> Array:
	var out: Array = Data.CURIOS.duplicate()
	for p in packs_unlocked():
		out.append_array(p.curios)
	return out


func fish_pool(depth: int) -> Array:
	var out: Array = Data.FISH_BY_DEPTH[depth].duplicate()
	for p in packs_unlocked():
		out.append_array(p.fish.get(depth, []))
	return out


func letter_pool() -> Array:
	var out: Array = Data.LETTERS.duplicate()
	for p in packs_unlocked():
		out.append_array(p.letters)
	return out


func quest_pool() -> Array:
	var out: Array = Data.QUESTS.duplicate()
	for p in packs_unlocked():
		out.append_array(p.quests)
	return out


func all_recipes() -> Array:
	var out: Array = Data.RECIPES.duplicate()
	for p in packs_unlocked():
		out.append_array(p.recipes)
	return out


## [name, emoji] for any good, including ones added by packs.
func goods_info(g: String) -> Array:
	if Data.GOODS.has(g):
		return Data.GOODS[g]
	for p in Data.PACKS:
		if p.goods.has(g):
			return p.goods[g]
	return [g, "📦"]


## What someone in town buys: their usual goods plus any pack products made for them.
func npc_buys(npc: String) -> Array:
	var out: Array = Data.NPCS[npc].buys.duplicate()
	for p in packs_unlocked():
		for r in p.recipes:
			if r.buyer == npc:
				out.append(r.out)
	return out


func _pack_desc(item_name: String) -> String:
	for p in Data.PACKS:
		for j in p.junk:
			if j[0] == item_name:
				return j[4]
	return "Hard to say what this was."



## Whether the station that makes this good is on board (raw goods always count).
func can_make(g: String) -> bool:
	if Data.GOOD_STATION.has(g):
		return s.st.has(Data.GOOD_STATION[g])
	for p in Data.PACKS:
		for r in p.recipes:
			if r.out == g:
				return s.st.has(r.st)
	return true



# ---------- dev menu (debug builds only; see main.gd) ----------


func dev_coins(n: float) -> void:
	_earn(n)
	_commit()


func dev_basket(size: int) -> void:
	s.up.basket = clampi(size - 3, 0, Data.UPS.basket.max)
	_commit()


func dev_toggle_fast() -> void:
	dev_fast = not dev_fast
	toast.emit("Dev: fast dredging %s" % ("on" if dev_fast else "off"))
	_commit()


func dev_finish_dredge() -> void:
	if dredging():
		s.dredge_end = _now()


func dev_fill_tray(kind: String, count: int) -> void:
	for i in count:
		match kind:
			"magic":
				s.tray.append(
					{
						"uid": _next_uid(), "kind": "curio", "magic": true,
						"name": "Strange glowing curio", "e": "✨", "base": 0.0, "clicks": 0, "done": false,
					}
				)
			"puzzle":
				s.tray.append(
					{"uid": _next_uid(), "kind": "puzzle", "name": "Puzzle curio", "e": "🧩", "rar": _roll_rarity()}
				)
			_:
				s.tray.append(_new_item(kind))
	_commit()


func dev_give_goods(n: int) -> void:
	for k in Data.BIN_KEYS:
		_add("bin_" + k, n, n * Data.BINS[k].p * 1.25)
	_add("fish_dressed", n, n * 16.0)
	for g in Data.GOOD_STATION:
		if can_make(g):
			_add(g, n, n * 35.0)
	for p in packs_unlocked():
		for g in p.goods:
			if can_make(g):
				_add(g, n, n * 60.0)
	for i in n:
		var f: Array = fish_pool(s.depth).pick_random()
		s.cooler.append({"uid": _next_uid(), "name": f[0], "e": f[1], "v": f[2] * g_mult()})
	toast.emit("Dev: +%d of every good" % n)
	_commit()


func dev_give_rares() -> void:
	for r in Data.RARES:
		s.rares[r] = int(s.rares.get(r, 0)) + 5
	_commit()


func dev_station_reqs() -> void:
	var k := next_station()
	if k != "":
		var needs: Dictionary = Data.STATIONS[k].needs
		s.since[needs.stat] = int(needs.count)
		toast.emit("Dev: requirement met for %s (basket must also be %d)" % [Data.STATIONS[k].n, Data.STATIONS_UNLOCK_BASKET])
	_commit()


func dev_install_next() -> void:
	var k := next_station()
	if k == "":
		return
	s.st[k] = true
	s.since = {}
	deliver_letter("crow_" + k, true)
	_commit()


func dev_install_all() -> void:
	while next_station() != "":
		dev_install_next()


func dev_next_letter() -> void:
	for id in Data.STORY_LETTERS:
		if not s.story.has(id):
			deliver_letter(id, true)
			return


func dev_open_town() -> void:
	s.story.crow1 = true
	s.story.crow1_read = true
	if not s.seen.has("crow1"):
		s.seen.append("crow1")
	_commit()


func dev_meet_all() -> void:
	for id in Data.NPC_ORDER:
		s.met[id] = true
	_commit()


func dev_finish_story_quests() -> void:
	for q in quest_pool():
		if s.quests_done.has(q.id):
			continue
		s.quests_done[q.id] = true
		for r in q.reward.get("rares", {}):
			s.rares[r] = int(s.rares.get(r, 0)) + int(q.reward.rares[r])
	_commit()


func dev_open_emporium() -> void:
	s.emporium = true
	board_fill()
	deliver_letter("crow_emporium", true)
	_commit()


func dev_customer() -> void:
	add_customer()
	_commit()


func dev_puzzles(n: int) -> void:
	for i in n:
		s.puzzles.append(_roll_rarity())
	_commit()


func dev_tickets(n: int) -> void:
	s.tickets += n
	_commit()


func dev_decor(rar: String) -> void:
	_grant_decor(rar)
	_commit()


func dev_all_magic() -> void:
	s.magic = Data.MAGIC.map(func(m): return m.id)
	_commit()


## Retire right now, ignoring the lifetime-coins goal.
func dev_prestige() -> void:
	_do_retire()


func dev_reset() -> void:
	s = _fresh()
	s.merge(_persistent())
	dev_fast = false
	toast.emit("Dev: save wiped")
	_commit()


## Jump straight to a point in the game. Each builds on the one before it.
func dev_preset(preset: String) -> void:
	dev_reset()
	if preset == "fresh":
		return
	# Town just opened
	dev_basket(5)
	_earn(300)
	dev_open_town()
	if preset == "town":
		return
	# Full basket, ready for stations
	dev_basket(32)
	_earn(20000)
	dev_meet_all()
	dev_give_goods(30)
	if preset == "basket32":
		return
	# Every station installed
	dev_install_all()
	dev_give_goods(40)
	if preset == "stations":
		return
	# Emporium open
	dev_finish_story_quests()
	dev_open_emporium()
	dev_puzzles(3)
	dev_tickets(300)
	for r in ["common", "uncommon", "rare"]:
		_grant_decor(r)
	for i in 3:
		add_customer()
	if preset == "emporium":
		return
	# Prestige presets: retire up to the target, then rebuild the run.
	var target: int = {"sandbox": 1, "depths": 3, "packs": 6, "relics": 13}.get(preset, 1)
	s.prestige = target - 1
	_do_retire()
	dev_basket(32)
	dev_install_all()
	dev_meet_all()
	_earn(100000)
	dev_give_goods(40)
	toast.emit("Dev: prestige %d, basket 32, all stations" % s.prestige)
	_commit()
