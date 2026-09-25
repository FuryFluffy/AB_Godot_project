class_name GrappleController
extends RefCounted


const DEFAULT_UNARMED_GRAPPLE_WEAPON: WeaponDefinition = preload(
	"res://scripts/data/equipment/weapons/default_unarmed_grapple.tres"
)


var battler_states: Dictionary = {}
var battlefield_state: BattlefieldState
var targeting_controller: BattleTargetingController
var dice_resolver: DiceResolver

var tracks: Dictionary = {}
var pending_attempt: GrappleAttemptResult
var next_track_number: int = 1
var next_succession_order: int = 1
var seed_counter: int = 0
var base_seed: int = 1
var reconciling_defeats: bool = false


func initialize(
	new_battler_states: Dictionary,
	new_battlefield_state: BattlefieldState,
	new_targeting_controller: BattleTargetingController,
	new_dice_resolver: DiceResolver,
	new_base_seed: int = 1
) -> void:
	battler_states = new_battler_states
	battlefield_state = new_battlefield_state
	targeting_controller = new_targeting_controller
	dice_resolver = new_dice_resolver
	base_seed = new_base_seed
	reset()


func reset() -> void:
	tracks.clear()
	pending_attempt = null
	next_track_number = 1
	next_succession_order = 1
	seed_counter = 0

	for value: Variant in battler_states.values():
		var battler: BattlerState = value as BattlerState
		if battler == null:
			continue
		if not battler.state_changed.is_connected(
			_on_battler_state_changed.bind(battler)
		):
			battler.state_changed.connect(
				_on_battler_state_changed.bind(battler)
			)
		battler.active_grapple_track_ids.clear()
		battler.grapple_cluster_position_id = &""
		battler.grapple_cooldown_activations = 0
		battler.grapple_used_once = false
		battler.grapple_stage = 0
		battler.grapple_stage_count = 0


func get_track(
	track_id: StringName
) -> GrappleTrackState:
	return tracks.get(track_id) as GrappleTrackState


func has_active_tracks() -> bool:
	return not tracks.is_empty()


func is_full_party_defeated() -> bool:
	for value: Variant in battler_states.values():
		var battler: BattlerState = value as BattlerState
		if (
			battler != null
			and battler.definition != null
			and battler.definition.faction
			== BattlerDefinition.Faction.HEROINE
			and not battler.is_defeated
		):
			return false
	return true


func get_track_for_grappler(
	grappler_id: StringName
) -> GrappleTrackState:
	for value: Variant in tracks.values():
		var track: GrappleTrackState = value as GrappleTrackState
		if track != null and track.grappler_id == grappler_id:
			return track
	return null


func get_main_track_for_heroine(
	heroine_id: StringName
) -> GrappleTrackState:
	for value: Variant in tracks.values():
		var track: GrappleTrackState = value as GrappleTrackState
		if (
			track != null
			and track.heroine_id == heroine_id
			and track.is_main
		):
			return track
	return null


func get_tracks_for_heroine(
	heroine_id: StringName
) -> Array[GrappleTrackState]:
	var heroine_tracks: Array[GrappleTrackState] = []
	for value: Variant in tracks.values():
		var track: GrappleTrackState = value as GrappleTrackState
		if track != null and track.heroine_id == heroine_id:
			heroine_tracks.append(track)
	heroine_tracks.sort_custom(
		func(first: GrappleTrackState, second: GrappleTrackState) -> bool:
			if first.is_main != second.is_main:
				return first.is_main
			return first.succession_order < second.succession_order
	)
	return heroine_tracks


func get_cluster_participant_ids(
	heroine_id: StringName
) -> Array[StringName]:
	var participant_ids: Array[StringName] = [heroine_id]
	for track: GrappleTrackState in get_tracks_for_heroine(heroine_id):
		participant_ids.append(track.grappler_id)
	return participant_ids


