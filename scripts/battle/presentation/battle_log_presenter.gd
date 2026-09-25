class_name BattleLogPresenter
extends RefCounted


signal entry_added(message: String)
signal detail_added(details: String)


var log_text: RichTextLabel
var pending_round_details: PackedStringArray = PackedStringArray()
var pending_phase_summary: String = ""
var pending_phase_details: PackedStringArray = PackedStringArray()
var pending_action_details: PackedStringArray = PackedStringArray()
var pending_grapple_details: PackedStringArray = PackedStringArray()


func _init(
	new_log_text: RichTextLabel = null
) -> void:
	log_text = new_log_text
	if log_text != null:
		log_text.scroll_following = true


func clear() -> void:
	pending_round_details.clear()
	pending_phase_summary = ""
	pending_phase_details.clear()
	pending_action_details.clear()
	pending_grapple_details.clear()
	if log_text != null:
		log_text.clear()
		log_text.scroll_following = true


func append(message: String, details: String = "") -> void:
	print("[Combat Log] %s" % message)
	if message.is_empty():
		return
	entry_added.emit(message)
	if not details.is_empty():
		detail_added.emit(details)

	if log_text == null:
		return

	log_text.append_text(message + "\n")
	log_text.scroll_following = true


func append_detail(details: String) -> void:
	if details.is_empty():
		return
	print("[Combat Detail] %s" % details)
	detail_added.emit(details)


func debug(details: String) -> void:
	if not details.is_empty():
		print("[Combat Detail] %s" % details)


func log_encounter_ready(
	selected_state: BattlerState
) -> void:
	var selected_name: String = "None"
	if selected_state != null and selected_state.definition != null:
		selected_name = selected_state.definition.display_name
	append(
		"Encounter ready.",
		"Combat battler states and reusable encounter systems initialized.\n"
		+ "Selected combatant: %s." % selected_name
	)


func log_encounter_setup() -> void:
	append(
		"Choose Order, then begin the encounter.",
		"Seeded Order rolls every heroine's Agility against the highest Enemy Order."
	)


func log_order_resolved(
	state: BattleState,
	battler_states: Dictionary
) -> void:
	var details: PackedStringArray = PackedStringArray()
	if state.order_was_forced_for_testing:
		details.append("Order test preset applied.")
	else:
		var heroine_ids: Array = state.party_order_rolls.keys()
		heroine_ids.sort()

		for heroine_id: Variant in heroine_ids:
			var roll: RollResult = state.party_order_rolls.get(
				heroine_id
			) as RollResult
			var heroine: BattlerState = battler_states.get(
				heroine_id
			) as BattlerState

			if roll == null or heroine == null:
				continue

			details.append(
				"%s Order: %s -> %d successes."
				% [
					heroine.definition.display_name,
					str(roll.final_rolls),
					roll.total_successes,
				]
			)

		details.append(
			"Highest Enemy Order: %d."
			% state.enemy_order_value
		)

	append(state.get_order_summary(), "\n".join(details))


func log_round_started(
	state: BattleState,
	battler_states: Dictionary
) -> void:
	pending_round_details.clear()
	pending_round_details.append(
		"Round %d Start: all leftover Actions discarded and refreshed."
		% state.round_number
	)

	if (
		state.round_number == 1
		and state.momentum_side != BattleState.CombatSide.NONE
	):
		pending_round_details.append(
			"%s Momentum: %s begins round one with zero Actions."
			% [
				state.get_side_label(state.momentum_side),
				state.get_side_label(state.second_side),
			]
		)

	var action_entries: PackedStringArray = PackedStringArray()

	for state_value: Variant in battler_states.values():
		var battler: BattlerState = state_value as BattlerState
		if battler == null or battler.definition == null:
			continue

		action_entries.append(
			"%s %d/%d" % [
				battler.definition.display_name,
				battler.current_actions,
				battler.get_max_actions(),
			]
		)

	action_entries.sort()
	pending_round_details.append(
		"Actions: %s." % ", ".join(action_entries)
	)


func log_phase_started(
	state: BattleState
) -> void:
	pending_phase_summary = "Round %d — %s" % [
		state.round_number,
		state.get_phase_label(),
	]
	pending_phase_details = pending_round_details.duplicate()
	pending_round_details.clear()
	pending_phase_details.append(
		"Phase-start order: regeneration, damage-over-time, control, Action changes, expiry."
	)


