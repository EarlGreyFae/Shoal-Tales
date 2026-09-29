extends PanelContainer
## A sorting bin. Takes dropped junk, or a click after a piece of junk was picked up.

var key := ""
var _hover := false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("uid")
	_set_hover(ok)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_hover(false)
	Game.sort_item(int(data.uid), key)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		Game.sort_into(key)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_set_hover(false)


func _set_hover(on: bool) -> void:
	if on == _hover:
		return
	_hover = on
	self_modulate = Color(1.35, 1.25, 1.0) if on else Color.WHITE
