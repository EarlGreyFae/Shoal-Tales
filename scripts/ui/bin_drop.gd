extends PanelContainer
## A sorting bin (takes junk) or the cooler (takes fish), by drop or by click after picking up.

var key := ""
var accepts := "junk"
var _hover := false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.get("kind", "") == accepts
	_set_hover(ok)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_hover(false)
	_deliver(int(data.uid))


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_deliver(int(Game.s.sel))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_set_hover(false)


func _set_hover(on: bool) -> void:
	if on == _hover:
		return
	_hover = on
	self_modulate = Color(1.35, 1.25, 1.0) if on else Color.WHITE


func _deliver(uid: int) -> void:
	if accepts == "fish":
		Game.stash_fish(uid)
	else:
		Game.sort_item(uid, key)
