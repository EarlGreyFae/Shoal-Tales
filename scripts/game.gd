extends Node
## Game state, rules and saving. The UI calls the action methods and redraws on `changed`.

signal changed
signal toast(msg: String)
signal letter_opened(letter: Dictionary)

const SAVE_PATH := "user://shoal_tales_save.json"
const MAX_PENDING_LETTERS := 3
const LETTER_MAX_CHARS := 400

var s: Dictionary = {}


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
		toast.emit("The basket lifts…")
		_commit()


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
		"sub": "library",
		"uid": 1,
		"hauls": 0,
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
	return (1.0 + 0.1 * s.prestige) * Data.DEPTHS[s.depth].m * bonus


func streak_mult() -> float:
	return 1.0 + 0.05 * mini(s.streak, 20)


func dredge_secs() -> float:
	var t: float = 6.0 * pow(0.88, s.up.speed)
	t *= 1.0 - minf(0.5, 0.03 * s.prestige)
	return t * (0.95 if has_magic("tooth") else 1.0)


func basket() -> int:
	return 3 + int(s.up.basket) + (1 if has_magic("lantern") else 0)


func clean_clicks() -> int:
	return maxi(1, 4 - int(s.up.clean))


func up_cost(k: String) -> int:
	return roundi(Data.UPS[k].base * pow(Data.UPS[k].g, s.up[k]))


func prestige_goal() -> int:
	return roundi(6000.0 * pow(2.2, s.prestige))


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
			var j: Array = Data.JUNK.pick_random()
			var base: float = Data.BINS[j[2]].p * randf_range(1.0, 1.5)
			it.merge({"name": j[0], "e": j[1], "bin": j[2], "base": base})
		"fish":
			var f: Array = Data.FISH.pick_random()
			it.merge({"name": f[0], "e": f[1], "base": f[2] * randf_range(0.8, 1.4)})
		"curio":
			var c: Array = Data.CURIOS.pick_random()
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
		else:
			out.append(_new_item(_pick_kind()))
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


func sort_into(bin: String) -> void:
	var it := _item(s.sel)
	if it.is_empty() or it.kind != "junk":
		toast.emit("Pick up a piece of junk first.")
		return
	if it.bin == bin:
		_add("bin_" + bin, 1, it.base * streak_mult() * g_mult())
		s.streak += 1
		s.best = maxi(s.best, s.streak)
	else:
		_add("bin_" + bin, 1, it.base * 0.4 * g_mult())
		s.streak = 0
		toast.emit(
			"Wrong bin! %s belongs in %s. Streak lost." % [it.name, Data.BINS[it.bin].n]
		)
		if it.bin == "hazardous":
			s.coins = maxf(0.0, s.coins - 15.0)
			toast.emit("Hazmat fine: −15")
	_drop(it)
	_commit()


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


func fish_sell(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty():
		return
	_earn(it.base * g_mult())
	_drop(it)
	_commit()


func fish_store(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty():
		return
	_add("fish_raw", 1, it.base * g_mult())
	_drop(it)
	_commit()


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
		it.kind = "empty"
		it.name = "Empty bottle"
		it.e = "🫙"
		_commit()
		return
	var unseen: Array = Data.LETTERS.filter(func(l): return not s.seen.has(l.id))
	var comm: Array = community_pool().filter(
		func(l): return not s.seen.has(l.id) and score(l) > -3
	)
	var letter: Dictionary
	if not unseen.is_empty() and (randf() < 0.5 or comm.is_empty()):
		letter = unseen.pick_random()
	elif not comm.is_empty():
		letter = comm.pick_random()
	else:
		letter = Data.LETTERS.pick_random()
	if not s.seen.has(letter.id):
		s.seen.append(letter.id)
	_drop(it)
	_commit()
	letter_opened.emit(letter)


func empty_keep(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty():
		return
	s.empties += 1
	toast.emit("Saved an empty bottle for the Desk.")
	_drop(it)
	_commit()


func empty_sell(uid: int) -> void:
	var it := _item(uid)
	if it.is_empty():
		return
	_earn(3.0 * g_mult())
	_drop(it)
	_commit()


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
	var r: Dictionary = Data.RECIPES[i]
	if not has_station(r.st) or not s.goods.has(r.inp):
		return
	var o: Dictionary = s.goods[r.inp]
	_add(r.out, o.n, o.v * r.f)
	s.goods.erase(r.inp)
	toast.emit("Processed into %s" % Data.GOODS[r.out][0])
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
	var total := 0.0
	for g in s.goods:
		total += s.goods[g].v
	_earn(total)
	s.goods = {}
	toast.emit("Sold everything for %d" % roundi(total))
	_commit()


func upgrade(k: String) -> void:
	var c := up_cost(k)
	if s.coins < c or s.up[k] >= Data.UPS[k].max:
		return
	s.coins -= c
	s.up[k] += 1
	_commit()


func build_station(k: String) -> void:
	var st: Dictionary = Data.STATIONS[k]
	if s.coins < st.cost or s.st.has(k):
		return
	s.coins -= st.cost
	s.st[k] = true
	toast.emit("Built the %s" % st.n)
	_commit()


func can_chart(i: int) -> bool:
	return not s.unlocked[i] and s.unlocked[i - 1] and s.coins >= Data.DEPTHS[i].cost


func set_depth(i: int) -> void:
	if s.unlocked[i]:
		s.depth = i
	elif can_chart(i):
		s.coins -= Data.DEPTHS[i].cost
		s.unlocked[i] = true
		s.depth = i
		toast.emit("Charted %s" % Data.DEPTHS[i].n)
	_commit()


## Prestige: reset the run, keep collections, gain permanent bonuses.
func retire() -> void:
	if s.life < prestige_goal():
		return
	var keep := {}
	for k in _persistent():
		keep[k] = s[k]
	keep.prestige = s.prestige + 1
	s = _fresh()
	s.merge(keep, true)
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
