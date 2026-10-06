class_name CombatActionEffect
extends Node2D

## Procedural pilot VFX, owned by the encounter and using no random gameplay state.
var caster_floor: Vector2
var target_floor: Vector2
var start: Vector2
var destination: Vector2
var caster_scale: float = 1.0
var target_scale: float = 1.0
var spell: bool = false
var damaged: bool = false
var age: float = 0.0
var lifetime: float = 0.9


func _ready() -> void:
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend
	z_index = 80


func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= lifetime:
		queue_free()


func _draw() -> void:
	var gold := Color(1.0, 0.72, 0.24)
	var impact_color := gold if damaged else Color(0.48, 0.78, 1.0)
	if spell:
		var ring_alpha: float = sin(clampf(age / lifetime, 0.0, 1.0) * PI)
		draw_set_transform(caster_floor, 0.0, Vector2(1.0, 0.26))
		for radius: float in [88.0, 106.0]:
			draw_arc(Vector2.ZERO, radius * caster_scale, 0.0, TAU, 80,
				Color(gold, ring_alpha * 0.75), 2.5, true)
		for index: int in range(12):
			var angle: float = TAU * float(index) / 12.0 + age * 0.35
			var inner: Vector2 = Vector2.from_angle(angle) * 91.0 * caster_scale
			var outer: Vector2 = Vector2.from_angle(angle) * 103.0 * caster_scale
			draw_line(inner, outer, Color(gold, ring_alpha), 2.0, true)
		draw_set_transform(Vector2.ZERO)
		_draw_floor_glow(caster_floor, Vector2(135.0, 30.0) * caster_scale,
			Color(gold, ring_alpha * 0.12))
		var flight: float = clampf((age - 0.15) / 0.34, 0.0, 1.0)
		if age > 0.15 and flight < 1.0:
			var head: Vector2 = _flight_point(flight)
			var direction: Vector2 = (destination - start).normalized()
			var normal: Vector2 = direction.orthogonal()
			for index: int in range(18):
				var t: float = maxf(0.0, flight - float(index) * 0.018)
				var next: float = maxf(0.0, t - 0.018)
				draw_line(_flight_point(t), _flight_point(next),
					Color(gold, 1.0 - float(index) / 18.0), 4.0, true)
			_draw_glow(head, 28.0, Color(gold, 0.35))
			draw_line(head - direction * 34.0, head, Color(1.0, 0.97, 0.82), 3.0, true)
			draw_colored_polygon(PackedVector2Array([
				head + direction * 9.0,
				head - direction * 10.0 + normal * 6.0,
				head - direction * 10.0 - normal * 6.0]), Color(1.0, 0.97, 0.82))
	else:
		var swing: float = clampf((age - 0.10) / 0.22, 0.0, 1.0)
		if age > 0.10 and age < 0.45:
			var fade: float = 1.0 - clampf((age - 0.25) / 0.20, 0.0, 1.0)
			draw_set_transform(destination, -0.5, Vector2(1.0, 0.38))
			draw_arc(Vector2.ZERO, 105.0, -2.4, -2.4 + 3.6 * swing,
				40, Color(1.0, 0.9, 0.65, fade), 5.0, true)
			draw_set_transform(Vector2.ZERO)
	var impact_time: float = 0.49 if spell else 0.25
	if age >= impact_time:
		var progress: float = clampf((age - impact_time) / 0.35, 0.0, 1.0)
		var fade: float = 1.0 - progress
		_draw_glow(destination, 62.0 + progress * 25.0, Color(impact_color, fade * 0.13))
		for index: int in range(10):
			var direction: Vector2 = Vector2.from_angle(float(index) * TAU / 10.0 + 0.3)
			var point: Vector2 = destination + direction * (12.0 + progress * 75.0)
			draw_line(point, point + direction * 13.0 * fade,
				Color(impact_color, fade), 2.0, true)
		if spell:
			draw_arc(destination, 12.0 + progress * 66.0, 0.0, TAU, 50,
				Color(impact_color, fade * 0.7), 2.0, true)
			_draw_floor_glow(target_floor,
				Vector2(150.0, 34.0) * target_scale, Color(gold, fade * 0.22))


func _flight_point(t: float) -> Vector2:
	return start.lerp(destination, t) + Vector2(0.0, -sin(t * PI) * 45.0)


func _draw_glow(point: Vector2, radius: float, color: Color) -> void:
	for index: int in range(8, 0, -1):
		draw_circle(point, radius * float(index) / 8.0, Color(color, color.a / 8.0))


func _draw_floor_glow(point: Vector2, size: Vector2, color: Color) -> void:
	draw_set_transform(point, 0.0, size)
	_draw_glow(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO)
