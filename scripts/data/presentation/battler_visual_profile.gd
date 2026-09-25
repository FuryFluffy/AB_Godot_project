@tool
class_name BattlerVisualProfile
extends Resource


const ALLOWED_DEPTH_BANDS: Array[StringName] = [
	&"foreground",
	&"midground",
	&"background",
]


@export_group("Identity")
@export var profile_id: StringName
@export var battler_id: StringName

@export_group("Supported Intents")
@export var supported_pose_keys: Array[StringName] = []
@export var supported_orientation_keys: Array[StringName] = []
@export var states: Array[BattlerVisualStateDefinition] = []
@export var pose_fallbacks: Array[BattlerVisualFallbackDefinition] = []
@export var orientation_fallbacks: Array[BattlerVisualFallbackDefinition] = []

@export_group("Placement")
## Normalized texture pivot. (0.5, 1.0) means bottom-centre floor contact.
@export var floor_contact_pivot: Vector2 = Vector2(0.5, 1.0)
@export var baseline_scale: Vector2 = Vector2.ONE
@export var default_depth_band: StringName = &"midground"
@export_range(-100, 100, 1) var z_order_bias: int = 0
@export var bounded_y_sort_within_band: bool = true

@export_group("Grapple Presentation")
@export var grapple_metadata: BattlerGrappleVisualMetadata

@export_group("Development Status")
@export var development_placeholder: bool = false
@export_multiline var diagnostic_message: String = ""


func get_state(
	pose_key: StringName,
	orientation_key: StringName
) -> BattlerVisualStateDefinition:
	for state: BattlerVisualStateDefinition in states:
		if (
			state != null
			and state.pose_key == pose_key
			and state.orientation_key == orientation_key
		):
			return state
	return null


func resolve_state(
	requested_pose_key: StringName,
	requested_orientation_key: StringName
) -> Dictionary:
	if requested_pose_key not in supported_pose_keys:
		return {
			"error": "Visual profile '%s' does not support pose '%s'." % [
				profile_id,
				requested_pose_key,
			],
			"state": null,
		}
	if requested_orientation_key not in supported_orientation_keys:
		return {
			"error": "Visual profile '%s' does not support orientation '%s'." % [
				profile_id,
				requested_orientation_key,
			],
			"state": null,
		}
	var pose_chain_result: Dictionary = _make_fallback_chain(
		requested_pose_key,
		pose_fallbacks,
		supported_pose_keys,
		"pose"
	)
	var orientation_chain_result: Dictionary = _make_fallback_chain(
		requested_orientation_key,
		orientation_fallbacks,
		supported_orientation_keys,
		"orientation"
	)
	var chain_error: String = String(pose_chain_result.get("error", ""))
	if chain_error.is_empty():
		chain_error = String(orientation_chain_result.get("error", ""))
	if not chain_error.is_empty():
		return {"error": chain_error, "state": null}
	for pose_key: StringName in pose_chain_result.get("chain", []):
		for orientation_key: StringName in orientation_chain_result.get(
			"chain",
			[]
		):
			var state: BattlerVisualStateDefinition = get_state(
				pose_key,
				orientation_key
			)
			if state != null:
				return {
					"error": "",
					"state": state,
					"resolved_pose_key": pose_key,
					"resolved_orientation_key": orientation_key,
					"used_fallback": (
						pose_key != requested_pose_key
						or orientation_key != requested_orientation_key
					),
				}
	return {
		"error": "Visual profile '%s' cannot resolve '%s/%s'." % [
			profile_id,
			requested_pose_key,
			requested_orientation_key,
		],
		"state": null,
	}


