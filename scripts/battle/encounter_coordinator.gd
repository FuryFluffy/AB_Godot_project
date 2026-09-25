class_name CombatEncounter
extends Node


signal encounter_outcome_ready(outcome: EncounterOutcome)


const MOVE_STEP_POSE_LEAD_SECONDS: float = 0.1
const MOVE_STEP_FADE_OUT_SECONDS: float = 0.15
const MOVE_STEP_FADE_IN_SECONDS: float = 0.18
const MOVE_STEP_POSE_HOLD_SECONDS: float = 0.08


@export_group("Battle Composition")
@export var battler_catalog: BattlerCatalogDefinition
@export var default_encounter_template: EncounterTemplateDefinition
@export var battlefield_host: Node
@export var marker_host: Node2D
@export var marker_factory: BattleMarkerFactory
@export var combat_stage_catalog: CombatStageCatalog
@export var combat_stage_presenter: CombatStagePresenter


var attack_button: Button
var move_button: Button
var aoe_button: Button
var struggle_button: Button
var grapple_wait_button: Button
var submit_button: Button
var struggle_panel: StrugglePanel
var ability_panel: AbilityPanel
@export var battlefield_input_overlay: BattlefieldInteractionOverlay


@export_group("Items")
@export var item_catalog: ItemCatalogDefinition


@export var base_seed: int = 12345
@export var developer_grant_weapon_techniques_when_run_directly: bool = true


@export var battlefield_overlay: BattlefieldOverlay
@export_group("Reusable Runtime")
@export var combat_engine: CombatEngine
@export var combat_presenter: CombatPresenter
@export var reusable_hud: ReusableCombatHUD


var battler_states: Dictionary = {}
var battler_markers: Array[BattleMarker] = []
var battlefield_definition: BattlefieldDefinition
var enemy_group_rulebook: EnemyGroupRulebookDefinition
var active_battlefield: AuthoredBattlefield
var active_combat_stage: CombatStageDefinition
var composed_battler_definitions: Array[BattlerDefinition] = []

var battle_bootstrap: BattleBootstrap
var battle_runtime: BattleRuntimeState
var battle_flow_controller: BattleFlowController
var action_controller: BattleActionController
var log_presenter: BattleLogPresenter

var dice_resolver: DiceResolver
var attack_resolver: AttackResolver

var battlefield_state: BattlefieldState
var movement_controller: BattleMovementController
var targeting_controller: BattleTargetingController
var enemy_ai_controller: EnemyAIController
var status_controller: StatusController
var aoe_controller: AoeActionController
var ability_controller: AbilityActionController
var lifecycle_controller: BattleLifecycleController
var grapple_controller: GrappleController
var item_inventory: SixSlotInventoryState
var item_use_controller: ItemUseController
var dodge_step_controller: DodgeStepController

var enemy_ai_advancing: bool = false
var pending_player_move_reaction: bool = false
var pending_player_move_reactor_id: StringName = &""
var pending_grapple_move_reaction: bool = false
var commands_locked: bool = false
var pending_struggle_heroine_id: StringName = &""
var marker_layout_refresh_scheduled: bool = false
var marker_orientation_refresh_scheduled: bool = false
var pending_encounter_definition: EncounterDefinition
var pending_party_snapshot: Dictionary = {}
var pending_inventory_snapshot: Array[Dictionary] = []
var pending_heroine_progression_snapshot: Dictionary = {}
var pending_run_equipment: RunEquipmentState
var encounter_outcome_emitted: bool = false
var pending_dodge_attacker: BattlerState
var pending_dodge_target: BattlerState
var pending_dodge_result: ActionResult
var pending_grapple_dodge_attempt: GrappleAttemptResult
var resolving_dodge_step: bool = false
var encounter_starting: bool = false
var combat_progression_queued: bool = false
var combat_progression_running: bool = false

const GRAPPLE_CLUSTER_MARKER_SPACING: float = 170.0
const GRAPPLE_CLUSTER_GRAPPLER_Y: float = -45.0
const GRAPPLE_CLUSTER_HEROINE_Y: float = 45.0
const OVER_CAPACITY_MARKER_OFFSET: Vector2 = Vector2(170.0, 55.0)


func _input(event: InputEvent) -> void:
	if not _is_cancel_input(event):
		return
	if not _cancel_current_interaction():
		return
	get_viewport().set_input_as_handled()


func _is_cancel_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return (
			key_event.pressed
			and not key_event.echo
			and key_event.keycode == KEY_ESCAPE
		)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_RIGHT
		)
	return false


func _ready() -> void:
	log_presenter = BattleLogPresenter.new()
	log_presenter.clear()

	var composition_error: String = _prepare_battle_composition()
	if not composition_error.is_empty():
		push_error(
			"Battle composition failed: %s" % composition_error
		)
		return
	var engine_error: String = _initialize_combat_engine()
	if not engine_error.is_empty():
		push_error(
			"Reusable CombatEngine initialization failed: %s"
			% engine_error
		)
		return
	battle_runtime.battle_state.state_changed.connect(
		_queue_combat_progression
	)

	_apply_pending_run_snapshot()
	combat_engine.capture_inventory_checkpoint()

	_create_dynamic_battler_markers()
	_bind_battler_markers()
	_initialize_spatial_presentation()
	_initialize_reusable_presentation()

	_connect_aoe_controls()
	_connect_move_controls()
	_connect_grapple_runtime_controls()
	enemy_ai_controller.set_difficulty(
		EnemyAIController.Difficulty.STANDARD
	)

	var selected_state: BattlerState = get_battler_state(
		battle_runtime.selected_battler_id
	)

	log_presenter.log_encounter_ready(selected_state)
	log_presenter.append(
		"Spatial battlefield ready: %s."
		% battlefield_definition.display_name
	)
	log_presenter.append(
		"Enemy rulebooks ready: %s."
		% (
			enemy_group_rulebook.display_name
			if enemy_group_rulebook != null
			else "MISSING"
		)
	)
	log_presenter.append(
		"Ordinary combat systems ready: AOE, statuses, outcomes, Revival, and runtime controls."
	)
	log_presenter.append(
		"Grapple multi-tracks ready: attachment, independent progress, Struggle selection, and succession."
	)
	log_presenter.append(
		"Six-slot Item Bar ready: 33 catalog definitions (32 canonical plus one legacy), targeting, costs, stacks, and explicit Grapple hooks."
	)
	log_presenter.log_encounter_setup()
	if pending_encounter_definition != null:
		log_presenter.append(
			"%s encounter: %s (%d enemy/enemies)."
			% [
				pending_encounter_definition.difficulty_label,
				_get_battler_name_list(
					pending_encounter_definition.enemy_ids
				),
				pending_encounter_definition.get_enemy_count(),
			]
		)
	_refresh_battle_flow_ui()


func prepare_run_encounter(
	encounter: EncounterDefinition,
	party_snapshot: Dictionary,
	inventory_snapshot: Array[Dictionary],
	heroine_progression_snapshot: Dictionary = {},
	run_equipment: RunEquipmentState = null
) -> void:
	pending_encounter_definition = encounter
	pending_party_snapshot = party_snapshot.duplicate(true)
	pending_inventory_snapshot = inventory_snapshot.duplicate(true)
	pending_heroine_progression_snapshot = (
		heroine_progression_snapshot.duplicate(true)
	)
	pending_run_equipment = run_equipment
	encounter_outcome_emitted = false


func get_battler_state(
	battler_id: StringName
) -> BattlerState:
	return battler_states.get(
		battler_id
	) as BattlerState


func get_scene_background_texture() -> Texture2D:
	if active_battlefield == null:
		return null
	var background := active_battlefield.get_node_or_null(
		"BackgroundLayer/BackgroundArt"
	) as Sprite2D
	if background == null:
		background = active_battlefield.find_child(
			"BackgroundArt",
			true,
			false
		) as Sprite2D
	return background.texture if background != null else null


func _prepare_battle_composition() -> String:
	if battler_catalog == null:
		return "BattlerCatalogDefinition is missing."
	if battlefield_host == null:
		return "BattlefieldHost is missing."
	if marker_host == null or marker_factory == null:
		return "Dynamic BattleMarker composition is incomplete."

	if pending_encounter_definition == null:
		pending_encounter_definition = EncounterDefinition.new()
		pending_encounter_definition.encounter_id = &"direct_preview"
		pending_encounter_definition.display_name = "Direct Combat Preview"
		pending_encounter_definition.encounter_seed = base_seed
		if default_encounter_template != null:
			pending_encounter_definition.enemy_ids = (
				default_encounter_template.preview_enemy_ids.duplicate()
			)
	if pending_encounter_definition.template == null:
		pending_encounter_definition.template = default_encounter_template
	var assignment_error: String = (
		pending_encounter_definition.ensure_spawn_assignments()
	)
	if not assignment_error.is_empty():
		return assignment_error

	var battler_ids: Array[StringName] = (
		pending_encounter_definition.get_all_battler_ids()
	)
	composed_battler_definitions = battler_catalog.resolve_battlers(
		battler_ids
	)
	if composed_battler_definitions.size() != battler_ids.size():
		for battler_id: StringName in battler_ids:
			if battler_catalog.get_battler(battler_id) == null:
				return "Encounter requested missing battler '%s'." % battler_id

	var battlefield_scene: PackedScene = (
		pending_encounter_definition.template.battlefield_scene
	)
	active_battlefield = (
		battlefield_scene.instantiate() as AuthoredBattlefield
	)
	if active_battlefield == null:
		return "Encounter battlefield scene is not an AuthoredBattlefield."
	battlefield_host.add_child(active_battlefield)
	if combat_stage_catalog != null:
		active_combat_stage = combat_stage_catalog.resolve_stage_for_encounter(
			pending_encounter_definition.encounter_id,
			pending_encounter_definition.authored_room_id
		)
		if pending_encounter_definition.combat_stage_id != &"":
			active_combat_stage = combat_stage_catalog.get_stage(
				pending_encounter_definition.combat_stage_id
			)
		if active_combat_stage == null:
			active_combat_stage = (
				combat_stage_catalog.get_default_stage_for_battlefield(
					active_battlefield.battlefield_id
				)
			)
		if active_combat_stage == null:
			return "Encounter '%s' has no combat stage." % (
				pending_encounter_definition.encounter_id
			)
		if combat_stage_presenter == null:
			return "Combat-stage presenter is missing."
		var stage_error: String = combat_stage_presenter.apply_stage(
			active_combat_stage,
			active_battlefield
		)
		if not stage_error.is_empty():
			return stage_error
	var field_error: String = active_battlefield.validate_assignments(
		composed_battler_definitions,
		pending_encounter_definition.spawn_assignments
	)
	if not field_error.is_empty():
		return field_error
	battlefield_definition = active_battlefield.make_runtime_definition(
		composed_battler_definitions,
		pending_encounter_definition.spawn_assignments
	)
	enemy_group_rulebook = (
		pending_encounter_definition.template.enemy_group_rulebook
	)
	return ""


func _create_dynamic_battler_markers() -> void:
	battler_markers = marker_factory.create_markers(
		marker_host,
		pending_encounter_definition.get_all_battler_ids()
	)


func _initialize_combat_engine() -> String:
	if combat_engine == null:
		return "CombatEngine scene instance is missing."

	var definitions: Array[BattlerDefinition] = (
		composed_battler_definitions.duplicate()
	)
	var ordered_ids: Array[StringName] = (
		pending_encounter_definition.get_all_battler_ids()
	)
	var initial_item_ids: Array[StringName] = [
		&"l01_bandage_roll",
		&"l01_smelling_salts",
		&"l01_warm_wine_flask",
		&"l01_servants_tonic",
		&"l01_red_wax_ampoule",
		&"l01_kitchen_knife",
	]
	var initial_item_quantities: Array[int] = [
		3,
		2,
		2,
		2,
		2,
		2,
	]
	var progression_snapshots: Dictionary = (
		pending_heroine_progression_snapshot.duplicate(true)
	)
	if (
		progression_snapshots.is_empty()
		and developer_grant_weapon_techniques_when_run_directly
	):
		progression_snapshots = (
			RunState.make_default_heroine_progression_snapshot(true)
		)
	var engine_error: String = combat_engine.initialize(
		definitions,
		ordered_ids,
		battlefield_definition,
		enemy_group_rulebook,
		item_catalog,
		base_seed,
		initial_item_ids,
		initial_item_quantities,
		progression_snapshots,
		pending_run_equipment
	)
	if not engine_error.is_empty():
		return engine_error

	battler_states = combat_engine.battler_states
	battle_bootstrap = combat_engine.battle_bootstrap
	battle_runtime = combat_engine.battle_runtime
	battle_flow_controller = combat_engine.battle_flow_controller
	action_controller = combat_engine.action_controller
	dice_resolver = combat_engine.dice_roller.resolver
	attack_resolver = combat_engine.attack_resolver
	battlefield_state = combat_engine.battlefield_state
	movement_controller = combat_engine.movement_controller
	targeting_controller = combat_engine.targeting_controller
	enemy_ai_controller = combat_engine.enemy_ai_controller
	status_controller = combat_engine.status_controller
	aoe_controller = combat_engine.aoe_controller
	ability_controller = combat_engine.ability_controller
	lifecycle_controller = combat_engine.lifecycle_controller
	grapple_controller = combat_engine.grapple_controller
	item_inventory = combat_engine.item_inventory
	item_use_controller = combat_engine.item_use_controller
	dodge_step_controller = combat_engine.dodge_step_controller
	return ""


func _initialize_reusable_presentation() -> void:
	if combat_presenter == null or reusable_hud == null:
		push_error(
			"Reusable CombatPresenter or CombatHUD scene instance is missing."
		)
		return

	combat_presenter.initialize(
		combat_engine,
		reusable_hud,
		battler_markers
	)
	ability_panel = reusable_hud.ability_panel
	struggle_panel = reusable_hud.struggle_panel
	attack_button = reusable_hud.command_bar.attack_button
	move_button = reusable_hud.command_bar.move_button
	aoe_button = reusable_hud.command_bar.ability_button
	struggle_button = reusable_hud.command_bar.struggle_button
	grapple_wait_button = reusable_hud.command_bar.grapple_wait_button
	submit_button = reusable_hud.command_bar.submit_button
	combat_presenter.connect_log(log_presenter)
	combat_presenter.heroine_selected.connect(_on_battler_selected)
	combat_presenter.attack_requested.connect(_on_attack_pressed)
	combat_presenter.move_requested.connect(_on_move_pressed)
	combat_presenter.ability_requested.connect(_on_abilities_pressed)
	combat_presenter.item_requested.connect(_on_item_slot_pressed)
	combat_presenter.end_phase_requested.connect(
		_on_phase_button_pressed
	)
	combat_presenter.struggle_requested.connect(
		_on_struggle_pressed
	)
	combat_presenter.grapple_wait_requested.connect(
		_on_grapple_wait_pressed
	)
	combat_presenter.submit_requested.connect(_on_submit_pressed)
	combat_presenter.reaction_selected.connect(
		_on_reusable_reaction_selected
	)
	combat_presenter.defence_selected.connect(
		_on_reusable_defence_selected
	)
	combat_presenter.equipment_break_selected.connect(
		_on_reusable_equipment_break_selected
	)
	combat_presenter.grapple_response_selected.connect(
		_on_grapple_response_chosen
	)
	combat_presenter.move_reaction_selected.connect(
		_on_reusable_move_reaction_selected
	)