func log_phase_ended(
	round_number: int,
	phase_label: String
) -> void:
	debug(
		"Round %d — %s ended."
		% [
			round_number,
			phase_label,
		]
	)


func log_combatant_selected(
	state: BattlerState
) -> void:
	debug(
		"Selected combatant: %s."
		% state.definition.display_name
	)


func log_attack_targeting_started(
	attacker: BattlerState,
	weapon: WeaponDefinition
) -> void:
	debug(
		"%s is preparing an attack with %s; select a target."
		% [
			attacker.definition.display_name,
			weapon.display_name,
		]
	)


func log_attack_committed(
	attacker: BattlerState,
	target: BattlerState,
	context: ReactionContext
) -> void:
	pending_action_details.clear()
	var source_label: String = "Attack"
	if context.request != null:
		source_label = context.request.get_source_label()

	pending_action_details.append(
		"%s commits %s against %s."
		% [
			attacker.definition.display_name,
			source_label,
			target.definition.display_name,
		]
	)
	if (
		context.request != null
		and not context.request.spatial_range_label.is_empty()
	):
		pending_action_details.append(
			"Spatial range: %s."
			% context.request.spatial_range_label
		)
	if (
		context.request != null
		and context.request.attack_dice_modifier != 0
	):
		pending_action_details.append(
			"Spatial dice modifier: %dd10."
			% context.request.attack_dice_modifier
		)
	if (
		context.request != null
		and context.request.suppress_skill_modification
	):
		pending_action_details.append(
			"Engaged ranged Attack: Weapon Skill and Specialty modification suppressed."
		)
	pending_action_details.append(
		"Attack dice: %s"
		% str(context.attack_roll.final_rolls)
	)
	pending_action_details.append(
		"Incoming successes: %d"
		% context.attack_successes
	)
	if (
		context.request != null
		and context.request.weapon != null
	):
		var property_summary: String = (
			context.request.weapon.get_property_summary(
				context.request.weapon_family_rank
			)
		)
		if not property_summary.is_empty():
			pending_action_details.append(
				"Weapon Property: %s."
				% property_summary
			)
		var rank_definition: WeaponRankDefinition = (
			context.request.weapon.get_rank_definition(
				context.request.weapon_family_rank
			)
		)
		if rank_definition != null:
			pending_action_details.append(
				"Weapon Family: %s — %s."
				% [
					context.request.weapon.family.display_name,
					rank_definition.display_name,
				]
			)


func log_attack_result(
	attacker: BattlerState,
	target: BattlerState,
	weapon: WeaponDefinition,
	result: ActionResult
) -> void:
	_log_compact_attack_result(
		attacker,
		target,
		weapon,
		result
	)