func force_move_cluster(
	heroine_id: StringName,
	destination_anchor_id: StringName,
	destination_position_index: int
) -> String:
	var heroine: BattlerState = _get_battler(heroine_id)
	if heroine == null or not heroine.is_grappled():
		return "Forced cluster movement requires a grappled heroine."
	if battlefield_state == null or battlefield_state.definition == null:
		return "Battlefield state is unavailable."

	var destination_anchor: AnchorDefinition = (
		battlefield_state.definition.get_anchor(destination_anchor_id)
	)
	if destination_anchor == null:
		return "Forced-movement destination '%s' does not exist." % (
			destination_anchor_id
		)
	if (
		destination_position_index < 0
		or destination_position_index >= destination_anchor.capacity
	):
		return "Forced-movement Position %d is outside '%s'." % [
			destination_position_index,
			destination_anchor.display_name,
		]
	if battlefield_state.is_anchor_over_capacity(destination_anchor_id):
		return (
			"Forced cluster movement failed: '%s' is over capacity."
			% destination_anchor.display_name
		)

	var participant_ids: Array[StringName] = get_cluster_participant_ids(
		heroine_id
	)
	for participant_id: StringName in participant_ids:
		if _get_battler(participant_id) == null:
			return "Grapple cluster participant '%s' is unavailable." % (
				participant_id
			)

	var destination_occupants: Array[StringName] = (
		battlefield_state.get_battlers_at(
			destination_anchor_id,
			destination_position_index
		)
	)
	for participant_id: StringName in participant_ids:
		destination_occupants.erase(participant_id)
	if not destination_occupants.is_empty():
		return (
			"Forced cluster movement failed: '%s' Position %d is occupied."
			% [
				destination_anchor.display_name,
				destination_position_index + 1,
			]
		)

	var heroine_position: BattlerPositionState = (
		battlefield_state.get_battler_position(heroine_id)
	)
	if (
		heroine_position != null
		and heroine_position.anchor_id == destination_anchor_id
		and heroine_position.position_index
		== destination_position_index
	):
		return ""

	var placement_error: String = battlefield_state.place_battler(
		heroine_id,
		destination_anchor_id,
		destination_position_index
	)
	if not placement_error.is_empty():
		return placement_error

	for track: GrappleTrackState in get_tracks_for_heroine(heroine_id):
		var bundle_error: String = battlefield_state.bundle_battler_with(
			track.grappler_id,
			heroine_id
		)
		if not bundle_error.is_empty():
			return bundle_error
		var grappler: BattlerState = _get_battler(track.grappler_id)
		if grappler != null:
			grappler.grapple_cluster_position_id = StringName(
				"%s:%d" % [
					destination_anchor_id,
					destination_position_index,
				]
			)
			grappler.state_changed.emit()
	return ""


func force_separate_grappler(
	grappler_id: StringName
) -> GrappleActionResult:
	var result: GrappleActionResult = GrappleActionResult.new()
	result.action_name = "Forced Separation"
	var track: GrappleTrackState = get_track_for_grappler(grappler_id)
	if track == null:
		return result.fail("The selected battler has no active Grapple track.")
	var grappler: BattlerState = _get_battler(grappler_id)
	if grappler == null or grappler.is_defeated:
		return result.fail("Forced separation requires a living grappler.")

	result.track = track
	result.stage_before = track.get_stage_number()
	result.stage_after = 0
	_end_track(track, true)
	result.detached = true
	result.succeeded = true
	return result


func apply_item_track_effect(
	heroine_id: StringName,
	grappler_id: StringName,
	stage_reduction: int,
	force_detach: bool
) -> GrappleActionResult:
	var result: GrappleActionResult = GrappleActionResult.new()
	result.action_name = "Item Grapple Effect"
	var track: GrappleTrackState = get_track_for_grappler(
		grappler_id
	)
	if track == null or track.heroine_id != heroine_id:
		return result.fail(
			"The item target is not attached to its user."
		)

	result.track = track
	result.stage_before = track.get_stage_number()
	var should_detach: bool = (
		force_detach
		or maxi(stage_reduction, 0) >= result.stage_before
	)
	if should_detach:
		_end_track(track, true)
		result.stage_after = 0
		result.detached = true
		result.succeeded = true
		return result

	if stage_reduction <= 0:
		return result.fail(
			"The item has no positive Grapple-stage reduction."
		)

	# Resolve changes are deliberately not inferred here. The item definition
	# must author them as a separate effect.
	track.stage_index = maxi(
		track.stage_index - stage_reduction,
		0
	)
	track.current_stage_holds = 0
	result.stage_after = track.get_stage_number()
	_update_grappler_progress(track)
	result.succeeded = true
	return result


func get_participation_capacity(
	heroine_id: StringName
) -> int:
	var heroine: BattlerState = _get_battler(heroine_id)
	if heroine == null:
		return 0
	if heroine.current_corruption >= 60:
		return 3
	if heroine.current_corruption >= 30:
		return 2
	return 1


func can_attach_secondary(
	grappler_id: StringName,
	heroine_id: StringName,
	template_override: GrappleTemplateDefinition = null,
	move_action_paid: bool = false
) -> bool:
	return _validate_secondary_attachment(
		_get_battler(grappler_id),
		_get_battler(heroine_id),
		template_override,
		move_action_paid
	).is_empty()