func _bind_battler_markers() -> void:
	assert(
		not battler_markers.is_empty(),
		"No BattleMarker nodes have been assigned."
	)
	for marker: BattleMarker in battler_markers:
		assert(marker != null, "A BattleMarker array entry is empty.")
		assert(
			marker.battler_id != &"",
			"%s has no battler_id." % marker.name
		)
		var state: BattlerState = get_battler_state(marker.battler_id)
		if state == null:
			marker.visible = false
			marker.process_mode = Node.PROCESS_MODE_DISABLED
			continue
		marker.visible = true
		marker.process_mode = Node.PROCESS_MODE_INHERIT
		marker.bind_state(state)
		if not marker.battler_selected.is_connected(
			_on_battler_selected
		):
			marker.battler_selected.connect(_on_battler_selected)
		if not marker.visual_pose_reset_requested.is_connected(
			_on_marker_visual_pose_reset_requested
		):
			marker.visual_pose_reset_requested.connect(
				_on_marker_visual_pose_reset_requested
			)
	for value: Variant in battler_states.values():
		var state: BattlerState = value as BattlerState
		if (
			state != null
			and not state.state_changed.is_connected(
				_queue_marker_cluster_layout_refresh
			)
		):
			state.state_changed.connect(
				_queue_marker_cluster_layout_refresh
			)
		if (
			state != null
			and not state.state_changed.is_connected(
				_queue_marker_orientation_refresh
			)
		):
			state.state_changed.connect(
				_queue_marker_orientation_refresh
			)


func _initialize_spatial_presentation() -> void:
	assert(
		battlefield_overlay != null,
		"No battlefield presentation overlay has been assigned."
	)
	assert(
		battlefield_input_overlay != null,
		"No BattlefieldInteractionOverlay has been assigned."
	)

	battlefield_overlay.initialize(
		battlefield_definition,
		battlefield_state,
		battler_states
	)
	battlefield_input_overlay.initialize(
		battlefield_definition,
		battlefield_state
	)
	if not battlefield_input_overlay.selection_visibility_changed.is_connected(
		_on_board_selection_visibility_changed
	):
		battlefield_input_overlay.selection_visibility_changed.connect(
			_on_board_selection_visibility_changed
		)
	battlefield_overlay.set_selected_battler(
		battle_runtime.selected_battler_id
	)

	if not battlefield_state.position_changed.is_connected(
		_on_spatial_position_changed
	):
		battlefield_state.position_changed.connect(
			_on_spatial_position_changed
		)

	for marker: BattleMarker in battler_markers:
		if marker == null:
			continue

		var position_state: BattlerPositionState = (
			battlefield_state.get_battler_position(
				marker.battler_id
			)
		)
		if position_state == null:
			continue

		marker.position = battlefield_state.get_world_position(
			marker.battler_id
		)
		_apply_marker_anchor_presentation(
			marker,
			position_state.anchor_id
		)
		marker.set_location_label(
			_compact_location_label(marker.battler_id)
		)

	_refresh_grapple_cluster_marker_offsets()
	battlefield_input_overlay.clear_selection()


func _compact_location_label(
	battler_id: StringName
) -> String:
	var position_state: BattlerPositionState = (
		battlefield_state.get_battler_position(battler_id)
	)
	if position_state == null:
		return "Unplaced"

	var anchor: AnchorDefinition = (
		battlefield_definition.get_anchor(
			position_state.anchor_id
		)
	)
	if anchor == null:
		return "Invalid anchor"

	return "%s P%d" % [
		anchor.display_name,
		position_state.position_index + 1,
	]


func _get_battler_marker(
	battler_id: StringName
) -> BattleMarker:
	for marker: BattleMarker in battler_markers:
		if marker != null and marker.battler_id == battler_id:
			return marker

	return null


func _resolve_battler_visual_orientation(
	battler_id: StringName,
	fallback_orientation: StringName
) -> StringName:
	if battlefield_state == null:
		return fallback_orientation
	var actor: BattlerState = get_battler_state(battler_id)
	var actor_placement: BattlerPositionState = (
		battlefield_state.get_battler_position(battler_id)
	)
	var marker: BattleMarker = _get_battler_marker(battler_id)
	var current_orientation: StringName = (
		marker.current_orientation
		if marker != null
		else fallback_orientation
	)
	if actor == null or actor.definition == null or actor_placement == null:
		return fallback_orientation
	if actor.is_defeated:
		return current_orientation

	var actor_position: Vector2 = battlefield_state.get_world_position(
		battler_id
	)
	var closest_opponent_id: StringName = &""
	var closest_opponent_position: Vector2 = Vector2.ZERO
	var closest_distance_squared: float = INF
	for value: Variant in battler_states.values():
		var candidate: BattlerState = value as BattlerState
		if (
			candidate == null
			or candidate == actor
			or candidate.definition == null
			or candidate.is_defeated
			or candidate.definition.faction == actor.definition.faction
		):
			continue
		var candidate_id: StringName = candidate.definition.battler_id
		if battlefield_state.get_battler_position(candidate_id) == null:
			continue
		var candidate_position: Vector2 = (
			battlefield_state.get_world_position(candidate_id)
		)
		var distance_squared: float = actor_position.distance_squared_to(
			candidate_position
		)
		var replaces_closest: bool = (
			distance_squared < closest_distance_squared
			or (
				is_equal_approx(distance_squared, closest_distance_squared)
				and (
					closest_opponent_id == &""
					or String(candidate_id) < String(closest_opponent_id)
				)
			)
		)
		if replaces_closest:
			closest_opponent_id = candidate_id
			closest_opponent_position = candidate_position
			closest_distance_squared = distance_squared

	if closest_opponent_id == &"":
		return fallback_orientation
	return BattlerVisualIntentResolver.orientation_toward_opponent(
		actor_position,
		closest_opponent_position,
		current_orientation,
		fallback_orientation
	)


func _apply_marker_anchor_presentation(
	marker: BattleMarker,
	anchor_id: StringName
) -> void:
	if marker == null or battlefield_definition == null:
		return
	var anchor := battlefield_definition.get_anchor(anchor_id)
	if anchor == null:
		return
	if battlefield_state == null:
		return
	var placement: BattlerPositionState = (
		battlefield_state.get_battler_position(marker.battler_id)
	)
	if placement == null:
		return
	marker.set_battlefield_presentation(
		anchor.get_position_battler_scale(placement.position_index),
		anchor.get_position_visual_order(placement.position_index),
		anchor.visual_depth_band,
		(
			anchor.bounded_y_sort_within_band
			and not anchor.has_position_visual_order_override(
				placement.position_index
			)
		),
		battlefield_state.get_world_position(marker.battler_id).y
	)
	if marker_factory == null:
		return
	if marker_factory.visual_profile_catalog == null:
		return
	var authored_placement := BattlerPlacementDefinition.new()
	authored_placement.battler_id = marker.battler_id
	authored_placement.anchor_id = placement.anchor_id
	authored_placement.position_index = placement.position_index
	var orientation: StringName = _resolve_battler_visual_orientation(
		marker.battler_id,
		anchor.visual_orientation
	)
	var resolution: Dictionary = BattlerVisualIntentResolver.resolve_intent(
		marker_factory.visual_profile_catalog,
		battlefield_definition,
		marker.battler_id,
		StringName(marker.name),
		marker.current_visual_event,
		marker.battler_state != null and marker.battler_state.is_defeated,
		authored_placement,
		orientation
	)
	# Spatial/facing relayout must not cancel an in-flight transient pose.
	marker.present_visual_resolution(resolution, 0.0, false, true)


func _on_marker_visual_pose_reset_requested(
	battler_id: StringName
) -> void:
	var marker: BattleMarker = _get_battler_marker(battler_id)
	_present_battler_visual_event(
		battler_id,
		marker.get_resting_visual_event() if marker != null else &"idle",
		0.0
	)
	_queue_marker_orientation_refresh()


func _present_battler_visual_event(
	battler_id: StringName,
	event_key: StringName,
	transient_seconds: float = -1.0,
	crossfade: bool = true
) -> void:
	var marker: BattleMarker = _get_battler_marker(battler_id)
	if marker == null or battlefield_state == null:
		return
	var placement: BattlerPositionState = (
		battlefield_state.get_battler_position(battler_id)
	)
	if placement == null:
		return
	var anchor: AnchorDefinition = battlefield_definition.get_anchor(
		placement.anchor_id
	)
	if anchor == null:
		return
	var orientation: StringName = _resolve_battler_visual_orientation(
		battler_id,
		anchor.visual_orientation
	)
	marker.present_visual_event(
		event_key,
		orientation,
		transient_seconds,
		crossfade
	)


func _on_spatial_position_changed(
	battler_id: StringName,
	_anchor_id: StringName,
	_position_index: int
) -> void:
	var marker: BattleMarker = _get_battler_marker(battler_id)
	if marker != null:
		var active_move: CommittedMoveState = (
			battle_runtime.active_move
			if battle_runtime != null
			else null
		)
		var uses_move_animation: bool = (
			active_move != null
			and active_move.mover_id == battler_id
		)
		# Committed Moves own their marker fade/snap transition. Every other
		# placement change (including Grapple bundling and detachment) must
		# synchronize the presentation here.
		if not uses_move_animation:
			_apply_marker_anchor_presentation(marker, _anchor_id)
			marker.position = battlefield_state.get_world_position(
				battler_id
			)
		marker.set_location_label(
			_compact_location_label(battler_id)
		)
	_queue_marker_cluster_layout_refresh()
	_queue_marker_orientation_refresh()


func _queue_marker_cluster_layout_refresh() -> void:
	if marker_layout_refresh_scheduled:
		return
	marker_layout_refresh_scheduled = true
	call_deferred("_refresh_grapple_cluster_marker_offsets")


func _refresh_grapple_cluster_marker_offsets() -> void:
	marker_layout_refresh_scheduled = false
	for marker: BattleMarker in battler_markers:
		if marker != null:
			marker.set_cluster_display_offset(Vector2.ZERO)
			marker.set_grapple_cluster_role(&"")

	for value: Variant in battler_states.values():
		var heroine: BattlerState = value as BattlerState
		if heroine == null or not heroine.is_grappled():
			continue

		var heroine_id: StringName = heroine.definition.battler_id
		var heroine_marker: BattleMarker = _get_battler_marker(heroine_id)
		var tracks: Array[GrappleTrackState] = (
			grapple_controller.get_tracks_for_heroine(heroine_id)
		)
		if heroine_marker == null or tracks.is_empty():
			continue

		# All participants keep the same authoritative battlefield Position.
		# Static participant art and clickable overlays fan out around that point;
		# the holder's art is layered behind the subject until combined authored
		# Grapple sprites become available.
		heroine_marker.set_cluster_display_offset(
			Vector2(0.0, GRAPPLE_CLUSTER_HEROINE_Y)
		)
		heroine_marker.set_grapple_cluster_role(&"subject")
		var first_x: float = (
			-float(tracks.size() - 1)
			* GRAPPLE_CLUSTER_MARKER_SPACING
			* 0.5
		)
		for track_index: int in range(tracks.size()):
			var track: GrappleTrackState = tracks[track_index]
			var grappler_marker: BattleMarker = _get_battler_marker(
				track.grappler_id
			)
			if grappler_marker == null:
				continue
			grappler_marker.set_cluster_display_offset(
				Vector2(
					first_x
					+ float(track_index)
					* GRAPPLE_CLUSTER_MARKER_SPACING,
					GRAPPLE_CLUSTER_GRAPPLER_Y
				)
			)
			grappler_marker.set_grapple_cluster_role(&"holder")

	for anchor: AnchorDefinition in battlefield_definition.anchors:
		var overflow_ids: Array[StringName] = (
			battlefield_state.get_over_capacity_battler_ids(
				anchor.anchor_id
			)
		)
		for overflow_index: int in range(overflow_ids.size()):
			var overflow_marker: BattleMarker = _get_battler_marker(
				overflow_ids[overflow_index]
			)
			if overflow_marker == null:
				continue
			overflow_marker.set_cluster_display_offset(
				OVER_CAPACITY_MARKER_OFFSET
				* float(overflow_index + 1)
			)


func _connect_grapple_runtime_controls() -> void:
	assert(
		struggle_panel != null,
		"Grapple runtime controls are incomplete."
	)

	struggle_panel.confirmed.connect(_on_struggle_confirmed)
	struggle_panel.cancelled.connect(_on_struggle_cancelled)
	struggle_panel.close_panel()
	_refresh_grapple_command_bar()


func _connect_aoe_controls() -> void:
	assert(
		ability_panel != null
		and battlefield_input_overlay != null,
		"Ability controls are incomplete."
	)

	if not ability_panel.ability_chosen.is_connected(
		_on_ability_chosen
	):
		ability_panel.ability_chosen.connect(_on_ability_chosen)
	if not ability_panel.cancelled.is_connected(
		_on_ability_menu_cancelled
	):
		ability_panel.cancelled.connect(_on_ability_menu_cancelled)
	if not battlefield_input_overlay.aoe_zone_confirmed.is_connected(
		_on_aoe_zone_confirmed
	):
		battlefield_input_overlay.aoe_zone_confirmed.connect(
			_on_aoe_zone_confirmed
		)

	ability_panel.close_panel()


func _connect_move_controls() -> void:
	assert(
		battlefield_input_overlay != null,
		"No BattlefieldInteractionOverlay has been assigned."
	)

	if not battlefield_input_overlay.move_preview_changed.is_connected(
		_on_move_preview_changed
	):
		battlefield_input_overlay.move_preview_changed.connect(
			_on_move_preview_changed
		)
	if not battlefield_input_overlay.move_confirmed.is_connected(
		_on_move_confirmed
	):
		battlefield_input_overlay.move_confirmed.connect(
			_on_move_confirmed
		)
	if not battlefield_input_overlay.dodge_step_confirmed.is_connected(
		_on_dodge_step_confirmed
	):
		battlefield_input_overlay.dodge_step_confirmed.connect(
			_on_dodge_step_confirmed
		)
	if not battlefield_input_overlay.selection_cancelled.is_connected(
		_on_board_selection_cancelled
	):
		battlefield_input_overlay.selection_cancelled.connect(
			_on_board_selection_cancelled
		)

	battlefield_overlay.visible = true


func _on_battler_selected(
	battler_id: StringName
) -> void:
	var state: BattlerState = get_battler_state(
		battler_id
	)

	if state == null:
		push_error(
			"Selected BattlerState '%s' does not exist."
			% battler_id
		)
		return

	if battle_runtime.is_selecting_item_target:
		_commit_pending_item_use(battler_id)
		return
	if battle_runtime.is_selecting_ability_target:
		_commit_pending_ability(battler_id)
		return

	if commands_locked:
		log_presenter.append(
			"Finish the current resolution first."
		)
		return

	if battle_runtime.has_pending_reaction():
		log_presenter.append(
			"Resolve the pending reaction first."
		)
		return

	if battle_runtime.has_active_move():
		log_presenter.append(
			"Finish the committed Move first."
		)
		return

	if battle_runtime.is_selecting_move:
		log_presenter.append(
			"Confirm or cancel the current Move first."
		)
		return

	if battle_runtime.is_selecting_aoe:
		log_presenter.append(
			"Confirm or cancel the current AOE first."
		)
		return
	if battle_runtime.is_selecting_ability_target:
		log_presenter.append(
			"Confirm or cancel the current Ability first."
		)
		return

	if battle_runtime.is_selecting_attack_target:
		_prepare_pending_attack(state)
		return

	battle_runtime.selected_battler_id = battler_id
	battlefield_overlay.set_selected_battler(battler_id)
	log_presenter.log_combatant_selected(state)
	_refresh_grapple_command_bar()
	_refresh_item_bar()
	if combat_presenter != null:
		combat_presenter.refresh_all()


