extends Control
## The item under the cursor while it's being dragged.
## It swings with your movement like something held by one corner; heavier items swing slower.

var _weight := 1
var _last := Vector2.ZERO
var _sway := 0.0


func setup(emoji: String, weight: int) -> void:
	_weight = weight
	mouse_filter = MOUSE_FILTER_IGNORE
	var font_size := 46 + 6 * weight
	var shadow := _make_label(emoji, font_size)
	shadow.modulate = Color(0, 0, 0, 0.35)
	shadow.position += Vector2(6, 10)
	add_child(shadow)
	add_child(_make_label(emoji, font_size))


func _make_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	# Centre the item on the cursor.
	l.position = -Vector2(font_size, font_size) * 0.6
	return l


func _ready() -> void:
	_last = get_global_mouse_position()


func _process(delta: float) -> void:
	var p := get_global_mouse_position()
	var vx := (p.x - _last.x) / maxf(delta, 0.001)
	_last = p
	var target := clampf(-vx * 0.0005, -0.45, 0.45)
	var follow := 16.0 - 2.4 * _weight
	_sway = lerpf(_sway, target, 1.0 - exp(-delta * follow))
	rotation = _sway
