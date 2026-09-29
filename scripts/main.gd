extends Control
## Builds the whole UI in code and redraws it whenever Game changes.
## Everything here is placeholder presentation until real art and scenes replace it.

const C_BG := Color("0e1f2b")
const C_HEADER := Color("0a161f")
const C_PANEL := Color("16303f")
const C_PANEL2 := Color("1d3d50")
const C_LINE := Color("2a5068")
const C_INK := Color("e8f1f5")
const C_DIM := Color("8fb0bf")
const C_ACCENT := Color("f2b84b")
const C_GOOD := Color("5fd39a")
const C_BAD := Color("ef6a6a")
const C_PAPER := Color("f4ead2")
const C_PAPER_INK := Color("3b2f1c")
const RAR_COLORS := {
	"common": Color("e8f1f5"),
	"uncommon": Color("6fc3ff"),
	"rare": Color("c58bff"),
	"epic": Color("ffb347"),
}
const TABS := [
	["dredge", "⚓ Dredge"],
	["storage", "📦 Storage"],
	["craft", "🔨 Stations"],
	["desk", "🗒️ Desk"],
	["work", "🛠️ Work Table"],
	["map", "🗺️ Map"],
	["guild", "🤝 Guild"],
]
const DragCard := preload("res://scripts/ui/drag_card.gd")
const BinDrop := preload("res://scripts/ui/bin_drop.gd")
const DESK_TABS := [
	["library", "Letters"],
	["log", "Collector's Log"],
	["magic", "Magic Curios"],
	["tos", "Rules"],
]

const RULES := [
	"This game is for fun. Fun is earned; trust, once lost, takes the fun away.",
	"• Letters are shown as anonymous, but the developer can see your handle for moderation. You may sign your own letter if you choose.",
	"• Write safe, read safe. Never share personal information, contact details, or anything hateful or unsafe.",
	"• Letters can be audited. By sending one you accept that risk and responsibility.",
	"• You may have at most 3 letters awaiting review at once.",
]

var header_labels := {}
var root_box: VBoxContainer
var tab_bar: HBoxContainer
var content: VBoxContainer
var progress: ProgressBar
var progress_label: Label
var bin_nodes := {}
var pending_impact := {}
var pending_pop := false
var shown_coins := 0.0
var known_tabs := []
var toasts: VBoxContainer
var modal: Control
var confirm: ConfirmationDialog
var confirm_action := Callable()


func _ready() -> void:
	theme = _make_theme()

	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root_box = root

	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", _box(C_HEADER, C_LINE, 0, 0, 12))
	root.add_child(header_panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 28)
	header_panel.add_child(header)
	header.add_child(_label("🌊 Shoal Tales", 22, C_ACCENT))
	for k in ["coins", "streak", "mult", "title"]:
		var l := _label("", 16)
		header.add_child(l)
		header_labels[k] = l

	var tab_margin := _margin(16, 10)
	root.add_child(tab_margin)
	tab_bar = HBoxContainer.new()
	tab_margin.add_child(tab_bar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content_margin := _margin(16, 0)
	content_margin.size_flags_horizontal = SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_bottom", 32)
	scroll.add_child(content_margin)
	content = VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	content_margin.add_child(content)

	toasts = VBoxContainer.new()
	toasts.mouse_filter = MOUSE_FILTER_IGNORE
	toasts.alignment = BoxContainer.ALIGNMENT_END
	toasts.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT, PRESET_MODE_MINSIZE, 16)
	toasts.grow_horizontal = GROW_DIRECTION_BEGIN
	toasts.grow_vertical = GROW_DIRECTION_BEGIN
	add_child(toasts)

	confirm = ConfirmationDialog.new()
	confirm.dialog_autowrap = true
	confirm.confirmed.connect(func(): confirm_action.call())
	add_child(confirm)

	# Deferred so a button can safely trigger a redraw that frees it.
	Game.changed.connect(refresh, CONNECT_DEFERRED)
	Game.toast.connect(show_toast)
	Game.letter_opened.connect(show_letter)
	Game.sorted.connect(_on_sorted)
	Game.hauled.connect(_on_hauled)
	shown_coins = Game.s.coins
	refresh()