func log_verbose_attack_result(
	attacker: BattlerState,
	target: BattlerState,
	weapon: WeaponDefinition,
	result: ActionResult
) -> void:
	append("")
	append(
		"%s attacks %s with %s."
		% [
			attacker.definition.display_name,
			target.definition.display_name,
			weapon.display_name,
		]
	)
	if result.request != null and result.request.is_free_attack:
		append("Free Attack: no Action spent.")
	else:
		append(
			"Attacker Actions: %d -> %d"
			% [
				result.actor_actions_before,
				result.actor_actions_after,
			]
		)
	append(
		"Attack successes: %d"
		% result.attack_successes
	)

	if (
		result.attack_reaction_choice
		== AttackReactionChoice.Type.COUNTERATTACK
	):
		append(
			"%s chooses Counterattack; the original Attack lands in full."
			% target.definition.display_name
		)
	else:
		match result.defense_choice:
			DefenseChoice.Type.SKIP:
				append(
					"%s skips Defense."
					% target.definition.display_name
				)

			DefenseChoice.Type.DODGE:
				append(
					"%s attempts to Dodge."
					% target.definition.display_name
				)
				_append_reaction_action_log(result)
				if result.defense_roll != null:
					append(
						"Dodge dice: %s"
						% str(result.defense_roll.final_rolls)
					)
				append(
					"Dodge successes: %d"
					% result.defense_successes
				)

			DefenseChoice.Type.ARMOR:
				append(
					"%s uses Armor Defense."
					% target.definition.display_name
				)
				_append_reaction_action_log(result)
				if result.defense_roll != null:
					append(
						"Armor Defense dice: %s"
						% str(result.defense_roll.final_rolls)
					)
				append(
					"Armor Defense successes: %d"
					% result.defense_successes
				)

			DefenseChoice.Type.SHIELD:
				append(
					"%s uses Shield Defense."
					% target.definition.display_name
				)
				_append_reaction_action_log(result)
				if result.defense_roll != null:
					append(
						"Shield Defense dice: %s"
						% str(result.defense_roll.final_rolls)
					)
				append(
					"Shield Defense successes: %d"
					% result.defense_successes
				)

			DefenseChoice.Type.PARRY:
				append(
					"%s attempts to Parry."
					% target.definition.display_name
				)
				_append_reaction_action_log(result)
				append(
					"Parry penalty: -%dd10"
					% result.parry_penalty
				)
				if result.parry_shield_bonus > 0:
					append(
						"Small shield Parry bonus: +%dd10"
						% result.parry_shield_bonus
					)
				if result.defense_roll != null:
					append(
						"Parry dice: %s"
						% str(result.defense_roll.final_rolls)
					)
				append(
					"Parry successes: %d"
					% result.defense_successes
				)

	if result.ward_dice_bonus > 0:
		append(
			"Ward of Grace added +%dd10 and was consumed."
			% result.ward_dice_bonus
		)

	if result.counterattack_generated:
		append(
			"Counterattack queued; its Action is paid after survival."
		)

	if result.weapon_durability_event:
		append(
			"Attack fully negated: %s durability %d -> %d."
			% [
				weapon.display_name,
				result.weapon_durability_before,
				result.weapon_durability_after,
			]
		)
	if result.weapon_attack_dice_bonus != 0:
		append(
			"Weapon rank Attack bonus: %dd10."
			% result.weapon_attack_dice_bonus
		)
	if result.weapon_attack_success_bonus > 0:
		append(
			"Weapon added %d success after rolling."
			% result.weapon_attack_success_bonus
		)
	if result.weapon_flat_damage_bonus > 0:
		append(
			"Weapon art added %d flat damage after defense."
			% result.weapon_flat_damage_bonus
		)
	for effect_message: String in result.weapon_effect_messages:
		append(effect_message)

		if result.weapon_broken:
			append(
				"%s is Broken and unusable."
				% weapon.display_name
			)

	if result.defense_successes_ignored > 0:
		append(
			"%s ignores %d %s success."
			% [
				weapon.display_name,
				result.defense_successes_ignored,
				_get_defense_name(result.defense_choice),
			]
		)
		append(
			"Effective Defense successes: %d"
			% result.effective_defense_successes
		)
	if result.analyzed_bonus_consumed:
		append("Find the Catch ignored 1 Defense success and was consumed.")
	if result.blessed_attack_consumed:
		append("Bless guaranteed at least 1 incoming damage and was consumed.")
	if result.specialty_damage_bonus > 0:
		append(
			"Combat Specialty added +%d damage."
			% result.specialty_damage_bonus
		)

	if result.defense_choice == DefenseChoice.Type.PARRY:
		append(
			"Parry prevented damage: %d"
			% result.parry_prevented_damage
		)

	append(
		"Remaining attack successes: %d"
		% result.remaining_attack_successes
	)

	if result.armor_damage_absorbed > 0:
		append(
			"Armor absorbed: %d"
			% result.armor_damage_absorbed
		)

		if (
			target.armor_state != null
			and target.armor_state.definition != null
		):
			if target.armor_state.is_broken:
				append(
					"Armor condition: Broken | Total absorbed: %d"
					% target.armor_state.absorbed_damage
				)
			else:
				append(
					"Armor condition: %d/%d"
					% [
						target.armor_state.absorbed_damage,
						target.armor_state.get_safe_absorption_limit(),
					]
				)

	if result.armor_broken:
		if (
			target.armor_state != null
			and target.armor_state.definition != null
		):
			append(
				"%s was destroyed."
				% target.armor_state.definition.display_name
			)
		else:
			append(
				"%s's armor was destroyed."
				% target.definition.display_name
			)

	if result.shield_damage_absorbed > 0:
		append(
			"Shield absorbed: %d"
			% result.shield_damage_absorbed
		)

		if (
			target.shield_state != null
			and target.shield_state.definition != null
		):
			if target.shield_state.is_broken:
				append(
					"Shield condition: Broken | Total absorbed: %d"
					% target.shield_state.absorbed_damage
				)
			else:
				append(
					"Shield condition: %d/%d"
					% [
						target.shield_state.absorbed_damage,
						target.shield_state.get_safe_absorption_limit(),
					]
				)

	if result.shield_broken:
		if (
			target.shield_state != null
			and target.shield_state.definition != null
		):
			append(
				"%s was destroyed."
				% target.shield_state.definition.display_name
			)
		else:
			append(
				"%s's shield was destroyed."
				% target.definition.display_name
			)

	append(
		"%s HP: %d -> %d"
		% [
			target.definition.display_name,
			result.target_hp_before,
			result.target_hp_after,
		]
	)
	append(
		"HP damage dealt: %d"
		% result.damage_dealt
	)

	if result.target_defeated:
		append(
			"%s was defeated."
			% target.definition.display_name
		)
	if result.blood_riposte_generated:
		append("Perfect Dodge triggered Blood Riposte (once this round).")