func _on_item_slot_pressed(
	slot_index: int
) -> void:
	if battle_runtime.is_selecting_item_target:
		if slot_index == battle_runtime.pending_item_slot_index:
			_cancel_item_targeting(
				"Item targeting cancelled."
			)
			return
		log_presenter.append(
			"Cancel the selected item before choosing another slot."
		)
		return
	if commands_locked or battle_runtime.has_pending_reaction():
		log_presenter.append(
			"Finish the current resolution before using an item."
		)
		return
	if (
		battle_runtime.is_selecting_attack_target
		or battle_runtime.is_selecting_move
		or battle_runtime.is_selecting_aoe
		or battle_runtime.is_selecting_ability_target
		or battle_runtime.has_active_move()
	):
		log_presenter.append(
			"Finish or cancel the current Action before using an item."
		)
		return

	var actor_id: StringName = battle_runtime.selected_battler_id
	var item: ItemDefinition = item_use_controller.get_item(
		slot_index
	)
	var unavailable_reason: String = (
		item_use_controller.get_availability_reason(
			actor_id,
			slot_index
		)
	)
	if not unavailable_reason.is_empty():
		log_presenter.append(unavailable_reason)
		return

	var legal_target_ids: Array[StringName] = (
		item_use_controller.get_legal_target_ids(
			actor_id,
			slot_index
		)
	)
	if item == null or legal_target_ids.is_empty():
		log_presenter.append(
			"The selected item has no legal target."
		)
		return

	if (
		item.target_rule == ItemDefinition.TargetRule.SELF
		and legal_target_ids.has(actor_id)
		and not item.performs_attack
	):
		_execute_direct_item_use(
			actor_id,
			actor_id,
			slot_index
		)
		return

	battle_runtime.begin_item_targeting(
		actor_id,
		slot_index
	)
	_set_item_targeting_markers(true, legal_target_ids)
	_set_commands_locked(true)
	log_presenter.debug(
		"%s selected %s from Item Bar slot %d."
		% [
			_get_battler_display_name(actor_id),
			item.display_name,
			slot_index + 1,
		]
	)
	log_presenter.debug(
		(
			"Legal item targets: %s. Right-click, press Esc, "
			+ "or click the selected slot again to cancel."
		)
		% _get_battler_name_list(legal_target_ids)
	)


func _commit_pending_item_use(
	target_id: StringName
) -> void:
	if not battle_runtime.is_selecting_item_target:
		return
	var actor_id: StringName = battle_runtime.pending_item_user_id
	var slot_index: int = battle_runtime.pending_item_slot_index
	var legal_target_ids: Array[StringName] = (
		item_use_controller.get_legal_target_ids(
			actor_id,
			slot_index
		)
	)
	if not legal_target_ids.has(target_id):
		log_presenter.append(
			"That combatant is not a legal target for the selected item."
		)
		return

	var item: ItemDefinition = item_use_controller.get_item(
		slot_index
	)
	if item == null:
		_cancel_item_targeting(
			"The selected item stack no longer exists."
		)
		return

	if item.performs_attack:
		var context: ReactionContext = (
			item_use_controller.prepare_item_attack(
				actor_id,
				target_id,
				slot_index
			)
		)
		if not context.is_valid:
			log_presenter.append(
				"Item Attack failed: %s"
				% context.error_message
			)
			return
		_set_item_targeting_markers(false)
		_refresh_item_bar()
		var actor: BattlerState = get_battler_state(actor_id)
		var target: BattlerState = get_battler_state(target_id)
		log_presenter.log_attack_committed(
			actor,
			target,
			context
		)
		_present_pending_reaction(context, target)
		return

	_execute_direct_item_use(
		actor_id,
		target_id,
		slot_index
	)


func _execute_direct_item_use(
	actor_id: StringName,
	target_id: StringName,
	slot_index: int
) -> void:
	var result: ItemUseResult = item_use_controller.use_item(
		actor_id,
		target_id,
		slot_index
	)
	if battle_runtime.is_selecting_item_target:
		battle_runtime.cancel_item_targeting()
		_set_item_targeting_markers(false)
	_log_item_use_result(result)
	_restore_selected_battler(actor_id)
	_set_commands_locked(false)
	_refresh_item_bar()
	_evaluate_and_present_outcome()


func _cancel_item_targeting(
	message: String
) -> void:
	battle_runtime.cancel_item_targeting()
	_set_item_targeting_markers(false)
	_set_commands_locked(false)
	_refresh_item_bar()
	if not message.is_empty():
		log_presenter.append(message)


func _set_item_targeting_markers(
	active: bool,
	legal_target_ids: Array[StringName] = []
) -> void:
	# The temporary markers reuse the existing legal-target presentation.
	# Finished UI art can give Item targeting its own reticle later.
	_set_attack_targeting_markers(
		active,
		legal_target_ids
	)


func _log_item_use_result(
	result: ItemUseResult
) -> void:
	if result == null:
		log_presenter.append("Item use produced no result.")
		return
	if not result.succeeded:
		log_presenter.append(
			"Item use failed: %s" % result.error_message
		)
		return
	if result.log_lines.is_empty():
		log_presenter.append("Item used.")
		return
	var summary: String = result.log_lines[result.log_lines.size() - 1]
	var details: PackedStringArray = PackedStringArray()
	for index: int in range(result.log_lines.size() - 1):
		details.append(result.log_lines[index])
	log_presenter.append(summary, "\n".join(details))


func _refresh_item_bar() -> void:
	if combat_presenter != null:
		combat_presenter.refresh_all()


func _on_attack_pressed() -> void:
	if battle_runtime.has_pending_reaction():
		log_presenter.append(
			"Resolve the pending reaction first."
		)
		return

	if battle_runtime.is_selecting_move:
		log_presenter.append(
			"Confirm or cancel the current Move first."
		)
		return
	if battle_runtime.is_selecting_aoe:
		log_presenter.append(
			"Confirm or cancel the current AOE first."
		)
		return

	if battle_runtime.is_selecting_attack_target:
		_cancel_attack_targeting()
		log_presenter.append(
			"Attack targeting cancelled."
		)
		return

	var error_message: String = (
		action_controller.begin_attack_targeting()
	)

	if not error_message.is_empty():
		log_presenter.append(error_message)
		return

	var attacker: BattlerState = (
		action_controller.get_selected_attacker()
	)

	var weapon: WeaponDefinition = (
		action_controller.get_main_hand_weapon(attacker)
	)

	assert(
		attacker != null and weapon != null,
		"Validated attack preparation lost its attacker or weapon."
	)

	_set_attack_command_hint("Attack targeting active. RMB or Esc cancels.")
	var legal_target_ids: Array[StringName] = (
		action_controller.get_legal_attack_target_ids(
			attacker,
			weapon
		)
	)
	_set_attack_targeting_markers(
		true,
		legal_target_ids
	)

	log_presenter.log_attack_targeting_started(
		attacker,
		weapon
	)
	log_presenter.debug(
		"Legal targets: %s."
		% _get_battler_name_list(legal_target_ids)
	)


func _on_abilities_pressed() -> void:
	if battle_runtime.is_selecting_ability_target:
		_cancel_ability_targeting("Ability targeting cancelled.")
		return
	if battle_runtime.is_selecting_aoe:
		_on_aoe_cancelled()
		return
	if (
		battle_runtime.has_pending_reaction()
		or battle_runtime.has_active_move()
	):
		log_presenter.append(
			"Finish the current resolution before choosing an ability."
		)
		return
	if battle_runtime.is_selecting_attack_target:
		log_presenter.append(
			"Cancel Attack targeting before choosing an ability."
		)
		return
	if battle_runtime.is_selecting_move:
		log_presenter.append(
			"Confirm or cancel the current Move first."
		)
		return
	if ability_panel.visible:
		ability_panel.close_panel()
		return
	var caster: BattlerState = get_battler_state(
		battle_runtime.selected_battler_id
	)
	if (
		caster == null
		or caster.definition == null
		or caster.definition.faction
		!= BattlerDefinition.Faction.HEROINE
	):
		log_presenter.append("Select a heroine to use an ability.")
		return
	var abilities: Array[AbilityDefinition] = (
		ability_controller.get_active_abilities(
			caster.definition.battler_id
		)
	)
	ability_panel.present(caster, abilities, ability_controller)


func _on_ability_chosen(
	ability_id: StringName
) -> void:
	var caster: BattlerState = get_battler_state(
		battle_runtime.selected_battler_id
	)
	if caster == null or caster.definition == null:
		return
	var ability: AbilityDefinition = caster.get_ability(
		ability_id
	)
	if ability == null:
		log_presenter.append("The selected ability no longer exists.")
		return
	var unavailable: String = ability_controller.get_availability_reason(
		caster.definition.battler_id,
		ability
	)
	if not unavailable.is_empty():
		log_presenter.append(unavailable)
		return
	ability_panel.close_panel()
	if (
		ability.targeting_mode
		== AbilityDefinition.TargetingMode.BATTLE_ZONE
	):
		_begin_aoe_ability(caster, ability)
		return
	if (
		ability.targeting_mode
		== AbilityDefinition.TargetingMode.SELF
	):
		_present_battler_visual_event(
			caster.definition.battler_id,
			&"cast_started"
		)
		var self_result: AbilityUseResult = (
			ability_controller.use_self_ability(
				caster.definition.battler_id,
				ability
			)
		)
		_log_ability_use_result(self_result)
		_refresh_battle_flow_ui()
		_evaluate_and_present_outcome()
		return
	var legal_target_ids: Array[StringName] = (
		ability_controller.begin_targeting(
			caster.definition.battler_id,
			ability
		)
	)
	if legal_target_ids.is_empty():
		log_presenter.append(
			"%s has no legal target." % ability.display_name
		)
		return
	_set_commands_locked(true)
	aoe_button.disabled = false
	_set_ability_command_hint("Ability targeting active. RMB or Esc cancels.")
	_set_attack_targeting_markers(true, legal_target_ids)
	log_presenter.debug(
		"%s selected %s. Legal targets: %s."
		% [
			caster.definition.display_name,
			ability.display_name,
			_get_battler_name_list(legal_target_ids),
		]
	)


func _begin_aoe_ability(
	caster: BattlerState,
	ability: AbilityDefinition
) -> void:
	var legal_zone_ids: Array[StringName] = (
		aoe_controller.begin_zone_targeting(
			caster.definition.battler_id,
			ability
		)
	)
	if legal_zone_ids.is_empty():
		log_presenter.append(
			"%s has no legal BattleZone target."
			% ability.display_name
		)
		return

	_set_commands_locked(true)
	aoe_button.disabled = false
	_set_ability_command_hint("Ability BattleZone selection active. RMB or Esc cancels.")
	battlefield_input_overlay.begin_aoe_selection(
		legal_zone_ids,
		ability.display_name
	)
	log_presenter.debug(
		"%s began %s targeting. Click a highlighted BattleZone."
		% [
			caster.definition.display_name,
			ability.display_name,
		]
	)


func _commit_pending_ability(
	target_id: StringName
) -> void:
	var caster_id: StringName = battle_runtime.pending_ability_caster_id
	var outcome: Variant = ability_controller.commit_target(target_id)
	if outcome is AbilityTargetSelectionResult:
		var selection: AbilityTargetSelectionResult = (
			outcome as AbilityTargetSelectionResult
		)
		if not selection.succeeded:
			log_presenter.append(
				"Ability failed: %s" % selection.error_message
			)
			return
		_set_attack_targeting_markers(
			true,
			selection.legal_target_ids
		)
		log_presenter.append(
			"%s selected. Choose %d different target%s." % [
				_get_battler_name_list(
					selection.selected_target_ids
				),
				selection.remaining_target_count,
				"" if selection.remaining_target_count == 1 else "s",
			]
		)
		return
	_present_battler_visual_event(
		caster_id,
		&"cast_started"
	)
	if outcome is ReactionContext:
		var context: ReactionContext = outcome as ReactionContext
		if not context.is_valid:
			log_presenter.append(
				"Ability failed: %s" % context.error_message
			)
			return
		_set_attack_targeting_markers(false)
		_set_ability_command_hint("Ability")
		var caster: BattlerState = get_battler_state(caster_id)
		var target: BattlerState = (
			action_controller.get_pending_reaction_target()
		)
		log_presenter.log_attack_committed(caster, target, context)
		_present_pending_reaction(context, target)
		return
	var direct_result: AbilityUseResult = outcome as AbilityUseResult
	if direct_result == null or not direct_result.succeeded:
		log_presenter.append(
			"Ability failed: %s" % (
				direct_result.error_message
				if direct_result != null
				else "unknown result"
			)
		)
		return
	_set_attack_targeting_markers(false)
	_set_ability_command_hint("Ability")
	_set_commands_locked(false)
	_log_ability_use_result(direct_result)
	_restore_selected_battler(caster_id)
	_evaluate_and_present_outcome()


func _log_ability_use_result(
	result: AbilityUseResult
) -> void:
	if result == null:
		log_presenter.append("Ability use produced no result.")
		return
	if not result.succeeded:
		log_presenter.append(
			"Ability failed: %s" % result.error_message
		)
		return
	if result.log_lines.is_empty():
		log_presenter.append("Ability resolved.")
		return
	var details: PackedStringArray = PackedStringArray()
	for index: int in range(1, result.log_lines.size()):
		details.append(result.log_lines[index])
	log_presenter.append(result.log_lines[0], "\n".join(details))


func _cancel_ability_targeting(
	message: String = ""
) -> void:
	ability_controller.cancel_targeting()
	_set_attack_targeting_markers(false)
	_set_ability_command_hint("Ability")
	_set_commands_locked(false)
	if not message.is_empty():
		log_presenter.append(message)


func _on_ability_menu_cancelled() -> void:
	ability_panel.close_panel()


func _on_aoe_zone_confirmed(
	zone_id: StringName
) -> void:
	var context: ReactionContext = aoe_controller.commit_zone(
		zone_id
	)
	if not context.is_valid:
		log_presenter.append(
			"AOE failed: %s" % context.error_message
		)
		return

	battlefield_input_overlay.clear_selection()
	_set_ability_command_hint("Ability")
	var aoe_state: AoeResolutionState = battle_runtime.active_aoe
	var caster: BattlerState = get_battler_state(
		aoe_state.caster_id
	)
	var target: BattlerState = (
		action_controller.get_pending_reaction_target()
	)
	var zone: BattleZoneDefinition = (
		battlefield_definition.get_zone(zone_id)
	)
	log_presenter.log_aoe_committed(
		caster,
		aoe_state.ability,
		(
			zone.display_name
			if zone != null
			else String(zone_id)
		),
		_get_battler_name_list(aoe_state.target_ids),
		context
	)
	_present_pending_reaction(context, target)


func _on_aoe_cancelled() -> void:
	aoe_controller.cancel_zone_targeting()
	battlefield_input_overlay.clear_selection()
	_set_ability_command_hint("Ability")
	_set_commands_locked(false)
	log_presenter.debug("Ability BattleZone selection cancelled.")


func _on_move_pressed() -> void:
	if battle_runtime.is_selecting_move:
		_on_move_cancelled()
		return
	if battle_runtime.has_pending_reaction():
		log_presenter.append(
			"Resolve the pending reaction first."
		)
		return
	if battle_runtime.is_selecting_attack_target:
		log_presenter.append(
			"Cancel Attack targeting before starting a Move."
		)
		return
	if battle_runtime.is_selecting_aoe:
		log_presenter.append(
			"Confirm or cancel the current AOE first."
		)
		return
	if battle_runtime.is_selecting_ability_target:
		log_presenter.append(
			"Confirm or cancel the current Ability first."
		)
		return

	var previews: Array[MovementPreview] = (
		movement_controller.begin_move_selection(
			battle_runtime.selected_battler_id
		)
	)
	if previews.is_empty():
		log_presenter.append(
			movement_controller.last_error
		)
		return

	_set_commands_locked(true)
	move_button.disabled = false
	_set_move_command_hint("Move selection active. RMB or Esc cancels.")
	var mover: BattlerState = get_battler_state(
		battle_runtime.pending_mover_id
	)
	battlefield_input_overlay.begin_move_selection(
		previews,
		(
			mover.definition.display_name
			if mover != null and mover.definition != null
			else "Combatant"
		)
	)

	log_presenter.debug(
		(
			"%s began Move selection. Choose a highlighted Engagement Area, "
			+ "then choose an exact Position."
		)
		% (
			mover.definition.display_name
			if mover != null and mover.definition != null
			else "Combatant"
		)
	)