func _process(delta: float) -> void:
	if is_instance_valid(progress):
		var p: float = Game.dredge_progress()
		progress.value = p * 100.0
		if Game.dredging():
			progress_label.text = "Lowering the basket…" if p < 0.5 else "Hauling it up…"
	# Coins count up rather than jumping.
	var target: float = Game.s.coins
	shown_coins = lerpf(shown_coins, target, 1.0 - exp(-delta * 8.0))
	if absf(target - shown_coins) < 0.5:
		shown_coins = target
	header_labels.coins.text = "💰 %d" % roundi(shown_coins)


# ---------- building blocks ----------


func _box(
	bg: Color, border: Color, radius := 10, border_w := 1, pad := 12
) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(pad)
	return b


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_color("font_color", "Label", C_INK)
	t.set_stylebox("panel", "PanelContainer", _box(C_PANEL, C_LINE))
	t.set_stylebox("normal", "Button", _box(C_PANEL2, C_LINE, 8, 1, 8))
	t.set_stylebox("hover", "Button", _box(C_PANEL2, C_ACCENT, 8, 1, 8))
	t.set_stylebox("pressed", "Button", _box(C_ACCENT.darkened(0.35), C_ACCENT, 8, 1, 8))
	t.set_stylebox("disabled", "Button", _box(C_PANEL2.darkened(0.35), C_LINE.darkened(0.3), 8, 1, 8))
	var focus := _box(Color.TRANSPARENT, C_ACCENT, 8, 2, 8)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", C_INK)
	t.set_color("font_hover_color", "Button", C_INK)
	t.set_color("font_pressed_color", "Button", C_INK)
	t.set_color("font_focus_color", "Button", C_INK)
	t.set_color("font_disabled_color", "Button", C_DIM.darkened(0.3))
	t.set_stylebox("background", "ProgressBar", _box(C_HEADER, C_LINE, 7, 1, 0))
	t.set_stylebox("fill", "ProgressBar", _box(C_GOOD, C_GOOD, 7, 0, 0))
	return t


