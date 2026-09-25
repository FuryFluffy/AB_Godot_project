class_name LayerRoomCatalogDefinition
extends Resource


@export var rooms: Array[LayerRoomDefinition] = []


func get_room(room_id: StringName) -> LayerRoomDefinition:
	for room: LayerRoomDefinition in rooms:
		if room != null and room.room_id == room_id:
			return room
	return null


func get_rooms_for_layer(layer_number: int) -> Array[LayerRoomDefinition]:
	var matches: Array[LayerRoomDefinition] = []
	for room: LayerRoomDefinition in rooms:
		if room != null and room.layer_number == layer_number:
			matches.append(room)
	matches.sort_custom(
		func(first: LayerRoomDefinition, second: LayerRoomDefinition) -> bool:
			return first.canonical_order < second.canonical_order
	)
	return matches


func get_rooms_with_pending_art() -> Array[LayerRoomDefinition]:
	var matches: Array[LayerRoomDefinition] = []
	for room: LayerRoomDefinition in rooms:
		if room != null and room.has_pending_art():
			matches.append(room)
	return matches


func validate_catalog() -> String:
	var seen_ids: Dictionary = {}
	var seen_layer_orders: Dictionary = {}
	for room: LayerRoomDefinition in rooms:
		if room == null:
			return "The Layer room catalog contains an empty entry."
		var room_error: String = room.validate_definition()
		if not room_error.is_empty():
			return room_error
		if seen_ids.has(room.room_id):
			return "Duplicate Layer room_id: %s." % room.room_id
		seen_ids[room.room_id] = true
		var layer_order_key: String = "%d:%d" % [
			room.layer_number,
			room.canonical_order,
		]
		if seen_layer_orders.has(layer_order_key):
			return "Duplicate canonical room order: %s." % layer_order_key
		seen_layer_orders[layer_order_key] = true
	return ""
