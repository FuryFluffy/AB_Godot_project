class_name LayerRoomDefinition
extends Resource


@export_group("Identity")
@export var room_id: StringName = &""
@export var display_name: String = ""
@export_range(1, 10, 1) var layer_number: int = 1
@export_range(1, 99, 1) var canonical_order: int = 1

@export_group("Authoring Reference")
@export_multiline var authoring_summary: String = ""
@export var strong_battle_candidate: bool = false
@export var authoring_tags: Array[StringName] = []

@export_group("Visuals")
@export var visual_variants: Array[LayerRoomVisualDefinition] = []

@export_group("Existing Authored Content")
@export var exploration_definition: EventRoomDefinition
@export var production_battlefields: Array[PackedScene] = []
@export var battlefield_authoring_templates: Array[PackedScene] = []


func get_visual(variant_id: StringName) -> LayerRoomVisualDefinition:
	for visual: LayerRoomVisualDefinition in visual_variants:
		if visual != null and visual.variant_id == variant_id:
			return visual
	return null


func has_pending_art() -> bool:
	for visual: LayerRoomVisualDefinition in visual_variants:
		if visual != null and visual.art_pending:
			return true
	return false


func validate_definition() -> String:
	if room_id == &"":
		return "A Layer room requires a room_id."
	if display_name.is_empty():
		return "Room '%s' requires a display name." % room_id
	if layer_number < 1 or layer_number > 10:
		return "Room '%s' has invalid Layer %d." % [room_id, layer_number]
	if canonical_order <= 0:
		return "Room '%s' has invalid canonical order." % room_id
	if visual_variants.is_empty():
		return "Room '%s' requires at least one visual variant." % room_id
	if (
		exploration_definition != null
		and exploration_definition.room_id != room_id
	):
		return (
			"Room '%s' links exploration definition '%s'."
			% [room_id, exploration_definition.room_id]
		)

	var seen_variant_ids: Dictionary = {}
	for visual: LayerRoomVisualDefinition in visual_variants:
		if visual == null:
			return "Room '%s' contains an empty visual variant." % room_id
		var visual_error: String = visual.validate_definition(room_id)
		if not visual_error.is_empty():
			return visual_error
		if seen_variant_ids.has(visual.variant_id):
			return "Room '%s' duplicates visual variant '%s'." % [
				room_id,
				visual.variant_id,
			]
		seen_variant_ids[visual.variant_id] = true

	for battlefield: PackedScene in production_battlefields:
		if battlefield == null:
			return "Room '%s' contains an empty production battlefield." % room_id
	for authoring_template: PackedScene in battlefield_authoring_templates:
		if authoring_template == null:
			return "Room '%s' contains an empty authoring template." % room_id
	return ""
