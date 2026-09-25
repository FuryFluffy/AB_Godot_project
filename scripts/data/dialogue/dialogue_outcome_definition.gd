@tool
class_name DialogueOutcomeDefinition
extends Resource


enum Kind {
	SET_FLAG,
	RECORD_CHOICE,
	ADD_ITEM,
	CONSUME_ITEM,
	MODIFY_HEROINE_STAT,
	GRANT_BLOOM,
	GRANT_KNOWLEDGE,
	RESOLVE_INTERACTION,
	RECRUIT_HEROINE,
	START_BATTLE,
	REQUEST_SCENE,
	RETURN_TO_EXPLORATION,
	MODIFY_ACTIVE_PARTY_STAT,
	RESTORE_ACTIVE_PARTY_FULL,
	CONSUME_ROOM_ITEM,
	GRANT_CAMPAIGN_ITEM,
}


@export var kind: Kind = Kind.SET_FLAG
@export var scope: StringName = &"run"
@export var subject_id: StringName
@export var key: StringName
@export var integer_value: int = 1
@export var boolean_value: bool = true


func validate_definition() -> String:
	if kind == Kind.RETURN_TO_EXPLORATION:
		return ""
	if kind == Kind.GRANT_BLOOM:
		if integer_value < 0:
			return "Dialogue cannot grant negative Bloom."
		return ""
	if subject_id == &"":
		return "A dialogue outcome has no subject_id."
	if kind == Kind.SET_FLAG and scope not in [
		&"run",
		&"save",
		&"persistent",
	]:
		return "Dialogue flag outcome has an invalid scope."
	if kind == Kind.MODIFY_HEROINE_STAT and key == &"":
		return "Heroine-stat dialogue outcome has no stat key."
	if kind == Kind.MODIFY_ACTIVE_PARTY_STAT and key == &"":
		return "Party-stat dialogue outcome has no stat key."
	if kind in [Kind.ADD_ITEM, Kind.CONSUME_ITEM, Kind.CONSUME_ROOM_ITEM] and integer_value <= 0:
		return "Dialogue item outcome requires a positive quantity."
	return ""


func to_snapshot() -> Dictionary:
	return {
		"kind": kind,
		"scope": String(scope),
		"subject_id": String(subject_id),
		"key": String(key),
		"integer_value": integer_value,
		"boolean_value": boolean_value,
	}
