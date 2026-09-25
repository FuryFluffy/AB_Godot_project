class_name BattleState
extends RefCounted


signal state_changed


enum CombatSide {
	NONE,
	HEROES,
	ENEMIES,
}


enum Phase {
	SETUP,
	HERO,
	ENEMY,
	COMPLETE,
}

enum Outcome {
	NONE,
	VICTORY,
	DEFEAT,
}


var encounter_started: bool = false
var round_number: int = 0
var phase: Phase = Phase.SETUP
var phase_index: int = -1

var first_side: CombatSide = CombatSide.NONE
var second_side: CombatSide = CombatSide.NONE
var momentum_side: CombatSide = CombatSide.NONE

var party_order_total: int = 0
var enemy_order_value: int = 0
var party_order_rolls: Dictionary = {}
var order_was_forced_for_testing: bool = false
var outcome: Outcome = Outcome.NONE


func reset() -> void:
	encounter_started = false
	round_number = 0
	phase = Phase.SETUP
	phase_index = -1
	first_side = CombatSide.NONE
	second_side = CombatSide.NONE
	momentum_side = CombatSide.NONE
	party_order_total = 0
	enemy_order_value = 0
	party_order_rolls.clear()
	order_was_forced_for_testing = false
	outcome = Outcome.NONE
	state_changed.emit()


func set_order(
	new_party_order_total: int,
	new_enemy_order_value: int,
	new_party_order_rolls: Dictionary = {},
	was_forced_for_testing: bool = false
) -> void:
	party_order_total = maxi(new_party_order_total, 0)
	enemy_order_value = maxi(new_enemy_order_value, 0)
	party_order_rolls = new_party_order_rolls.duplicate()
	order_was_forced_for_testing = was_forced_for_testing

	if party_order_total >= enemy_order_value:
		first_side = CombatSide.HEROES
		second_side = CombatSide.ENEMIES
	else:
		first_side = CombatSide.ENEMIES
		second_side = CombatSide.HEROES

	if abs(party_order_total - enemy_order_value) >= 3:
		momentum_side = first_side
	else:
		momentum_side = CombatSide.NONE

	state_changed.emit()


func begin_round(
	new_round_number: int
) -> void:
	assert(
		first_side != CombatSide.NONE and second_side != CombatSide.NONE,
		"Order must be resolved before a round begins."
	)

	encounter_started = true
	round_number = maxi(new_round_number, 1)
	phase_index = 0
	phase = _phase_for_side(first_side)
	state_changed.emit()


func advance_phase() -> bool:
	if not encounter_started or phase == Phase.COMPLETE:
		return false

	if phase_index == 0:
		phase_index = 1
		phase = _phase_for_side(second_side)
		state_changed.emit()
		return true

	return false


func complete_battle(
	new_outcome: Outcome = Outcome.NONE
) -> void:
	outcome = new_outcome
	phase = Phase.COMPLETE
	phase_index = -1
	state_changed.emit()


func get_active_side() -> CombatSide:
	match phase:
		Phase.HERO:
			return CombatSide.HEROES
		Phase.ENEMY:
			return CombatSide.ENEMIES

	return CombatSide.NONE


func is_side_active(
	side: CombatSide
) -> bool:
	return side != CombatSide.NONE and get_active_side() == side


func is_side_momentum_locked(
	side: CombatSide
) -> bool:
	return (
		encounter_started
		and round_number == 1
		and momentum_side != CombatSide.NONE
		and side != momentum_side
	)


func get_phase_label() -> String:
	match phase:
		Phase.SETUP:
			return "Encounter Setup"
		Phase.HERO:
			return "Hero Phase"
		Phase.ENEMY:
			return "Enemy Phase"
		Phase.COMPLETE:
			match outcome:
				Outcome.VICTORY:
					return "Victory"
				Outcome.DEFEAT:
					return "Defeat"
			return "Battle Complete"

	return "Unknown Phase"


func get_outcome_label() -> String:
	match outcome:
		Outcome.VICTORY:
			return "Victory"
		Outcome.DEFEAT:
			return "Defeat"

	return "In Progress"


func get_side_label(
	side: CombatSide
) -> String:
	match side:
		CombatSide.HEROES:
			return "Party"
		CombatSide.ENEMIES:
			return "Enemies"

	return "None"


func get_order_summary() -> String:
	var winner_name: String = get_side_label(first_side)
	var first_score: int = (
		party_order_total
		if first_side == CombatSide.HEROES
		else enemy_order_value
	)
	var second_score: int = (
		enemy_order_value
		if first_side == CombatSide.HEROES
		else party_order_total
	)
	var first_verb: String = (
		"goes"
		if first_side == CombatSide.HEROES
		else "go"
	)
	var summary: String = "%s won the Order (%d vs %d). %s %s first" % [
		winner_name,
		first_score,
		second_score,
		winner_name,
		first_verb,
	]

	if momentum_side != CombatSide.NONE:
		summary += " with Momentum."
	else:
		summary += "."

	return summary


func _phase_for_side(
	side: CombatSide
) -> Phase:
	match side:
		CombatSide.HEROES:
			return Phase.HERO
		CombatSide.ENEMIES:
			return Phase.ENEMY

	return Phase.SETUP