func _on_move_preview_changed(
	preview: MovementPreview,
	destination_position_index: int
) -> void:
	battlefield_overlay.show_move_preview(
		preview,
		destination_position_index
	)


func _on_move_confirmed(
	preview: MovementPreview,
	destination_position_index: int
) -> void:
	var mover: BattlerState = get_battler_state(
		preview.mover_id
	)
	if mover == null or mover.definition == null:
		log_presenter.append(
			"Move failed: the mover no longer exists."
		)
		return

	var route_label: String = preview.get_route_label(
		battlefield_definition
	)
	var move_state: CommittedMoveState = (
		movement_controller.begin_committed_move(
			preview,
			destination_position_index
		)
	)
	if not move_state.is_valid:
		log_presenter.append(
			"Move failed: %s" % move_state.error_message
		)
		return
	battlefield_input_overlay.clear_selection()
	battlefield_overlay.clear_move_preview()
	_set_move_command_hint("Move")

	log_presenter.append(
		"%s moved: %s."
		% [
			mover.definition.display_name,
			route_label,
		],
		"Move committed for 1 Action."
	)
	var selected_route_threats := (
		preview.get_threat_battler_ids_for_position(
			destination_position_index
		)
	)
	if not selected_route_threats.is_empty():
		log_presenter.append_detail(
			"Move Reaction opportunity armed: %s."
			% _get_battler_name_list(
				selected_route_threats
			)
		)

	call_deferred("_continue_committed_move")


func _continue_committed_move() -> void:
	if not battle_runtime.has_active_move():
		_set_commands_locked(false)
		return
	if battle_runtime.has_pending_reaction():
		return

	var move_state: CommittedMoveState = battle_runtime.active_move
	var mover: BattlerState = get_battler_state(
		move_state.mover_id
	)
	if mover == null or mover.definition == null:
		log_presenter.append(
			"Committed Move stopped: mover is missing."
		)
		move_state.is_complete = true
		move_state.stopped_early = true
		move_state.stop_reason = "Mover is missing."
		_finish_committed_move()
		return

	if mover.is_defeated:
		move_state.is_complete = true
		move_state.stopped_early = true
		move_state.stop_reason = (
			"%s was defeated." % mover.definition.display_name
		)
		_finish_committed_move()
		return

	if move_state.is_complete:
		if _offer_next_move_reaction(mover):
			return
		_finish_committed_move()
		return

	if _offer_next_move_reaction(mover):
		return

	var next_anchor_id: StringName = (
		move_state.get_next_anchor_id()
	)
	var next_is_final: bool = move_state.is_next_step_final()
	if next_anchor_id == &"":
		next_anchor_id = move_state.destination_anchor_id
		next_is_final = true

	var move_error: String = (
		movement_controller.advance_active_move_step()
	)
	if not move_error.is_empty():
		log_presenter.append(
			"Committed Move stopped: %s" % move_error
		)
		_finish_committed_move()
		return

	await _animate_move_step(
		move_state.mover_id,
		next_anchor_id,
		(
			move_state.destination_position_index
			if next_is_final
			else -1
		)
	)

	if _offer_next_move_reaction(mover):
		return

	if move_state.is_complete:
		_finish_committed_move()
		return

	call_deferred("_continue_committed_move")


func _offer_next_move_reaction(
	mover: BattlerState
) -> bool:
	if (
		mover == null
		or mover.definition == null
		or not battle_runtime.has_active_move()
	):
		return false

	var move_state: CommittedMoveState = battle_runtime.active_move
	if (
		move_state.reaction_anchor_path_index
		!= move_state.current_path_index
	):
		return false

	var reactor_ids: Array[StringName] = (
		movement_controller.get_active_move_reactor_ids()
	)
	if reactor_ids.is_empty():
		move_state.reaction_anchor_path_index = -1
		return false

	if (
		mover.definition.faction
		== BattlerDefinition.Faction.HEROINE
	):
		var enemy_reactor_id: StringName = (
			enemy_ai_controller.choose_move_reactor(
				reactor_ids
			)
		)
		if enemy_reactor_id == &"":
			for reactor_id: StringName in reactor_ids:
				movement_controller.mark_active_move_reaction_declined(
					reactor_id
				)
			return false

		var reaction_action: EnemyAIController.MoveReactionAction = (
			enemy_ai_controller.choose_move_reaction_action(
				enemy_reactor_id,
				move_state.mover_id
			)
		)
		log_presenter.debug(
			"%s rulebook chose Move Reaction: %s."
			% [
				_get_battler_display_name(enemy_reactor_id),
				enemy_ai_controller.get_move_reaction_action_label(
					reaction_action
				),
			]
		)
		match reaction_action:
			EnemyAIController.MoveReactionAction.GRAPPLE:
				return _begin_move_reaction_grapple(
					enemy_reactor_id,
					move_state.mover_id
				)
			EnemyAIController.MoveReactionAction.ATTACK:
				return _queue_move_reaction_attack(
					enemy_reactor_id,
					move_state.mover_id
				)
			EnemyAIController.MoveReactionAction.DECLINE:
				movement_controller.mark_active_move_reaction_declined(
					enemy_reactor_id
				)
				call_deferred("_continue_committed_move")
				return true

	var heroine_reactor_id: StringName = reactor_ids[0]
	pending_player_move_reaction = true
	pending_player_move_reactor_id = heroine_reactor_id
	var heroine_reactor: BattlerState = get_battler_state(
		heroine_reactor_id
	)
	combat_presenter.present_move_reaction(
		heroine_reactor,
		mover,
	)
	log_presenter.append(
		"%s may make a Move Reaction against %s."
		% [
			(
				heroine_reactor.definition.display_name
				if (
					heroine_reactor != null
					and heroine_reactor.definition != null
				)
				else String(heroine_reactor_id)
			),
			mover.definition.display_name,
		]
	)
	return true


func _on_reusable_move_reaction_selected(react: bool) -> void:
	var reactor_id: StringName = pending_player_move_reactor_id
	pending_player_move_reactor_id = &""
	combat_presenter.close_reaction_exchange()
	if reactor_id == &"":
		return
	if react:
		_on_player_move_reactor_chosen(reactor_id)
	else:
		_on_player_move_reaction_waited(reactor_id)


func _queue_move_reaction_attack(
	reactor_id: StringName,
	mover_id: StringName
) -> bool:
	var reactor: BattlerState = get_battler_state(reactor_id)
	var mover: BattlerState = get_battler_state(mover_id)
	if (
		reactor == null
		or reactor.definition == null
		or mover == null
		or mover.definition == null
	):
		return false

	var mark_error: String = (
		movement_controller.mark_active_move_reaction_used(
			reactor_id
		)
	)
	if not mark_error.is_empty():
		log_presenter.append(
			"Move Reaction could not begin: %s"
			% mark_error
		)
		return false

	var reaction_error: String = (
		action_controller.queue_move_reaction(
			reactor_id,
			mover_id,
			enemy_ai_controller.get_next_attack_seed() + 700
		)
	)
	if not reaction_error.is_empty():
		log_presenter.append(
			"Move Reaction could not queue: %s"
			% reaction_error
		)
		return false

	log_presenter.append("")
	log_presenter.append(
		"%s uses the committed Move reaction opportunity against %s."
		% [
			reactor.definition.display_name,
			mover.definition.display_name,
		]
	)
	_present_next_queued_attack()
	return true


func _begin_move_reaction_grapple(
	reactor_id: StringName,
	mover_id: StringName
) -> bool:
	var reactor: BattlerState = get_battler_state(reactor_id)
	var mover: BattlerState = get_battler_state(mover_id)
	if (
		reactor == null
		or reactor.definition == null
		or mover == null
		or mover.definition == null
	):
		return false

	var mark_error: String = (
		movement_controller.mark_active_move_reaction_used(
			reactor_id
		)
	)
	if not mark_error.is_empty():
		log_presenter.append(
			"Grapple Reaction could not begin: %s" % mark_error
		)
		return false

	var attempt: GrappleAttemptResult = (
		grapple_controller.prepare_initiation(
			reactor_id,
			mover_id,
			true
		)
	)
	if not attempt.error_message.is_empty():
		log_presenter.append(
			"Grapple Reaction failed revalidation: %s"
			% attempt.error_message
		)
		call_deferred("_continue_committed_move")
		return true
	_present_battler_visual_event(
		reactor_id,
		&"grapple_started"
	)

	pending_grapple_move_reaction = true
	log_presenter.append("")
	log_presenter.append(
		"%s uses a Grapple Reaction against moving %s: %d rolled + %d automatic successes."
		% [
			reactor.definition.display_name,
			mover.definition.display_name,
			attempt.attack_roll.total_successes,
			attempt.automatic_successes,
		]
	)
	combat_presenter.close_reaction_exchange()
	combat_presenter.present_grapple_reaction(
		attempt,
		reactor,
		mover
	)
	return true


func _animate_move_step(
	mover_id: StringName,
	anchor_id: StringName,
	destination_position_index: int
) -> void:
	var marker: BattleMarker = _get_battler_marker(mover_id)
	var anchor: AnchorDefinition = battlefield_definition.get_anchor(
		anchor_id
	)
	if marker == null or anchor == null:
		return

	var target_point: Vector2 = anchor.get_center()
	if destination_position_index >= 0:
		target_point = anchor.get_position_point(
			destination_position_index
		)

	# One committed route step is presented as a static step pose at the old
	# Position, a fade, an invisible authoritative snap, and a fade-in at the
	# new Position. There is deliberately no interpolation between Positions.
	marker.present_visual_event(
		&"move_started",
		marker.current_orientation,
		0.0,
		false
	)
	await get_tree().create_timer(MOVE_STEP_POSE_LEAD_SECONDS).timeout
	await marker.fade_character_art_to(0.0, MOVE_STEP_FADE_OUT_SECONDS)
	marker.position = target_point
	_apply_marker_anchor_presentation(marker, anchor_id)
	await marker.fade_character_art_to(1.0, MOVE_STEP_FADE_IN_SECONDS)
	await get_tree().create_timer(MOVE_STEP_POSE_HOLD_SECONDS).timeout
	_present_battler_visual_event(mover_id, &"idle", 0.0, false)
	_refresh_battler_marker_orientations()


func _refresh_battler_marker_orientations() -> void:
	marker_orientation_refresh_scheduled = false
	for marker: BattleMarker in battler_markers:
		if (
			marker == null
			or marker.battler_state == null
			or marker.battler_state.is_defeated
		):
			continue
		var placement: BattlerPositionState = (
			battlefield_state.get_battler_position(marker.battler_id)
		)
		if placement != null:
			_apply_marker_anchor_presentation(marker, placement.anchor_id)


func _queue_marker_orientation_refresh() -> void:
	if marker_orientation_refresh_scheduled:
		return
	marker_orientation_refresh_scheduled = true
	call_deferred("_refresh_battler_marker_orientations")


func _finish_committed_move() -> void:
	var completed_move: CommittedMoveState = (
		movement_controller.finish_active_move()
	)
	if completed_move == null:
		return

	var mover: BattlerState = get_battler_state(
		completed_move.mover_id
	)
	_present_battler_visual_event(
		completed_move.mover_id,
		&"idle",
		0.0,
		false
	)
	if completed_move.stopped_early:
		log_presenter.append(
			"Move stopped early at %s: %s"
			% [
				battlefield_state.get_location_label(
					completed_move.mover_id
				),
				completed_move.stop_reason,
			]
		)
	else:
		log_presenter.append(
			"Move completed. Destination: %s."
			% battlefield_state.get_location_label(
				completed_move.mover_id
			)
		)

	if (
		mover != null
		and mover.definition != null
		and completed_move.reaction_opportunity_used
	):
		log_presenter.append(
			"Move reactions used: %s."
			% _get_battler_name_list(
				completed_move.reaction_attacker_ids
			)
		)

	if (
		not completed_move.stopped_early
		and _try_complete_secondary_attachment_from_enemy_move(
			mover,
			completed_move
		)
	):
		log_presenter.append(
			"The spent Move Action satisfied the secondary attachment cost; remaining Actions were forfeited."
		)

	_set_commands_locked(false)

	if (
		mover != null
		and mover.definition != null
		and mover.definition.faction
		== BattlerDefinition.Faction.ENEMY
		and enemy_ai_controller.is_enemy_phase_active()
	):
		_enemy_action_completed()


func _try_complete_secondary_attachment_from_enemy_move(
	mover: BattlerState,
	completed_move: CommittedMoveState
) -> bool:
	if (
		mover == null
		or mover.definition == null
		or mover.definition.faction != BattlerDefinition.Faction.ENEMY
		or mover.definition.grapple_template == null
		or enemy_ai_controller.pending_decision == null
		or enemy_ai_controller.pending_decision.type
		!= EnemyDecision.Type.MOVE
	):
		return false
	var heroine: BattlerState = get_battler_state(
		enemy_ai_controller.pending_decision.target_id
	)
	if heroine == null or not heroine.is_grappled():
		return false
	var mover_position: BattlerPositionState = (
		battlefield_state.get_battler_position(
			mover.definition.battler_id
		)
	)
	var heroine_position: BattlerPositionState = (
		battlefield_state.get_battler_position(
			heroine.definition.battler_id
		)
	)
	if (
		mover_position == null
		or heroine_position == null
		or mover_position.anchor_id != heroine_position.anchor_id
	):
		return false
	var attachment: GrappleActionResult = (
		grapple_controller.attach_secondary(
			mover.definition.battler_id,
			heroine.definition.battler_id,
			null,
			true
		)
	)
	if not attachment.succeeded:
		return false
	_log_grapple_action_result(attachment)
	return true


func _on_player_move_reactor_chosen(
	reactor_id: StringName
) -> void:
	pending_player_move_reaction = false
	pending_player_move_reactor_id = &""
	if (
		battle_runtime.active_move == null
		or battle_runtime.active_move.mover_id == &""
	):
		log_presenter.append(
			"The enemy Move no longer has a valid reactor opportunity."
		)
		return

	if _queue_move_reaction_attack(
		reactor_id,
		battle_runtime.active_move.mover_id
	):
		return

	call_deferred("_continue_committed_move")


func _on_player_move_reaction_waited(
	reactor_id: StringName
) -> void:
	pending_player_move_reaction = false
	pending_player_move_reactor_id = &""
	var decline_error: String = (
		movement_controller.mark_active_move_reaction_declined(
			reactor_id
		)
	)
	if not decline_error.is_empty():
		log_presenter.append(
			"Move Reaction could not be declined: %s"
			% decline_error
		)
		call_deferred("_continue_committed_move")
		return
	var reactor: BattlerState = get_battler_state(reactor_id)
	log_presenter.append(
		"%s declined the Move Reaction."
		% (
			reactor.definition.display_name
			if reactor != null and reactor.definition != null
			else String(reactor_id)
		)
	)
	call_deferred("_continue_committed_move")