func validate_definition() -> String:
	if profile_id == &"":
		return "A BattlerVisualProfile has no profile_id."
	if battler_id == &"":
		return "Visual profile '%s' has no battler_id." % profile_id
	if states.is_empty():
		return "Visual profile '%s' has no available states." % profile_id
	if supported_pose_keys.is_empty() or supported_orientation_keys.is_empty():
		return "Visual profile '%s' has no supported intent keys." % profile_id
	if (
		floor_contact_pivot.x < 0.0
		or floor_contact_pivot.x > 1.0
		or floor_contact_pivot.y < 0.0
		or floor_contact_pivot.y > 1.0
	):
		return "Visual profile '%s' has a non-normalized floor pivot." % profile_id
	if baseline_scale.x <= 0.0 or baseline_scale.y <= 0.0:
		return "Visual profile '%s' requires positive baseline scale." % profile_id
	if default_depth_band not in ALLOWED_DEPTH_BANDS:
		return "Visual profile '%s' has an invalid depth band." % profile_id
	if development_placeholder and diagnostic_message.strip_edges().is_empty():
		return "Placeholder visual profile '%s' needs a diagnostic." % profile_id

	var pose_error: String = _validate_key_list(
		supported_pose_keys,
		BattlerVisualStateDefinition.ALLOWED_POSE_KEYS,
		"pose"
	)
	if not pose_error.is_empty():
		return pose_error
	var orientation_error: String = _validate_key_list(
		supported_orientation_keys,
		BattlerVisualStateDefinition.ALLOWED_ORIENTATION_KEYS,
		"orientation"
	)
	if not orientation_error.is_empty():
		return orientation_error

	var state_keys: Dictionary = {}
	for state: BattlerVisualStateDefinition in states:
		if state == null:
			return "Visual profile '%s' contains an empty state." % profile_id
		var state_error: String = state.validate_definition()
		if not state_error.is_empty():
			return state_error
		if (
			state.pose_key not in supported_pose_keys
			or state.orientation_key not in supported_orientation_keys
		):
			return "Visual profile '%s' contains an unsupported state." % profile_id
		var state_key: String = state.get_state_key()
		if state_keys.has(state_key):
			return "Visual profile '%s' repeats state '%s'." % [
				profile_id,
				state_key,
			]
		state_keys[state_key] = true

	var fallback_error: String = _validate_fallbacks(
		pose_fallbacks,
		supported_pose_keys,
		"pose"
	)
	if fallback_error.is_empty():
		fallback_error = _validate_fallbacks(
			orientation_fallbacks,
			supported_orientation_keys,
			"orientation"
		)
	if not fallback_error.is_empty():
		return fallback_error
	for pose_key: StringName in supported_pose_keys:
		for orientation_key: StringName in supported_orientation_keys:
			var resolution: Dictionary = resolve_state(pose_key, orientation_key)
			if not String(resolution.get("error", "")).is_empty():
				return String(resolution.get("error"))
	if grapple_metadata != null:
		var grapple_error: String = grapple_metadata.validate_definition()
		if not grapple_error.is_empty():
			return grapple_error
	return ""


func _validate_key_list(
	keys: Array[StringName],
	allowed_keys: Array[StringName],
	label: String
) -> String:
	var seen: Dictionary = {}
	for key: StringName in keys:
		if key not in allowed_keys:
			return "Visual profile '%s' has invalid %s '%s'." % [
				profile_id,
				label,
				key,
			]
		if seen.has(key):
			return "Visual profile '%s' repeats %s '%s'." % [
				profile_id,
				label,
				key,
			]
		seen[key] = true
	return ""


func _validate_fallbacks(
	fallbacks: Array[BattlerVisualFallbackDefinition],
	allowed_keys: Array[StringName],
	label: String
) -> String:
	var seen_sources: Dictionary = {}
	for fallback: BattlerVisualFallbackDefinition in fallbacks:
		if fallback == null:
			return "Visual profile '%s' has an empty %s fallback." % [
				profile_id,
				label,
			]
		var fallback_error: String = fallback.validate_definition(
			allowed_keys,
			label
		)
		if not fallback_error.is_empty():
			return fallback_error
		if seen_sources.has(fallback.from_key):
			return "Visual profile '%s' repeats %s fallback '%s'." % [
				profile_id,
				label,
				fallback.from_key,
			]
		seen_sources[fallback.from_key] = true
	for key: StringName in allowed_keys:
		var chain_result: Dictionary = _make_fallback_chain(
			key,
			fallbacks,
			allowed_keys,
			label
		)
		var chain_error: String = String(chain_result.get("error", ""))
		if not chain_error.is_empty():
			return chain_error
	return ""


func _make_fallback_chain(
	start_key: StringName,
	fallbacks: Array[BattlerVisualFallbackDefinition],
	allowed_keys: Array[StringName],
	label: String
) -> Dictionary:
	var chain: Array[StringName] = []
	var visited: Dictionary = {}
	var current_key: StringName = start_key
	while current_key != &"":
		if current_key not in allowed_keys:
			return {
				"error": "Visual profile '%s' has invalid %s fallback key '%s'." % [
					profile_id,
					label,
					current_key,
				],
			}
		if visited.has(current_key):
			return {
				"error": "Visual profile '%s' has a cyclic %s fallback at '%s'." % [
					profile_id,
					label,
					current_key,
				],
			}
		visited[current_key] = true
		chain.append(current_key)
		current_key = _fallback_target(current_key, fallbacks)
	return {"error": "", "chain": chain}


func _fallback_target(
	from_key: StringName,
	fallbacks: Array[BattlerVisualFallbackDefinition]
) -> StringName:
	for fallback: BattlerVisualFallbackDefinition in fallbacks:
		if fallback != null and fallback.from_key == from_key:
			return fallback.to_key
	return &""