func _margin(h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	return m


func _label(text: String, font_size := 16, color := C_INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## A wrapping paragraph.
func _para(text: String, color := C_INK, font_size := 16) -> Label:
	var l := _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	return l


func _button(text: String, action: Callable, disabled := false, sound := "") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	if sound != "":
		b.pressed.connect(Sfx.play.bind(sound))
	b.pressed.connect(action)
	return b


func _row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	parent.add_child(r)
	return r


## A bordered panel added to `parent` (the page by default); returns its inner column.
func _card(title := "", parent: Control = null, bg := C_PANEL) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(bg, C_LINE))
	p.size_flags_horizontal = SIZE_EXPAND_FILL
	var host: Control = parent if parent else content
	host.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	if title != "":
		v.add_child(_label(title, 18, C_ACCENT))
	return v


func _grid(parent: Control, cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	parent.add_child(g)
	return g


# ---------- refresh ----------


func refresh() -> void:
	var s: Dictionary = Game.s
	header_labels.streak.text = "🔥 Sort streak %d" % s.streak
	header_labels.mult.text = "✨ Payout ×%.2f" % (Game.g_mult() * Game.streak_mult())
	var stars: String = "  ★%d" % s.prestige if s.prestige > 0 else ""
	header_labels.title.text = "🏅 " + Game.title() + stars

	var open_tabs := TABS.filter(func(t): return Game.tab_unlocked(t[0]))
	var first := known_tabs.is_empty()
	for t in open_tabs:
		if not known_tabs.has(t[0]):
			known_tabs.append(t[0])
			if not first:
				show_toast("New on your ship: %s" % t[1])
				Sfx.play("coin", 0.8)
	if not Game.tab_unlocked(s.tab):
		s.tab = "dredge"

	for c in tab_bar.get_children():
		tab_bar.remove_child(c)
		c.queue_free()
	for t in open_tabs:
		var b := _button(t[1], Game.set_tab.bind(t[0]))
		if s.tab == t[0]:
			b.add_theme_stylebox_override("normal", _box(C_ACCENT, C_ACCENT, 8, 1, 8))
			b.add_theme_stylebox_override("hover", _box(C_ACCENT, C_ACCENT, 8, 1, 8))
			b.add_theme_color_override("font_color", C_HEADER)
			b.add_theme_color_override("font_hover_color", C_HEADER)
		tab_bar.add_child(b)

	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	progress = null
	bin_nodes = {}
	match s.tab:
		"dredge":
			_page_dredge()
		"storage":
			_page_storage()
		"craft":
			_page_craft()
		"desk":
			_page_desk()
		"work":
			_page_work()
		"map":
			_page_map()
		"guild":
			_page_guild()


# ---------- pages ----------


func _page_dredge() -> void:
	var s: Dictionary = Game.s
	var v := _card("%s  ·  basket holds %d/%d" % [Data.DEPTHS[s.depth].n, Game.basket(), Data.MAX_BASKET])
	var busy: bool = Game.dredging()
	var has_catch: bool = not s.tray.is_empty()
	var txt: String = "Dredging…" if busy else ("Sort your catch first" if has_catch else "Drop the dredge")
	var b := _button(txt, _start_dredge, busy or has_catch)
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(300, 56)
	b.size_flags_horizontal = SIZE_SHRINK_BEGIN
	v.add_child(b)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 14
	progress.value = Game.dredge_progress() * 100.0
	v.add_child(progress)
	progress_label = _label("", 14, C_DIM)
	v.add_child(progress_label)

	if has_catch:
		var c := _card("Catch — clear it all to dredge again")
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		c.add_child(flow)
		var i := 0
		for it in s.tray:
			var card := _item_card(it)
			flow.add_child(card)
			if pending_pop:
				card.modulate.a = 0.0
				var tw := card.create_tween()
				tw.tween_interval(0.035 * i)
				tw.tween_property(card, "modulate:a", 1.0, 0.25)
			i += 1
		pending_pop = false
		c.add_child(
			_para(
				"Drag each piece of junk into its bin. There's no timer: getting it right in a row raises your payout (now ×%.2f)."
				% Game.streak_mult(),
				C_DIM
			)
		)
	else:
		progress_label.text = "The tray is empty. Drop the dredge, or sell what you've sorted in Storage."

	var bc := _card("Sorting bins")
	var grid := _grid(bc, 3)
	for k in Data.BIN_KEYS:
		grid.add_child(_bin(k))
	var rules := _active_rules()
	if not rules.is_empty():
		bc.add_child(_para("Your stations have changed where some things go:", C_ACCENT, 14))
		for line in rules:
			bc.add_child(_para(line, C_DIM, 14))
	if not pending_impact.is_empty() and bin_nodes.has(pending_impact.bin):
		# Wait a frame so the freshly built bin has its size before it squashes.
		get_tree().process_frame.connect(
			_impact.bind(bin_nodes[pending_impact.bin], pending_impact), CONNECT_ONE_SHOT
		)
	pending_impact = {}


func _bin(k: String) -> Control:
	var info: Dictionary = Data.BINS[k]
	var sorted: Dictionary = Game.s.goods.get("bin_" + k, {"n": 0})
	# A plain Control slot, so the bin inside can squash and shake without its container undoing it.
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(0, 92)
	slot.size_flags_horizontal = SIZE_EXPAND_FILL
	var bin := BinDrop.new()
	bin.key = k
	bin.set_anchors_preset(PRESET_FULL_RECT)
	bin.add_theme_stylebox_override("panel", _box(C_HEADER, C_LINE, 12, 2, 8))
	slot.add_child(bin)
	var v := VBoxContainer.new()
	v.mouse_filter = MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	bin.add_child(v)
	for l in [_label(info.e, 30), _label(info.n), _label("%d sorted" % sorted.n, 13, C_DIM)]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	bin_nodes[k] = bin
	return slot


func _active_rules() -> Array:
	var out := []
	for r in Data.SORT_RULES:
		if Game.has_station(r.st):
			out.append("• %s → %s  (%s)" % [r.item, Data.BINS[r.bin].n, Data.STATIONS[r.st].n])
	return out


func _start_dredge() -> void:
	Sfx.play("crank")
	Game.start_dredge()


func _on_hauled() -> void:
	Sfx.play("splash")
	pending_pop = true


func _on_sorted(bin: String, correct: bool, weight: int, amount: float) -> void:
	# Heavier things land lower and louder.
	Sfx.play("drop_" + bin, 1.25 - 0.1 * weight, -12.0 + 2.5 * weight)
	if not correct:
		Sfx.play("wrong", 1.0, -8.0)
	pending_impact = {"bin": bin, "correct": correct, "w": weight, "amount": amount}


## Squash the bin, shake the screen for heavy items, and float the payout up.
func _impact(bin: Control, info: Dictionary) -> void:
	if not is_instance_valid(bin):
		return
	var w: int = info.w
	bin.pivot_offset = Vector2(bin.size.x * 0.5, bin.size.y)
	var tw := bin.create_tween()
	tw.tween_property(bin, "scale", Vector2(1.0 + 0.03 * w, 1.0 - 0.045 * w), 0.05)
	tw.tween_property(bin, "scale", Vector2.ONE, 0.4 + 0.06 * w).set_trans(
		Tween.TRANS_ELASTIC
	).set_ease(Tween.EASE_OUT)
	if w >= 3:
		var amp := 2.0 * (w - 2)
		var sh := root_box.create_tween()
		for n in 4:
			var dir := 1.0 if n % 2 == 0 else -1.0
			sh.tween_property(root_box, "position", Vector2(dir * amp, amp * 0.5), 0.03)
			amp *= 0.6
		sh.tween_property(root_box, "position", Vector2.ZERO, 0.03)
	var correct: bool = info.correct
	var pop := _label(
		("+%d" % roundi(info.amount)) if correct else "wrong bin", 20, C_GOOD if correct else C_BAD
	)
	pop.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(pop)
	pop.position = bin.global_position - global_position + Vector2(bin.size.x * 0.5 - 20, 4)
	var pt := pop.create_tween()
	pt.tween_property(pop, "position:y", pop.position.y - 44, 0.9).set_ease(Tween.EASE_OUT)
	pt.parallel().tween_property(pop, "modulate:a", 0.0, 0.9).set_delay(0.3)
	pt.tween_callback(pop.queue_free)


func _item_card(it: Dictionary) -> Control:
	var uid: int = it.uid
	var selected: bool = Game.s.sel == uid
	var p: PanelContainer
	if it.kind == "junk":
		var dc := DragCard.new()
		dc.uid = uid
		dc.emoji = it.e
		dc.weight = int(it.get("w", 2))
		p = dc
	else:
		p = PanelContainer.new()
	p.add_theme_stylebox_override(
		"panel", _box(C_PANEL2, C_ACCENT if selected else C_LINE, 10, 2, 10)
	)
	p.custom_minimum_size = Vector2(150, 0)
	var v := VBoxContainer.new()
	v.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(v)

	var sub := ""
	var sub_color := C_DIM
	var actions := []  # [text, Callable, sound]
	match it.kind:
		"junk":
			sub = "in hand — pick a bin" if selected else "drag to a bin"
		"fish":
			actions.append(["Store", Game.fish_store.bind(uid), "pickup"])
			actions.append(["Sell now", Game.fish_sell.bind(uid), "coin"])
		"curio":
			if not it.done:
				sub = "dirty (%d/%d)" % [it.clicks, Game.clean_clicks()]
				actions.append(["Clean", Game.clean.bind(uid), "scrub"])
			else:
				sub = "%s · %dc" % [it.rar, roundi(it.value * Game.g_mult())]
				sub_color = RAR_COLORS[it.rar]
				actions.append(["To Log", Game.curio_keep.bind(uid), "pickup"])
				actions.append(["Sell", Game.curio_sell.bind(uid), "coin"])
		"crate":
			actions.append(["Open", Game.open_crate.bind(uid), "drop_wood"])
		"bottle":
			actions.append(["Open", Game.open_bottle.bind(uid), "pickup"])
		"empty":
			actions.append(["Keep", Game.empty_keep.bind(uid), "pickup"])
			actions.append(["Recycle", Game.empty_sell.bind(uid), "coin"])
		"animal":
			sub = "tangled in the net"
			actions.append(["Set free", Game.free_animal.bind(uid), "splash"])

	for l in [_label(it.e, 38), _label(it.name), _label(sub, 14, sub_color)]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var r := _row(v)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	for a in actions:
		r.add_child(_button(a[0], a[1], false, a[2]))
	return p


func _goods_name(g: String) -> String:
	if g.begins_with("bin_"):
		var bin: Dictionary = Data.BINS[g.substr(4)]
		return "%s %s bin" % [bin.e, bin.n]
	return "%s %s" % [Data.GOODS[g][1], Data.GOODS[g][0]]


func _page_storage() -> void:
	var s: Dictionary = Game.s
	var v := _card("Ship storage")
	if s.goods.is_empty():
		v.add_child(_para("Nothing stored. Sort some junk first.", C_DIM))
	else:
		for g in s.goods:
			var o: Dictionary = s.goods[g]
			var r := _row(v)
			var name_l := _label("%s ×%d" % [_goods_name(g), o.n])
			name_l.size_flags_horizontal = SIZE_EXPAND_FILL
			r.add_child(name_l)
			r.add_child(_label("%dc" % roundi(o.v)))
			r.add_child(_button("Sell", Game.sell.bind(g)))
		v.add_child(HSeparator.new())
		var b := _button("Sell everything", Game.sell_all)
		b.size_flags_horizontal = SIZE_SHRINK_BEGIN
		v.add_child(b)
	_card().add_child(
		_para(
			"Tip: sorted bins pay more when fed through a station first. Build stations to go from selling everything to breaking it all down.",
			C_DIM
		)
	)


func _page_craft() -> void:
	var s: Dictionary = Game.s
	for i in Data.RECIPES.size():
		var r: Dictionary = Data.RECIPES[i]
		if not Game.has_station(r.st):
			continue
		var v := _card("%s %s" % [r.e, r.n])
		v.add_child(_para(r.d))
		var inp: String = r.inp
		var inp_name: String = (
			Data.BINS[inp.substr(4)].n + " bin" if inp.begins_with("bin_") else Data.GOODS[inp][0]
		)
		var have: bool = s.goods.has(inp)
		var amount: String = "%d units" % s.goods[inp].n if have else "none"
		v.add_child(_para("Input: %s — %s  ·  output value ×%.1f" % [inp_name, amount, r.f], C_DIM))
		var pb := _button("Process all", Game.process_recipe.bind(i), not have, "scrub")
		pb.size_flags_horizontal = SIZE_SHRINK_BEGIN
		v.add_child(pb)

	if not Game.stations_open():
		_card("🔧 Room for more").add_child(
			_para(
				"There's space on deck for more workstations once your basket holds %d items (now %d)."
				% [Data.STATIONS_UNLOCK_BASKET, Game.basket()],
				C_DIM
			)
		)
		return
	var k: String = Game.next_station()
	if k == "":
		return
	var st: Dictionary = Data.STATIONS[k]
	var lv := _card("%s %s  (not installed)" % [st.e, st.n])
	lv.add_child(_para(st.d))
	for r in Data.SORT_RULES:
		if r.st == k:
			lv.add_child(_para("Opens a new use: %s → %s" % [r.item, Data.BINS[r.bin].n], C_DIM, 14))
	var b := _button("Install — %dc" % st.cost, Game.build_station.bind(k), s.coins < st.cost, "drop_metal")
	b.size_flags_horizontal = SIZE_SHRINK_BEGIN
	lv.add_child(b)


func _page_desk() -> void:
	var s: Dictionary = Game.s
	var tabs := _row(_card())
	for t in DESK_TABS:
		var b := _button(t[1], Game.set_sub.bind(t[0]))
		if s.sub == t[0]:
			b.add_theme_stylebox_override("normal", _box(C_PANEL2, C_ACCENT, 8, 2, 8))
		tabs.add_child(b)
	match s.sub:
		"library":
			_desk_library()
		"log":
			_desk_log()
		"magic":
			_desk_magic()
		"tos":
			_desk_rules()


func _desk_library() -> void:
	var s: Dictionary = Game.s
	var v := _card("Letter library (%d found)" % s.seen.size())
	var shown := 0
	for l in Data.LETTERS + Data.SEED_COMMUNITY + s.outbox:
		var mine: bool = l.get("mine", false)
		if not (mine or s.seen.has(l.id)):
			continue
		shown += 1
		var dev: bool = l.get("dev", false)
		var head: String = ("🖋 Lore Letter · " if dev else "✉️ ") + str(l.from)
		if mine:
			head += "  (approved)" if l.approved else "  (awaiting review)"
		var lv := _card(head, v, C_PANEL2)
		lv.add_child(_para(l.t))
		if not dev and not mine:
			var r := _row(lv)
			r.add_child(_button("👍", Game.vote.bind(l.id, 1)))
			r.add_child(_button("👎", Game.vote.bind(l.id, -1)))
			var sc: int = Game.score(l)
			r.add_child(_label("score %d%s" % [sc, "  · hidden from bottles" if sc <= -3 else ""], 14, C_DIM))
	if shown == 0:
		v.add_child(_para("No letters yet. Dredge up some bottles.", C_DIM))
	var r := _row(v)
	r.add_child(_label("Empty bottles saved: %d" % s.empties, 16, C_DIM))
	r.add_child(_button("Write a letter", _start_writing))


func _desk_log() -> void:
	var v := _card("Collector's Log")
	var g := _grid(v, 4)
	for c in Data.CURIOS:
		var r: String = Game.s.log.get(c[0], "")
		var cv := _card("", g, C_PANEL2)
		cv.custom_minimum_size.x = 200
		cv.add_child(_label(("%s %s" % [c[1], c[0]]) if r != "" else "❔ ???"))
		cv.add_child(_label(r if r != "" else "not found", 14, RAR_COLORS.get(r, C_DIM)))


func _desk_magic() -> void:
	var v := _card("Magic Curios %d/%d" % [Game.s.magic.size(), Data.MAGIC.size()])
	var g := _grid(v, 3)
	for m in Data.MAGIC:
		var cv := _card("", g, C_PANEL2)
		cv.custom_minimum_size.x = 260
		if Game.has_magic(m.id):
			cv.add_child(_label("%s %s" % [m.e, m.n]))
			cv.add_child(_label(m.d, 14, C_GOOD))
		else:
			cv.add_child(_label("❔ ???", 16, C_DIM))
	v.add_child(_para("Collect the full set for +25% payout permanently.", C_DIM))



func _desk_rules() -> void:
	var v := _card("Rules of the shore")
	for line in RULES:
		v.add_child(_para(line))


func _page_work() -> void:
	var s: Dictionary = Game.s
	for k in Data.UP_KEYS:
		if not Game.up_visible(k):
			continue
		var u: Dictionary = Data.UPS[k]
		var cost: int = Game.up_cost(k)
		var maxed: bool = s.up[k] >= u.max
		var title: String = "%s   lv %d/%d" % [u.n, s.up[k], u.max]
		if k == "basket":
			title = "%s   holds %d/%d" % [u.n, Game.basket(), Data.MAX_BASKET]
		var v := _card(title)
		v.add_child(_para(u.d, C_DIM))
		var b := _button(
			"Maxed" if maxed else "Upgrade — %dc" % cost,
			Game.upgrade.bind(k),
			maxed or s.coins < cost,
			"drop_metal"
		)
		b.size_flags_horizontal = SIZE_SHRINK_BEGIN
		v.add_child(b)

	# Prestige only shows up once every station is installed.
	if Game.next_station() != "":
		return
	var goal: int = Game.prestige_goal()
	var v := _card("🌅 Retire the vessel (prestige %d)" % s.prestige)
	v.add_child(
		_para(
			(
				"Earn %d lifetime coins this run (%d so far). Resets coins, upgrades and stations; keeps your log, letters and magic curios. Each retirement: +10%% payout, −3%% dredge time, and a new title."
				% [goal, roundi(s.life)]
			)
		)
	)
	var b := _button("Begin a new tide", _confirm_retire, s.life < goal)
	b.size_flags_horizontal = SIZE_SHRINK_BEGIN
	v.add_child(b)


func _page_map() -> void:
	var s: Dictionary = Game.s
	for i in Data.DEPTHS.size():
		var d: Dictionary = Data.DEPTHS[i]
		var here: bool = s.depth == i
		var v := _card(d.n + ("  (current)" if here else ""))
		v.add_child(_para("Payout ×%.1f" % d.m, C_DIM))
		var unlocked: bool = s.unlocked[i]
		var txt: String = "Sail here" if unlocked else "Chart it — %dc" % d.cost
		var b := _button(txt, Game.set_depth.bind(i), here or not (unlocked or Game.can_chart(i)))
		b.size_flags_horizontal = SIZE_SHRINK_BEGIN
		v.add_child(b)


func _page_guild() -> void:
	var v := _card("🤝 Guild Manifest")
	v.add_child(
		_para(
			"Guilds, parties, shared quests, guild chat and the player-to-player bottle network need an online server with accounts and moderation. That comes later."
		)
	)
	v.add_child(
		_para(
			"Planned: guilds with turn-in quests, parties (timed bonus when online together), guild- and party-only collectibles. Letters currently use a local stand-in pool and a local review queue.",
			C_DIM
		)
	)


# ---------- overlays ----------


func show_toast(msg: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(C_HEADER, C_ACCENT, 8, 1, 10))
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var l := _para(msg)
	l.custom_minimum_size.x = 320
	p.add_child(l)
	toasts.add_child(p)
	move_child(toasts, -1)
	var tw := p.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 1.0)
	tw.tween_callback(p.queue_free)


func _ask(text: String, action: Callable) -> void:
	confirm.dialog_text = text
	confirm_action = action
	confirm.popup_centered(Vector2i(520, 200))


func _confirm_retire() -> void:
	_ask(
		"Retire this vessel and start again? You keep your log, letters and magic curios, and gain permanent bonuses.",
		Game.retire
	)


## Opens a parchment panel over the game; returns its inner column.
func _open_modal() -> VBoxContainer:
	_close_modal()
	modal = Control.new()
	modal.set_anchors_preset(PRESET_FULL_RECT)
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	modal.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(C_PAPER, Color("b89b62"), 10, 2, 20))
	p.custom_minimum_size.x = 560
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	move_child(toasts, -1)
	return v


