class_name GeneratedRoomItemHostCandidate
extends Resource


enum AccessPolicy {
	NORMALLY_REACHABLE,
	REACHABLE_WITHOUT_BLOCKING_ROOM,
}


@export_group("Host")
@export var room_definition_id: StringName = &""

@export var access_policy: AccessPolicy = (
	AccessPolicy.NORMALLY_REACHABLE
)

@export var blocking_room_definition_id: StringName = &""


func collect_validation_errors(
	candidate_label: String
) -> Array[String]:
	var errors: Array[String] = []

	if room_definition_id == &"":
		errors.append(
			"%s has no room_definition_id."
			% candidate_label
		)

	if access_policy not in [
		AccessPolicy.NORMALLY_REACHABLE,
		AccessPolicy.REACHABLE_WITHOUT_BLOCKING_ROOM,
	]:
		errors.append(
			"%s has an invalid access policy."
			% candidate_label
		)

	if (
		access_policy
		== AccessPolicy.NORMALLY_REACHABLE
		and blocking_room_definition_id != &""
	):
		errors.append(
			(
				"%s uses NORMALLY_REACHABLE but also "
				+ "defines a blocking room."
			)
			% candidate_label
		)

	if (
		access_policy
		== AccessPolicy.REACHABLE_WITHOUT_BLOCKING_ROOM
		and blocking_room_definition_id == &""
	):
		errors.append(
			(
				"%s requires a blocking_room_definition_id."
			)
			% candidate_label
		)

	if (
		blocking_room_definition_id != &""
		and blocking_room_definition_id
		== room_definition_id
	):
		errors.append(
			(
				"%s cannot be blocked by its own "
				+ "room definition."
			)
			% candidate_label
		)

	return errors


func get_stable_signature() -> String:
	return "%s|%d|%s" % [
		String(room_definition_id),
		int(access_policy),
		String(blocking_room_definition_id),
	]
