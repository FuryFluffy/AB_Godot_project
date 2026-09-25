class_name GeneratedRoomItemPlacementRule
extends Resource


@export_group("Assignment")
@export var assignment_id: StringName = &""
@export var item_id: StringName = &""
@export var reward_source: RoomLootSourceDefinition

@export_range(1, 99, 1)
var quantity: int = 1

@export var required_anchor_tag: StringName = &""

@export_group("Candidates")
@export var candidates: Array[GeneratedRoomItemHostCandidate] = []


func collect_validation_errors(
	rule_label: String
) -> Array[String]:
	var errors: Array[String] = []

	if assignment_id == &"":
		errors.append(
			"%s has no assignment_id."
			% rule_label
		)

	if item_id == &"" and reward_source == null:
		errors.append(
			"%s has neither an item_id nor a reward source."
			% rule_label
		)
	if item_id != &"" and reward_source != null:
		errors.append(
			"%s cannot define both item_id and reward_source."
			% rule_label
		)
	if (
		reward_source != null
		and reward_source.source_id != assignment_id
	):
		errors.append(
			"%s reward source ID must match its stable assignment ID."
			% rule_label
		)

	if quantity <= 0:
		errors.append(
			"%s has an invalid quantity."
			% rule_label
		)

	if required_anchor_tag == &"":
		errors.append(
			"%s has no required_anchor_tag."
			% rule_label
		)

	if candidates.is_empty():
		errors.append(
			"%s has no host candidates."
			% rule_label
		)

	var seen_candidate_signatures: Dictionary = {}

	for candidate_index: int in range(
		candidates.size()
	):
		var candidate: GeneratedRoomItemHostCandidate = (
			candidates[candidate_index]
		)

		var candidate_label: String = (
			"%s candidate %d"
			% [
				rule_label,
				candidate_index,
			]
		)

		if candidate == null:
			errors.append(
				"%s is null."
				% candidate_label
			)
			continue

		errors.append_array(
			candidate.collect_validation_errors(
				candidate_label
			)
		)

		var signature: String = (
			candidate.get_stable_signature()
		)

		if seen_candidate_signatures.has(
			signature
		):
			errors.append(
				(
					"%s duplicates an earlier "
					+ "candidate configuration."
				)
				% candidate_label
			)
		else:
			seen_candidate_signatures[
				signature
			] = true

	return errors