func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null


func show_letter(letter: Dictionary) -> void:
	var v := _open_modal()
	var dev: bool = letter.get("dev", false)
	var head: String = ("🖋 Lore Letter from " if dev else "✉️ Letter from ") + str(letter.from)
	v.add_child(_label(head, 18, C_PAPER_INK))
	v.add_child(_para(letter.t, C_PAPER_INK, 18))
	var b := _button("Fold it away", _close_modal)
	b.size_flags_horizontal = SIZE_SHRINK_BEGIN
	v.add_child(b)
	b.grab_focus()


func _start_writing() -> void:
	if Game.s.tos:
		_show_writer()
		return
	_ask(
		"Before writing: letters are shown to strangers and can be audited (the developer can see your handle). Never share personal information. Do you accept the Rules of the shore (Desk → Rules) and that risk?",
		_accept_and_write
	)


func _accept_and_write() -> void:
	Game.accept_tos()
	_show_writer()


func _show_writer() -> void:
	var v := _open_modal()
	v.add_child(_label("Write a letter", 18, C_PAPER_INK))
	v.add_child(
		_para(
			"⚠️ Letters are shown to strangers and can be audited by the developer, who can see your handle. Never include personal info.",
			C_PAPER_INK,
			14
		)
	)
	var te := TextEdit.new()
	te.placeholder_text = "Dear stranger…"
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size.y = 150
	v.add_child(te)
	var counter := _label("0/%d" % Game.LETTER_MAX_CHARS, 14, C_PAPER_INK)
	te.text_changed.connect(_update_counter.bind(te, counter))
	v.add_child(counter)
	var sign_box := CheckBox.new()
	sign_box.text = "Sign with my name instead of anonymous"
	sign_box.add_theme_color_override("font_color", C_PAPER_INK)
	sign_box.add_theme_color_override("font_hover_color", C_PAPER_INK)
	sign_box.add_theme_color_override("font_pressed_color", C_PAPER_INK)
	v.add_child(sign_box)
	var r := _row(v)
	r.add_child(_button("Send bottle", _send_letter.bind(te, sign_box)))
	r.add_child(_button("Cancel", _close_modal))
	te.grab_focus()


func _update_counter(te: TextEdit, counter: Label) -> void:
	counter.text = "%d/%d" % [te.text.length(), Game.LETTER_MAX_CHARS]


func _send_letter(te: TextEdit, sign_box: CheckBox) -> void:
	if Game.send_letter(te.text, sign_box.button_pressed):
		_close_modal()
