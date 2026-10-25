class_name RefugeProductionProvider
extends RecipeProductionProvider
## Banked Materials -> Stash only. Never bind this provider to field services.
var ownership: RefugeOwnershipState

func _init(state: RefugeOwnershipState = null) -> void:
	ownership = state
	if state != null:
		item_catalog = state.item_catalog
		material_catalog = state.MATERIAL_CATALOG

func fork() -> RecipeProductionProvider:
	if ownership == null or ownership.equipment_loadouts_by_heroine.size() != ownership.known_heroine_ids.size():
		return null
	var copy := RefugeOwnershipState.new()
	if not copy.restore_from_snapshot(ownership.to_snapshot(), item_catalog, ownership.battler_catalog, ownership.known_heroine_ids).is_empty():
		return null
	return RefugeProductionProvider.new(copy)

func material_quantity(id: StringName) -> int:
	return ownership.get_banked_material_quantity(id)

func consume_material(id: StringName, quantity: int) -> String:
	if quantity <= 0 or material_quantity(id) < quantity:
		return "Insufficient banked Materials."
	var remaining: int = material_quantity(id) - quantity
	if remaining == 0:
		ownership.banked_materials.erase(String(id))
	else:
		ownership.banked_materials[String(id)] = remaining
	return ""

func store_output(id: StringName, quantity: int) -> String:
	return ownership.add_stash_item(id, quantity)

func publish(staged: RecipeProductionProvider) -> String:
	if not staged is RefugeProductionProvider or staged == self:
		return "Invalid Refuge production stage."
	var next: RefugeOwnershipState = (staged as RefugeProductionProvider).ownership
	var error: String = RefugeOwnershipState.validate_snapshot(next.to_snapshot(), item_catalog, ownership.battler_catalog, ownership.known_heroine_ids)
	if not error.is_empty():
		return error
	ownership._copy_from(next)
	return ""