func attach_secondary(
	grappler_id: StringName,
	heroine_id: StringName,
	template_override: GrappleTemplateDefinition = null,
	move_action_paid: bool = false
) -> GrappleActionResult:
	var result: GrappleActionResult = GrappleActionResult.new()
	result.action_name = "Attach"
	var grappler: BattlerState = _get_battler(grappler_id)
	var heroine: BattlerState = _get_battler(heroine_id)
	var validation_error: String = _validate_secondary_attachment(
		grappler,
		heroine,
		template_override,
		move_action_paid
	)
	if not validation_error.is_empty():
		return result.fail(validation_error)

	var template: GrappleTemplateDefinition = template_override
	if template == null:
		template = grappler.definition.grapple_template
	result.actions_spent = grappler.current_actions
	grappler.set_current_actions(0)

	var track: GrappleTrackState = _create_track(
		heroine,
		grappler,
		template,
		false
	)
	if track == null:
		return result.fail("The secondary Grapple track could not be created.")

	result.track = track
	result.stage_before = 0
	result.stage_after = track.get_stage_number()
	result.succeeded = true
	return result


func has_pending_initiation() -> bool:
	return pending_attempt != null


func can_initiate(
	grappler_id: StringName,
	heroine_id: StringName
) -> bool:
	if pending_attempt != null or targeting_controller == null:
		return false
	var grappler: BattlerState = _get_battler(grappler_id)
	var heroine: BattlerState = _get_battler(heroine_id)
	if not _validate_initiation(grappler, heroine).is_empty():
		return false

	var weapon: WeaponDefinition = _get_grapple_weapon(grappler)
	var targeting: AttackTargetingResult = (
		targeting_controller.evaluate_attack(
			grappler_id,
			heroine_id,
			weapon,
			false
		)
	)
	return targeting.is_legal


func get_legal_initiation_target_ids(
	grappler_id: StringName
) -> Array[StringName]:
	var target_ids: Array[StringName] = []
	for value: Variant in battler_states.values():
		var target: BattlerState = value as BattlerState
		if (
			target == null
			or target.definition == null
			or target.definition.faction
			!= BattlerDefinition.Faction.HEROINE
		):
			continue
		if can_initiate(
			grappler_id,
			target.definition.battler_id
		):
			target_ids.append(target.definition.battler_id)
	target_ids.sort()
	return target_ids


func get_legal_grapple_action_target_ids(
	grappler_id: StringName
) -> Array[StringName]:
	var target_ids: Array[StringName] = []
	for value: Variant in battler_states.values():
		var heroine: BattlerState = value as BattlerState
		if (
			heroine == null
			or heroine.definition == null
			or heroine.definition.faction
			!= BattlerDefinition.Faction.HEROINE
		):
			continue
		var heroine_id: StringName = heroine.definition.battler_id
		if not heroine.is_grappled():
			if can_initiate(grappler_id, heroine_id):
				target_ids.append(heroine_id)
			continue
		if (
			can_attach_secondary(grappler_id, heroine_id)
			and _shares_position(grappler_id, heroine_id)
		):
			target_ids.append(heroine_id)
	target_ids.sort()
	return target_ids


func can_hold_track(
	grappler_id: StringName
) -> bool:
	var track: GrappleTrackState = get_track_for_grappler(grappler_id)
	var grappler: BattlerState = _get_battler(grappler_id)
	return (
		track != null
		and grappler != null
		and grappler.current_actions > 0
		and not grappler.is_stunned()
		and not is_full_party_defeated()
		and track.can_hold()
	)


func can_progress_track(
	grappler_id: StringName
) -> bool:
	var track: GrappleTrackState = get_track_for_grappler(grappler_id)
	var grappler: BattlerState = _get_battler(grappler_id)
	return (
		track != null
		and grappler != null
		and grappler.current_actions > 0
		and not grappler.is_stunned()
		and track.can_progress()
	)