func _on_move_cancelled() -> void:
	movement_controller.cancel_move_selection()
	battlefield_input_overlay.clear_selection()
	battlefield_overlay.clear_move_preview()
	_set_move_command_hint("Move")
	_set_commands_locked(false)
	log_presenter.append("Move selection cancelled.")


func _on_board_selection_cancelled() -> void:
	_cancel_current_interaction()


func _cancel_current_interaction() -> bool:
	if pending_grapple_dodge_attempt != null:
		var heroine: BattlerState = get_battler_state(
			pending_grapple_dodge_attempt.target_id
		)
		log_presenter.append(
			"%s keeps position after preventing Grapple with Dodge."
			% (
				heroine.definition.display_name
				if heroine != null and heroine.definition != null
				else String(pending_grapple_dodge_attempt.target_id)
			)
		)
		_resume_after_grapple_dodge_step()
		return true
	if pending_dodge_result != null:
		log_presenter.append(
			"%s keeps position after Dodge."
			% pending_dodge_target.definition.display_name
		)
		_resume_after_dodge_step()
		return true
	if struggle_panel != null and struggle_panel.visible:
		_on_struggle_cancelled()
		return true
	if ability_panel != null and ability_panel.visible:
		_on_ability_menu_cancelled()
		return true
	if battle_runtime == null:
		return false
	if battle_runtime.is_selecting_item_target:
		_cancel_item_targeting("Item targeting cancelled.")
		return true
	if battle_runtime.is_selecting_move:
		_on_move_cancelled()
		return true
	if battle_runtime.is_selecting_aoe:
		_on_aoe_cancelled()
		return true
	if battle_runtime.is_selecting_ability_target:
		_cancel_ability_targeting("Ability targeting cancelled.")
		return true
	if battle_runtime.is_selecting_attack_target:
		_cancel_attack_targeting()
		log_presenter.append("Attack targeting cancelled.")
		return true
	return false


func _prepare_pending_attack(
	target: BattlerState
) -> void:
	if target == null or target.definition == null:
		log_presenter.append(
			"Selected target is invalid."
		)
		return

	var context: ReactionContext = (
		action_controller.prepare_attack(
			target.definition.battler_id
		)
	)

	if not context.is_valid:
		log_presenter.append(
			"Attack failed: %s"
			% context.error_message
		)

		if not battle_runtime.is_selecting_attack_target:
			_set_attack_command_hint("Attack")

		# Invalid target choices leave target selection active.
		return

	var attacker: BattlerState = (
		action_controller.get_pending_reaction_attacker()
	)

	target = action_controller.get_pending_reaction_target()

	assert(
		attacker != null and target != null,
		"Committed attack lost its combatants."
	)

	_set_attack_command_hint("Attack")
	_set_attack_targeting_markers(false)
	_set_commands_locked(true)

	log_presenter.log_attack_committed(
		attacker,
		target,
		context
	)

	_present_pending_reaction(
		context,
		target
	)


func _present_pending_reaction(
	context: ReactionContext,
	target: BattlerState
) -> void:
	if context == null or target == null or target.definition == null:
		_clear_pending_reaction()
		return
	if context.request != null:
		_present_battler_visual_event(
			context.request.actor_id,
			(
				&"cast_started"
				if context.request.source in [
					ActionRequest.Source.ABILITY,
					ActionRequest.Source.AOE,
				]
				else &"attack_started"
			)
		)

	if target.current_actions <= 0:
		log_presenter.debug(
			"No Actions available. Reaction skipped."
		)
		combat_presenter.close_reaction_exchange()
		_resolve_automatic_skip()
		return

	if target.is_attached_grappler():
		log_presenter.debug(
			"Attached grapplers cannot use active Defense reactions."
		)
		combat_presenter.close_reaction_exchange()
		_resolve_automatic_skip()
		return

	if target.definition.faction == BattlerDefinition.Faction.ENEMY:
		combat_presenter.close_reaction_exchange()
		log_presenter.debug(
			"%s rulebook is resolving its reaction."
			% target.definition.display_name
		)
		if (
			context.request != null
			and context.request.reaction_mode
			== ActionRequest.ReactionMode.FULL
		):
			call_deferred("_resolve_enemy_attack_reaction")
		else:
			call_deferred("_resolve_enemy_defense")
		return

	combat_presenter.present_reaction(
		context,
		action_controller.get_pending_reaction_attacker(),
		target,
		true
	)


func _present_reaction_panel(
	context: ReactionContext,
	target: BattlerState
) -> void:
	if target == null or target.definition == null:
		_clear_pending_reaction()
		return
	if target.definition.faction == BattlerDefinition.Faction.ENEMY:
		call_deferred("_resolve_enemy_defense")
		return
	combat_presenter.present_reaction(
		context,
		action_controller.get_pending_reaction_attacker(),
		target,
		true
	)


func _resolve_enemy_attack_reaction() -> void:
	if not battle_runtime.has_pending_reaction():
		return

	var target: BattlerState = (
		action_controller.get_pending_reaction_target()
	)
	if target == null or target.definition == null:
		return

	var choice: AttackReactionChoice.Type = (
		enemy_ai_controller.choose_attack_reaction(
			target,
			action_controller.can_counterattack(target)
		)
	)
	log_presenter.debug(
		"%s rulebook chose %s." % [
			target.definition.display_name,
			enemy_ai_controller.get_attack_reaction_label(choice),
		]
	)
	_on_attack_reaction_chosen(choice)


func _resolve_enemy_defense() -> void:
	if not battle_runtime.has_pending_reaction():
		return

	var target: BattlerState = (
		action_controller.get_pending_reaction_target()
	)
	if target == null or target.definition == null:
		return

	var choice: DefenseChoice.Type = (
		enemy_ai_controller.choose_defense(
			target,
			action_controller
		)
	)
	log_presenter.debug(
		"%s rulebook chose %s." % [
			target.definition.display_name,
			enemy_ai_controller.get_defense_label(choice),
		]
	)
	_on_defense_chosen(choice)


func _on_attack_reaction_chosen(
	choice: AttackReactionChoice.Type
) -> void:
	if not battle_runtime.has_pending_reaction():
		push_error(
			"No ReactionContext is pending."
		)
		return

	var attacker: BattlerState = (
		action_controller.get_pending_reaction_attacker()
	)
	var target: BattlerState = (
		action_controller.get_pending_reaction_target()
	)

	if attacker == null or target == null:
		push_error(
			"Pending attack combatants are missing."
		)
		_clear_pending_reaction()
		return

	var result: ActionResult = (
		action_controller.resolve_attack_reaction(choice)
	)

	if not result.succeeded:
		log_presenter.append(
			"Reaction failed: %s"
			% result.error_message
		)
		_present_pending_reaction(
			battle_runtime.pending_reaction_context,
			target
		)
		return

	if choice == AttackReactionChoice.Type.DEFEND:
		_present_reaction_panel(
			battle_runtime.pending_reaction_context,
			target
		)
		return

	if result.requires_equipment_break_choice:
		_present_pending_equipment_break(
			target,
			result
		)
		return

	_finish_completed_action(
		attacker,
		target,
		result
	)


func _on_reusable_reaction_selected(
	choice: StringName
) -> void:
	var target := action_controller.get_pending_reaction_target()
	if (
		target == null
		or target.definition == null
		or target.definition.faction
		== BattlerDefinition.Faction.ENEMY
	):
		return
	match choice:
		&"attack":
			_on_attack_reaction_chosen(
				AttackReactionChoice.Type.COUNTERATTACK
			)
		&"dodge":
			_on_defense_chosen(DefenseChoice.Type.DODGE)
		&"parry":
			_on_defense_chosen(DefenseChoice.Type.PARRY)
		&"skip":
			if (
				battle_runtime.has_pending_reaction()
				and battle_runtime.pending_reaction_context.request
				!= null
				and battle_runtime.pending_reaction_context.request.reaction_mode
				== ActionRequest.ReactionMode.FULL
			):
				_on_attack_reaction_chosen(
					AttackReactionChoice.Type.SKIP
				)
			else:
				_on_defense_chosen(DefenseChoice.Type.SKIP)


func _on_reusable_defence_selected(
	choice: StringName
) -> void:
	var target := action_controller.get_pending_reaction_target()
	if (
		target == null
		or target.definition == null
		or target.definition.faction
		== BattlerDefinition.Faction.ENEMY
	):
		return
	match choice:
		&"armor":
			_on_defense_chosen(DefenseChoice.Type.ARMOR)
		&"shield":
			_on_defense_chosen(DefenseChoice.Type.SHIELD)


func _on_reusable_equipment_break_selected(
	choice: StringName
) -> void:
	# The equipment decision is terminal. Remove its modal before resolving
	# damage so the next state is always presented on a clean exchange.
	combat_presenter.close_reaction_exchange()
	match choice:
		&"preserve":
			_on_equipment_break_choice(BreakChoice.Type.PRESERVE)
		&"destroy":
			_on_equipment_break_choice(BreakChoice.Type.DESTROY)


func _on_defense_chosen(
	choice: DefenseChoice.Type
) -> void:
	if not battle_runtime.has_pending_reaction():
		push_error(
			"No ReactionContext is pending."
		)
		return

	var attacker: BattlerState = (
		action_controller.get_pending_reaction_attacker()
	)

	var target: BattlerState = (
		action_controller.get_pending_reaction_target()
	)

	if attacker == null or target == null:
		push_error(
			"Pending attack combatants are missing."
		)
		_clear_pending_reaction()
		return
	if choice != DefenseChoice.Type.SKIP:
		_present_battler_visual_event(
			target.definition.battler_id,
			&"defend_started"
		)

	var result: ActionResult = (
		action_controller.resolve_reaction(choice)
	)

	if (
		battle_runtime.pending_reaction_context.request != null
		and battle_runtime.pending_reaction_context.request.reaction_mode
		== ActionRequest.ReactionMode.FULL
		and battle_runtime.pending_attack_reaction_choice
		== AttackReactionChoice.Type.DEFEND
	):
		result.attack_reaction_choice = (
			AttackReactionChoice.Type.DEFEND
		)
	elif choice == DefenseChoice.Type.SKIP:
		result.attack_reaction_choice = (
			AttackReactionChoice.Type.SKIP
		)
	else:
		result.attack_reaction_choice = (
			AttackReactionChoice.Type.DEFEND
		)

	if not result.succeeded:
		log_presenter.append(
			"Reaction failed: %s"
			% result.error_message
		)

		_present_pending_reaction(
			battle_runtime.pending_reaction_context,
			target
		)
		return

	if result.requires_equipment_break_choice:
		_present_pending_equipment_break(
			target,
			result
		)
		return

	_finish_completed_action(
		attacker,
		target,
		result
	)


func _on_equipment_break_choice(
	choice: BreakChoice.Type
) -> void:
	if (
		not battle_runtime.has_pending_reaction()
		or battle_runtime.pending_action_result == null
	):
		push_error(
			"No equipment-break resolution is pending."
		)
		return

	var attacker: BattlerState = (
		action_controller.get_pending_reaction_attacker()
	)

	var target: BattlerState = (
		action_controller.get_pending_reaction_target()
	)

	if attacker == null or target == null:
		push_error(
			"Pending equipment-break combatants are missing."
		)
		_clear_pending_reaction()
		return

	var result: ActionResult = (
		action_controller.resolve_equipment_break_choice(
			choice
		)
	)

	if not result.succeeded:
		log_presenter.append(
			"Equipment allocation failed: %s"
			% result.error_message
		)
		return

	if result.requires_equipment_break_choice:
		_present_pending_equipment_break(
			target,
			result
		)
		return

	_finish_completed_action(
		attacker,
		target,
		result
	)


func _finish_completed_action(
	attacker: BattlerState,
	target: BattlerState,
	result: ActionResult
) -> void:
	var completed_context: ReactionContext = (
		battle_runtime.pending_reaction_context
	)

	assert(
		completed_context != null
		and completed_context.request != null,
		"A completed Action lost its ReactionContext."
	)

	if (
		not resolving_dodge_step
		and result.dodge_step_available
		and not result.dodge_step_taken
		and target != null
		and target.definition != null
		and not target.is_defeated
		and not target.is_grappled()
	):
		var destinations: Array[Dictionary] = (
			dodge_step_controller.get_legal_destinations(
				target.definition.battler_id,
				attacker.definition.battler_id
			)
		)
		if not destinations.is_empty():
			if (
				target.definition.faction
				== BattlerDefinition.Faction.ENEMY
			):
				_apply_enemy_dodge_step(
					attacker,
					target,
					result
				)
			else:
				pending_dodge_attacker = attacker
				pending_dodge_target = target
				pending_dodge_result = result
				combat_presenter.close_reaction_exchange()
				battlefield_input_overlay.begin_dodge_step_selection(
					destinations,
					target.definition.display_name
				)
				log_presenter.append(
					"%s prevented damage with Dodge and may take one defensive step."
					% target.definition.display_name
				)
				return

	var completed_was_aoe_target: bool = (
		completed_context.request.source
		== ActionRequest.Source.AOE
	)
	var completed_was_item_attack: bool = (
		completed_context.request.source
		== ActionRequest.Source.ITEM
	)
	var completed_was_multi_target_art: bool = (
		completed_context.request.source
		== ActionRequest.Source.ABILITY
		and battle_runtime.has_active_multi_target_attack()
		and battle_runtime.active_multi_target_attack.current_target_id
		== completed_context.request.target_id
	)
	if completed_was_aoe_target:
		aoe_controller.complete_current_target()
	if completed_was_multi_target_art:
		ability_controller.complete_current_multi_target()
	if completed_was_item_attack:
		var item_result: ItemUseResult = (
			item_use_controller.complete_pending_item_attack(
				result
			)
		)
		_log_item_use_result(item_result)
		_refresh_item_bar()

	var follow_up_error: String = (
		action_controller.enqueue_result_follow_up(
			result
		)
	)

	log_presenter.log_attack_result(
		attacker,
		target,
		completed_context.request.weapon,
		result
	)

	if not follow_up_error.is_empty():
		log_presenter.log_generated_attack_failed(
			follow_up_error
		)

	if _evaluate_and_present_outcome():
		return

	if action_controller.has_queued_attacks():
		_present_next_queued_attack()
		return

	if battle_runtime.has_active_multi_target_attack():
		_continue_multi_target_if_needed()
		return

	if battle_runtime.has_active_aoe():
		_continue_aoe_if_needed()
		return

	_clear_pending_reaction()


func _on_dodge_step_confirmed(
	anchor_id: StringName,
	position_index: int
) -> void:
	if pending_grapple_dodge_attempt != null:
		var attempt: GrappleAttemptResult = pending_grapple_dodge_attempt
		var grappler: BattlerState = get_battler_state(attempt.actor_id)
		var heroine: BattlerState = get_battler_state(attempt.target_id)
		if (
			grappler == null
			or grappler.definition == null
			or heroine == null
			or heroine.definition == null
		):
			_resume_after_grapple_dodge_step()
			return
		var grapple_placement_error: String = (
			dodge_step_controller.apply_step(
				attempt.target_id,
				attempt.actor_id,
				anchor_id,
				position_index
			)
		)
		if not grapple_placement_error.is_empty():
			log_presenter.append(
				"Grapple Dodge step failed: %s"
				% grapple_placement_error
			)
			return
		var grapple_anchor := battlefield_definition.get_anchor(anchor_id)
		log_presenter.append(
			"%s takes a defensive Grapple Dodge step to %s Position %d."
			% [
				heroine.definition.display_name,
				(
					grapple_anchor.display_name
					if grapple_anchor != null
					else String(anchor_id)
				),
				position_index + 1,
			]
		)
		_resume_after_grapple_dodge_step()
		return

	if (
		pending_dodge_attacker == null
		or pending_dodge_target == null
		or pending_dodge_result == null
	):
		return
	var placement_error: String = dodge_step_controller.apply_step(
		pending_dodge_target.definition.battler_id,
		pending_dodge_attacker.definition.battler_id,
		anchor_id,
		position_index
	)
	if not placement_error.is_empty():
		log_presenter.append(
			"Dodge step failed: %s" % placement_error
		)
		return

	pending_dodge_result.dodge_step_taken = true
	pending_dodge_result.dodge_destination_anchor_id = anchor_id
	pending_dodge_result.dodge_destination_position_index = (
		position_index
	)
	log_presenter.append(
		"%s takes a defensive Dodge step to %s Position %d."
		% [
			pending_dodge_target.definition.display_name,
			battlefield_definition.get_anchor(anchor_id).display_name,
			position_index + 1,
		]
	)
	_resume_after_dodge_step()


