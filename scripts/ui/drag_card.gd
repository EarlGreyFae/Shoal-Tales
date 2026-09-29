extends PanelContainer
## A draggable catch on the tray: junk goes to a bin, fish to the cooler.
## Clicking it and then clicking a bin works too.

const Ghost := preload("res://scripts/ui/drag_ghost.gd")

var uid := -1
var kind := "junk"
var emoji := ""
var weight := 1


func _ready() -> void:
	mouse_default_cursor_shape = CURSOR_DRAG


func _get_drag_data(_at_position: Vector2) -> Variant:
	var ghost := Ghost.new()
	ghost.setup(emoji, weight)
	set_drag_preview(ghost)
	modulate.a = 0.3
	Sfx.play("pickup", 1.2 - 0.06 * weight, -4.0)
	return {"uid": uid, "w": weight, "kind": kind}


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	# Select on release so a drag that starts from this press isn't interrupted by a redraw.
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		Sfx.play("pickup", 1.3, -8.0)
		Game.select(uid)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
