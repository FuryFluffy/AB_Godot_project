extends Node

## Run scenes/battle/presentation/dining_hall_pilot.tscn (F6) for the pilot.
func _ready() -> void:
	var definition := EncounterDefinition.new()
	definition.encounter_id = &"dining_hall_presentation_preview"
	definition.authored_room_id = &"dining_service_hall"
	definition.combat_stage_id = &"dining_service_hall_stage"
	definition.display_name = "Dining Service Hall Presentation Pilot"
	definition.encounter_seed = 1
	definition.enemy_ids.assign([&"hollow_servant"])
	definition.template = load("res://data/encounters/dining_service_hall_template.tres")
	var encounter: CombatEncounter = load("res://scenes/battle/combat_encounter.tscn").instantiate()
	var inventory: Array[Dictionary] = []
	encounter.prepare_run_encounter(definition, {}, inventory)
	add_child(encounter)