func prepare_initiation(
	grappler_id: StringName,
	heroine_id: StringName,
	is_move_reaction: bool = false
) -> GrappleAttemptResult:
	var result: GrappleAttemptResult = GrappleAttemptResult.new()
	result.actor_id = grappler_id
	result.target_id = heroine_id
	result.is_move_reaction = is_move_reaction

	if pending_attempt != null:
		return result.fail("Another Grapple attempt is already pending.")
	if dice_resolver == null:
		return result.fail("DiceResolver is missing.")

	var grappler: BattlerState = _get_battler(grappler_id)
	var heroine: BattlerState = _get_battler(heroine_id)
	var validation_error: String = _validate_initiation(
		grappler,
		heroine
	)
	if not validation_error.is_empty():
		return result.fail(validation_error)

	var template: GrappleTemplateDefinition = (
		grappler.definition.grapple_template
	)
	var weapon: WeaponDefinition = _get_grapple_weapon(grappler)
	var targeting: AttackTargetingResult = (
		targeting_controller.evaluate_attack(
			grappler_id,
			heroine_id,
			weapon,
			false
		)
	)
	if not targeting.is_legal:
		return result.fail(targeting.error_message)

	result.template = template
	result.corruption_snapshot = heroine.current_corruption
	result.resolve_snapshot = heroine.current_resolve
	result.rolled_pool = _get_grapple_pool(
		grappler,
		weapon,
		targeting.attack_dice_modifier,
		result.corruption_snapshot,
		result.resolve_snapshot
	)
	result.attack_roll = _roll_weapon_check(
		grappler,
		weapon,
		result.rolled_pool,
		_next_seed()
	)
	result.attack_successes = (
		result.attack_roll.total_successes
		+ result.automatic_successes
	)

	if not grappler.spend_actions(1):
		return result.fail("%s could not spend the Grapple Action." % (
			grappler.definition.display_name
		))
	result.action_spent = 1
	pending_attempt = result
	return result


func resolve_initiation(
	dodge: bool
) -> GrappleAttemptResult:
	if pending_attempt == null:
		return GrappleAttemptResult.new().fail(
			"No Grapple attempt is pending."
		)

	var result: GrappleAttemptResult = pending_attempt
	var grappler: BattlerState = _get_battler(result.actor_id)
	var heroine: BattlerState = _get_battler(result.target_id)

	if grappler == null or heroine == null:
		pending_attempt = null
		return result.fail("A Grapple participant no longer exists.")

	if dodge and heroine.current_actions > 0 and not heroine.is_defeated:
		heroine.spend_actions(1)
		result.dodge_action_spent = 1
		var dodge_pool: int = maxi(
			heroine.definition.attributes.get_value(
				AttributeSet.Attribute.AGILITY
			)
			+ heroine.get_armor_dodge_modifier()
			+ heroine.get_shield_dodge_modifier(),
			0
		)
		result.dodge_roll = dice_resolver.roll_attribute(
			dodge_pool,
			_next_seed()
		)
		result.dodge_successes = result.dodge_roll.total_successes

	result.remaining_successes = maxi(
		result.attack_successes - result.dodge_successes,
		0
	)
	result.succeeded = result.remaining_successes >= 1
	result.is_complete = true

	if result.succeeded:
		# Ordinary initiation forfeits every remaining Action. A Grapple
		# Reaction is the locked exception: its one-Action cost was already
		# paid during prepare_initiation(), and the reactor retains the rest.
		if not result.is_move_reaction:
			grappler.set_current_actions(0)
		var track: GrappleTrackState = _create_initial_track(
			heroine,
			grappler,
			result.template
		)
		result.track = track
		if track == null:
			result.succeeded = false
			result.error_message = "The Grapple track could not be created."
		else:
			var stage_effects: Vector2i = _apply_stage_effects(track)
			result.stage_corruption_applied = stage_effects.x
			result.stage_resolve_applied = stage_effects.y

	pending_attempt = null
	return result


func progress_track(
	grappler_id: StringName
) -> GrappleActionResult:
	var result: GrappleActionResult = GrappleActionResult.new()
	result.action_name = "Progress"
	var track: GrappleTrackState = get_track_for_grappler(grappler_id)
	var grappler: BattlerState = _get_battler(grappler_id)
	if track == null or grappler == null:
		return result.fail("The grappler has no active track.")
	if grappler.current_actions <= 0 or grappler.is_stunned():
		return result.fail("The grappler cannot Progress with zero Actions.")
	if not track.can_progress():
		return result.fail("The track has no later stage.")

	result.track = track
	result.stage_before = track.get_stage_number()
	result.actions_spent = grappler.current_actions
	grappler.set_current_actions(0)
	track.progress()
	result.stage_after = track.get_stage_number()

	if track.is_main:
		var stage_effects: Vector2i = _apply_stage_effects(track)
		result.corruption_applied = stage_effects.x
		result.resolve_applied = stage_effects.y

	result.climax_reached = track.is_at_climax()
	_update_grappler_progress(track)
	result.succeeded = true
	if result.climax_reached:
		_resolve_climax(track, result)
	return result