func _log_compact_attack_result(
	attacker: BattlerState,
	target: BattlerState,
	weapon: WeaponDefinition,
	result: ActionResult
) -> void:
	var action_name: String = "Attack"
	if result.request != null:
		action_name = result.request.get_source_label()

	var defense_name: String = _get_defense_name(
		result.defense_choice
	)
	if result.defense_choice == DefenseChoice.Type.SKIP:
		defense_name = "No Defense"

	var summary: String = "%s used %s on %s — %s." % [
		attacker.definition.display_name,
		action_name,
		target.definition.display_name,
		(
			"%d damage" % result.damage_dealt
			if result.damage_dealt > 0
			else "no damage"
		),
	]
	if result.target_defeated:
		summary = summary.trim_suffix(".") + "; defeated."
	var details: PackedStringArray = pending_action_details.duplicate()
	pending_action_details.clear()
	if weapon != null:
		details.append("Weapon: %s." % weapon.display_name)
	if result.roll_result != null:
		details.append("Attack dice: %s." % str(result.roll_result.final_rolls))
	details.append(
		"%s: %d successes; %s: %d %s successes."
		% [
			attacker.definition.display_name,
			result.attack_successes,
			target.definition.display_name,
			result.effective_defense_successes,
			defense_name,
		]
	)
	if result.defense_roll != null:
		details.append(
			"%s dice: %s."
			% [defense_name, str(result.defense_roll.final_rolls)]
		)
	details.append(
		"HP: %d → %d; Actions: attacker %d → %d, defender %d → %d."
		% [
			result.target_hp_before,
			result.target_hp_after,
			result.actor_actions_before,
			result.actor_actions_after,
			result.target_actions_before,
			result.target_actions_after,
		]
	)
	if result.armor_damage_absorbed > 0:
		details.append(
			"Armor absorbed %d."
			% result.armor_damage_absorbed
		)
	if result.shield_damage_absorbed > 0:
		details.append(
			"Shield absorbed %d."
			% result.shield_damage_absorbed
		)
	if result.armor_broken:
		details.append("Armor was destroyed.")
	if result.shield_broken:
		details.append("Shield was destroyed.")
	if result.weapon_durability_event:
		details.append(
			"%s durability %d -> %d%s."
			% [
				weapon.display_name,
				result.weapon_durability_before,
				result.weapon_durability_after,
				" and is Broken"
				if result.weapon_broken
				else "",
			]
		)
	if result.status_applied:
		details.append(
			"%s %s on %s."
			% [
				"Refreshed"
				if result.status_replaced_existing
				else "Applied",
				result.status_display_name,
				target.definition.display_name,
			]
		)
	elif not result.status_error_message.is_empty():
		details.append(
			"Status was not applied: %s"
			% result.status_error_message
		)
	if result.counterattack_generated:
		details.append("Counterattack queued after survival.")
	if result.parry_generated_free_attack:
		details.append("Parry free Attack queued.")
	if result.weapon_critical_free_attack_generated:
		details.append("Weapon critical free Attack queued.")
	for effect_message: String in result.weapon_effect_messages:
		details.append(effect_message)
	append(summary, "\n".join(details))


