class_name EventRoomCatalogDefinition
extends Resource

@export var rooms: Array[EventRoomDefinition] = []

func get_room(room_id: StringName) -> EventRoomDefinition:
	for room: EventRoomDefinition in rooms:
		if room != null and room.room_id == room_id:
			return room
	return null
	
