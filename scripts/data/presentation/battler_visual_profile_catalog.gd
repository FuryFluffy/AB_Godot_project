@tool
class_name BattlerVisualProfileCatalog
extends Resource


const MARKER_ONLY_STATUS: StringName = &"marker_only_placeholder"


@export var profiles: Array[BattlerVisualProfile] = []
@export var required_battler_ids: Array[StringName] = []
@export var allowed_marker_only_battler_ids: Array[StringName] = []


func get_profile(battler_id: StringName) -> BattlerVisualProfile:
	for profile: BattlerVisualProfile in profiles:
		if profile != null and profile.battler_id == battler_id:
			return profile
	return null


func is_marker_only_allowed(battler_id: StringName) -> bool:
	return allowed_marker_only_battler_ids.has(battler_id)


func make_render_key(
	battler_id: StringName,
	render_instance_id: StringName
) -> StringName:
	if battler_id == &"":
		return &""
	return StringName(
		"%s::%s" % [
			String(battler_id),
			(
				String(render_instance_id)
				if render_instance_id != &""
				else "default"
			),
		]
	)


func resolve_visual(
	battler_id: StringName,
	pose_key: StringName,
	orientation_key: StringName,
	render_instance_id: StringName = &""
) -> Dictionary:
	var render_key: StringName = make_render_key(
		battler_id,
		render_instance_id
	)
	var profile: BattlerVisualProfile = get_profile(battler_id)
	if profile == null:
		return {
			"error": (
				""
				if is_marker_only_allowed(battler_id)
				else "Battler '%s' has no visual profile." % battler_id
			),
			"status": MARKER_ONLY_STATUS,
			"render_key": render_key,
			"profile": null,
			"state": null,
			"texture": null,
			"diagnostic": (
				"Battler '%s' uses the explicit marker-only development fallback."
				% battler_id
			),
		}
	var resolution: Dictionary = profile.resolve_state(
		pose_key,
		orientation_key
	)
	var resolution_error: String = String(resolution.get("error", ""))
	var state: BattlerVisualStateDefinition = resolution.get(
		"state"
	) as BattlerVisualStateDefinition
	if not resolution_error.is_empty() or state == null:
		return {
			"error": resolution_error,
			"status": MARKER_ONLY_STATUS,
			"render_key": render_key,
			"profile": profile,
			"state": null,
			"texture": null,
			"diagnostic": resolution_error,
		}
	resolution["status"] = (
		&"development_texture"
		if profile.development_placeholder
		else &"production_texture"
	)
	resolution["render_key"] = render_key
	resolution["profile"] = profile
	resolution["texture"] = state.texture
	resolution["floor_contact_pivot"] = profile.floor_contact_pivot
	resolution["baseline_scale"] = profile.baseline_scale
	resolution["offset_correction"] = state.offset_correction
	resolution["scale_correction"] = state.scale_correction
	resolution["depth_band"] = profile.default_depth_band
	resolution["z_order_bias"] = profile.z_order_bias
	resolution["bounded_y_sort_within_band"] = (
		profile.bounded_y_sort_within_band
	)
	resolution["diagnostic"] = profile.diagnostic_message
	return resolution


func validate_definition(
	battler_catalog: BattlerCatalogDefinition
) -> String:
	if battler_catalog == null:
		return "Battler visual catalog requires the BattlerCatalogDefinition."
	if required_battler_ids.is_empty():
		return "Battler visual catalog has no required roster."
	var required_ids: Dictionary = {}
	for battler_id: StringName in required_battler_ids:
		if battler_id == &"":
			return "Battler visual catalog has an empty required battler ID."
		if required_ids.has(battler_id):
			return "Battler visual catalog repeats required battler '%s'." % (
				battler_id
			)
		required_ids[battler_id] = true
	var profile_ids: Dictionary = {}
	var profiled_battler_ids: Dictionary = {}
	for profile: BattlerVisualProfile in profiles:
		if profile == null:
			return "Battler visual catalog contains an empty profile."
		var profile_error: String = profile.validate_definition()
		if not profile_error.is_empty():
			return profile_error
		if profile_ids.has(profile.profile_id):
			return "Battler visual catalog repeats profile '%s'." % (
				profile.profile_id
			)
		if profiled_battler_ids.has(profile.battler_id):
			return "Battler visual catalog repeats battler '%s'." % (
				profile.battler_id
			)
		if not required_ids.has(profile.battler_id):
			return "Visual profile '%s' references unknown battler '%s'." % [
				profile.profile_id,
				profile.battler_id,
			]
		profile_ids[profile.profile_id] = true
		profiled_battler_ids[profile.battler_id] = true

	var marker_only_ids: Dictionary = {}
	for battler_id: StringName in allowed_marker_only_battler_ids:
		if battler_id not in required_battler_ids:
			return "Marker-only battler '%s' is outside the required roster." % (
				battler_id
			)
		if marker_only_ids.has(battler_id):
			return "Battler visual catalog repeats marker-only battler '%s'." % (
				battler_id
			)
		if profiled_battler_ids.has(battler_id):
			return "Profiled battler '%s' cannot also be marker-only." % battler_id
		marker_only_ids[battler_id] = true

	for battler_id: StringName in required_battler_ids:
		if (
			not profiled_battler_ids.has(battler_id)
			and not marker_only_ids.has(battler_id)
		):
			return "Required battler '%s' has no profile or allowed fallback." % (
				battler_id
			)
	return ""


func get_development_diagnostics(
	battler_catalog: BattlerCatalogDefinition
) -> Array[String]:
	var diagnostics: Array[String] = []
	for profile: BattlerVisualProfile in profiles:
		if profile != null and profile.development_placeholder:
			diagnostics.append(profile.diagnostic_message)
		if (
			profile != null
			and battler_catalog != null
			and battler_catalog.get_battler(profile.battler_id) == null
		):
			diagnostics.append(
				"Battler '%s' has curated visual data but its BattlerDefinition is deferred."
				% profile.battler_id
			)
	for battler_id: StringName in allowed_marker_only_battler_ids:
		var registration_note: String = (
			"; its BattlerDefinition is also deferred"
			if (
				battler_catalog == null
				or battler_catalog.get_battler(battler_id) == null
			)
			else ""
		)
		diagnostics.append(
			"Battler '%s' has no approved stage PNG and remains marker-only%s."
			% [battler_id, registration_note]
		)
	return diagnostics