func hold_track(
	grappler_id: StringName
) -> GrappleActionResult:
	var result: GrappleActionResult = GrappleActionResult.new()
	result.action_name = "Hold"
	var track: GrappleTrackState = get_track_for_grappler(grappler_id)
	var grappler: BattlerState = _get_battler(grappler_id)
	if track == null or grappler == null:
		return result.fail("The grappler has no active track.")
	if grappler.current_actions <= 0 or grappler.is_stunned():
		return result.fail("The grappler cannot Hold with zero Actions.")
	if not track.can_hold():
		return result.fail("This stage has no Hold allowance remaining.")

	result.track = track
	result.stage_before = track.get_stage_number()
	result.stage_after = result.stage_before
	result.actions_spent = grappler.current_actions
	grappler.set_current_actions(0)
	track.record_hold()

	if track.is_main:
		var stage_effects: Vector2i = _apply_stage_effects(track)
		result.corruption_applied = stage_effects.x
		result.resolve_applied = stage_effects.y

	result.succeeded = true
	return result


func struggle(
	heroine_id: StringName,
	attribute: AttributeSet.Attribute,
	seed_value: int = -1
) -> GrappleActionResult:
	var track: GrappleTrackState = get_main_track_for_heroine(heroine_id)
	return struggle_track(heroine_id, track.track_id if track != null else &"", attribute, seed_value)


func struggle_track(
	heroine_id: StringName,
	track_id: StringName,
	attribute: AttributeSet.Attribute,
	seed_value: int = -1
) -> GrappleActionResult:
	var result: GrappleActionResult = GrappleActionResult.new()
	result.action_name = "Struggle"
	var track: GrappleTrackState = get_track(track_id)
	var heroine: BattlerState = _get_battler(heroine_id)
	if (
		track == null
		or heroine == null
		or track.heroine_id != heroine_id
	):
		return result.fail("The heroine has no active Grapple track.")
	if heroine.current_actions <= 0 or heroine.is_stunned():
		return result.fail("Struggle requires at least one available Action.")

	var grappler: BattlerState = _get_battler(track.grappler_id)
	if grappler == null:
		return result.fail("The grappler no longer exists.")

	result.track = track
	result.stage_before = track.get_stage_number()
	result.actions_spent = heroine.current_actions
	heroine.set_current_actions(0)

	var other_grapplers: int = maxi(
		heroine.active_grapple_track_ids.size() - 1,
		0
	)
	var heroine_pool: int = heroine.definition.attributes.get_value(attribute)
	var grappler_pool: int = (
		grappler.definition.attributes.get_value(attribute)
		+ other_grapplers
	)
	var first_seed: int = (
		seed_value
		if seed_value >= 0
		else _next_seed()
	)
	result.heroine_roll = dice_resolver.roll_attribute(
		heroine_pool,
		first_seed
	)
	result.grappler_roll = dice_resolver.roll_attribute(
		grappler_pool,
		first_seed + 1
	)
	result.heroine_successes = result.heroine_roll.total_successes
	result.grappler_successes = result.grappler_roll.total_successes

	if result.heroine_successes <= result.grappler_successes:
		result.stage_after = result.stage_before
		return result

	var undone_stage: GrappleStageDefinition = track.get_current_stage()
	if (
		track.is_main
		and undone_stage != null
		and undone_stage.resolve_change < 0
	):
		result.resolve_applied = heroine.change_resolve(
			abs(undone_stage.resolve_change)
		)

	if track.stage_index == 0:
		_end_track(track, true)
		result.detached = true
		result.stage_after = 0
	else:
		track.stage_index -= 1
		track.current_stage_holds = 0
		result.stage_after = track.get_stage_number()

	result.succeeded = true
	return result


func wait(
	heroine_id: StringName
) -> GrappleActionResult:
	var result: GrappleActionResult = GrappleActionResult.new()
	result.action_name = "Wait"
	var heroine: BattlerState = _get_battler(heroine_id)
	if heroine == null or not heroine.is_grappled():
		return result.fail("The heroine is not grappled.")
	if heroine.current_actions <= 0 or heroine.is_stunned():
		return result.fail("Wait requires at least one available Action.")

	result.actions_spent = heroine.current_actions
	heroine.set_current_actions(0)
	result.succeeded = true
	return result