func _apply_enemy_dodge_step(
	attacker: BattlerState,
	target: BattlerState,
	result: ActionResult
) -> void:
	var destination: Dictionary = (
		dodge_step_controller.choose_ai_destination(
			target.definition.battler_id,
			attacker.definition.battler_id
		)
	)
	if destination.is_empty():
		return
	var anchor_id := StringName(
		destination.get("anchor_id", &"")
	)
	var position_index := int(
		destination.get("position_index", -1)
	)
	var placement_error := dodge_step_controller.apply_step(
		target.definition.battler_id,
		attacker.definition.battler_id,
		anchor_id,
		position_index
	)
	if not placement_error.is_empty():
		log_presenter.append(
			"%s could not complete its Dodge step: %s"
			% [target.definition.display_name, placement_error]
		)
		return
	result.dodge_step_taken = true
	result.dodge_destination_anchor_id = anchor_id
	result.dodge_destination_position_index = position_index
	var anchor := battlefield_definition.get_anchor(anchor_id)
	log_presenter.append(
		"%s rulebook takes its optional Dodge step to %s Position %d."
		% [
			target.definition.display_name,
			anchor.display_name if anchor != null else String(anchor_id),
			position_index + 1,
		]
	)


func _resume_after_dodge_step() -> void:
	var attacker := pending_dodge_attacker
	var target := pending_dodge_target
	var result := pending_dodge_result
	pending_dodge_attacker = null
	pending_dodge_target = null
	pending_dodge_result = null
	battlefield_input_overlay.clear_selection()
	resolving_dodge_step = true
	_finish_completed_action(attacker, target, result)
	resolving_dodge_step = false


func _present_next_queued_attack() -> void:
	while action_controller.has_queued_attacks():
		var context: ReactionContext = (
			action_controller.prepare_next_queued_attack()
		)

		if not context.is_valid:
			log_presenter.log_generated_attack_failed(
				context.error_message
			)
			continue

		var attacker: BattlerState = (
			action_controller.get_pending_reaction_attacker()
		)
		var target: BattlerState = (
			action_controller.get_pending_reaction_target()
		)

		if attacker == null or target == null:
			log_presenter.log_generated_attack_failed(
				"Queued Attack lost its combatants."
			)
			continue

		log_presenter.log_attack_committed(
			attacker,
			target,
			context
		)

		_present_pending_reaction(
			context,
			target
		)
		return

	if battle_runtime.has_active_multi_target_attack():
		_continue_multi_target_if_needed()
		return

	if battle_runtime.has_active_aoe():
		_continue_aoe_if_needed()
		return

	_clear_pending_reaction()


func _continue_multi_target_if_needed() -> void:
	battle_runtime.clear_pending_reaction()
	if not battle_runtime.has_active_multi_target_attack():
		_clear_pending_reaction()
		return

	var state: MultiTargetAttackState = (
		battle_runtime.active_multi_target_attack
	)
	var caster: BattlerState = get_battler_state(state.caster_id)
	if (
		caster == null
		or caster.definition == null
		or caster.is_defeated
		or not state.has_remaining_targets()
	):
		ability_controller.finish_active_multi_target_attack()
		log_presenter.append(
			"%s resolution complete." % state.ability.display_name
		)
		_clear_pending_reaction()
		return

	var context: ReactionContext = (
		ability_controller.prepare_next_multi_target_attack()
	)
	if not context.is_valid:
		ability_controller.finish_active_multi_target_attack()
		log_presenter.append(
			"%s stopped: %s" % [
				state.ability.display_name,
				context.error_message,
			]
		)
		_clear_pending_reaction()
		return

	var target: BattlerState = (
		action_controller.get_pending_reaction_target()
	)
	if target == null or target.definition == null:
		ability_controller.finish_active_multi_target_attack()
		log_presenter.append(
			"%s stopped: target is missing."
			% state.ability.display_name
		)
		_clear_pending_reaction()
		return

	log_presenter.append(
		"%s next target: %s; incoming successes: %d." % [
			state.ability.display_name,
			target.definition.display_name,
			context.attack_successes,
		]
	)
	_present_pending_reaction(context, target)


func _continue_aoe_if_needed() -> void:
	battle_runtime.clear_pending_reaction()
	if not battle_runtime.has_active_aoe():
		_clear_pending_reaction()
		return

	var aoe_state: AoeResolutionState = battle_runtime.active_aoe
	var caster: BattlerState = get_battler_state(
		aoe_state.caster_id
	)
	if (
		caster == null
		or caster.definition == null
		or caster.is_defeated
		or not aoe_state.has_remaining_targets()
	):
		aoe_controller.finish_active_aoe()
		log_presenter.append("AOE resolution complete.")
		_clear_pending_reaction()
		return

	var context: ReactionContext = aoe_controller.prepare_next_target()
	if not context.is_valid:
		aoe_controller.finish_active_aoe()
		log_presenter.append(
			"AOE stopped: %s" % context.error_message
		)
		_clear_pending_reaction()
		return

	var target: BattlerState = (
		action_controller.get_pending_reaction_target()
	)
	if target == null or target.definition == null:
		aoe_controller.finish_active_aoe()
		log_presenter.append("AOE stopped: target is missing.")
		_clear_pending_reaction()
		return

	log_presenter.append(
		"AOE next target: %s; shared incoming successes: %d."
		% [
			target.definition.display_name,
			context.attack_successes,
		]
	)
	_present_pending_reaction(context, target)


func _resolve_automatic_skip() -> void:
	if not battle_runtime.has_pending_reaction():
		return

	var context: ReactionContext = (
		battle_runtime.pending_reaction_context
	)

	if (
		context.request != null
		and context.request.reaction_mode
		== ActionRequest.ReactionMode.FULL
	):
		_on_attack_reaction_chosen(
			AttackReactionChoice.Type.SKIP
		)
		return

	_on_defense_chosen(
		DefenseChoice.Type.SKIP
	)


func _present_pending_equipment_break(
	target: BattlerState,
	result: ActionResult
) -> void:
	var item_name: String = "Defensive equipment"

	match result.pending_break_item:
		ActionResult.AllocationItem.ARMOR:
			assert(
				target.armor_state != null
				and target.armor_state.definition != null,
				"Armor confirmation requires valid armor."
			)
			item_name = target.armor_state.definition.display_name

		ActionResult.AllocationItem.SHIELD:
			assert(
				target.shield_state != null
				and target.shield_state.definition != null,
				"Shield confirmation requires a valid shield."
			)
			item_name = target.shield_state.definition.display_name

		_:
			push_error(
				"Unknown pending equipment-break item."
			)
			return

	if (
		target.definition != null
		and target.definition.faction
		== BattlerDefinition.Faction.ENEMY
	):
		var enemy_choice: BreakChoice.Type = (
			enemy_ai_controller.choose_break_choice(target)
		)
		log_presenter.debug(
			"%s rulebook chose %s %s." % [
				target.definition.display_name,
				(
					"Destroy"
					if enemy_choice == BreakChoice.Type.DESTROY
					else "Preserve"
				),
				item_name,
			]
		)
		call_deferred(
			"_on_equipment_break_choice",
			enemy_choice
		)
		return

	if (
		target != null
		and target.definition != null
		and target.definition.faction
		== BattlerDefinition.Faction.HEROINE
	):
		combat_presenter.present_equipment_break(
			item_name,
			result.pending_damage_after_safe_absorption,
			target
		)


func _clear_pending_reaction() -> void:
	action_controller.clear_pending_reaction()
	if combat_presenter != null:
		combat_presenter.close_reaction_exchange()

	if battle_runtime.has_active_move():
		call_deferred("_continue_committed_move")
		return

	_set_commands_locked(false)

	if enemy_ai_controller.is_enemy_phase_active():
		_enemy_action_completed()


func _cancel_attack_targeting() -> void:
	action_controller.cancel_attack_targeting()
	_set_attack_targeting_markers(false)

	if attack_button != null:
		_set_attack_command_hint("Attack")


func _set_attack_command_hint(hint: String) -> void:
	if reusable_hud != null and reusable_hud.command_bar != null:
		reusable_hud.command_bar.set_attack_hint(hint)
	elif attack_button != null:
		attack_button.text = ""
		attack_button.tooltip_text = hint


func _set_move_command_hint(hint: String) -> void:
	if reusable_hud != null and reusable_hud.command_bar != null:
		reusable_hud.command_bar.set_move_hint(hint)
	elif move_button != null:
		move_button.text = ""
		move_button.tooltip_text = hint


func _set_ability_command_hint(hint: String) -> void:
	if reusable_hud != null and reusable_hud.command_bar != null:
		reusable_hud.command_bar.set_ability_hint(hint)
	elif aoe_button != null:
		aoe_button.text = ""
		aoe_button.tooltip_text = hint


func _set_attack_targeting_markers(
	active: bool,
	legal_target_ids: Array[StringName] = []
) -> void:
	if battlefield_overlay != null:
		var actor_id: StringName = &""
		if active:
			actor_id = battle_runtime.pending_attacker_id
			if actor_id == &"":
				actor_id = battle_runtime.pending_ability_caster_id
			if actor_id == &"":
				actor_id = battle_runtime.pending_item_user_id
			if actor_id == &"":
				actor_id = battle_runtime.selected_battler_id
		battlefield_overlay.set_targeting_contacts(
			active,
			actor_id,
			legal_target_ids
		)
	for marker: BattleMarker in battler_markers:
		if marker == null:
			continue
		marker.set_selection_visibility(
			active,
			0.72 if legal_target_ids.has(marker.battler_id) else 0.46
		)
		marker.set_attack_targeting(
			active,
			active and legal_target_ids.has(marker.battler_id)
		)


func _on_board_selection_visibility_changed(active: bool) -> void:
	for marker: BattleMarker in battler_markers:
		if marker != null:
			marker.set_selection_visibility(active, 0.46)


func _get_battler_name_list(
	battler_ids: Array[StringName]
) -> String:
	var names: Array[String] = []
	for battler_id: StringName in battler_ids:
		var state: BattlerState = get_battler_state(battler_id)
		names.append(
			state.definition.display_name
			if state != null and state.definition != null
			else String(battler_id)
		)

	if names.is_empty():
		return "none"

	names.sort()
	return ", ".join(PackedStringArray(names))


func _get_battler_display_name(
	battler_id: StringName
) -> String:
	var state: BattlerState = get_battler_state(battler_id)
	return (
		state.definition.display_name
		if state != null and state.definition != null
		else String(battler_id)
	)


func _set_commands_locked(
	locked: bool
) -> void:
	commands_locked = locked
	if combat_presenter != null:
		combat_presenter.set_commands_locked(locked)

	if attack_button != null:
		attack_button.disabled = locked

	if move_button != null:
		move_button.disabled = locked

	if aoe_button != null:
		aoe_button.disabled = locked

	if struggle_button != null:
		struggle_button.disabled = locked

	if grapple_wait_button != null:
		grapple_wait_button.disabled = locked

	if submit_button != null:
		submit_button.disabled = true

	if not locked:
		_refresh_battle_flow_ui()
	else:
		_refresh_grapple_command_bar()
		_refresh_item_bar()


func _refresh_grapple_command_bar() -> void:
	if (
		attack_button == null
		or move_button == null
		or aoe_button == null
		or struggle_button == null
		or grapple_wait_button == null
		or submit_button == null
	):
		return

	var selected: BattlerState = get_battler_state(
		battle_runtime.selected_battler_id
	)
	var grapple_mode: bool = (
		selected != null
		and selected.definition != null
		and selected.definition.faction
		== BattlerDefinition.Faction.HEROINE
		and selected.is_grappled()
	)
	attack_button.visible = not grapple_mode
	move_button.visible = not grapple_mode
	aoe_button.visible = not grapple_mode
	struggle_button.visible = grapple_mode
	grapple_wait_button.visible = grapple_mode
	submit_button.visible = grapple_mode

	if not grapple_mode:
		return

	var hero_phase: bool = (
		battle_runtime.battle_state.encounter_started
		and battle_runtime.battle_state.phase == BattleState.Phase.HERO
	)
	var can_act: bool = (
		hero_phase
		and not commands_locked
		and not selected.is_defeated
		and not selected.is_stunned()
		and selected.current_actions > 0
	)
	struggle_button.disabled = not can_act
	grapple_wait_button.disabled = not can_act
	submit_button.disabled = true

	var unavailable_reason: String = ""
	if selected.is_defeated:
		unavailable_reason = "Defeated heroines cannot act."
	elif selected.is_stunned():
		unavailable_reason = "Stunned heroines cannot act."
	elif selected.current_actions <= 0:
		unavailable_reason = "No Actions remain."
	elif not hero_phase:
		unavailable_reason = "Available during the Hero Phase."
	elif commands_locked:
		unavailable_reason = "Finish the current resolution first."

	struggle_button.tooltip_text = (
		unavailable_reason
		if not can_act
		else "Spend all remaining Actions on an opposed Attribute check."
	)
	grapple_wait_button.tooltip_text = (
		unavailable_reason
		if not can_act
		else "End this heroine's activation without resisting."
	)
	submit_button.tooltip_text = (
		"Requires Refuge Grapple upgrade level 1."
	)


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
	Engine.time_scale = 1.0


func _start_enemy_ai_if_needed() -> void:
	var state: BattleState = battle_runtime.battle_state
	if (
		state.phase != BattleState.Phase.ENEMY
		or enemy_ai_controller.is_enemy_phase_active()
	):
		return

	var start_error: String = (
		enemy_ai_controller.begin_enemy_phase()
	)
	if not start_error.is_empty():
		log_presenter.append(
			"Enemy AI could not start: %s" % start_error
		)
		return

	enemy_ai_advancing = false
	_set_commands_locked(true)
	log_presenter.append("")
	log_presenter.append(
		"Enemy group rulebook selected its activation order."
	)
	call_deferred("_continue_enemy_ai")


func _continue_enemy_ai() -> void:
	if enemy_ai_advancing:
		return
	if not enemy_ai_controller.is_enemy_phase_active():
		return
	if (
		battle_runtime.has_pending_reaction()
		or battle_runtime.has_active_move()
		or pending_player_move_reaction
		or grapple_controller.has_pending_initiation()
	):
		return

	var decision: EnemyDecision = (
		enemy_ai_controller.get_next_decision()
	)

	if decision == null:
		if enemy_ai_controller.is_phase_complete():
			_finish_enemy_ai_phase()
		return

	enemy_ai_advancing = true

	await get_tree().create_timer(0.3).timeout

	if (
		not enemy_ai_controller.is_enemy_phase_active()
		or battle_runtime.has_pending_reaction()
		or battle_runtime.has_active_move()
		or grapple_controller.has_pending_initiation()
	):
		enemy_ai_advancing = false
		return

	_execute_enemy_decision(decision)


