class_name FieldProductionProvider
extends RecipeProductionProvider
## Current-run pouch -> one explicitly selected active heroine's Backpack.
var inventory: RunInventoryState
var recipient: StringName

func _init(state: RunInventoryState = null, heroine: StringName = &"") -> void:
	inventory = state
	recipient = heroine
	if state != null:
		item_catalog = state.catalog
		material_catalog = RefugeOwnershipState.MATERIAL_CATALOG

func fork() -> RecipeProductionProvider:
	if inventory == null or not inventory.backpacks_by_heroine.has(recipient):
		return null
	var copy := RunInventoryState.new()
	var ids: Array[StringName] = []
	for id: Variant in inventory.backpacks_by_heroine:
		ids.append(StringName(id))
	if not copy.initialize(item_catalog,ids).is_empty() or not copy.restore_from_snapshot(inventory.get_snapshot(),true).is_empty():
		return null
	return FieldProductionProvider.new(copy,recipient)

func material_quantity(id: StringName) -> int:
	return int(inventory.material_pouch.get(String(id),0))

func consume_material(id: StringName, quantity: int) -> String:
	return inventory.consume_material(id,quantity)

func store_output(id: StringName, quantity: int) -> String:
	return inventory.add_to_backpack(recipient,id,quantity)

func publish(staged: RecipeProductionProvider) -> String:
	if not staged is FieldProductionProvider or staged == self or staged.recipient != recipient:
		return "Invalid field production stage."
	return inventory.restore_from_snapshot(staged.inventory.get_snapshot(),true)