func _validate_initiation(
	grappler: BattlerState,
	heroine: BattlerState
) -> String:
	if grappler == null or grappler.definition == null:
		return "The grappler is invalid."
	if heroine == null or heroine.definition == null:
		return "The Grapple target is invalid."
	if grappler.is_defeated or grappler.current_actions <= 0:
		return "%s cannot pay the Grapple Action." % (
			grappler.definition.display_name
		)
	if grappler.definition.faction != BattlerDefinition.Faction.ENEMY:
		return "Only an enemy can initiate this Grapple."
	if heroine.definition.faction != BattlerDefinition.Faction.HEROINE:
		return "Grapple requires a heroine target."
	if is_full_party_defeated():
		return "No new Grapple may begin after a full party knockdown."
	if grappler.definition.grapple_template == null:
		return "%s has no Grapple template." % (
			grappler.definition.display_name
		)
	var template_error: String = (
		grappler.definition.grapple_template.validate_definition()
	)
	if not template_error.is_empty():
		return template_error
	if grappler.grapple_cooldown_activations > 0:
		return "%s is on Grapple cooldown." % (
			grappler.definition.display_name
		)
	if (
		grappler.definition.grapple_template.one_use_only
		and grappler.grapple_used_once
	):
		return "%s has already used its one Grapple." % (
			grappler.definition.display_name
		)
	if get_track_for_grappler(grappler.definition.battler_id) != null:
		return "%s is already attached." % (
			grappler.definition.display_name
		)
	if heroine.is_grappled():
		return "Use secondary attachment for an existing Grapple cluster."
	var template: GrappleTemplateDefinition = (
		grappler.definition.grapple_template
	)
	if heroine.is_defeated and not template.can_target_defeated_heroines:
		return "%s cannot Grapple a defeated heroine." % (
			grappler.definition.display_name
		)
	if _get_grapple_weapon(grappler) == null:
		return "%s has no legal Grapple weapon." % (
			grappler.definition.display_name
		)
	return ""


func _get_grapple_weapon(
	grappler: BattlerState
) -> WeaponDefinition:
	if grappler == null:
		return null

	var main_hand: WeaponDefinition = (
		grappler.get_usable_main_hand_weapon()
	)
	if (
		main_hand != null
		and main_hand.attack_range
		!= WeaponDefinition.AttackRange.RANGED
	):
		return main_hand

	# Ranged weapons may contribute to ordinary Attacks, but they never turn
	# Grapple into a ranged action. A broken, missing, or ranged main hand
	# falls through to the battler's ordinary Unarmed/Might Grapple check.
	return DEFAULT_UNARMED_GRAPPLE_WEAPON


func _validate_secondary_attachment(
	grappler: BattlerState,
	heroine: BattlerState,
	template_override: GrappleTemplateDefinition,
	move_action_paid: bool
) -> String:
	if grappler == null or grappler.definition == null:
		return "The attaching grappler is invalid."
	if heroine == null or heroine.definition == null:
		return "The Grapple cluster owner is invalid."
	if grappler.is_defeated:
		return "%s is defeated." % grappler.definition.display_name
	if not move_action_paid and grappler.current_actions <= 0:
		return "%s cannot pay the attachment Action." % (
			grappler.definition.display_name
		)
	if grappler.definition.faction != BattlerDefinition.Faction.ENEMY:
		return "Only an enemy can attach to this Grapple cluster."
	if heroine.definition.faction != BattlerDefinition.Faction.HEROINE:
		return "A Grapple cluster must belong to a heroine."
	if is_full_party_defeated():
		return "No enemy may attach after a full party knockdown."
	if not heroine.is_grappled():
		return "%s has no Grapple cluster." % heroine.definition.display_name
	if get_track_for_grappler(grappler.definition.battler_id) != null:
		return "%s is already attached." % grappler.definition.display_name
	if (
		heroine.active_grapple_track_ids.size()
		>= get_participation_capacity(heroine.definition.battler_id)
	):
		return "%s has no free Grapple participation slot." % (
			heroine.definition.display_name
		)
	var template: GrappleTemplateDefinition = template_override
	if template == null:
		template = grappler.definition.grapple_template
	if template == null:
		return "%s has no Grapple template." % (
			grappler.definition.display_name
		)
	var template_error: String = template.validate_definition()
	if not template_error.is_empty():
		return template_error
	if grappler.grapple_cooldown_activations > 0:
		return "%s is on Grapple cooldown." % (
			grappler.definition.display_name
		)
	if template.one_use_only and grappler.grapple_used_once:
		return "%s has already used its one Grapple." % (
			grappler.definition.display_name
		)
	return ""


