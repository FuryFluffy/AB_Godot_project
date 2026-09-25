@tool
class_name BattlerVisualFallbackDefinition
extends Resource


@export var from_key: StringName
@export var to_key: StringName


func validate_definition(
	allowed_keys: Array[StringName],
	label: String
) -> String:
	if from_key == &"" or to_key == &"":
		return "Battler visual %s fallback has an empty key." % label
	if from_key not in allowed_keys or to_key not in allowed_keys:
		return (
			"Battler visual %s fallback '%s' -> '%s' uses an invalid key."
			% [label, from_key, to_key]
		)
	return ""
