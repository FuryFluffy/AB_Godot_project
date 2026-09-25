class_name BattleMarkerFactory
extends Node


@export var marker_scene: PackedScene
@export var view_catalog: BattlerViewCatalogDefinition
@export var visual_profile_catalog: BattlerVisualProfileCatalog


func create_markers(
	parent: Node2D,
	battler_ids: Array[StringName]
) -> Array[BattleMarker]:
	var markers: Array[BattleMarker] = []
	if parent == null or marker_scene == null:
		return markers
	for battler_id: StringName in battler_ids:
		var marker: BattleMarker = marker_scene.instantiate() as BattleMarker
		if marker == null:
			continue
		marker.name = _marker_name(battler_id)
		marker.configure_view(
			battler_id,
			view_catalog.get_view(battler_id) if view_catalog != null else null
		)
		marker.configure_visual_profile(visual_profile_catalog)
		parent.add_child(marker)
		markers.append(marker)
	return markers


func _marker_name(battler_id: StringName) -> String:
	var result: String = ""
	for part: String in String(battler_id).split("_"):
		result += part.capitalize().replace(" ", "")
	return "%sMarker" % result