func _get_grapple_pool(
	grappler: BattlerState,
	weapon: WeaponDefinition,
	spatial_modifier: int,
	corruption: int,
	resolve: int
) -> int:
	var attribute_value: int = grappler.definition.attributes.get_value(
		weapon.attribute
	)
	return maxi(
		attribute_value
		+ weapon.dice_modifier
		+ spatial_modifier
		+ floori(float(corruption) / 10.0)
		- floori(float(resolve) / 10.0),
		1
	)


func _roll_weapon_check(
	grappler: BattlerState,
	weapon: WeaponDefinition,
	dice_count: int,
	seed_value: int
) -> RollResult:
	var skill: SkillEntry = grappler.definition.get_skill_entry(
		weapon.skill
	)
	return dice_resolver.roll_check(
		dice_count,
		skill.level if skill != null else 0,
		skill.tier if skill != null else SkillEntry.Tier.UNTRAINED,
		seed_value
	)


func _create_initial_track(
	heroine: BattlerState,
	grappler: BattlerState,
	template: GrappleTemplateDefinition
) -> GrappleTrackState:
	return _create_track(heroine, grappler, template, true)


func _create_track(
	heroine: BattlerState,
	grappler: BattlerState,
	template: GrappleTemplateDefinition,
	is_main: bool
) -> GrappleTrackState:
	var track_id: StringName = StringName(
		"grapple_%d" % next_track_number
	)
	next_track_number += 1
	var track: GrappleTrackState = GrappleTrackState.new(
		track_id,
		heroine.definition.battler_id,
		grappler.definition.battler_id,
		template,
		is_main,
		next_succession_order
	)
	next_succession_order += 1

	var bundle_error: String = battlefield_state.bundle_battler_with(
		grappler.definition.battler_id,
		heroine.definition.battler_id
	)
	if not bundle_error.is_empty():
		push_error(bundle_error)
		return null

	tracks[track_id] = track
	heroine.add_grapple_track(track_id)
	grappler.active_grapple_track_ids.clear()
	grappler.active_grapple_track_ids.append(track_id)
	grappler.grapple_cluster_position_id = StringName(
		"%s:%d" % [
			battlefield_state.get_battler_position(
				heroine.definition.battler_id
			).anchor_id,
			battlefield_state.get_battler_position(
				heroine.definition.battler_id
			).position_index,
		]
	)
	grappler.grapple_used_once = true
	_update_grappler_progress(track)
	grappler.state_changed.emit()
	return track


func _apply_stage_effects(
	track: GrappleTrackState
) -> Vector2i:
	if track == null or not track.is_main:
		return Vector2i.ZERO
	var stage: GrappleStageDefinition = track.get_current_stage()
	var heroine: BattlerState = _get_battler(track.heroine_id)
	if stage == null or heroine == null:
		return Vector2i.ZERO

	return Vector2i(
		heroine.change_corruption(stage.corruption_change),
		heroine.change_resolve(stage.resolve_change)
	)


func _resolve_climax(
	track: GrappleTrackState,
	result: GrappleActionResult
) -> void:
	var grappler: BattlerState = _get_battler(track.grappler_id)
	if grappler == null:
		_end_track(track, false)
		return

	var climax_damage: int = maxi(
		ceili(float(grappler.get_max_hp()) * 0.15),
		1
	)
	grappler.apply_damage(climax_damage)
	_end_track(track, not grappler.is_defeated)
	result.detached = true


func _end_track(
	track: GrappleTrackState,
	place_surviving_grappler: bool
) -> void:
	if track == null or not tracks.has(track.track_id):
		return
	var heroine: BattlerState = _get_battler(track.heroine_id)
	var grappler: BattlerState = _get_battler(track.grappler_id)

	tracks.erase(track.track_id)
	if heroine != null:
		heroine.remove_grapple_track(track.track_id)
	if grappler != null:
		grappler.active_grapple_track_ids.erase(track.track_id)
		grappler.grapple_cluster_position_id = &""
		grappler.grapple_stage = 0
		grappler.grapple_stage_count = 0
		if not grappler.is_defeated:
			grappler.begin_grapple_cooldown(
				track.template.grapple_cooldown_activations
			)
		if place_surviving_grappler and not grappler.is_defeated:
			_place_detached_grappler(grappler, heroine)
		grappler.state_changed.emit()

	if track.is_main:
		_promote_successor(track.heroine_id)