func log_aoe_committed(
	caster: BattlerState,
	ability: AbilityDefinition,
	zone_name: String,
	target_names: String,
	context: ReactionContext
) -> void:
	pending_action_details.clear()
	pending_action_details.append(
		"%s used %s on %s for %d Action / %d MP."
		% [
			caster.definition.display_name,
			ability.display_name,
			zone_name,
			ability.action_cost,
			ability.mp_cost,
		]
	)
	pending_action_details.append(
		"AOE roll %s -> %d shared successes; targets: %s."
		% [
			str(context.attack_roll.final_rolls),
			context.attack_successes,
			target_names,
		]
	)


func log_status_phase(
	report: StatusPhaseReport
) -> void:
	if report == null or report.is_empty():
		pending_phase_details.append("Phase-start effects: none.")
	else:
		for entry: String in report.entries:
			pending_phase_details.append(entry)
	var summary: String = pending_phase_summary
	if summary.is_empty():
		summary = "Phase started."
	append(summary, "\n".join(pending_phase_details))
	pending_phase_summary = ""
	pending_phase_details.clear()


func log_grapple_attempt(
	grappler: BattlerState,
	heroine: BattlerState,
	attempt: GrappleAttemptResult
) -> void:
	pending_grapple_details.clear()
	if grappler == null or heroine == null or attempt == null:
		return
	pending_grapple_details.append(
		"%s attempted to Grapple %s."
		% [grappler.definition.display_name, heroine.definition.display_name]
	)
	if attempt.attack_roll != null:
		pending_grapple_details.append(
			"Grapple dice: %s." % str(attempt.attack_roll.final_rolls)
		)
	pending_grapple_details.append(
		"Rolled %d successes; +%d automatic."
		% [
			attempt.attack_roll.total_successes
			if attempt.attack_roll != null
			else 0,
			attempt.automatic_successes,
		]
	)


func log_grapple_result(
	grappler: BattlerState,
	heroine: BattlerState,
	attempt: GrappleAttemptResult,
	dodge_chosen: bool
) -> void:
	if grappler == null or heroine == null or attempt == null:
		return
	var details: PackedStringArray = pending_grapple_details.duplicate()
	pending_grapple_details.clear()
	details.append(
		"%s: %d successes; %s: %s."
		% [
			grappler.definition.display_name,
			attempt.attack_successes,
			heroine.definition.display_name,
			(
				"%d Dodge successes" % attempt.dodge_successes
				if dodge_chosen
				else "skipped"
			),
		]
	)
	if attempt.dodge_roll != null:
		details.append("Dodge dice: %s." % str(attempt.dodge_roll.final_rolls))
	if attempt.succeeded:
		details.append(
			"Stage 1 applied; Corruption %+d, Resolve %+d."
			% [attempt.stage_corruption_applied, attempt.stage_resolve_applied]
		)
	var summary: String = "%s failed to grapple %s." % [
		grappler.definition.display_name,
		heroine.definition.display_name,
	]
	if attempt.succeeded:
		summary = "%s grappled %s." % [
			grappler.definition.display_name,
			heroine.definition.display_name,
		]
	append(summary, "\n".join(details))


func log_struggle_result(
	heroine: BattlerState,
	grappler: BattlerState,
	result: GrappleActionResult
) -> void:
	if heroine == null or grappler == null or result == null:
		return
	var summary: String
	if result.detached:
		summary = "%s escaped %s." % [
			heroine.definition.display_name,
			grappler.definition.display_name,
		]
	elif result.succeeded:
		summary = "%s pushed %s's Grapple back to Stage %d." % [
			heroine.definition.display_name,
			grappler.definition.display_name,
			result.stage_after,
		]
	else:
		summary = "%s failed to escape %s." % [
			heroine.definition.display_name,
			grappler.definition.display_name,
		]
	var details: PackedStringArray = PackedStringArray()
	details.append(
		"%s: %d successes; %s: %d successes."
		% [
			heroine.definition.display_name,
			result.heroine_successes,
			grappler.definition.display_name,
			result.grappler_successes,
		]
	)
	details.append(
		"Stage %d → %d; Resolve %+d."
		% [result.stage_before, result.stage_after, result.resolve_applied]
	)
	if result.heroine_roll != null:
		details.append("Heroine dice: %s." % str(result.heroine_roll.final_rolls))
	if result.grappler_roll != null:
		details.append("Grappler dice: %s." % str(result.grappler_roll.final_rolls))
	append(summary, "\n".join(details))


