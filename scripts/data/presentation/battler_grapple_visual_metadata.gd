@tool
class_name BattlerGrappleVisualMetadata
extends Resource


const ALLOWED_ROLE_KEYS: Array[StringName] = [
	&"subject",
	&"holder",
	&"overlay",
]


@export var supported_role_keys: Array[StringName] = []
@export var overlay_profile_ids: Array[StringName] = []
@export_multiline var development_notes: String = ""


func validate_definition() -> String:
	var seen_roles: Dictionary = {}
	for role_key: StringName in supported_role_keys:
		if role_key not in ALLOWED_ROLE_KEYS:
			return "Grapple visual metadata has invalid role '%s'." % role_key
		if seen_roles.has(role_key):
			return "Grapple visual metadata repeats role '%s'." % role_key
		seen_roles[role_key] = true
	var seen_overlays: Dictionary = {}
	for overlay_profile_id: StringName in overlay_profile_ids:
		if overlay_profile_id == &"":
			return "Grapple visual metadata has an empty overlay profile ID."
		if seen_overlays.has(overlay_profile_id):
			return (
				"Grapple visual metadata repeats overlay '%s'."
				% overlay_profile_id
			)
		seen_overlays[overlay_profile_id] = true
	return ""