func _update_grappler_progress(
	track: GrappleTrackState
) -> void:
	if track == null:
		return
	var grappler: BattlerState = _get_battler(track.grappler_id)
	if grappler == null:
		return
	grappler.grapple_stage = track.get_stage_number()
	grappler.grapple_stage_count = track.get_stage_count()
	grappler.state_changed.emit()


func _promote_successor(
	heroine_id: StringName
) -> GrappleTrackState:
	if get_main_track_for_heroine(heroine_id) != null:
		return null

	var candidates: Array[GrappleTrackState] = (
		get_tracks_for_heroine(heroine_id)
	)
	if candidates.is_empty():
		return null
	candidates.sort_custom(
		func(first: GrappleTrackState, second: GrappleTrackState) -> bool:
			if first.stage_index != second.stage_index:
				return first.stage_index > second.stage_index
			return first.succession_order < second.succession_order
	)
	var promoted: GrappleTrackState = candidates[0]
	promoted.is_main = true
	_update_grappler_progress(promoted)
	return promoted


func _on_battler_state_changed(
	battler: BattlerState
) -> void:
	if (
		reconciling_defeats
		or battler == null
		or not battler.is_defeated
		or not battler.is_attached_grappler()
	):
		return
	var track: GrappleTrackState = get_track_for_grappler(
		battler.definition.battler_id
	)
	if track == null:
		return
	reconciling_defeats = true
	_end_track(track, false)
	reconciling_defeats = false


func _place_detached_grappler(
	grappler: BattlerState,
	heroine: BattlerState
) -> void:
	if grappler == null or heroine == null:
		return
	var heroine_position: BattlerPositionState = (
		battlefield_state.get_battler_position(
			heroine.definition.battler_id
		)
	)
	if heroine_position == null:
		return

	var free_here: Array[int] = battlefield_state.get_free_position_indices(
		heroine_position.anchor_id,
		grappler.definition.battler_id
	)
	if not free_here.is_empty():
		var nearest_here: int = _get_nearest_position_index(
			heroine_position.anchor_id,
			free_here,
			battlefield_state.get_world_position(
				heroine.definition.battler_id
			)
		)
		battlefield_state.place_battler(
			grappler.definition.battler_id,
			heroine_position.anchor_id,
			nearest_here
		)
		return

	var anchor: AnchorDefinition = battlefield_state.definition.get_anchor(
		heroine_position.anchor_id
	)
	if anchor == null:
		return
	for connected_id: StringName in anchor.connected_anchor_ids:
		var free_connected: Array[int] = (
			battlefield_state.get_free_position_indices(
				connected_id,
				grappler.definition.battler_id
			)
		)
		if free_connected.is_empty():
			continue
		var nearest_connected: int = _get_nearest_position_index(
			connected_id,
			free_connected,
			battlefield_state.get_world_position(
				heroine.definition.battler_id
			)
		)
		battlefield_state.place_battler(
			grappler.definition.battler_id,
			connected_id,
			nearest_connected
		)
		return

	battlefield_state.force_place_battler_over_capacity(
		grappler.definition.battler_id,
		heroine_position.anchor_id,
		heroine_position.position_index
	)


func _get_nearest_position_index(
	anchor_id: StringName,
	candidate_indices: Array[int],
	source_point: Vector2
) -> int:
	var anchor: AnchorDefinition = battlefield_state.definition.get_anchor(
		anchor_id
	)
	if anchor == null or candidate_indices.is_empty():
		return -1
	var nearest_index: int = candidate_indices[0]
	var nearest_distance: float = source_point.distance_squared_to(
		anchor.get_position_point(nearest_index)
	)
	for candidate_index: int in candidate_indices:
		var candidate_distance: float = source_point.distance_squared_to(
			anchor.get_position_point(candidate_index)
		)
		if (
			candidate_distance < nearest_distance
			or (
				is_equal_approx(candidate_distance, nearest_distance)
				and candidate_index < nearest_index
			)
		):
			nearest_index = candidate_index
			nearest_distance = candidate_distance
	return nearest_index


func _get_battler(
	battler_id: StringName
) -> BattlerState:
	return battler_states.get(battler_id) as BattlerState


func _shares_position(
	first_id: StringName,
	second_id: StringName
) -> bool:
	var first: BattlerPositionState = (
		battlefield_state.get_battler_position(first_id)
	)
	var second: BattlerPositionState = (
		battlefield_state.get_battler_position(second_id)
	)
	return (
		first != null
		and second != null
		and first.anchor_id == second.anchor_id
		and first.position_index == second.position_index
	)


func _next_seed() -> int:
	var value: int = base_seed + seed_counter
	seed_counter += 1
	return value