func _execute_enemy_decision(
	decision: EnemyDecision
) -> void:
	enemy_ai_advancing = false
	if decision == null or not decision.is_valid():
		enemy_ai_controller.forfeit_current_actor_actions(
			"Invalid EnemyDecision."
		)
		call_deferred("_continue_enemy_ai")
		return

	var actor: BattlerState = get_battler_state(decision.actor_id)
	if actor == null or actor.definition == null:
		enemy_ai_controller.forfeit_current_actor_actions(
			"Acting enemy is missing."
		)
		call_deferred("_continue_enemy_ai")
		return

	battle_runtime.selected_battler_id = decision.actor_id
	battlefield_overlay.set_selected_battler(decision.actor_id)

	match decision.type:
		EnemyDecision.Type.ATTACK:
			_execute_enemy_attack(decision, actor)
		EnemyDecision.Type.MOVE:
			_execute_enemy_move(decision, actor)
		EnemyDecision.Type.GRAPPLE:
			_execute_enemy_grapple(decision, actor)
		EnemyDecision.Type.GRAPPLE_HOLD:
			_execute_enemy_grapple_action(decision, true)
		EnemyDecision.Type.GRAPPLE_PROGRESS:
			_execute_enemy_grapple_action(decision, false)
		EnemyDecision.Type.ABILITY:
			_execute_enemy_ability(decision, actor)
		EnemyDecision.Type.WAIT:
			actor.set_current_actions(0)
			log_presenter.append(
				"%s used Wait and forfeited remaining Actions."
				% actor.definition.display_name
			)
			_enemy_action_completed()
		_:
			enemy_ai_controller.forfeit_current_actor_actions(
				"Unsupported enemy Action."
			)
			call_deferred("_continue_enemy_ai")


func _execute_enemy_ability(
	decision: EnemyDecision,
	actor: BattlerState
) -> void:
	var ability: AbilityDefinition = actor.get_ability(
		decision.ability_id
	)
	if ability == null:
		log_presenter.append(
			"%s could not find ability '%s'."
			% [actor.definition.display_name, decision.ability_id]
		)
		actor.spend_actions(1)
		_enemy_action_completed()
		return
	ability_controller.attack_seed = (
		enemy_ai_controller.get_next_attack_seed()
	)
	var legal_ids: Array[StringName] = (
		ability_controller.begin_targeting(
			actor.definition.battler_id,
			ability
		)
	)
	if not legal_ids.has(decision.target_id):
		log_presenter.append(
			"%s could not use %s on its selected target."
			% [actor.definition.display_name, ability.display_name]
		)
		actor.spend_actions(ability.action_cost)
		_enemy_action_completed()
		return
	_present_battler_visual_event(
		actor.definition.battler_id,
		&"cast_started"
	)
	var outcome: Variant = ability_controller.commit_target(
		decision.target_id
	)
	if outcome is ReactionContext:
		var context: ReactionContext = outcome as ReactionContext
		if not context.is_valid:
			log_presenter.append(
				"%s failed: %s"
				% [ability.display_name, context.error_message]
			)
			_enemy_action_completed()
			return
		var target: BattlerState = get_battler_state(
			decision.target_id
		)
		_set_commands_locked(true)
		log_presenter.log_attack_committed(
			actor,
			target,
			context
		)
		_present_pending_reaction(context, target)
		return
	var direct_result: AbilityUseResult = outcome as AbilityUseResult
	_log_ability_use_result(direct_result)
	_evaluate_and_present_outcome()
	_enemy_action_completed()


func _execute_enemy_attack(
	decision: EnemyDecision,
	actor: BattlerState
) -> void:
	action_controller.attack_seed = (
		enemy_ai_controller.get_next_attack_seed()
	)
	var begin_error: String = (
		action_controller.begin_attack_targeting()
	)
	if not begin_error.is_empty():
		log_presenter.append(
			"%s rulebook Attack failed: %s" % [
				actor.definition.display_name,
				begin_error,
			]
		)
		actor.spend_actions(1)
		enemy_ai_controller.complete_pending_decision()
		call_deferred("_continue_enemy_ai")
		return

	var context: ReactionContext = (
		action_controller.prepare_attack(decision.target_id)
	)
	if not context.is_valid:
		log_presenter.append(
			"%s rulebook Attack failed revalidation: %s" % [
				actor.definition.display_name,
				context.error_message,
			]
		)
		action_controller.cancel_attack_targeting()
		actor.spend_actions(1)
		enemy_ai_controller.complete_pending_decision()
		call_deferred("_continue_enemy_ai")
		return

	var target: BattlerState = get_battler_state(
		decision.target_id
	)
	_set_commands_locked(true)
	log_presenter.log_attack_committed(
		actor,
		target,
		context
	)
	_present_pending_reaction(context, target)


func _execute_enemy_move(
	decision: EnemyDecision,
	actor: BattlerState
) -> void:
	battle_runtime.begin_move_targeting(decision.actor_id)
	var move_state: CommittedMoveState = (
		movement_controller.begin_committed_move(
			decision.move_preview,
			decision.destination_position_index
		)
	)
	if not move_state.is_valid:
		log_presenter.append(
			"%s rulebook Move failed revalidation: %s" % [
				actor.definition.display_name,
				move_state.error_message,
			]
		)
		battle_runtime.cancel_move_targeting()
		actor.spend_actions(1)
		enemy_ai_controller.complete_pending_decision()
		call_deferred("_continue_enemy_ai")
		return
	_set_commands_locked(true)
	log_presenter.append("")
	log_presenter.append(
		"%s rulebook committed Move (1 Action): %s." % [
			actor.definition.display_name,
			decision.move_preview.get_route_label(
				battlefield_definition
			),
		]
	)
	call_deferred("_continue_committed_move")


func _execute_enemy_grapple(
	decision: EnemyDecision,
	actor: BattlerState
) -> void:
	var heroine: BattlerState = get_battler_state(decision.target_id)
	if heroine == null or heroine.definition == null:
		log_presenter.append(
			"%s rulebook Grapple failed: target is missing."
			% actor.definition.display_name
		)
		actor.spend_actions(1)
		enemy_ai_controller.complete_pending_decision()
		call_deferred("_continue_enemy_ai")
		return
	if heroine != null and heroine.is_grappled():
		var attachment: GrappleActionResult = (
			grapple_controller.attach_secondary(
				decision.actor_id,
				decision.target_id
			)
		)
		_log_grapple_action_result(attachment)
		enemy_ai_controller.complete_pending_decision()
		call_deferred("_continue_enemy_ai")
		return

	var attempt: GrappleAttemptResult = (
		grapple_controller.prepare_initiation(
			decision.actor_id,
			decision.target_id
		)
	)
	if not attempt.error_message.is_empty():
		log_presenter.append(
			"%s rulebook Grapple failed revalidation: %s" % [
				actor.definition.display_name,
				attempt.error_message,
			]
		)
		actor.spend_actions(1)
		enemy_ai_controller.complete_pending_decision()
		call_deferred("_continue_enemy_ai")
		return
	_present_battler_visual_event(
		decision.actor_id,
		&"grapple_started"
	)

	log_presenter.log_grapple_attempt(actor, heroine, attempt)
	_set_commands_locked(true)
	combat_presenter.close_reaction_exchange()
	if heroine.current_actions <= 0 or heroine.is_defeated:
		log_presenter.debug(
			"%s has no available Dodge reaction. Grapple resolves automatically."
			% heroine.definition.display_name
		)
		call_deferred("_on_grapple_response_chosen", false)
		return
	combat_presenter.present_grapple_reaction(
		attempt,
		actor,
		heroine
	)


func _on_grapple_response_chosen(
	dodge: bool
) -> void:
	combat_presenter.close_reaction_exchange()
	pending_grapple_move_reaction = false
	var attempt: GrappleAttemptResult = (
		grapple_controller.resolve_initiation(dodge)
	)
	if not attempt.error_message.is_empty():
		log_presenter.append(
			"Grapple resolution failed: %s" % attempt.error_message
		)
	else:
		var resolved_grappler: BattlerState = get_battler_state(
			attempt.actor_id
		)
		var resolved_heroine: BattlerState = get_battler_state(
			attempt.target_id
		)
		log_presenter.log_grapple_result(
			resolved_grappler,
			resolved_heroine,
			attempt,
			dodge
		)
	_refresh_grapple_command_bar()

	if (
		attempt.error_message.is_empty()
		and dodge
		and not attempt.succeeded
		and attempt.dodge_successes > 0
	):
		var destinations: Array[Dictionary] = (
			dodge_step_controller.get_legal_destinations(
				attempt.target_id,
				attempt.actor_id
			)
		)
		if not destinations.is_empty():
			var heroine: BattlerState = get_battler_state(
				attempt.target_id
			)
			pending_grapple_dodge_attempt = attempt
			battlefield_input_overlay.begin_dodge_step_selection(
				destinations,
				(
					heroine.definition.display_name
					if heroine != null and heroine.definition != null
					else String(attempt.target_id)
				)
			)
			log_presenter.append_detail(
				"%s prevented Grapple with Dodge and may take one defensive step."
				% (
					heroine.definition.display_name
					if heroine != null and heroine.definition != null
					else String(attempt.target_id)
				)
			)
			return

	_complete_grapple_response(attempt)


func _resume_after_grapple_dodge_step() -> void:
	var attempt: GrappleAttemptResult = pending_grapple_dodge_attempt
	pending_grapple_dodge_attempt = null
	battlefield_input_overlay.clear_selection()
	_complete_grapple_response(attempt)


func _complete_grapple_response(
	attempt: GrappleAttemptResult
) -> void:
	if attempt == null:
		_enemy_action_completed()
		return
	if attempt.is_move_reaction:
		if attempt.succeeded:
			var grappler: BattlerState = get_battler_state(
				attempt.actor_id
			)
			var heroine: BattlerState = get_battler_state(
				attempt.target_id
			)
			movement_controller.interrupt_active_move(
				"%s was Grappled by %s."
				% [
					(
						heroine.definition.display_name
						if (
							heroine != null
							and heroine.definition != null
						)
						else String(attempt.target_id)
					),
					(
						grappler.definition.display_name
						if (
							grappler != null
							and grappler.definition != null
						)
						else String(attempt.actor_id)
					),
				]
			)
		call_deferred("_continue_committed_move")
		return

	_enemy_action_completed()


func _execute_enemy_grapple_action(
	decision: EnemyDecision,
	hold: bool
) -> void:
	var result: GrappleActionResult = (
		grapple_controller.hold_track(decision.actor_id)
		if hold
		else grapple_controller.progress_track(decision.actor_id)
	)
	_log_grapple_action_result(result)
	_refresh_grapple_command_bar()
	_evaluate_and_present_outcome()
	_enemy_action_completed()


func _enemy_action_completed() -> void:
	if not enemy_ai_controller.is_enemy_phase_active():
		_queue_combat_progression()
		return

	enemy_ai_controller.complete_pending_decision()
	_set_commands_locked(true)
	_queue_combat_progression()


func _finish_enemy_ai_phase() -> void:
	var state: BattleState = battle_runtime.battle_state
	var previous_round: int = state.round_number
	var previous_phase_label: String = state.get_phase_label()

	enemy_ai_controller.end_enemy_phase()
	enemy_ai_advancing = false

	log_presenter.log_phase_ended(
		previous_round,
		previous_phase_label
	)

	var phase_error: String = (
		battle_flow_controller.end_current_phase()
	)
	if not phase_error.is_empty():
		log_presenter.append(
			"Enemy Phase could not finish: %s"
			% phase_error
		)
		return

	if state.round_number != previous_round:
		log_presenter.log_round_started(
			state,
			battler_states
		)
		_log_round_start_kit_effects()

	log_presenter.log_phase_started(state)
	if _process_phase_start_and_outcome():
		return
	if _skip_momentum_locked_phase_if_needed():
		return
	_set_commands_locked(false)
	_refresh_battle_flow_ui()

	_queue_combat_progression()


func _on_struggle_pressed() -> void:
	var heroine: BattlerState = get_battler_state(
		battle_runtime.selected_battler_id
	)
	if heroine == null or not heroine.is_grappled():
		log_presenter.append("Select a grappled heroine first.")
		return
	var tracks: Array[GrappleTrackState] = (
		grapple_controller.get_tracks_for_heroine(
			heroine.definition.battler_id
		)
	)
	if tracks.is_empty():
		log_presenter.append("The selected heroine has no Grapple track.")
		return
	pending_struggle_heroine_id = heroine.definition.battler_id
	_set_commands_locked(true)
	struggle_panel.present(heroine, tracks, battler_states)


func _on_struggle_confirmed(
	track_id: StringName,
	attribute: AttributeSet.Attribute
) -> void:
	var heroine_id: StringName = pending_struggle_heroine_id
	pending_struggle_heroine_id = &""
	var result: GrappleActionResult = grapple_controller.struggle_track(
		heroine_id,
		track_id,
		attribute
	)
	struggle_panel.close_panel()
	_log_grapple_action_result(result)
	_set_commands_locked(false)
	_restore_selected_battler(heroine_id)
	_refresh_grapple_command_bar()
	_evaluate_and_present_outcome()


func _on_struggle_cancelled() -> void:
	var heroine_id: StringName = pending_struggle_heroine_id
	pending_struggle_heroine_id = &""
	struggle_panel.close_panel()
	_set_commands_locked(false)
	_restore_selected_battler(heroine_id)
	_refresh_grapple_command_bar()


func _restore_selected_battler(
	battler_id: StringName
) -> void:
	if battler_id == &"" or get_battler_state(battler_id) == null:
		return
	battle_runtime.selected_battler_id = battler_id
	battlefield_overlay.set_selected_battler(battler_id)


func _on_grapple_wait_pressed() -> void:
	var result: GrappleActionResult = grapple_controller.wait(
		battle_runtime.selected_battler_id
	)
	_log_grapple_action_result(result)
	_refresh_grapple_command_bar()


func _on_submit_pressed() -> void:
	log_presenter.append(
		"Submit is locked until Refuge Grapple upgrade level 1."
	)


func _log_grapple_action_result(
	result: GrappleActionResult
) -> void:
	if result == null:
		return
	if not result.error_message.is_empty():
		log_presenter.append(
			"%s failed: %s" % [
				result.action_name,
				result.error_message,
			]
		)
		return
	var heroine: BattlerState
	var grappler: BattlerState
	if result.track != null:
		heroine = get_battler_state(result.track.heroine_id)
		grappler = get_battler_state(result.track.grappler_id)
		match result.action_name:
			"Attach":
				_present_battler_visual_event(
					result.track.grappler_id,
					&"grapple_started"
				)
			"Progress", "Hold":
				_present_battler_visual_event(
					result.track.grappler_id,
					&"grapple_progressed"
				)
			"Struggle":
				_present_battler_visual_event(
					result.track.heroine_id,
					&"defend_started"
				)

	if result.action_name == "Struggle":
		log_presenter.log_struggle_result(heroine, grappler, result)
		return

	if result.action_name == "Attach":
		log_presenter.append(
			"%s joined the Grapple on %s."
			% [
				grappler.definition.display_name
				if grappler != null and grappler.definition != null
				else "An enemy",
				heroine.definition.display_name
				if heroine != null and heroine.definition != null
				else "the heroine",
			],
			"Secondary attachment: Stage %d/%d; Corruption +0, Resolve +0."
			% [result.stage_after, result.track.get_stage_count()]
		)
		return

	if result.action_name == "Forced Separation":
		log_presenter.append(
			"The Grapple between %s and %s ended."
			% [
				grappler.definition.display_name
				if grappler != null and grappler.definition != null
				else "the enemy",
				heroine.definition.display_name
				if heroine != null and heroine.definition != null
				else "the heroine",
			],
			"Forced Separation ended the selected track at Stage %d."
			% result.stage_before
		)
		return

	log_presenter.append(
		"%s advanced the Grapple on %s to Stage %d."
		% [
			grappler.definition.display_name
			if grappler != null and grappler.definition != null
			else result.action_name,
			heroine.definition.display_name
			if heroine != null and heroine.definition != null
			else "the heroine",
			result.stage_after,
		],
		"%s: Stage %d → %d; Corruption %+d, Resolve %+d."
		% [
			result.action_name,
			result.stage_before,
			result.stage_after,
			result.corruption_applied,
			result.resolve_applied,
		]
	)
	if result.track != null and not result.track.is_main:
		log_presenter.append_detail(
			"Secondary-track ordinary Corruption/Resolve effects suppressed."
		)
	if result.climax_reached:
		log_presenter.append_detail(
			"Climax resolved: the track ended and cooldown began."
		)


