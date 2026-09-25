@tool
class_name AuthoredSpawnSlot
extends Marker2D


const HEROINE_COLOR := Color(0.25, 0.72, 1.0, 0.94)
const ENEMY_COLOR := Color(1.0, 0.31, 0.24, 0.94)
const NEUTRAL_COLOR := Color(0.92, 0.84, 0.52, 0.94)


@export_group("Spawn Identity")
@export var slot_id: StringName
@export var display_name: String = "Unnamed Spawn Slot"

@export_group("Compatibility")
@export var faction: BattlerDefinition.Faction = (
	BattlerDefinition.Faction.NEUTRAL
)
@export var role_tags: Array[StringName] = []

@export_group("Snapping")
@export_range(8.0, 160.0, 1.0) var position_snap_radius: float = 48.0


func _ready() -> void:
	visible = Engine.is_editor_hint()
	z_index = -20
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func make_definition(
	battlefield: AuthoredBattlefield
) -> SpawnSlotDefinition:
	var result := SpawnSlotDefinition.new()
	result.slot_id = slot_id
	result.display_name = display_name
	result.faction = faction
	result.role_tags = role_tags.duplicate()
	var resolved: Dictionary = battlefield.resolve_spawn_marker(self)
	result.anchor_id = StringName(resolved.get("anchor_id", &""))
	result.position_index = int(resolved.get("position_index", -1))
	return result


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var marker_color := NEUTRAL_COLOR
	if faction == BattlerDefinition.Faction.HEROINE:
		marker_color = HEROINE_COLOR
	elif faction == BattlerDefinition.Faction.ENEMY:
		marker_color = ENEMY_COLOR
	var diamond := PackedVector2Array([
		Vector2(0.0, -22.0),
		Vector2(22.0, 0.0),
		Vector2(0.0, 22.0),
		Vector2(-22.0, 0.0),
	])
	draw_colored_polygon(diamond, Color(marker_color, 0.34))
	draw_polyline(
		PackedVector2Array([
			diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]
		]),
		marker_color,
		3.0,
		true
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-90.0, -30.0),
		String(slot_id),
		HORIZONTAL_ALIGNMENT_CENTER,
		180.0,
		13,
		marker_color
	)
