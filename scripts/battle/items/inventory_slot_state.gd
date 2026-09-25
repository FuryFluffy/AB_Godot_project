class_name InventorySlotState
extends RefCounted


var item: ItemDefinition
var quantity: int = 0


func _init(
	new_item: ItemDefinition = null,
	new_quantity: int = 0
) -> void:
	item = new_item
	quantity = maxi(new_quantity, 0)


func is_empty() -> bool:
	return item == null or quantity <= 0


func clear() -> void:
	item = null
	quantity = 0

