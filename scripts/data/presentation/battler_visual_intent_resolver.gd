class_name BattlerVisualIntentResolver
extends RefCounted


const EVENT_POSE_MAP: Dictionary = {
	&"idle": &"idle",
	&"turn_started": &"idle",
	&"move_started": &"move",
	&"attack_started": &"attack",
	&"cast_started": &"cast",
	&"defend_started": &"defend",
	&"block_started": &"block",
	&"damage_received": &"hurt",
	&"defeated": &"defeated",
	&"grapple_started": &"defend",
	&"grapple_progressed": &"hurt",
	&"grapple_subject": &"hurt",
	&"grapple_holder": &"attack",
}

const EVENT_HOLD_SECONDS: Dictionary = {
	&"idle": 0.0,
	&"turn_started": 0.0,
	&"move_started": 0.0,
	&"attack_started": 0.7,
	&"cast_started": 0.7,
	&"defend_started": 0.55,
	&"block_started": 0.55,
	&"damage_received": 0.55,
	&"defeated": 0.0,
	&"grapple_started": 0.65,
	&"grapple_progressed": 0.6,
	&"grapple_subject": 0.0,
	&"grapple_holder": 0.0,
}

const FACING_DEPTH_TOLERANCE: float = 12.0


static func pose_key_for_event(
	event_key: StringName,
	is_defeated: bool
) -> StringName:
	if is_defeated:
		return &"defeated"
	return StringName(EVENT_POSE_MAP.get(event_key, &"idle"))


static func hold_seconds_for_event(event_key: StringName) -> float:
	return float(EVENT_HOLD_SECONDS.get(event_key, 0.55))


static func orientation_toward_opponent(
	actor_position: Vector2,
	opponent_position: Vector2,
	current_orientation: StringName,
	fallback_orientation: StringName
) -> StringName:
	var depth_delta: float = opponent_position.y - actor_position.y
	if absf(depth_delta) <= FACING_DEPTH_TOLERANCE:
		if current_orientation in [&"front", &"back"]:
			return current_orientation
		return fallback_orientation
	# Smaller screen-space Y is deeper into these authored 2D rooms. A battler
	# looking toward a deeper opponent therefore shows their back to the camera.
	return &"back" if depth_delta < 0.0 else &"front"


static func resolve_intent(
	catalog: BattlerVisualProfileCatalog,
	battlefield: BattlefieldDefinition,
	battler_id: StringName,
	render_instance_id: StringName,
	event_key: StringName,
	is_defeated: bool,
	placement: BattlerPlacementDefinition,
	orientation_override: StringName = &""
) -> Dictionary:
	if catalog == null:
		return {"error": "Battler visual intent requires a profile catalog."}
	if battlefield == null or placement == null:
		return {"error": "Battler visual intent requires battlefield placement."}
	if placement.battler_id != battler_id:
		return {"error": "Battler visual placement uses the wrong battler ID."}
	var anchor: AnchorDefinition = battlefield.get_anchor(placement.anchor_id)
	if anchor == null:
		return {"error": "Battler visual placement uses a missing Anchor."}
	if (
		placement.position_index < 0
		or placement.position_index >= anchor.capacity
	):
		return {"error": "Battler visual placement uses an invalid Position."}
	var pose_key: StringName = pose_key_for_event(event_key, is_defeated)
	var orientation_key: StringName = (
		orientation_override
		if orientation_override in [&"front", &"back"]
		else anchor.visual_orientation
	)
	var resolution: Dictionary = catalog.resolve_visual(
		battler_id,
		pose_key,
		orientation_key,
		render_instance_id
	)
	resolution["battler_id"] = battler_id
	resolution["requested_pose_key"] = pose_key
	resolution["requested_orientation_key"] = orientation_key
	resolution["anchor_id"] = anchor.anchor_id
	resolution["position_index"] = placement.position_index
	resolution["world_position"] = anchor.get_position_point(
		placement.position_index
	)
	resolution["depth_band"] = anchor.visual_depth_band
	resolution["anchor_scale"] = anchor.get_position_battler_scale(
		placement.position_index
	)
	resolution["visual_order"] = anchor.get_position_visual_order(
		placement.position_index
	)
	resolution["bounded_y_sort_within_band"] = anchor.bounded_y_sort_within_band
	if anchor.has_position_visual_order_override(placement.position_index):
		resolution["bounded_y_sort_within_band"] = false
	return resolution