func _on_phase_button_pressed() -> void:
	if encounter_starting:
		return
	if not battle_runtime.can_change_phase():
		log_presenter.append(
			"Finish or cancel the current Action before changing phase."
		)
		return

	var state: BattleState = battle_runtime.battle_state

	if not state.encounter_started:
		encounter_starting = true
		_set_commands_locked(true)
		call_deferred("_start_encounter_deferred")
		return

	if state.phase == BattleState.Phase.ENEMY:
		log_presenter.append(
			"Enemy Phase is controlled by the enemy rulebooks."
		)
		return

	var previous_round: int = state.round_number
	var previous_phase_label: String = state.get_phase_label()
	log_presenter.log_phase_ended(
		previous_round,
		previous_phase_label
	)

	var phase_error: String = (
		battle_flow_controller.end_current_phase()
	)

	if not phase_error.is_empty():
		log_presenter.append(
			"Phase could not advance: %s"
			% phase_error
		)
		return

	if state.round_number != previous_round:
		log_presenter.log_round_started(
			state,
			battler_states
		)

	log_presenter.log_phase_started(state)
	if _process_phase_start_and_outcome():
		return
	if _skip_momentum_locked_phase_if_needed():
		return
	_refresh_battle_flow_ui()
	_start_enemy_ai_if_needed()


func _start_encounter_deferred() -> void:
	var state: BattleState = battle_runtime.battle_state
	var start_error: String = (
		battle_flow_controller.start_encounter(
			BattleFlowController.OrderMode.SEEDED
		)
	)

	if not start_error.is_empty():
		encounter_starting = false
		_set_commands_locked(false)
		log_presenter.append(
			"Encounter could not start: %s"
			% start_error
		)
		return

	log_presenter.log_order_resolved(
		state,
		battler_states
	)
	log_presenter.log_round_started(
		state,
		battler_states
	)
	_log_round_start_kit_effects()
	log_presenter.log_phase_started(state)
	if _process_phase_start_and_outcome():
		encounter_starting = false
		return

	encounter_starting = false
	_set_commands_locked(
		state.phase == BattleState.Phase.ENEMY
	)
	_refresh_battle_flow_ui()
	_queue_combat_progression()


func _skip_momentum_locked_phase_if_needed() -> bool:
	var state: BattleState = battle_runtime.battle_state
	var active_side: BattleState.CombatSide = state.get_active_side()
	if not state.is_side_momentum_locked(active_side):
		return false

	var skipped_round: int = state.round_number
	var skipped_phase: String = state.get_phase_label()
	log_presenter.append(
		"%s is skipped automatically: Momentum left that side with zero Actions."
		% skipped_phase
	)
	log_presenter.log_phase_ended(skipped_round, skipped_phase)

	var phase_error: String = battle_flow_controller.end_current_phase()
	if not phase_error.is_empty():
		log_presenter.append(
			"Momentum phase could not finish: %s" % phase_error
		)
		_set_commands_locked(false)
		_refresh_battle_flow_ui()
		return true

	if state.round_number != skipped_round:
		log_presenter.log_round_started(state, battler_states)
		_log_round_start_kit_effects()
	log_presenter.log_phase_started(state)
	if _process_phase_start_and_outcome():
		return true

	_set_commands_locked(state.phase == BattleState.Phase.ENEMY)
	_refresh_battle_flow_ui()
	_queue_combat_progression()
	return true


func _queue_combat_progression() -> void:
	if combat_progression_queued:
		return
	combat_progression_queued = true
	call_deferred("_advance_combat_progression")


func _advance_combat_progression() -> void:
	combat_progression_queued = false
	if combat_progression_running:
		return
	if (
		battle_runtime == null
		or battle_runtime.battle_state == null
		or not battle_runtime.battle_state.encounter_started
		or encounter_starting
	):
		return

	var state: BattleState = battle_runtime.battle_state
	if _resolve_unavailable_pending_input():
		return
	if (
		state.phase == BattleState.Phase.COMPLETE
		or battle_runtime.has_pending_reaction()
		or battle_runtime.has_active_move()
		or pending_player_move_reaction
		or pending_grapple_move_reaction
		or pending_dodge_result != null
		or pending_grapple_dodge_attempt != null
		or grapple_controller.has_pending_initiation()
	):
		return

	combat_progression_running = true

	# Momentum still owns a real phase for phase-start effects and logging,
	# but that phase can never wait for input or an AI decision.
	if state.is_side_momentum_locked(state.get_active_side()):
		if enemy_ai_controller.is_enemy_phase_active():
			enemy_ai_controller.end_enemy_phase()
			enemy_ai_advancing = false
		_skip_momentum_locked_phase_if_needed()
		combat_progression_running = false
		return

	if state.phase == BattleState.Phase.ENEMY:
		if enemy_ai_controller.is_enemy_phase_active():
			call_deferred("_continue_enemy_ai")
		else:
			call_deferred("_start_enemy_ai_if_needed")

	combat_progression_running = false


func _resolve_unavailable_pending_input() -> bool:
	if battle_runtime.has_pending_reaction():
		var reaction_target: BattlerState = (
			action_controller.get_pending_reaction_target()
		)
		if (
			reaction_target == null
			or reaction_target.is_defeated
			or reaction_target.current_actions <= 0
		):
			combat_presenter.close_reaction_exchange()
			call_deferred("_resolve_automatic_skip")
			return true

	if pending_player_move_reaction:
		var move_reactor: BattlerState = get_battler_state(
			pending_player_move_reactor_id
		)
		if (
			move_reactor == null
			or move_reactor.is_defeated
			or move_reactor.is_stunned()
			or move_reactor.current_actions <= 0
		):
			var reactor_id: StringName = pending_player_move_reactor_id
			combat_presenter.close_reaction_exchange()
			call_deferred(
				"_on_player_move_reaction_waited",
				reactor_id
			)
			return true

	if grapple_controller.has_pending_initiation():
		var grapple_attempt: GrappleAttemptResult = (
			grapple_controller.pending_attempt
		)
		var grapple_target: BattlerState = (
			get_battler_state(grapple_attempt.target_id)
			if grapple_attempt != null
			else null
		)
		if (
			grapple_target == null
			or grapple_target.is_defeated
			or grapple_target.current_actions <= 0
		):
			combat_presenter.close_reaction_exchange()
			call_deferred("_on_grapple_response_chosen", false)
			return true

	return false


func _process_phase_start_and_outcome() -> bool:
	var report: StatusPhaseReport = (
		lifecycle_controller.process_current_phase_start()
	)
	log_presenter.log_status_phase(report)
	_trigger_blood_rite_if_needed()
	return _present_existing_outcome_if_any()


func _log_round_start_kit_effects() -> void:
	for line: String in battle_flow_controller.last_round_start_effects:
		log_presenter.append(line)


func _evaluate_and_present_outcome() -> bool:
	_clear_terminal_kit_effects()
	_trigger_blood_rite_if_needed()
	lifecycle_controller.evaluate_outcome()
	return _present_existing_outcome_if_any()


func _trigger_blood_rite_if_needed() -> void:
	var blood_nun: BattlerState = get_battler_state(&"blood_nun")
	if (
		blood_nun == null
		or blood_nun.is_defeated
		or blood_nun.boss_phase_triggered
		or blood_nun.current_hp * 2 > blood_nun.get_max_hp()
	):
		return
	blood_nun.boss_phase_triggered = true
	blood_nun.passive_attack_dice_bonus = 1
	blood_nun.regeneration_rounds = 3
	var cleansed: int = status_controller.remove_first_status(
		blood_nun
	)
	blood_nun.state_changed.emit()
	log_presenter.append(
		"Blood Rite begins: +1d10 to Blood Nun Attacks, "
		+ "1 HP regeneration for three rounds"
		+ (", and one negative status cleansed." if cleansed > 0 else ".")
	)


func _clear_terminal_kit_effects() -> void:
	for state_value: Variant in battler_states.values():
		var state: BattlerState = state_value as BattlerState
		if state == null or state.analyzed_target_id == &"":
			continue
		var analyzed_target: BattlerState = get_battler_state(
			state.analyzed_target_id
		)
		if analyzed_target == null or analyzed_target.is_defeated:
			state.set_analyzed_target(&"")


func _present_existing_outcome_if_any() -> bool:
	var state: BattleState = battle_runtime.battle_state
	if state.outcome == BattleState.Outcome.NONE:
		return false

	if enemy_ai_controller.is_enemy_phase_active():
		enemy_ai_controller.end_enemy_phase()
	enemy_ai_advancing = false
	pending_player_move_reaction = false
	pending_grapple_move_reaction = false
	pending_dodge_attacker = null
	pending_dodge_target = null
	pending_dodge_result = null
	pending_grapple_dodge_attempt = null
	pending_struggle_heroine_id = &""

	battle_runtime.clear_active_move()
	battle_runtime.clear_active_aoe()
	battle_runtime.cancel_item_targeting()
	battle_runtime.clear_pending_item_attack()
	battle_runtime.clear_resolution_chain()
	battle_runtime.cancel_move_targeting()
	battle_runtime.cancel_attack_targeting()
	battle_runtime.cancel_aoe_targeting()
	battle_runtime.cancel_ability_targeting()

	combat_presenter.close_reaction_exchange()
	ability_panel.close_panel()
	battlefield_input_overlay.clear_selection()
	_set_move_command_hint("Move")
	_set_ability_command_hint("Ability")
	_set_attack_targeting_markers(false)

	log_presenter.log_battle_outcome(state)
	_set_commands_locked(true)
	_refresh_battle_flow_ui()
	_emit_encounter_outcome_if_ready()
	return true


func _apply_pending_run_snapshot() -> void:
	if not pending_party_snapshot.is_empty():
		for battler_id_value: Variant in pending_party_snapshot.keys():
			var battler_id: StringName = StringName(battler_id_value)
			var snapshot: Dictionary = pending_party_snapshot[
				battler_id_value
			] as Dictionary
			var state: BattlerState = get_battler_state(battler_id)
			if state == null or state.definition == null:
				continue
			state.current_hp = clampi(
				int(snapshot.get("hp", state.current_hp)),
				0,
				state.get_max_hp()
			)
			state.current_mp = clampi(
				int(snapshot.get("mp", state.current_mp)),
				0,
				state.get_max_mp()
			)
			state.current_resolve = clampi(
				int(snapshot.get("resolve", state.current_resolve)),
				0,
				100
			)
			state.current_corruption = clampi(
				int(snapshot.get("corruption", state.current_corruption)),
				0,
				100
			)
			state.item_guard_points = maxi(
				int(snapshot.get("item_guard", 0)),
				0
			)
			state.is_defeated = state.current_hp <= 0
			state.current_actions = (
				0 if state.is_defeated else state.get_max_actions()
			)
			if state.weapon_state != null:
				state.weapon_state.durability_damage = maxi(
					int(snapshot.get("weapon_damage", 0)),
					0
				)
				state.weapon_state.is_broken = bool(
					snapshot.get("weapon_broken", false)
				)
			if state.armor_state != null:
				state.armor_state.absorbed_damage = maxi(
					int(snapshot.get("armor_damage", 0)),
					0
				)
				state.armor_state.is_broken = bool(
					snapshot.get("armor_broken", false)
				)
			if state.shield_state != null:
				state.shield_state.absorbed_damage = maxi(
					int(snapshot.get("shield_damage", 0)),
					0
				)
				state.shield_state.is_broken = bool(
					snapshot.get("shield_broken", false)
				)
			state.state_changed.emit()

	if pending_inventory_snapshot.is_empty():
		return
	var item_ids: Array[StringName] = []
	var quantities: Array[int] = []
	for slot_index: int in range(SixSlotInventoryState.SLOT_COUNT):
		var slot_data: Dictionary = {}
		if slot_index < pending_inventory_snapshot.size():
			slot_data = pending_inventory_snapshot[slot_index]
		item_ids.append(
			StringName(slot_data.get("item_id", ""))
		)
		quantities.append(int(slot_data.get("quantity", 0)))
	var inventory_error: String = item_inventory.load_items(
		item_ids,
		quantities
	)
	if not inventory_error.is_empty():
		push_error(
			"Run inventory snapshot could not be applied: %s"
			% inventory_error
		)


func _emit_encounter_outcome_if_ready() -> void:
	if encounter_outcome_emitted:
		return
	if pending_encounter_definition == null:
		return
	var state: BattleState = battle_runtime.battle_state
	if state.outcome == BattleState.Outcome.NONE:
		return

	var outcome: EncounterOutcome = EncounterOutcome.new()
	outcome.encounter_id = pending_encounter_definition.encounter_id
	outcome.source_node_id = (
		pending_encounter_definition.source_node_id
	)
	outcome.result = (
		EncounterOutcome.Result.VICTORY
		if state.outcome == BattleState.Outcome.VICTORY
		else EncounterOutcome.Result.DEFEAT
	)
	outcome.party_snapshot = _capture_party_run_snapshot()
	outcome.inventory_snapshot = item_inventory.get_snapshot()
	outcome.heroine_progression_snapshot = (
		_capture_heroine_progression_snapshot()
	)
	if outcome.result == EncounterOutcome.Result.VICTORY:
		outcome.bloom_reward = (
			12 if pending_encounter_definition.is_boss else 4
		)
	encounter_outcome_emitted = true
	encounter_outcome_ready.emit(outcome)


func _capture_heroine_progression_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for battler_id: StringName in [
		&"lysandra",
		&"mira",
		&"seraphine",
	]:
		var state: BattlerState = get_battler_state(battler_id)
		if state != null:
			snapshot[battler_id] = state.get_progression_snapshot()
	return snapshot


func _capture_party_run_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for battler_id: StringName in [
		&"lysandra",
		&"mira",
		&"seraphine",
	]:
		var state: BattlerState = get_battler_state(battler_id)
		if state == null:
			continue
		snapshot[battler_id] = {
			"hp": state.current_hp,
			"mp": state.current_mp,
			"resolve": state.current_resolve,
			"corruption": state.current_corruption,
			"item_guard": state.item_guard_points,
			"weapon_damage": (
				state.weapon_state.durability_damage
				if state.weapon_state != null else 0
			),
			"weapon_broken": (
				state.weapon_state.is_broken
				if state.weapon_state != null else false
			),
			"armor_damage": (
				state.armor_state.absorbed_damage
				if state.armor_state != null else 0
			),
			"armor_broken": (
				state.armor_state.is_broken
				if state.armor_state != null else false
			),
			"shield_damage": (
				state.shield_state.absorbed_damage
				if state.shield_state != null else 0
			),
			"shield_broken": (
				state.shield_state.is_broken
				if state.shield_state != null else false
			),
		}
	return snapshot


func _refresh_battle_flow_ui() -> void:
	if combat_presenter != null:
		combat_presenter.refresh_all()
	_refresh_grapple_command_bar()
	_refresh_item_bar()
