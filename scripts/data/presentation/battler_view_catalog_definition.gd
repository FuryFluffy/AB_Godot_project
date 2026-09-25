class_name BattlerViewCatalogDefinition
extends Resource


@export var views: Array[BattlerViewDefinition] = []


func get_view(battler_id: StringName) -> BattlerViewDefinition:
	for view: BattlerViewDefinition in views:
		if view != null and view.battler_id == battler_id:
			return view
	return null
