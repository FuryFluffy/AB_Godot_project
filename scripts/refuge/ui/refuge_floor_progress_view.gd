class_name RefugeFloorProgressView
extends Control
## Persistent access history only. This diagram exposes no generated room routes.
var accessed: Array[StringName] = []

func _ready() -> void:
	custom_minimum_size = Vector2(280, 460)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func present(ids: Array[StringName]) -> void:
	accessed = ids.duplicate()
	queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var deepest: int = 0
	for number: int in range(1, 11):
		if accessed.has(StringName("layer_%d" % number)):
			deepest = maxi(deepest, number)
	var step: float = (size.y - 32) / 10.0
	for number: int in range(1, 11):
		var reached: bool = accessed.has(StringName("layer_%d" % number))
		var y: float = size.y - number * step
		var width: float = 90 + number * 4
		var rect := Rect2(12 + (140 - width) / 2, y, width, step - 3)
		var color := Color("bda36b") if reached else Color("55505c")
		draw_rect(rect, Color("312739") if reached else Color("15131a"))
		draw_rect(rect, color, false, 1.5)
		for window: int in range(3):
			draw_rect(Rect2(rect.position + Vector2(15 + window * (width - 40) / 3, 10), Vector2(8, 12)), color)
		draw_string(font, Vector2(164, y + 25), "Floor %d%s" % [number, "  ◀" if number == deepest else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, color)