func log_battle_outcome(
	state: BattleState
) -> void:
	match state.outcome:
		BattleState.Outcome.VICTORY:
			append("Victory.", "Every enemy is defeated.")
		BattleState.Outcome.DEFEAT:
			append(
				"Defeat.",
				"Every heroine is at zero HP.\n"
				+ "Full-wipe consequence: every participating heroine loses 15 Resolve."
			)


func log_battle_restarted() -> void:
	append(
		"Battle restarted.",
		"Battlers, equipment, statuses, Actions, Order, and Positions reset."
	)


func log_weapon_check(
	definition: BattlerDefinition,
	weapon: WeaponDefinition,
	result: RollResult
) -> void:
	var raw_rolls: Array[int] = result.get_all_rolls()
	var attribute_name: String = _get_attribute_name(
		weapon.attribute
	)
	var skill_name: String = _get_skill_name(
		weapon.skill
	)
	var tier_name: String = _get_skill_tier_name(
		result.skill_tier
	)

	append("")
	append(
		"%s attacks with %s."
		% [
			definition.display_name,
			weapon.display_name,
		]
	)
	append(
		"Check: %s with %s"
		% [
			skill_name,
			attribute_name,
		]
	)
	append(
		"Pool: %d dice | Seed: %d"
		% [
			result.dice_requested,
			result.seed_used,
		]
	)
	append(
		"Base dice: %s"
		% str(result.base_rolls)
	)

	if result.has_explosions():
		append(
			"Explosion dice: %s"
			% str(result.explosion_rolls)
		)
	else:
		append("Explosion dice: none")

	append(
		"Skill: Level %d, %s | Modifier: %d"
		% [
			result.skill_level,
			tier_name,
			result.skill_budget,
		]
	)

	if result.has_skill_modifications():
		for modification_index: int in range(
			result.modified_indices.size()
		):
			var die_index: int = result.modified_indices[
				modification_index
			]
			var bonus: int = result.modification_amounts[
				modification_index
			]

			if (
				die_index < 0
				or die_index >= raw_rolls.size()
				or die_index >= result.final_rolls.size()
			):
				push_error(
					"RollResult contains an invalid die index."
				)
				continue

			append(
				"Die %d: %d + %d -> %d"
				% [
					die_index + 1,
					raw_rolls[die_index],
					bonus,
					result.final_rolls[die_index],
				]
			)
	else:
		append("Skill modifications: none")

	append(
		"Final dice: %s"
		% str(result.final_rolls)
	)
	append(
		"Successes: %d -> %d"
		% [
			result.successes_before_skill,
			result.total_successes,
		]
	)


func log_generated_attack_failed(
	error_message: String
) -> void:
	append(
		"Generated Attack was not resolved: %s"
		% error_message
	)


func log_test_roll_mode_changed(
	mode_label: String
) -> void:
	append(
		"Test roll mode changed: %s."
		% mode_label
	)


func _get_defense_name(
	choice: DefenseChoice.Type
) -> String:
	match choice:
		DefenseChoice.Type.DODGE:
			return "Dodge"
		DefenseChoice.Type.ARMOR:
			return "Armor Defense"
		DefenseChoice.Type.SHIELD:
			return "Shield Defense"
		DefenseChoice.Type.PARRY:
			return "Parry"

	return "Defense"


func _append_reaction_action_log(
	result: ActionResult
) -> void:
	append(
		"Reaction Actions: %d -> %d"
		% [
			result.target_actions_before,
			result.target_actions_after,
		]
	)


func _get_attribute_name(
	attribute: AttributeSet.Attribute
) -> String:
	var attribute_keys: Array = AttributeSet.Attribute.keys()

	if (
		attribute < 0
		or attribute >= attribute_keys.size()
	):
		return "Unknown Attribute"

	return String(
		attribute_keys[attribute]
	).replace(
		"_",
		" "
	).capitalize()


func _get_skill_name(
	skill: SkillEntry.Skill
) -> String:
	var skill_keys: Array = SkillEntry.Skill.keys()

	if skill < 0 or skill >= skill_keys.size():
		return "Unknown Skill"

	return String(
		skill_keys[skill]
	).replace(
		"_",
		" "
	).capitalize()


func _get_skill_tier_name(
	tier: SkillEntry.Tier
) -> String:
	var tier_keys: Array = SkillEntry.Tier.keys()

	if tier < 0 or tier >= tier_keys.size():
		return "Unknown Tier"

	return String(
		tier_keys[tier]
	).replace(
		"_",
		" "
	).capitalize()
