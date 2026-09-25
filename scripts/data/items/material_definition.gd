class_name MaterialDefinition
extends ItemDefinition


enum Tier {
	COMMON,
	UNCOMMON,
}


@export_group("Material")
@export var material_tier: Tier = Tier.COMMON
@export var purpose_ids: Array[StringName] = []


func validate_definition() -> String:
	var definition_error: String = super.validate_definition()
	if not definition_error.is_empty():
		return definition_error
	if material_tier not in [Tier.COMMON, Tier.UNCOMMON]:
		return "Material '%s' has an invalid tier." % item_id
	if content_category != ContentCategory.MATERIAL:
		return "Material '%s' must use the Material content category." % item_id
	if item_type != ItemType.PASSIVE:
		return "Material '%s' must be passive inventory data." % item_id
	if consumes_on_use or combat_usable or action_cost != 0:
		return "Material '%s' cannot be used from carried-item interfaces." % item_id
	if performs_attack or not effects.is_empty():
		return "Material '%s' cannot declare direct gameplay effects." % item_id
	if purpose_ids.is_empty():
		return "Material '%s' requires at least one declared purpose." % item_id
	var seen_purposes: Dictionary = {}
	for purpose_id: StringName in purpose_ids:
		if purpose_id == &"":
			return "Material '%s' contains an empty purpose ID." % item_id
		if seen_purposes.has(purpose_id):
			return "Material '%s' repeats purpose '%s'." % [item_id, purpose_id]
		seen_purposes[purpose_id] = true
	return ""
