class_name StatusDefinition
extends Resource


enum Kind {
	BLEED,
	POISON,
	SLOW,
	STUNNED,
	BURNING,
	REGENERATION,
}


@export_group("Identity")
@export var status_id: StringName
@export var display_name: String = "Unnamed Status"
@export var kind: Kind = Kind.BLEED

@export_group("Phase-start Effect")
@export_range(0, 99, 1) var periodic_damage: int = 0
@export_range(0, 99, 1) var periodic_healing: int = 0
@export_range(1, 10, 1) var duration_ticks: int = 3

@export_group("Control")
@export_range(0, 3, 1) var maximum_action_penalty: int = 0
@export_range(0, 3, 1) var immediate_action_loss: int = 0
@export var prevents_actions: bool = false
@export var stops_committed_movement: bool = false

@export_group("Removal")
@export var is_magical: bool = false
@export var is_dispellable: bool = false
