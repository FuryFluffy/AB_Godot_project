class_name RunState
extends RefCounted


const RUINED_CHAPEL_TEMPLATE: EncounterTemplateDefinition = preload(
	"res://data/encounters/ruined_chapel_template.tres"
)
const LOWER_KITCHEN_TEMPLATE: EncounterTemplateDefinition = preload(
	"res://data/encounters/lower_kitchen_template.tres"
)
const OPENING_SERVANT_CORRIDOR_TEMPLATE: EncounterTemplateDefinition = preload(
	"res://data/encounters/opening_servant_corridor.tres"
)
const PROCESSING_CHAPEL_TEMPLATE: EncounterTemplateDefinition = preload(
	"res://data/encounters/processing_chapel_template.tres"
)
const JAILER_CONTAINMENT_TEMPLATE: EncounterTemplateDefinition = preload(
	"res://data/encounters/jailer_containment_landing_template.tres"
)
const LAYER_2_CHAIN_MAINTENANCE_TEMPLATE: EncounterTemplateDefinition = preload(
	"res://data/encounters/layer2_chain_maintenance_template.tres"
)
const DINING_SERVICE_HALL_TEMPLATE: EncounterTemplateDefinition = preload(
	"res://data/encounters/dining_service_hall_template.tres"
)
const ITEM_CATALOG: ItemCatalogDefinition = preload(
	"res://data/items/layer_1_2_item_catalog.tres"
)
const REWARD_SOURCE_CATALOG: RewardSourceCatalogDefinition = preload(
	"res://data/rewards/reward_source_catalog.tres"
)
const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const DIALOGUE_CATALOG: DialogueCatalogDefinition = preload(
	"res://data/dialogue/production_dialogue_catalog.tres"
)
const DEMO_HEROINE_IDS: Array[StringName] = [
	&"lysandra",
	&"mira",
	&"seraphine",
]

const OPENING_ENCOUNTER_ID: StringName = (
	&"layer_1_lysandra_opening_hollow_servant"
)
const OPENING_SOURCE_NODE_ID: StringName = (
	&"layer_1_opening_servant_corridor"
)
const MIRA_RECRUITMENT_ENCOUNTER_ID: StringName = (
	&"layer_1_corrupted_butler_opening"
)
const MIRA_RECRUITMENT_STORY_ID: StringName = (
	&"layer_1_mira_recruitment_aftermath"
)
const SERAPHINE_RECRUITMENT_ENCOUNTER_ID: StringName = (
	&"layer_1_seraphine_ruined_chapel"
)
const SERAPHINE_RECRUITMENT_PRELUDE_STORY_ID: StringName = (
	&"layer_1_seraphine_recruitment_prelude"
)
const SERAPHINE_RECRUITMENT_AFTERMATH_STORY_ID: StringName = (
	&"layer_1_seraphine_recruitment_aftermath"
)
const SERAPHINE_PRELUDE_FLAG_ID: StringName = (
	&"layer_1_seraphine_false_prayer_witnessed"
)
const BLOOD_NUN_ENCOUNTER_ID: StringName = &"layer_1_blood_nun"
const BLOOD_NUN_AFTERMATH_STORY_ID: StringName = (
	&"layer_1_blood_nun_aftermath"
)
const BLOOD_NUN_GO_UP_CHOICE_ID: StringName = (
	&"layer_1_blood_nun_go_up"
)
const BLOOD_NUN_GO_DOWN_CHOICE_ID: StringName = (
	&"layer_1_blood_nun_go_down"
)
const LAYER_1_COMPLETED_FLAG_ID: StringName = &"layer_1_completed"
const JAILER_FIRST_ENCOUNTER_ID: StringName = (
	&"layer_2_jailer_first_containment"
)
const JAILER_FIRST_NODE_ID: StringName = &"l2_jailer_first_encounter"
const LAYER_2_FARTHEST_CELL_NODE_ID: StringName = &"l2_refuge_farthest_cell"
const REFUGE_ORIGIN_STORY_ID: StringName = &"layer_2_refuge_origin"
const UPPER_ROUTE_REFUGE_ORIGIN_DIALOGUE_ID: StringName = (
	&"layer_2_refuge_origin_from_upper_route"
)
const JAILER_VICTORY_STORY_ID: StringName = (
	&"layer_2_jailer_victory_aftermath"
)
const FARTHEST_CELL_REFUGE_STORY_ID: StringName = (
	&"layer_2_farthest_cell_refuge_establishment"
)
const REFUGE_EVER_ESTABLISHED_FLAG_ID: StringName = (
	&"refuge_ever_established"
)
const BLOOD_NUN_BOSS_ID: StringName = BLOOD_NUN_ENCOUNTER_ID
const JAILER_BOSS_ID: StringName = JAILER_FIRST_ENCOUNTER_ID
const LAYER_2_FIRST_SLICE_ENCOUNTER_ID: StringName = (
	&"layer_2_farthest_cell_kept_watch"
)
const DINING_SERVICE_HALL_ENCOUNTER_ID: StringName = (
	&"layer_1_dining_service_hall"
)


signal run_changed


var run_seed: int = 0
var graph: LayerMapGraph
var current_node_id: StringName = &""
var selected_node_id: StringName = &""
var pending_node_id: StringName = &""
var pending_origin_node_id: StringName = &""
var pending_node_seed: int = 0
var party_snapshot: Dictionary = {}
var run_equipment: RunEquipmentState = RunEquipmentState.new()
var _run_inventory: RunInventoryState = RunInventoryState.new()
var run_inventory: RunInventoryState:
	get:
		return _run_inventory
	set(value):
		_run_inventory = value
		if run_equipment != null and _run_inventory != null:
			run_equipment.bind_run_inventory(_run_inventory)
var inventory_snapshot: Array[Dictionary]:
	get:
		return run_inventory.get_item_bar_snapshot()
	set(value):
		var restore_error: String = run_inventory.restore_item_bar_snapshot(
			value
		)
		if not restore_error.is_empty():
			push_error(restore_error)
var heroine_progression_snapshot: Dictionary = {}
var bloom: int = 0
var completed_encounters: Dictionary = {}
var event_room_snapshots: Dictionary = {}
var generated_room_item_requests: Dictionary = {}
var reward_resolutions: Dictionary = {}
var opening_completed: bool = false
var narrative_state: NarrativeState = NarrativeState.new()
var completed_layer_ids: Array[StringName] = []
var archived_layer_graphs: Dictionary = {}
var campaign_lifecycle: CampaignLifecycleState = CampaignLifecycleState.new()
var refuge_ownership: RefugeOwnershipState = RefugeOwnershipState.new()
var active_run_refuge_boundary_snapshot: Dictionary = {}


func _init() -> void:
	var inventory_error: String = run_inventory.initialize(
		ITEM_CATALOG,
		DEMO_HEROINE_IDS
	)
	if not inventory_error.is_empty():
		push_error(inventory_error)
	var equipment_error: String = run_equipment.initialize(
		BATTLER_CATALOG,
		DEMO_HEROINE_IDS,
		run_inventory
	)
	if not equipment_error.is_empty():
		push_error(equipment_error)


func initialize(
	new_seed: int, 
	new_graph: LayerMapGraph,
	generated_item_rules: Array[GeneratedRoomItemPlacementRule] = [],
	new_run_party_snapshot: Dictionary = {},
	new_narrative_state_snapshot: Dictionary = {},
	campaign_lifecycle_snapshot: Dictionary = {}
	) -> String:
	if new_graph == null:
		return "RunState requires a generated map."
	var graph_error: String = new_graph.validate_graph()
	if not graph_error.is_empty():
		return graph_error
	run_seed = new_seed
	if campaign_lifecycle == null:
		campaign_lifecycle = CampaignLifecycleState.new()
	if campaign_lifecycle_snapshot.is_empty():
		campaign_lifecycle.initialize_new(new_seed)
	else:
		var lifecycle_error: String = (
			campaign_lifecycle.restore_from_snapshot(
				campaign_lifecycle_snapshot
			)
		)
		if not lifecycle_error.is_empty():
			return lifecycle_error
		if (
			campaign_lifecycle.is_tutorial()
			and new_seed != campaign_lifecycle.tutorial_layer_1_seed
		):
			return "Tutorial recovery must reuse the original Layer 1 seed."
	graph = new_graph
	current_node_id = graph.start_node_id
	selected_node_id = current_node_id
	pending_node_id = &""
	pending_origin_node_id = &""
	pending_node_seed = 0
	party_snapshot = new_run_party_snapshot.duplicate(true)
	heroine_progression_snapshot = make_default_heroine_progression_snapshot()
	var inventory_error: String = run_inventory.initialize(
		ITEM_CATALOG,
		DEMO_HEROINE_IDS,
		true
	)
	if not inventory_error.is_empty():
		return inventory_error
	var equipment_error: String = run_equipment.initialize(
		BATTLER_CATALOG,
		DEMO_HEROINE_IDS,
		run_inventory,
		party_snapshot
	)
	if not equipment_error.is_empty():
		return equipment_error
	bloom = 0
	opening_completed = false
	completed_layer_ids.clear()
	archived_layer_graphs.clear()
	# Restore into an owned instance instead of replacing the RefCounted from a
	# factory expression. A regenerated Web run must never continue with a null
	# NarrativeState even when snapshot restoration fails.
	if narrative_state == null:
		narrative_state = NarrativeState.new()
	var narrative_error: String = narrative_state.restore_from_snapshot(
		new_narrative_state_snapshot,
		DIALOGUE_CATALOG
	)
	if not narrative_error.is_empty():
		return narrative_error
	completed_encounters.clear()
	event_room_snapshots.clear()
	generated_room_item_requests.clear()
	reward_resolutions.clear()
	refuge_ownership = RefugeOwnershipState.new()
	active_run_refuge_boundary_snapshot.clear()

	var placement_result := (
		GeneratedRoomItemPlacementResolver.resolve(
			graph,
			generated_item_rules,
			run_seed
		)
	)

	if not placement_result.succeeded():
		return (
			"Generated room-item placement failed:\n"
			+ placement_result.get_error_text()
		)

	generated_room_item_requests = (
		placement_result
			.requests_by_node
			.duplicate(true)
	)

	for warning_message: String in (
		placement_result.warnings
	):
		push_warning(
			warning_message
		)
		
	run_changed.emit()
	return ""


func make_full_wipe_recovery_party_snapshot(
	outcome: EncounterOutcome,
	battler_catalog: BattlerCatalogDefinition
) -> Dictionary:
	var recovered: Dictionary = {}
	if (
		outcome == null
		or battler_catalog == null
		or narrative_state == null
	):
		return recovered

	# A scene-present ally is still part of combat, but only heroines already
	# recruited before the failed run belong in the next run's party snapshot.
	# This prevents Mira's recruitment battle from recruiting her through a
	# defeat handoff.
	for heroine_id: StringName in narrative_state.recruited_heroine_ids:
		var stored_value: Variant = outcome.party_snapshot.get(
			heroine_id,
			outcome.party_snapshot.get(String(heroine_id), null)
		)
		if not (stored_value is Dictionary):
			continue
		var battler: BattlerDefinition = battler_catalog.get_battler(
			heroine_id
		)
		if (
			battler == null
			or battler.faction != BattlerDefinition.Faction.HEROINE
		):
			continue
		var snapshot := (stored_value as Dictionary).duplicate(true)
		# The combat lifecycle has already applied the locked -15 Resolve
		# consequence. Refuge recovery restores HP/MP, while Resolve,
		# Corruption, and equipment condition remain exactly as returned.
		snapshot["hp"] = battler.max_hp
		snapshot["mp"] = battler.max_mp
		snapshot["item_guard"] = 0
		recovered[heroine_id] = snapshot

	return recovered


func make_full_wipe_recovery_narrative_snapshot() -> Dictionary:
	if narrative_state == null:
		return {}
	var snapshot: Dictionary = narrative_state.to_snapshot()
	var scoped_flags: Dictionary = (
		snapshot.get("flags_by_scope", {}) as Dictionary
	).duplicate(true)
	# A wipe begins a fresh run. Recruitment and longer-lived narrative state
	# survive, while run-local flags and in-progress dialogue sessions do not.
	scoped_flags[&"run"] = {}
	snapshot["flags_by_scope"] = scoped_flags
	snapshot["dialogue_sessions"] = {}
	snapshot["pending_story_requests"] = []
	return snapshot


func get_narrative_state_snapshot() -> Dictionary:
	if narrative_state == null:
		return {}
	return narrative_state.to_snapshot()


func make_campaign_lifecycle_snapshot() -> Dictionary:
	if campaign_lifecycle == null:
		return {}
	return campaign_lifecycle.to_snapshot()


func get_campaign_mode_id() -> String:
	if campaign_lifecycle == null:
		return ""
	return campaign_lifecycle.get_mode_id()


func is_tutorial_pre_refuge() -> bool:
	return (
		campaign_lifecycle != null
		and campaign_lifecycle.is_tutorial()
	)


func is_refugeless_ascent() -> bool:
	return (
		campaign_lifecycle != null
		and campaign_lifecycle.is_refugeless()
	)


func no_refuge_ending_is_eligible() -> bool:
	return (
		campaign_lifecycle != null
		and campaign_lifecycle.no_refuge_ending_is_eligible()
	)


func get_refugeless_world_seed() -> int:
	if campaign_lifecycle == null:
		return maxi(run_seed, 1)
	return maxi(campaign_lifecycle.refugeless_world_seed, 1)


func get_refugeless_layer_seed(layer_number: int) -> int:
	if campaign_lifecycle == null or layer_number < 1:
		return 0
	return maxi(int(campaign_lifecycle.refugeless_layer_seeds.get(
		str(layer_number),
		0
	)), 0)


func has_defeated_boss(boss_id: StringName) -> bool:
	return (
		campaign_lifecycle != null
		and campaign_lifecycle.is_boss_defeated(boss_id)
	)


func get_defeated_boss_ids() -> Array[StringName]:
	if campaign_lifecycle == null:
		return []
	return campaign_lifecycle.defeated_boss_ids.duplicate()


func requires_opening_encounter() -> bool:
	return not opening_completed


func can_enter_generated_map() -> bool:
	return opening_completed


func make_opening_encounter_definition() -> EncounterDefinition:
	if opening_completed:
		return null
	var definition := EncounterDefinition.new()
	definition.encounter_id = OPENING_ENCOUNTER_ID
	definition.source_node_id = OPENING_SOURCE_NODE_ID
	definition.authored_room_id = &"opening_servant_corridor"
	definition.display_name = "Opening Servant Corridor"
	definition.node_type = MapNodeState.NodeType.BATTLE
	definition.encounter_seed = _allocate_combat_seed(
		OPENING_ENCOUNTER_ID,
		OPENING_SOURCE_NODE_ID
	)
	definition.difficulty_label = "Opening"
	definition.party_ids = _make_current_party_ids()
	if definition.party_ids.is_empty():
		# The first-ever Layer 1 opening has no recovery snapshot and remains
		# canonically Lysandra alone. Later Refuge-style restarts retain the
		# heroines already recruited before the wipe.
		definition.party_ids = [&"lysandra"]
	definition.enemy_ids = [&"hollow_servant"]
	definition.template = OPENING_SERVANT_CORRIDOR_TEMPLATE
	var assignment_error: String = definition.ensure_spawn_assignments()
	if not assignment_error.is_empty():
		push_error(assignment_error)
		return null
	return definition


func is_opening_encounter_outcome(
	outcome: EncounterOutcome
) -> bool:
	return (
		outcome != null
		and outcome.encounter_id == OPENING_ENCOUNTER_ID
		and outcome.source_node_id == OPENING_SOURCE_NODE_ID
	)


func apply_opening_encounter_outcome(
	outcome: EncounterOutcome
) -> String:
	if opening_completed:
		return "The Layer 1 opening encounter is already complete."
	if not is_opening_encounter_outcome(outcome):
		return "Encounter outcome does not match the Layer 1 opening."
	if outcome.result != EncounterOutcome.Result.VICTORY:
		return "Lysandra must win the opening encounter before entering the map."
	if not outcome.party_snapshot.has(&"lysandra"):
		return "The opening encounter returned no Lysandra state."
	if (
		outcome.inventory_snapshot.size()
		!= SixSlotInventoryState.SLOT_COUNT
	):
		return "The opening encounter returned an invalid inventory snapshot."

	party_snapshot = outcome.party_snapshot.duplicate(true)
	inventory_snapshot = outcome.inventory_snapshot.duplicate(true)
	for heroine_value: Variant in (
		outcome.heroine_progression_snapshot.keys()
	):
		var heroine_id := StringName(heroine_value)
		heroine_progression_snapshot[heroine_id] = (
			outcome.heroine_progression_snapshot[heroine_value]
			as Dictionary
		).duplicate(true)

	bloom += maxi(outcome.bloom_reward, 0)
	completed_encounters[OPENING_ENCOUNTER_ID] = true
	opening_completed = true
	run_changed.emit()
	return ""

func _inject_generated_room_item_requests(
	state: EventRoomInstanceState,
	node_id: StringName
) -> void:
	if state == null:
		return

	var requests: Array = (
		generated_room_item_requests.get(
			node_id,
			[]
		) as Array
	)

	if requests.is_empty():
		return

	# Once copied into the room state, the room owns its
	# concrete generation and collection history.
	if state.local_state.has(
		"generated_item_requests"
	):
		return

	state.local_state[
		"generated_item_requests"
	] = requests.duplicate(true)

func get_event_room_state(
	node_id: StringName,
	room_id: StringName
) -> EventRoomInstanceState:
	if event_room_snapshots.has(node_id):
		var stored: Dictionary = event_room_snapshots.get(
			node_id,
			{}
		) as Dictionary
		
		var restored := (
			EventRoomInstanceState.from_snapshot(stored)
		)
		
		if restored.room_id != room_id:
			push_warning(
				(
					"Map node '%s' changed Event-room definition"
					+ "from '%s' to '%s'. Resestting its local state"
				)
				% [
					node_id,
					restored.room_id,
					room_id,
				]
			)
		else:
			if restored.generation_seed <= 0:
				restored.generation_seed = (
					_make_event_room_generation_seed(
						node_id,
						room_id
					)
				)
				
			_inject_generated_room_item_requests(
				restored,
				node_id
			)
			
			return restored
			
	var state := EventRoomInstanceState.new()
	state.source_node_id = node_id
	state.room_id = room_id
	state.generation_seed = _make_event_room_generation_seed(
		node_id,
		room_id
	)
	
	_inject_generated_room_item_requests(
		state,
		node_id
		)
	
	return state

func _make_event_room_generation_seed(
	node_id: StringName,
	room_id: StringName
) -> int:
	var combined_seed: int = run_seed * 1009
	combined_seed += String(node_id).hash() * 31
	combined_seed += String(room_id).hash()
	
	return maxi(absi(combined_seed), 1)

static func make_default_heroine_progression_snapshot(
	include_developer_techniques: bool = false
) -> Dictionary:
	var snapshot: Dictionary = {
		&"lysandra": {
			"weapon_family_ranks": {"sword": 1, "dagger": 1},
			"unlocked_ability_ids": [],
		},
		&"mira": {
			"weapon_family_ranks": {"dagger": 1},
			"unlocked_ability_ids": [],
		},
		&"seraphine": {
			"weapon_family_ranks": {"staff": 1},
			"unlocked_ability_ids": [],
		},
	}
	if include_developer_techniques:
		(snapshot[&"lysandra"] as Dictionary)[
			"unlocked_ability_ids"
		] = ["forced_blade"]
		(snapshot[&"mira"] as Dictionary)[
			"unlocked_ability_ids"
		] = ["knife_dance"]
		(snapshot[&"seraphine"] as Dictionary)[
			"unlocked_ability_ids"
		] = ["jaw_break"]
	return snapshot


func grant_developer_weapon_techniques() -> void:
	var grants: Dictionary = {
		&"lysandra": &"forced_blade",
		&"mira": &"knife_dance",
		&"seraphine": &"jaw_break",
	}
	for heroine_value: Variant in grants.keys():
		var heroine_id: StringName = StringName(heroine_value)
		var stored: Dictionary = heroine_progression_snapshot.get(
			heroine_id,
			{}
		) as Dictionary
		if stored.is_empty():
			continue
		var progression: HeroineProgressionState = (
			HeroineProgressionState.new(heroine_id, stored)
		)
		progression.unlock_ability(
			StringName(grants[heroine_value])
		)
		heroine_progression_snapshot[heroine_id] = (
			progression.to_snapshot()
		)
	run_changed.emit()


func unlock_heroine_ability(
	heroine_id: StringName,
	ability_id: StringName
) -> String:
	var stored: Dictionary = heroine_progression_snapshot.get(
		heroine_id,
		{}
	) as Dictionary
	if stored.is_empty():
		return "Unknown heroine progression id: %s." % heroine_id
	var progression: HeroineProgressionState = (
		HeroineProgressionState.new(heroine_id, stored)
	)
	progression.unlock_ability(ability_id)
	heroine_progression_snapshot[heroine_id] = progression.to_snapshot()
	run_changed.emit()
	return ""


func set_heroine_weapon_family_rank(
	heroine_id: StringName,
	family_id: StringName,
	rank: int
) -> String:
	var stored: Dictionary = heroine_progression_snapshot.get(
		heroine_id,
		{}
	) as Dictionary
	if stored.is_empty():
		return "Unknown heroine progression id: %s." % heroine_id
	var progression: HeroineProgressionState = (
		HeroineProgressionState.new(heroine_id, stored)
	)
	progression.set_weapon_family_rank(family_id, rank)
	heroine_progression_snapshot[heroine_id] = progression.to_snapshot()
	run_changed.emit()
	return ""


func select_node(node_id: StringName) -> String:
	if graph == null or graph.get_map_node(node_id) == null:
		return "Selected map node does not exist."
	selected_node_id = node_id
	run_changed.emit()
	return ""


func can_travel_to(node_id: StringName) -> bool:
	if (
		graph == null
		or not opening_completed
		or pending_node_id != &""
	):
		return false
	if node_id == current_node_id:
		return false
	var current: MapNodeState = graph.get_map_node(current_node_id)
	var target: MapNodeState = graph.get_map_node(node_id)
	if current == null or target == null:
		return false
	if not target.travel_enabled:
		return false
	if (
		current.cleared
		and _get_connected_node_ids(current_node_id).has(node_id)
	):
		return true
	return target.visited and not get_backtrack_route(node_id).is_empty()


func get_backtrack_route(node_id: StringName) -> Array[StringName]:
	var empty_route: Array[StringName] = []
	if graph == null or node_id == current_node_id:
		return empty_route
	var target: MapNodeState = graph.get_map_node(node_id)
	if target == null or not target.visited:
		return empty_route

	var frontier: Array[StringName] = [current_node_id]
	var previous: Dictionary = {}
	previous[current_node_id] = &""
	while not frontier.is_empty():
		var route_node_id: StringName = frontier.pop_front()
		for neighbor_id: StringName in _get_connected_node_ids(
			route_node_id
		):
			if previous.has(neighbor_id):
				continue
			var neighbor: MapNodeState = graph.get_map_node(neighbor_id)
			if neighbor == null or not neighbor.visited:
				continue
			if neighbor_id != node_id and not neighbor.cleared:
				continue
			previous[neighbor_id] = route_node_id
			if neighbor_id == node_id:
				return _reconstruct_route(previous, node_id)
			frontier.append(neighbor_id)
	return empty_route


func _get_connected_node_ids(node_id: StringName) -> Array[StringName]:
	var connected_ids: Array[StringName] = []
	var node: MapNodeState = graph.get_map_node(node_id)
	if node == null:
		return connected_ids
	for outgoing_id: StringName in node.outgoing_ids:
		connected_ids.append(outgoing_id)
	for incoming_id: StringName in node.incoming_ids:
		if not connected_ids.has(incoming_id):
			connected_ids.append(incoming_id)
	return connected_ids


func _reconstruct_route(
	previous: Dictionary,
	target_id: StringName
) -> Array[StringName]:
	var route: Array[StringName] = []
	var route_node_id: StringName = target_id
	while route_node_id != &"" and route_node_id != current_node_id:
		route.push_front(route_node_id)
		route_node_id = StringName(previous.get(route_node_id, &""))
	return route


func travel_to(
	node_id: StringName
) -> String:
	if not can_travel_to(node_id):
		return (
			"That node is neither directly connected nor reachable "
			+ "through cleared passages."
		)

	var origin_node_id: StringName = current_node_id

	current_node_id = node_id
	selected_node_id = node_id

	var node: MapNodeState = graph.get_map_node(
		node_id
	)

	node.visited = true

	if not node.cleared:
		pending_node_id = node_id
		pending_origin_node_id = origin_node_id
		pending_node_seed = 0
	else:
		pending_node_id = &""
		pending_origin_node_id = &""
		pending_node_seed = 0
		if not node.reward_claimed and node.reward_source_id != &"":
			var deferred_result: Dictionary = retry_deferred_reward(node.node_id)
			var deferred_error: String = String(
				deferred_result.get("error", "")
			)
			if not deferred_error.is_empty():
				push_warning(deferred_error)

	run_changed.emit()
	return ""


func prepare_pending_node_seed() -> String:
	var node: MapNodeState = graph.get_map_node(pending_node_id) if graph != null else null
	if node == null:
		return "There is no pending node to seed."
	if pending_node_seed > 0:
		return ""
	if node.has_encounter_content():
		pending_node_seed = _allocate_combat_seed(node.encounter_id, node.node_id)
	elif node.content_seed > 0:
		pending_node_seed = node.content_seed
	elif node.requires_event_room():
		pending_node_seed = _make_event_room_generation_seed(
			node.node_id,
			node.room_definition_id
		)
	else:
		pending_node_seed = maxi(graph.run_seed, 1)
	return "" if pending_node_seed > 0 else "The pending node seed is invalid."


func rollback_pending_node_entry(
	node_id: StringName,
	target_was_visited: bool,
	lifecycle_snapshot: Dictionary
) -> String:
	if pending_node_id != node_id or pending_origin_node_id == &"":
		return "The pending node entry cannot be rolled back."
	var node: MapNodeState = graph.get_map_node(node_id)
	var origin: MapNodeState = graph.get_map_node(pending_origin_node_id)
	if node == null or origin == null:
		return "The pending node entry no longer has a valid route."
	var restored_lifecycle := CampaignLifecycleState.new()
	var lifecycle_error: String = restored_lifecycle.restore_from_snapshot(
		lifecycle_snapshot.duplicate(true)
	)
	if not lifecycle_error.is_empty():
		return lifecycle_error
	node.visited = target_was_visited
	current_node_id = origin.node_id
	selected_node_id = node_id
	pending_node_id = &""
	pending_origin_node_id = &""
	pending_node_seed = 0
	campaign_lifecycle = restored_lifecycle
	run_changed.emit()
	return ""


func get_node_map_state(node_id: StringName) -> MapNodeState.MapState:
	var node: MapNodeState = graph.get_map_node(node_id)
	if node == null:
		return MapNodeState.MapState.LOCKED
	if not node.travel_enabled:
		return MapNodeState.MapState.LOCKED
	if node_id == selected_node_id:
		return MapNodeState.MapState.SELECTED
	if node.cleared:
		return MapNodeState.MapState.CLEARED
	if node.visited:
		return MapNodeState.MapState.VISITED
	if can_travel_to(node_id):
		return MapNodeState.MapState.AVAILABLE
	return MapNodeState.MapState.LOCKED


func make_encounter_definition() -> EncounterDefinition:
	var node: MapNodeState = graph.get_map_node(pending_node_id)
	if node == null or not node.has_encounter_content():
		return null
	var definition: EncounterDefinition = EncounterDefinition.new()
	definition.encounter_id = node.encounter_id
	definition.source_node_id = node.node_id
	definition.authored_room_id = node.authored_room_id
	definition.display_name = node.display_name
	definition.node_type = node.node_type
	definition.party_ids = _make_current_party_ids()
	if (
		node.encounter_id == MIRA_RECRUITMENT_ENCOUNTER_ID
		and not definition.party_ids.has(&"mira")
	):
		# Mira is a scene-present ally for her recruitment battle. She is
		# not added to the persistent run party until the aftermath dialogue.
		definition.party_ids.append(&"mira")
	if (
		node.encounter_id == SERAPHINE_RECRUITMENT_ENCOUNTER_ID
		and not definition.party_ids.has(&"seraphine")
	):
		# Seraphine is physically present and fights beneath her ward, but the
		# persistent party changes only after the aftermath completes.
		definition.party_ids.append(&"seraphine")
	if definition.party_ids.is_empty():
		push_error(
			"Map encounter '%s' has no current party members."
			% node.encounter_id
		)
		return null
	if pending_node_seed <= 0:
		var seed_error: String = prepare_pending_node_seed()
		if not seed_error.is_empty():
			push_error(seed_error)
			return null
	definition.encounter_seed = pending_node_seed
	var composition_seed: int = StableSeedMixer.make_seed(
		graph.run_seed,
		&"encounter_composition",
		node.node_id
	)
	definition.is_boss = node.node_type == MapNodeState.NodeType.BOSS
	definition.enemy_ids = _make_enemy_composition(
		node,
		composition_seed
	)
	match node.node_type:
		MapNodeState.NodeType.ELITE:
			definition.difficulty_label = "Elite"
		MapNodeState.NodeType.BOSS:
			definition.difficulty_label = "Major Boss"
		_:
			definition.difficulty_label = "Regular"
	if node.encounter_id == &"layer_1_corrupted_butler_opening":
		definition.difficulty_label = "Opening Special"
	elif node.encounter_id == SERAPHINE_RECRUITMENT_ENCOUNTER_ID:
		definition.difficulty_label = "Recruitment Special"
	elif node.encounter_id == JAILER_FIRST_ENCOUNTER_ID:
		definition.difficulty_label = "Hard Major Boss"
	# Preserve active-run compatibility with snapshots created before the
	# Corrupted Butler encounter received its dedicated Lower Kitchen field.
	# The stable encounter identity is authoritative for this one recruitment
	# battle even if an older node still carries ruined_chapel_regular.
	definition.template = (
		LOWER_KITCHEN_TEMPLATE
		if node.encounter_id == MIRA_RECRUITMENT_ENCOUNTER_ID
		else _get_encounter_template(node.encounter_template_id)
	)
	if definition.template == null:
		push_error(
			"Map node '%s' selected unknown encounter template '%s'."
			% [node.node_id, node.encounter_template_id]
		)
		return null
	var assignment_error: String = definition.ensure_spawn_assignments()
	if not assignment_error.is_empty():
		push_error(assignment_error)
		return null
	return definition


func _allocate_combat_seed(
	encounter_id: StringName,
	source_node_id: StringName
) -> int:
	if campaign_lifecycle == null:
		campaign_lifecycle = CampaignLifecycleState.new()
		campaign_lifecycle.initialize_new(maxi(run_seed, 1))
	return campaign_lifecycle.allocate_combat_seed(
		encounter_id,
		source_node_id
	)


func _make_current_party_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	# Keep the established heroine order, then append any future party
	# members deterministically. The party snapshot is the run-time source
	# of truth; EncounterDefinition's prototype defaults must not recruit
	# heroines implicitly.
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		if (
			party_snapshot.has(heroine_id)
			or party_snapshot.has(String(heroine_id))
		):
			result.append(heroine_id)

	var future_ids: Array[StringName] = []
	for party_id_value: Variant in party_snapshot.keys():
		var party_id := StringName(party_id_value)
		if party_id != &"" and not result.has(party_id):
			future_ids.append(party_id)
	future_ids.sort()
	result.append_array(future_ids)
	return result


func _get_encounter_template(
	template_id: StringName
) -> EncounterTemplateDefinition:
	match template_id:
		&"lower_kitchen_regular":
			return LOWER_KITCHEN_TEMPLATE
		&"ruined_chapel_regular":
			return RUINED_CHAPEL_TEMPLATE
		&"blood_nun_processing_chapel_boss":
			return PROCESSING_CHAPEL_TEMPLATE
		&"jailer_containment_landing_boss":
			return JAILER_CONTAINMENT_TEMPLATE
		&"layer_2_chain_maintenance_regular":
			return LAYER_2_CHAIN_MAINTENANCE_TEMPLATE
		&"dining_service_hall_regular":
			return DINING_SERVICE_HALL_TEMPLATE
	return null


func _make_enemy_composition(
	node: MapNodeState,
	encounter_seed: int
) -> Array[StringName]:
	if node.encounter_id == JAILER_FIRST_ENCOUNTER_ID:
		return [&"jailer"]
	if node.encounter_id == LAYER_2_FIRST_SLICE_ENCOUNTER_ID:
		return [&"iron_masked_guard", &"chain_thrall"]
	if node.encounter_id == DINING_SERVICE_HALL_ENCOUNTER_ID:
		return [&"hollow_servant", &"knife_footman"]
	if node.encounter_id == &"layer_1_corrupted_butler_opening":
		return [&"corrupted_butler"]
	if node.encounter_id == SERAPHINE_RECRUITMENT_ENCOUNTER_ID:
		return [&"prayer_rag_novice", &"hollow_servant"]
	if node.node_type == MapNodeState.NodeType.BOSS:
		# The Prayer-Rag Novice gives Communion a meaningful support target
		# without turning the boss room into another generic three-on-three.
		return [&"blood_nun", &"prayer_rag_novice"]

	var selector: int = absi(encounter_seed) % 6
	if node.node_type == MapNodeState.NodeType.ELITE:
		if selector % 2 == 0:
			return [&"red_wax_acolyte", &"hollow_servant"]
		# Preserve the validated prototype trio as a hard elite-grade
		# formation, not as the ordinary room baseline.
		return [
			&"hollow_servant",
			&"knife_footman",
			&"prayer_rag_novice",
		]

	# Regular encounters are intentionally capped at one or two Standards.
	var regular_compositions: Array = [
		[&"hollow_servant"],
		[&"knife_footman"],
		[&"prayer_rag_novice"],
		[&"hollow_servant", &"knife_footman"],
		[&"hollow_servant", &"prayer_rag_novice"],
		[&"knife_footman", &"prayer_rag_novice"],
	]
	var selected: Array = regular_compositions[selector]
	var result: Array[StringName] = []
	for enemy_id: StringName in selected:
		result.append(enemy_id)
	return result


func apply_encounter_outcome(outcome: EncounterOutcome) -> String:
	if outcome == null or outcome.source_node_id != pending_node_id:
		return "Encounter outcome does not match the pending map node."
	var resolved_node: MapNodeState = graph.get_map_node(pending_node_id)
	if (
		outcome.result == EncounterOutcome.Result.DEFEAT
		and _is_unrecruited_recruitment_ally_outcome(outcome)
	):
		# A defeated recruitment attempt must not turn a scene ally into a
		# persistent party member merely because combat returned her state.
		var retained_party_snapshot: Dictionary = {}
		for party_id: StringName in _make_current_party_ids():
			if outcome.party_snapshot.has(party_id):
				retained_party_snapshot[party_id] = (
					outcome.party_snapshot[party_id] as Dictionary
				).duplicate(true)
		party_snapshot = retained_party_snapshot
	else:
		party_snapshot = outcome.party_snapshot.duplicate(true)
	inventory_snapshot = outcome.inventory_snapshot.duplicate(true)
	if not outcome.heroine_progression_snapshot.is_empty():
		_merge_heroine_progression_snapshot(
			outcome.heroine_progression_snapshot
		)
	if outcome.result == EncounterOutcome.Result.VICTORY:
		if (
			resolved_node != null
			and resolved_node.node_type == MapNodeState.NodeType.BOSS
			and campaign_lifecycle != null
		):
			campaign_lifecycle.mark_boss_defeated(outcome.encounter_id)
		var reward_claimed_now: bool = true
		if (
			resolved_node != null
			and not resolved_node.reward_claimed
			and resolved_node.reward_source_id != &""
		):
			var reward_result: Dictionary = _resolve_and_route_node_reward(
				resolved_node
			)
			var item_reward_error: String = String(
				reward_result.get("error", "")
			)
			reward_claimed_now = bool(
				reward_result.get("claimed", false)
			)
			if not item_reward_error.is_empty():
				push_warning(item_reward_error)
		complete_pending_node(outcome.bloom_reward, reward_claimed_now)
	else:
		pending_node_id = &""
		pending_origin_node_id = &""
		pending_node_seed = 0
	run_changed.emit()
	return ""


func is_mira_recruitment_encounter_outcome(
	outcome: EncounterOutcome
) -> bool:
	return (
		outcome != null
		and narrative_state != null
		and outcome.encounter_id == MIRA_RECRUITMENT_ENCOUNTER_ID
		and outcome.source_node_id == pending_node_id
		and not narrative_state.recruited_heroine_ids.has(&"mira")
	)


func is_seraphine_recruitment_node_pending() -> bool:
	if graph == null or pending_node_id == &"" or narrative_state == null:
		return false
	var node: MapNodeState = graph.get_map_node(pending_node_id)
	return (
		node != null
		and node.encounter_id == SERAPHINE_RECRUITMENT_ENCOUNTER_ID
		and not narrative_state.recruited_heroine_ids.has(&"seraphine")
	)


func requires_seraphine_recruitment_prelude() -> bool:
	return (
		is_seraphine_recruitment_node_pending()
		and not _has_narrative_flag(&"run", SERAPHINE_PRELUDE_FLAG_ID)
	)


func is_seraphine_recruitment_encounter_outcome(
	outcome: EncounterOutcome
) -> bool:
	return (
		outcome != null
		and narrative_state != null
		and outcome.encounter_id == SERAPHINE_RECRUITMENT_ENCOUNTER_ID
		and outcome.source_node_id == pending_node_id
		and not narrative_state.recruited_heroine_ids.has(&"seraphine")
	)


func is_blood_nun_encounter_outcome(
	outcome: EncounterOutcome
) -> bool:
	return (
		outcome != null
		and graph != null
		and graph.layer_id == &"layer_1"
		and outcome.encounter_id == BLOOD_NUN_ENCOUNTER_ID
		and outcome.source_node_id == pending_node_id
	)


func get_blood_nun_route_choice(
	story_outcome: StoryDialogueOutcome
) -> StringName:
	if story_outcome == null:
		return &""
	for dialogue_snapshot: Dictionary in (
		story_outcome.dialogue_result_snapshots
	):
		var selected_choice_id := StringName(
			dialogue_snapshot.get("selected_choice_id", "")
		)
		if selected_choice_id in [
			BLOOD_NUN_GO_UP_CHOICE_ID,
			BLOOD_NUN_GO_DOWN_CHOICE_ID,
		]:
			return selected_choice_id
	return &""


func apply_blood_nun_aftermath(
	combat_outcome: EncounterOutcome,
	story_outcome: StoryDialogueOutcome,
	next_graph: LayerMapGraph
) -> String:
	if not is_blood_nun_encounter_outcome(combat_outcome):
		return "Combat outcome does not match the Blood Nun encounter."
	var pending_boss_node: MapNodeState = graph.get_map_node(pending_node_id)
	if (
		pending_boss_node == null
		or pending_boss_node.node_type != MapNodeState.NodeType.BOSS
		or pending_boss_node.encounter_id != BLOOD_NUN_ENCOUNTER_ID
	):
		return "The pending Layer 1 boss node is invalid."
	if combat_outcome.result != EncounterOutcome.Result.VICTORY:
		return "The Blood Nun aftermath requires a victory."
	if story_outcome == null:
		return "The Blood Nun aftermath is missing."
	if story_outcome.story_id != BLOOD_NUN_AFTERMATH_STORY_ID:
		return "Story outcome does not match the Blood Nun aftermath."
	if story_outcome.source_node_id != pending_node_id:
		return "The Blood Nun aftermath came from the wrong map node."
	if narrative_state == null:
		return "The run narrative state is unavailable."
	if story_outcome.bloom_delta < 0:
		return "The Blood Nun aftermath returned negative Bloom."
	if story_outcome.inventory_snapshot.size() != SixSlotInventoryState.SLOT_COUNT:
		return "The Blood Nun aftermath returned an invalid inventory snapshot."
	var staged_inventory_result: Dictionary = _stage_outcome_run_inventory(
		story_outcome.inventory_snapshot,
		story_outcome.run_inventory_snapshot
	)
	var staged_inventory_error: String = String(
		staged_inventory_result.get("error", "")
	)
	if not staged_inventory_error.is_empty():
		return staged_inventory_error
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		if not story_outcome.party_snapshot.has(heroine_id):
			return "The Blood Nun aftermath must preserve all three heroines."
	var route_choice_id: StringName = get_blood_nun_route_choice(
		story_outcome
	)
	if route_choice_id == &"":
		return "The Blood Nun aftermath did not choose an exit route."
	var expected_layer_id: StringName = (
		&"layer_3"
		if route_choice_id == BLOOD_NUN_GO_UP_CHOICE_ID
		else &"layer_2"
	)
	if next_graph == null or next_graph.layer_id != expected_layer_id:
		return (
			"The Blood Nun aftermath route requires a %s map."
			% expected_layer_id
		)
	var graph_error: String = next_graph.validate_graph()
	if not graph_error.is_empty():
		return graph_error
	if next_graph.get_map_node(next_graph.start_node_id) == null:
		return "The Layer 2 map has no entrance node."
	var expected_start_node_id: StringName = (
		&"l3_lower_halls_threshold"
		if route_choice_id == BLOOD_NUN_GO_UP_CHOICE_ID
		else &"l2_jailer_threshold"
	)
	if next_graph.start_node_id != expected_start_node_id:
		return "The destination does not match the chosen stair."

	var next_narrative_state := NarrativeState.new()
	var narrative_error: String = next_narrative_state.restore_from_snapshot(
		narrative_state.to_snapshot(),
		DIALOGUE_CATALOG
	)
	if not narrative_error.is_empty():
		return narrative_error
	for dialogue_snapshot: Dictionary in (
		story_outcome.dialogue_result_snapshots
	):
		narrative_error = (
			next_narrative_state.apply_dialogue_result_snapshot(
				dialogue_snapshot,
				DIALOGUE_CATALOG
			)
		)
		if not narrative_error.is_empty():
			return narrative_error
	var save_flags: Dictionary = (
		next_narrative_state.flags_by_scope.get(&"save", {}) as Dictionary
	)
	if not bool(save_flags.get(LAYER_1_COMPLETED_FLAG_ID, false)):
		return "The Blood Nun aftermath did not mark Layer 1 complete."
	if not next_narrative_state.resolved_interaction_ids.has(
		BLOOD_NUN_AFTERMATH_STORY_ID
	):
		return "The Blood Nun aftermath did not resolve its story interaction."

	# Everything above is validation. Commit the layer boundary as one state
	# transaction so a malformed story result cannot half-complete Layer 1.
	var completed_layer_graph: LayerMapGraph = graph
	pending_boss_node.cleared = true
	pending_boss_node.reward_claimed = true
	party_snapshot = story_outcome.party_snapshot.duplicate(true)
	run_inventory = staged_inventory_result.get("state") as RunInventoryState
	if not combat_outcome.heroine_progression_snapshot.is_empty():
		_merge_heroine_progression_snapshot(
			combat_outcome.heroine_progression_snapshot
		)
	narrative_state = next_narrative_state
	bloom += maxi(combat_outcome.bloom_reward, 0)
	bloom += story_outcome.bloom_delta
	completed_encounters[BLOOD_NUN_ENCOUNTER_ID] = true
	if campaign_lifecycle == null:
		campaign_lifecycle = CampaignLifecycleState.new()
		campaign_lifecycle.initialize_new(maxi(run_seed, 1))
	campaign_lifecycle.mark_boss_defeated(BLOOD_NUN_BOSS_ID)
	campaign_lifecycle.begin_refugeless_ascent(route_choice_id)
	if not completed_layer_ids.has(&"layer_1"):
		completed_layer_ids.append(&"layer_1")
	archived_layer_graphs[&"layer_1"] = completed_layer_graph

	graph = next_graph
	run_seed = next_graph.run_seed
	current_node_id = graph.start_node_id
	selected_node_id = graph.start_node_id
	pending_node_id = &""
	pending_origin_node_id = &""
	pending_node_seed = 0
	event_room_snapshots.clear()
	generated_room_item_requests.clear()
	reward_resolutions.clear()
	opening_completed = true
	run_changed.emit()
	return ""


func begin_immediate_jailer_encounter() -> String:
	if graph == null or graph.layer_id != &"layer_2":
		return "The Jailer can only be entered from the Layer 2 exit threshold."
	if current_node_id != graph.start_node_id or pending_node_id != &"":
		return "The Layer 2 threshold is not ready for the Jailer encounter."
	var select_error: String = select_node(JAILER_FIRST_NODE_ID)
	if not select_error.is_empty():
		return select_error
	return travel_to(JAILER_FIRST_NODE_ID)


func is_jailer_first_encounter_outcome(
	outcome: EncounterOutcome
) -> bool:
	return (
		outcome != null
		and graph != null
		and graph.layer_id == &"layer_2"
		and outcome.encounter_id == JAILER_FIRST_ENCOUNTER_ID
		and outcome.source_node_id == pending_node_id
	)


func has_established_refuge() -> bool:
	return (
		_has_narrative_flag(
			&"save",
			REFUGE_EVER_ESTABLISHED_FLAG_ID
		)
		and campaign_lifecycle != null
		and campaign_lifecycle.has_refuge()
	)


func apply_jailer_victory(
	combat_outcome: EncounterOutcome,
	story_outcome: StoryDialogueOutcome,
	reverse_layer_2_graph: LayerMapGraph
) -> String:
	if not is_jailer_first_encounter_outcome(combat_outcome):
		return "Combat outcome does not match the Jailer encounter."
	if combat_outcome.result != EncounterOutcome.Result.VICTORY:
		return "Jailer victory requires a victorious encounter outcome."
	if campaign_lifecycle == null or not campaign_lifecycle.is_refugeless():
		return "The first Jailer victory belongs to Refuge-less ascent."
	if has_established_refuge():
		return "The first Jailer victory cannot establish or revisit the Refuge."
	if story_outcome == null or story_outcome.story_id != JAILER_VICTORY_STORY_ID:
		return "The Jailer victory aftermath is missing."
	if story_outcome.source_node_id != pending_node_id:
		return "The Jailer victory aftermath came from the wrong map node."
	if story_outcome.bloom_delta < 0:
		return "The Jailer victory aftermath returned negative Bloom."
	if story_outcome.inventory_snapshot.size() != SixSlotInventoryState.SLOT_COUNT:
		return "The Jailer victory aftermath returned an invalid inventory snapshot."
	if narrative_state == null:
		return "The run narrative state is unavailable."
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		if not (story_outcome.party_snapshot.get(heroine_id, null) is Dictionary):
			return "Jailer victory must preserve all three heroines."

	var jailer_node: MapNodeState = graph.get_map_node(pending_node_id)
	if (
		jailer_node == null
		or jailer_node.encounter_id != JAILER_FIRST_ENCOUNTER_ID
	):
		return "The pending Jailer node is invalid."
	if (
		reverse_layer_2_graph == null
		or reverse_layer_2_graph.layer_id != &"layer_2"
		or reverse_layer_2_graph.start_node_id != LAYER_2_FARTHEST_CELL_NODE_ID
		or reverse_layer_2_graph.boss_node_id != JAILER_FIRST_NODE_ID
	):
		return "Jailer victory requires the registered reverse Layer 2 route."
	var reverse_graph_error: String = reverse_layer_2_graph.validate_graph()
	if not reverse_graph_error.is_empty():
		return reverse_graph_error
	var expected_layer_seed: int = get_refugeless_layer_seed(2)
	if expected_layer_seed <= 0 or reverse_layer_2_graph.run_seed != expected_layer_seed:
		return "The reverse Layer 2 route does not match the Refuge-less seed."
	var cleared_jailer: MapNodeState = reverse_layer_2_graph.get_map_node(
		reverse_layer_2_graph.boss_node_id
	)
	if (
		cleared_jailer == null
		or not cleared_jailer.cleared
		or not cleared_jailer.reward_claimed
		or cleared_jailer.encounter_id != &""
		or cleared_jailer.encounter_template_id != &""
	):
		return "The reverse Layer 2 route must retain one cleared Jailer."
	var staged_inventory_result: Dictionary = _stage_outcome_run_inventory(
		story_outcome.inventory_snapshot,
		story_outcome.run_inventory_snapshot
	)
	var staged_inventory_error: String = String(
		staged_inventory_result.get("error", "")
	)
	if not staged_inventory_error.is_empty():
		return staged_inventory_error
	var staged_narrative := NarrativeState.new()
	var narrative_error: String = staged_narrative.restore_from_snapshot(
		narrative_state.to_snapshot(),
		DIALOGUE_CATALOG
	)
	if not narrative_error.is_empty():
		return narrative_error
	for dialogue_snapshot: Dictionary in story_outcome.dialogue_result_snapshots:
		narrative_error = staged_narrative.apply_dialogue_result_snapshot(
			dialogue_snapshot,
			DIALOGUE_CATALOG
		)
		if not narrative_error.is_empty():
			return narrative_error
	if not staged_narrative.resolved_interaction_ids.has(JAILER_VICTORY_STORY_ID):
		return "The Jailer victory aftermath did not resolve its story interaction."

	party_snapshot = story_outcome.party_snapshot.duplicate(true)
	run_inventory = staged_inventory_result.get("state") as RunInventoryState
	narrative_state = staged_narrative
	if not combat_outcome.heroine_progression_snapshot.is_empty():
		_merge_heroine_progression_snapshot(
			combat_outcome.heroine_progression_snapshot
		)
	bloom += maxi(combat_outcome.bloom_reward, 0)
	bloom += story_outcome.bloom_delta
	completed_encounters[JAILER_FIRST_ENCOUNTER_ID] = true
	campaign_lifecycle.mark_boss_defeated(JAILER_BOSS_ID)
	graph = reverse_layer_2_graph
	run_seed = reverse_layer_2_graph.run_seed
	current_node_id = reverse_layer_2_graph.boss_node_id
	selected_node_id = reverse_layer_2_graph.boss_node_id
	pending_node_id = &""
	pending_origin_node_id = &""
	pending_node_seed = 0
	event_room_snapshots.clear()
	generated_room_item_requests.clear()
	reward_resolutions.clear()
	run_changed.emit()
	return ""


func is_at_refugeless_farthest_cell() -> bool:
	return (
		campaign_lifecycle != null
		and campaign_lifecycle.is_refugeless()
		and not has_established_refuge()
		and campaign_lifecycle.is_boss_defeated(JAILER_BOSS_ID)
		and graph != null
		and graph.layer_id == &"layer_2"
		and graph.start_node_id == LAYER_2_FARTHEST_CELL_NODE_ID
		and current_node_id == LAYER_2_FARTHEST_CELL_NODE_ID
		and pending_node_id == &""
	)


func establish_refuge_at_farthest_cell(
	refuge_graph: LayerMapGraph,
	battler_catalog: BattlerCatalogDefinition,
	story_outcome: StoryDialogueOutcome
) -> String:
	if not is_at_refugeless_farthest_cell():
		return "The Bloom Refuge can only form at the Refuge-less Farthest Cell."
	if battler_catalog == null:
		return "Farthest Cell Refuge establishment requires the battler catalog."
	if refuge_graph == null or refuge_graph.layer_id != &"bloom_refuge":
		return "Farthest Cell Refuge establishment requires its holding-state graph."
	var refuge_graph_error: String = refuge_graph.validate_graph()
	if not refuge_graph_error.is_empty():
		return refuge_graph_error
	if narrative_state == null:
		return "The run narrative state is unavailable."
	if story_outcome == null or story_outcome.story_id != FARTHEST_CELL_REFUGE_STORY_ID:
		return "The Farthest Cell Refuge-establishment story is missing."
	if story_outcome.source_node_id != LAYER_2_FARTHEST_CELL_NODE_ID:
		return "The Farthest Cell story came from the wrong map node."
	if story_outcome.bloom_delta < 0:
		return "The Farthest Cell story returned negative Bloom."
	if story_outcome.inventory_snapshot.size() != SixSlotInventoryState.SLOT_COUNT:
		return "The Farthest Cell story returned an invalid inventory snapshot."
	var staged_inventory_result: Dictionary = _stage_outcome_run_inventory(
		story_outcome.inventory_snapshot,
		story_outcome.run_inventory_snapshot
	)
	var staged_inventory_error: String = String(
		staged_inventory_result.get("error", "")
	)
	if not staged_inventory_error.is_empty():
		return staged_inventory_error
	var recovered_party: Dictionary = _restore_party_hp_mp(
		story_outcome.party_snapshot,
		battler_catalog
	)
	if recovered_party.size() != story_outcome.party_snapshot.size() or recovered_party.size() != 3:
		return "The complete Refuge-less party could not recover at the Farthest Cell."

	var staged_narrative := NarrativeState.new()
	var narrative_error: String = staged_narrative.restore_from_snapshot(
		narrative_state.to_snapshot(),
		DIALOGUE_CATALOG
	)
	if not narrative_error.is_empty():
		return narrative_error
	for dialogue_snapshot: Dictionary in story_outcome.dialogue_result_snapshots:
		narrative_error = staged_narrative.apply_dialogue_result_snapshot(
			dialogue_snapshot,
			DIALOGUE_CATALOG
		)
		if not narrative_error.is_empty():
			return narrative_error
	var save_flags: Dictionary = (
		staged_narrative.flags_by_scope.get(&"save", {}) as Dictionary
	)
	if not bool(save_flags.get(REFUGE_EVER_ESTABLISHED_FLAG_ID, false)):
		return "The Farthest Cell story did not establish the Bloom Refuge."
	if not staged_narrative.resolved_interaction_ids.has(
		FARTHEST_CELL_REFUGE_STORY_ID
	):
		return "The Farthest Cell story did not resolve its interaction."

	var staged_refuge := RefugeOwnershipState.new()
	var refuge_error: String = staged_refuge.initialize_default(
		ITEM_CATALOG,
		battler_catalog,
		DEMO_HEROINE_IDS,
		party_snapshot
	)
	if not refuge_error.is_empty():
		return refuge_error
	var resolution: Dictionary = staged_refuge.make_run_return_transfer(
		staged_inventory_result.get("state") as RunInventoryState,
		run_equipment,
		false
	)
	refuge_error = String(resolution.get("error", ""))
	if not refuge_error.is_empty():
		return refuge_error

	# Commit only after the route, narrative, party, and ownership transfer all
	# validate. This is the living-party counterpart to the authored defeat
	# origin and commits only after its dialogue completion is present.
	archived_layer_graphs[graph.layer_id] = graph
	party_snapshot = recovered_party
	refuge_ownership = resolution.get("refuge_state") as RefugeOwnershipState
	run_inventory = resolution.get("run_inventory") as RunInventoryState
	run_equipment = resolution.get("run_equipment") as RunEquipmentState
	narrative_state = staged_narrative
	bloom += story_outcome.bloom_delta
	campaign_lifecycle.establish_refuge()
	graph = refuge_graph
	current_node_id = refuge_graph.start_node_id
	selected_node_id = refuge_graph.start_node_id
	pending_node_id = &""
	pending_origin_node_id = &""
	pending_node_seed = 0
	completed_encounters.clear()
	event_room_snapshots.clear()
	generated_room_item_requests.clear()
	reward_resolutions.clear()
	active_run_refuge_boundary_snapshot.clear()
	opening_completed = true
	run_changed.emit()
	return ""


func apply_first_jailer_defeat_and_refuge_origin(
	combat_outcome: EncounterOutcome,
	story_outcome: StoryDialogueOutcome,
	refuge_graph: LayerMapGraph,
	battler_catalog: BattlerCatalogDefinition
) -> String:
	if not is_jailer_first_encounter_outcome(combat_outcome):
		return "Combat outcome does not match the first Jailer encounter."
	return apply_refugeless_defeat_and_refuge_origin(
		combat_outcome,
		story_outcome,
		refuge_graph,
		battler_catalog
	)


func apply_refugeless_defeat_and_refuge_origin(
	combat_outcome: EncounterOutcome,
	story_outcome: StoryDialogueOutcome,
	refuge_graph: LayerMapGraph,
	battler_catalog: BattlerCatalogDefinition
) -> String:
	if (
		combat_outcome == null
		or combat_outcome.source_node_id != pending_node_id
	):
		return "Combat outcome does not match the pending Refuge-less encounter."
	if combat_outcome.result != EncounterOutcome.Result.DEFEAT:
		return "The first Refuge origin requires a Refuge-less full-party defeat."
	if campaign_lifecycle == null or not campaign_lifecycle.is_refugeless():
		return "The first Refuge origin requires Refuge-less ascent."
	if story_outcome == null or story_outcome.story_id != REFUGE_ORIGIN_STORY_ID:
		return "The Bloom Refuge origin story is missing."
	if story_outcome.source_node_id != pending_node_id:
		return "The Bloom Refuge origin came from the wrong map node."
	if narrative_state == null:
		return "The run narrative state is unavailable."
	if has_established_refuge():
		return "The Bloom Refuge has already been established."
	if battler_catalog == null:
		return "The Bloom Refuge recovery requires a battler catalog."
	if story_outcome.bloom_delta < 0:
		return "The Bloom Refuge origin returned negative Bloom."
	if story_outcome.inventory_snapshot.size() != SixSlotInventoryState.SLOT_COUNT:
		return "The Bloom Refuge origin returned an invalid inventory snapshot."
	var staged_inventory_result: Dictionary = _stage_outcome_run_inventory(
		story_outcome.inventory_snapshot,
		story_outcome.run_inventory_snapshot
	)
	var staged_inventory_error: String = String(
		staged_inventory_result.get("error", "")
	)
	if not staged_inventory_error.is_empty():
		return staged_inventory_error
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		var battler: BattlerDefinition = battler_catalog.get_battler(heroine_id)
		var heroine_value: Variant = story_outcome.party_snapshot.get(
			heroine_id,
			story_outcome.party_snapshot.get(String(heroine_id), null)
		)
		if battler == null or not (heroine_value is Dictionary):
			return "The Bloom Refuge origin must preserve all three heroines."
		var heroine_snapshot := heroine_value as Dictionary
		if (
			int(heroine_snapshot.get("hp", 0)) != battler.max_hp
			or int(heroine_snapshot.get("mp", -1)) != battler.max_mp
		):
			return "Bloom Refuge recovery must restore every heroine's HP and MP."
	if refuge_graph == null or refuge_graph.layer_id != &"bloom_refuge":
		return "The Bloom Refuge origin requires its holding-state graph."
	var graph_error: String = refuge_graph.validate_graph()
	if not graph_error.is_empty():
		return graph_error

	var next_narrative_state := NarrativeState.new()
	var narrative_error: String = next_narrative_state.restore_from_snapshot(
		narrative_state.to_snapshot(),
		DIALOGUE_CATALOG
	)
	if not narrative_error.is_empty():
		return narrative_error
	for dialogue_snapshot: Dictionary in story_outcome.dialogue_result_snapshots:
		narrative_error = next_narrative_state.apply_dialogue_result_snapshot(
			dialogue_snapshot,
			DIALOGUE_CATALOG
		)
		if not narrative_error.is_empty():
			return narrative_error
	var save_flags: Dictionary = (
		next_narrative_state.flags_by_scope.get(&"save", {}) as Dictionary
	)
	if not bool(save_flags.get(REFUGE_EVER_ESTABLISHED_FLAG_ID, false)):
		return "The Refuge origin completed without establishing the Refuge."
	if not next_narrative_state.resolved_interaction_ids.has(
		REFUGE_ORIGIN_STORY_ID
	):
		return "The Refuge origin interaction was not resolved."
	var staged_refuge := RefugeOwnershipState.new()
	var refuge_error: String = staged_refuge.initialize_default(
		ITEM_CATALOG,
		battler_catalog,
		DEMO_HEROINE_IDS,
		story_outcome.party_snapshot
	)
	if not refuge_error.is_empty():
		return refuge_error
	var resolution: Dictionary = staged_refuge.make_run_return_transfer(
		staged_inventory_result.get("state") as RunInventoryState,
		run_equipment,
		true
	)
	refuge_error = String(resolution.get("error", ""))
	if not refuge_error.is_empty():
		return refuge_error

	# Validation above is side-effect free. The defeated node remains unresolved,
	# while every already-defeated boss remains in the campaign registry.
	archived_layer_graphs[graph.layer_id] = graph
	party_snapshot = story_outcome.party_snapshot.duplicate(true)
	refuge_ownership = resolution.get("refuge_state") as RefugeOwnershipState
	run_inventory = resolution.get("run_inventory") as RunInventoryState
	run_equipment = resolution.get("run_equipment") as RunEquipmentState
	if not combat_outcome.heroine_progression_snapshot.is_empty():
		_merge_heroine_progression_snapshot(
			combat_outcome.heroine_progression_snapshot
		)
	narrative_state = next_narrative_state
	campaign_lifecycle.establish_refuge()
	bloom += story_outcome.bloom_delta
	graph = refuge_graph
	current_node_id = graph.start_node_id
	selected_node_id = graph.start_node_id
	pending_node_id = &""
	pending_origin_node_id = &""
	pending_node_seed = 0
	opening_completed = true
	run_changed.emit()
	return ""


func make_refuge_campaign_snapshot() -> Dictionary:
	if (
		graph == null
		or graph.layer_id != &"bloom_refuge"
		or not has_established_refuge()
		or narrative_state == null
	):
		return {}
	var serialized_party: Dictionary = {}
	for party_key: Variant in party_snapshot.keys():
		var party_value: Variant = party_snapshot[party_key]
		if party_value is Dictionary:
			serialized_party[String(party_key)] = (
				(party_value as Dictionary).duplicate(true)
			)
	var serialized_progression: Dictionary = {}
	for progression_key: Variant in heroine_progression_snapshot.keys():
		var progression_value: Variant = heroine_progression_snapshot[
			progression_key
		]
		if progression_value is Dictionary:
			serialized_progression[String(progression_key)] = (
				(progression_value as Dictionary).duplicate(true)
			)
	var serialized_layers: Array[String] = []
	for layer_id: StringName in completed_layer_ids:
		serialized_layers.append(String(layer_id))
	return {
		"saved_location_id": "bloom_refuge_farthest_cell",
		"run_seed": run_seed,
		"campaign_lifecycle": make_campaign_lifecycle_snapshot(),
		"party_snapshot": serialized_party,
		"inventory_snapshot": inventory_snapshot.duplicate(true),
		"heroine_progression_snapshot": serialized_progression,
		"bloom": bloom,
		"completed_layer_ids": serialized_layers,
		"narrative_state": _make_between_runs_narrative_snapshot(),
	}


func restore_refuge_campaign_snapshot(
	snapshot: Dictionary,
	refuge_graph: LayerMapGraph,
	battler_catalog: BattlerCatalogDefinition
) -> String:
	if String(snapshot.get("saved_location_id", "")) != (
		"bloom_refuge_farthest_cell"
	):
		return "Campaign save is not located at the Bloom Refuge boundary."
	if refuge_graph == null or refuge_graph.layer_id != &"bloom_refuge":
		return "Campaign load requires a valid Bloom Refuge graph."
	var graph_error: String = refuge_graph.validate_graph()
	if not graph_error.is_empty():
		return graph_error
	if battler_catalog == null:
		return "Campaign load requires the battler catalog."
	var party_value: Variant = snapshot.get("party_snapshot", {})
	var inventory_value: Variant = snapshot.get("inventory_snapshot", [])
	var progression_value: Variant = snapshot.get(
		"heroine_progression_snapshot",
		{}
	)
	var narrative_value: Variant = snapshot.get("narrative_state", {})
	var completed_value: Variant = snapshot.get("completed_layer_ids", [])
	var lifecycle_value: Variant = snapshot.get("campaign_lifecycle", {})
	if not (party_value is Dictionary):
		return "Campaign save contains invalid party state."
	if not (inventory_value is Array):
		return "Campaign save contains invalid inventory state."
	if not (progression_value is Dictionary):
		return "Campaign save contains invalid progression state."
	if not (narrative_value is Dictionary):
		return "Campaign save contains invalid narrative state."
	if not (completed_value is Array):
		return "Campaign save contains invalid completed-layer state."
	if not (lifecycle_value is Dictionary):
		return "Campaign save contains invalid campaign lifecycle state."

	var restored_party: Dictionary = _normalize_named_snapshot_dictionary(
		party_value as Dictionary
	)
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		if (
			battler_catalog.get_battler(heroine_id) == null
			or not restored_party.has(heroine_id)
		):
			return "Bloom Refuge campaign must preserve all three heroines."
	var restored_inventory: Array[Dictionary] = []
	for slot_value: Variant in (inventory_value as Array):
		if not (slot_value is Dictionary):
			return "Campaign save contains an invalid inventory slot."
		restored_inventory.append((slot_value as Dictionary).duplicate(true))
	if restored_inventory.size() != SixSlotInventoryState.SLOT_COUNT:
		return "Campaign save must contain the six-slot inventory."
	var restored_run_inventory := RunInventoryState.new()
	var run_inventory_error: String = restored_run_inventory.initialize(
		ITEM_CATALOG,
		DEMO_HEROINE_IDS
	)
	if run_inventory_error.is_empty():
		# Save Envelope v3 retains Milestone 1's explicitly isolated
		# quiet_cell_blanket compatibility only at this campaign boundary.
		run_inventory_error = restored_run_inventory.restore_item_bar_snapshot(
			restored_inventory,
			true
		)
	if not run_inventory_error.is_empty():
		return run_inventory_error
	var restored_progression: Dictionary = _normalize_named_snapshot_dictionary(
		progression_value as Dictionary
	)
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		if not restored_progression.has(heroine_id):
			return "Campaign save is missing heroine progression state."
	var restored_narrative := NarrativeState.new()
	var narrative_error: String = restored_narrative.restore_from_snapshot(
		narrative_value as Dictionary,
		DIALOGUE_CATALOG
	)
	if not narrative_error.is_empty():
		return narrative_error
	var save_flags: Dictionary = restored_narrative.flags_by_scope.get(
		&"save",
		{}
	) as Dictionary
	if not bool(save_flags.get(REFUGE_EVER_ESTABLISHED_FLAG_ID, false)):
		return "Campaign save does not establish the Bloom Refuge."

	var restored_layers: Array[StringName] = []
	for layer_value: Variant in (completed_value as Array):
		var layer_id := StringName(layer_value)
		if layer_id != &"" and not restored_layers.has(layer_id):
			restored_layers.append(layer_id)
	if not restored_layers.has(&"layer_1"):
		return "Bloom Refuge campaign must retain Layer 1 completion."

	var restored_lifecycle := CampaignLifecycleState.new()
	if (lifecycle_value as Dictionary).is_empty():
		restored_lifecycle.restore_legacy_refuge(
			maxi(int(snapshot.get("run_seed", 1)), 1)
		)
		restored_lifecycle.mark_boss_defeated(BLOOD_NUN_BOSS_ID)
	else:
		var lifecycle_error: String = restored_lifecycle.restore_from_snapshot(
			lifecycle_value as Dictionary
		)
		if not lifecycle_error.is_empty():
			return lifecycle_error
		if not restored_lifecycle.has_refuge():
			return "Bloom Refuge save is not in REFUGE_RUN mode."
	var restored_run_equipment := RunEquipmentState.new()
	var equipment_error: String = restored_run_equipment.initialize(
		battler_catalog,
		DEMO_HEROINE_IDS,
		restored_run_inventory,
		restored_party
	)
	if not equipment_error.is_empty():
		return equipment_error

	# Commit after the complete document has passed validation.
	run_seed = maxi(int(snapshot.get("run_seed", 1)), 1)
	party_snapshot = restored_party
	run_inventory = restored_run_inventory
	run_equipment = restored_run_equipment
	heroine_progression_snapshot = restored_progression
	bloom = maxi(int(snapshot.get("bloom", 0)), 0)
	completed_layer_ids = restored_layers
	narrative_state = restored_narrative
	campaign_lifecycle = restored_lifecycle
	graph = refuge_graph
	graph.run_seed = run_seed
	current_node_id = graph.start_node_id
	selected_node_id = graph.start_node_id
	pending_node_id = &""
	pending_origin_node_id = &""
	pending_node_seed = 0
	completed_encounters.clear()
	event_room_snapshots.clear()
	generated_room_item_requests.clear()
	reward_resolutions.clear()
	archived_layer_graphs.clear()
	active_run_refuge_boundary_snapshot.clear()
	opening_completed = true
	run_changed.emit()
	return ""


func validate_next_layer_2_run(next_graph: LayerMapGraph) -> String:
	if not has_established_refuge():
		return "The Bloom Refuge must exist before beginning a Layer 2 run."
	if graph == null or graph.layer_id != &"bloom_refuge":
		return "The next run can only begin from the Bloom Refuge."
	if next_graph == null or next_graph.layer_id != &"layer_2":
		return "The Bloom Refuge requires a Layer 2 route."
	if next_graph.start_node_id != &"l2_refuge_farthest_cell":
		return "Layer 2 runs must begin at the farthest cell."
	var graph_error: String = next_graph.validate_graph()
	if not graph_error.is_empty():
		return graph_error
	var staged_narrative := NarrativeState.new()
	var narrative_error: String = staged_narrative.restore_from_snapshot(
		_make_between_runs_narrative_snapshot()
	)
	if not narrative_error.is_empty():
		return narrative_error
	var refuge_error: String = ensure_refuge_ownership_initialized()
	if not refuge_error.is_empty():
		return refuge_error
	var party_order_result: Dictionary = _make_selected_party_snapshot()
	var party_order_error: String = String(
		party_order_result.get("error", "")
	)
	if not party_order_error.is_empty():
		return party_order_error
	return String(refuge_ownership.make_run_start_transfer().get("error", ""))


func begin_next_layer_2_run(next_graph: LayerMapGraph) -> String:
	var validation_error: String = validate_next_layer_2_run(next_graph)
	if not validation_error.is_empty():
		return validation_error
	var next_narrative := NarrativeState.new()
	var narrative_error: String = next_narrative.restore_from_snapshot(
		_make_between_runs_narrative_snapshot()
	)
	if not narrative_error.is_empty():
		return narrative_error
	var party_order_result: Dictionary = _make_selected_party_snapshot()
	var party_order_error: String = String(
		party_order_result.get("error", "")
	)
	if not party_order_error.is_empty():
		return party_order_error
	var refuge_boundary_snapshot: Dictionary = refuge_ownership.to_snapshot()
	var transfer: Dictionary = refuge_ownership.make_run_start_transfer()
	var transfer_error: String = String(transfer.get("error", ""))
	if not transfer_error.is_empty():
		return transfer_error

	archived_layer_graphs[&"bloom_refuge"] = graph
	refuge_ownership = transfer.get("refuge_state") as RefugeOwnershipState
	active_run_refuge_boundary_snapshot = refuge_boundary_snapshot.duplicate(true)
	run_inventory = transfer.get("run_inventory") as RunInventoryState
	run_equipment = transfer.get("run_equipment") as RunEquipmentState
	party_snapshot = (
		party_order_result.get("party_snapshot", {}) as Dictionary
	).duplicate(true)
	graph = next_graph
	run_seed = next_graph.run_seed
	campaign_lifecycle.begin_refuge_run(next_graph.run_seed)
	current_node_id = graph.start_node_id
	selected_node_id = graph.start_node_id
	pending_node_id = &""
	pending_origin_node_id = &""
	pending_node_seed = 0
	completed_encounters.clear()
	event_room_snapshots.clear()
	generated_room_item_requests.clear()
	reward_resolutions.clear()
	narrative_state = next_narrative
	# Locked economy rule: only Bloom spent before departure persists as value.
	# Spending is not active yet, so the hub warns before this is discarded.
	bloom = 0
	opening_completed = true
	run_changed.emit()
	return ""


func return_current_run_to_refuge(
	refuge_graph: LayerMapGraph,
	battler_catalog: BattlerCatalogDefinition
) -> String:
	if not has_established_refuge():
		return "The Bloom Refuge has not been established."
	var recovered_party: Dictionary = _restore_party_hp_mp(
		party_snapshot,
		battler_catalog
	)
	if recovered_party.size() != party_snapshot.size():
		return "The party could not recover at the Bloom Refuge."
	var resolution: Dictionary = refuge_ownership.make_run_return_transfer(
		run_inventory,
		run_equipment,
		false
	)
	var resolution_error: String = String(resolution.get("error", ""))
	if not resolution_error.is_empty():
		return resolution_error
	return _commit_refuge_return(
		refuge_graph,
		recovered_party,
		resolution
	)


func apply_post_refuge_defeat(
	outcome: EncounterOutcome,
	refuge_graph: LayerMapGraph,
	battler_catalog: BattlerCatalogDefinition
) -> String:
	if not has_established_refuge():
		return "Post-Refuge recovery requires the established Refuge."
	if outcome == null or outcome.result != EncounterOutcome.Result.DEFEAT:
		return "Post-Refuge recovery requires a defeated encounter outcome."
	var recovered_party: Dictionary = make_full_wipe_recovery_party_snapshot(
		outcome,
		battler_catalog
	)
	if recovered_party.size() != party_snapshot.size():
		return "The defeated party could not recover at the Bloom Refuge."
	if outcome.inventory_snapshot.size() != SixSlotInventoryState.SLOT_COUNT:
		return "The defeated run returned an invalid inventory snapshot."
	var staged_inventory_result: Dictionary = _stage_outcome_run_inventory(
		outcome.inventory_snapshot,
		{}
	)
	var staged_inventory_error: String = String(
		staged_inventory_result.get("error", "")
	)
	if not staged_inventory_error.is_empty():
		return staged_inventory_error
	var resolution: Dictionary = refuge_ownership.make_run_return_transfer(
		staged_inventory_result.get("state") as RunInventoryState,
		run_equipment,
		true
	)
	var resolution_error: String = String(resolution.get("error", ""))
	if not resolution_error.is_empty():
		return resolution_error
	return _commit_refuge_return(
		refuge_graph,
		recovered_party,
		resolution,
		outcome.heroine_progression_snapshot
	)


func _commit_refuge_return(
	refuge_graph: LayerMapGraph,
	recovered_party: Dictionary,
	resolution: Dictionary,
	progression_snapshot: Dictionary = {}
) -> String:
	if refuge_graph == null or refuge_graph.layer_id != &"bloom_refuge":
		return "Refuge return requires the Bloom Refuge graph."
	var graph_error: String = refuge_graph.validate_graph()
	if not graph_error.is_empty():
		return graph_error
	var next_narrative := NarrativeState.new()
	var narrative_error: String = next_narrative.restore_from_snapshot(
		_make_between_runs_narrative_snapshot()
	)
	if not narrative_error.is_empty():
		return narrative_error
	var staged_refuge: RefugeOwnershipState = resolution.get(
		"refuge_state"
	) as RefugeOwnershipState
	var staged_inventory: RunInventoryState = resolution.get(
		"run_inventory"
	) as RunInventoryState
	var staged_equipment: RunEquipmentState = resolution.get(
		"run_equipment"
	) as RunEquipmentState
	if staged_refuge == null or staged_inventory == null or staged_equipment == null:
		return "Refuge return produced incomplete ownership state."
	if graph != null and graph.layer_id != &"bloom_refuge":
		archived_layer_graphs[graph.layer_id] = graph
	party_snapshot = recovered_party.duplicate(true)
	refuge_ownership = staged_refuge
	run_inventory = staged_inventory
	run_equipment = staged_equipment
	if not progression_snapshot.is_empty():
		_merge_heroine_progression_snapshot(progression_snapshot)
	narrative_state = next_narrative
	graph = refuge_graph
	current_node_id = graph.start_node_id
	selected_node_id = graph.start_node_id
	pending_node_id = &""
	pending_origin_node_id = &""
	pending_node_seed = 0
	completed_encounters.clear()
	event_room_snapshots.clear()
	generated_room_item_requests.clear()
	reward_resolutions.clear()
	campaign_lifecycle.finish_active_run()
	active_run_refuge_boundary_snapshot.clear()
	opening_completed = true
	run_changed.emit()
	return ""


func ensure_refuge_ownership_initialized() -> String:
	if refuge_ownership == null:
		refuge_ownership = RefugeOwnershipState.new()
	if refuge_ownership.item_catalog != null:
		return ""
	return refuge_ownership.initialize_default(
		ITEM_CATALOG,
		BATTLER_CATALOG,
		DEMO_HEROINE_IDS,
		party_snapshot,
		inventory_snapshot
	)


func make_refuge_ownership_snapshot() -> Dictionary:
	if not has_established_refuge() or graph == null or graph.layer_id != &"bloom_refuge":
		return {}
	var refuge_error: String = ensure_refuge_ownership_initialized()
	if not refuge_error.is_empty():
		push_error(refuge_error)
		return {}
	return refuge_ownership.to_snapshot()


func apply_restored_refuge_ownership(
	restored_refuge: RefugeOwnershipState,
	battler_catalog: BattlerCatalogDefinition
) -> String:
	if restored_refuge == null or battler_catalog == null:
		return "Campaign load produced invalid Refuge ownership state."
	var empty_equipment := RunEquipmentState.new()
	var equipment_error: String = empty_equipment.initialize_empty(
		battler_catalog,
		run_inventory
	)
	if not equipment_error.is_empty():
		return equipment_error
	refuge_ownership = restored_refuge
	run_equipment = empty_equipment
	return ""


func _make_selected_party_snapshot() -> Dictionary:
	if refuge_ownership == null:
		return {"error": "The Refuge has no selected party.", "party_snapshot": {}}
	var ordered_party: Dictionary = {}
	for heroine_id: StringName in refuge_ownership.selected_party_ids:
		var heroine_value: Variant = party_snapshot.get(
			heroine_id,
			party_snapshot.get(String(heroine_id), null)
		)
		if not (heroine_value is Dictionary):
			return {
				"error": "Selected heroine '%s' has no campaign state." % heroine_id,
				"party_snapshot": {},
			}
		ordered_party[heroine_id] = (heroine_value as Dictionary).duplicate(true)
	return {"error": "", "party_snapshot": ordered_party}


func _make_between_runs_narrative_snapshot() -> Dictionary:
	if narrative_state == null:
		return {}
	var snapshot: Dictionary = narrative_state.to_snapshot()
	var scoped_flags: Dictionary = (
		snapshot.get("flags_by_scope", {}) as Dictionary
	).duplicate(true)
	scoped_flags[&"run"] = {}
	snapshot["flags_by_scope"] = scoped_flags
	snapshot["dialogue_sessions"] = {}
	snapshot["pending_story_requests"] = []
	return snapshot


func _restore_party_hp_mp(
	source: Dictionary,
	battler_catalog: BattlerCatalogDefinition
) -> Dictionary:
	var recovered: Dictionary = {}
	if battler_catalog == null:
		return recovered
	for party_key: Variant in source.keys():
		var heroine_id := StringName(party_key)
		var value: Variant = source[party_key]
		var battler: BattlerDefinition = battler_catalog.get_battler(heroine_id)
		if battler == null or not (value is Dictionary):
			continue
		var heroine_snapshot := (value as Dictionary).duplicate(true)
		heroine_snapshot["hp"] = battler.max_hp
		heroine_snapshot["mp"] = battler.max_mp
		heroine_snapshot["item_guard"] = 0
		recovered[heroine_id] = heroine_snapshot
	return recovered


func _normalize_named_snapshot_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for source_key: Variant in source.keys():
		var value: Variant = source[source_key]
		if value is Dictionary:
			result[StringName(source_key)] = (value as Dictionary).duplicate(true)
	return result


func _is_unrecruited_recruitment_ally_outcome(
	outcome: EncounterOutcome
) -> bool:
	return (
		is_mira_recruitment_encounter_outcome(outcome)
		or is_seraphine_recruitment_encounter_outcome(outcome)
	)


func _has_narrative_flag(
	scope: StringName,
	flag_id: StringName
) -> bool:
	if narrative_state == null:
		return false
	var scoped_flags: Dictionary = (
		narrative_state.flags_by_scope.get(scope, {}) as Dictionary
	)
	return bool(scoped_flags.get(flag_id, false))


func apply_seraphine_recruitment_prelude(
	story_outcome: StoryDialogueOutcome
) -> String:
	if not is_seraphine_recruitment_node_pending():
		return "Seraphine's recruitment node is not pending."
	if story_outcome == null:
		return "Seraphine's recruitment prelude is missing."
	if story_outcome.story_id != SERAPHINE_RECRUITMENT_PRELUDE_STORY_ID:
		return "Story outcome does not match Seraphine's recruitment prelude."
	if story_outcome.source_node_id != pending_node_id:
		return "Seraphine's prelude came from the wrong map node."
	if story_outcome.bloom_delta < 0:
		return "Seraphine's prelude returned negative Bloom."
	if story_outcome.inventory_snapshot.size() != SixSlotInventoryState.SLOT_COUNT:
		return "Seraphine's prelude returned an invalid inventory snapshot."
	var staged_inventory_result: Dictionary = _stage_outcome_run_inventory(
		story_outcome.inventory_snapshot,
		story_outcome.run_inventory_snapshot
	)
	var staged_inventory_error: String = String(
		staged_inventory_result.get("error", "")
	)
	if not staged_inventory_error.is_empty():
		return staged_inventory_error
	if (
		not story_outcome.party_snapshot.has(&"lysandra")
		or not story_outcome.party_snapshot.has(&"mira")
		or story_outcome.party_snapshot.has(&"seraphine")
	):
		return "Seraphine's prelude must preserve Lysandra and Mira without recruiting Seraphine."

	var next_narrative_state := NarrativeState.from_snapshot(
		narrative_state.to_snapshot(),
		DIALOGUE_CATALOG
	)
	for dialogue_snapshot: Dictionary in story_outcome.dialogue_result_snapshots:
		var dialogue_error: String = (
			next_narrative_state.apply_dialogue_result_snapshot(
				dialogue_snapshot,
				DIALOGUE_CATALOG
			)
		)
		if not dialogue_error.is_empty():
			return dialogue_error
	var run_flags: Dictionary = (
		next_narrative_state.flags_by_scope.get(&"run", {}) as Dictionary
	)
	if not bool(run_flags.get(SERAPHINE_PRELUDE_FLAG_ID, false)):
		return "Seraphine's prelude completed without recording the false prayer."

	party_snapshot = story_outcome.party_snapshot.duplicate(true)
	run_inventory = staged_inventory_result.get("state") as RunInventoryState
	narrative_state = next_narrative_state
	bloom += story_outcome.bloom_delta
	run_changed.emit()
	return ""


func apply_seraphine_recruitment_aftermath(
	combat_outcome: EncounterOutcome,
	story_outcome: StoryDialogueOutcome
) -> String:
	if not is_seraphine_recruitment_encounter_outcome(combat_outcome):
		return "Combat outcome does not match Seraphine's recruitment encounter."
	if combat_outcome.result != EncounterOutcome.Result.VICTORY:
		return "Seraphine's recruitment aftermath requires a victory."
	if story_outcome == null:
		return "Seraphine's recruitment aftermath is missing."
	if story_outcome.story_id != SERAPHINE_RECRUITMENT_AFTERMATH_STORY_ID:
		return "Story outcome does not match Seraphine's recruitment aftermath."
	if story_outcome.source_node_id != pending_node_id:
		return "Seraphine's aftermath came from the wrong map node."
	if story_outcome.bloom_delta < 0:
		return "Seraphine's aftermath returned negative Bloom."
	if story_outcome.inventory_snapshot.size() != SixSlotInventoryState.SLOT_COUNT:
		return "Seraphine's aftermath returned an invalid inventory snapshot."
	var staged_inventory_result: Dictionary = _stage_outcome_run_inventory(
		story_outcome.inventory_snapshot,
		story_outcome.run_inventory_snapshot
	)
	var staged_inventory_error: String = String(
		staged_inventory_result.get("error", "")
	)
	if not staged_inventory_error.is_empty():
		return staged_inventory_error
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		if not story_outcome.party_snapshot.has(heroine_id):
			return "Seraphine's aftermath must return all three heroines."

	var next_narrative_state := NarrativeState.from_snapshot(
		narrative_state.to_snapshot(),
		DIALOGUE_CATALOG
	)
	for dialogue_snapshot: Dictionary in story_outcome.dialogue_result_snapshots:
		var dialogue_error: String = (
			next_narrative_state.apply_dialogue_result_snapshot(
				dialogue_snapshot,
				DIALOGUE_CATALOG
			)
		)
		if not dialogue_error.is_empty():
			return dialogue_error
	if not next_narrative_state.recruited_heroine_ids.has(&"seraphine"):
		return "Seraphine's recruitment dialogue completed without recruiting Seraphine."

	party_snapshot = story_outcome.party_snapshot.duplicate(true)
	run_inventory = staged_inventory_result.get("state") as RunInventoryState
	if not combat_outcome.heroine_progression_snapshot.is_empty():
		_merge_heroine_progression_snapshot(
			combat_outcome.heroine_progression_snapshot
		)
	narrative_state = next_narrative_state
	bloom += story_outcome.bloom_delta
	return complete_pending_node(combat_outcome.bloom_reward)


func apply_mira_recruitment_aftermath(
	combat_outcome: EncounterOutcome,
	story_outcome: StoryDialogueOutcome
) -> String:
	if not is_mira_recruitment_encounter_outcome(combat_outcome):
		return "Combat outcome does not match Mira's recruitment encounter."
	if combat_outcome.result != EncounterOutcome.Result.VICTORY:
		return "Mira's recruitment aftermath requires a victory."
	if story_outcome == null:
		return "Mira's recruitment aftermath is missing."
	if story_outcome.story_id != MIRA_RECRUITMENT_STORY_ID:
		return "Story outcome does not match Mira's recruitment aftermath."
	if story_outcome.source_node_id != pending_node_id:
		return "Mira's recruitment story came from the wrong map node."
	if story_outcome.bloom_delta < 0:
		return "Mira's recruitment story returned negative Bloom."
	if (
		story_outcome.inventory_snapshot.size()
		!= SixSlotInventoryState.SLOT_COUNT
	):
		return "Mira's recruitment story returned an invalid inventory snapshot."
	var staged_inventory_result: Dictionary = _stage_outcome_run_inventory(
		story_outcome.inventory_snapshot,
		story_outcome.run_inventory_snapshot
	)
	var staged_inventory_error: String = String(
		staged_inventory_result.get("error", "")
	)
	if not staged_inventory_error.is_empty():
		return staged_inventory_error
	if (
		not story_outcome.party_snapshot.has(&"lysandra")
		or not story_outcome.party_snapshot.has(&"mira")
	):
		return "Mira's recruitment story must return Lysandra and Mira."

	var next_narrative_state := NarrativeState.from_snapshot(
		narrative_state.to_snapshot(),
		DIALOGUE_CATALOG
	)
	for dialogue_snapshot: Dictionary in (
		story_outcome.dialogue_result_snapshots
	):
		var dialogue_error: String = (
			next_narrative_state.apply_dialogue_result_snapshot(
				dialogue_snapshot,
				DIALOGUE_CATALOG
			)
		)
		if not dialogue_error.is_empty():
			return dialogue_error
	if not next_narrative_state.recruited_heroine_ids.has(&"mira"):
		return "Mira's recruitment dialogue completed without recruiting Mira."

	party_snapshot = story_outcome.party_snapshot.duplicate(true)
	run_inventory = staged_inventory_result.get("state") as RunInventoryState
	if not combat_outcome.heroine_progression_snapshot.is_empty():
		_merge_heroine_progression_snapshot(
			combat_outcome.heroine_progression_snapshot
		)
	narrative_state = next_narrative_state
	bloom += story_outcome.bloom_delta
	return complete_pending_node(combat_outcome.bloom_reward)


func _merge_heroine_progression_snapshot(snapshot: Dictionary) -> void:
	for heroine_value: Variant in snapshot.keys():
		var heroine_id := StringName(heroine_value)
		var heroine_snapshot: Dictionary = snapshot.get(
			heroine_value,
			{}
		) as Dictionary
		if heroine_id == &"" or heroine_snapshot.is_empty():
			continue
		heroine_progression_snapshot[heroine_id] = (
			heroine_snapshot.duplicate(true)
		)

func apply_event_room_outcome(
	outcome: EventRoomOutcome
) -> String:
	if outcome == null:
		return "Event room outcome is missing"
		
	if graph == null:
		return "The run has no active layer map"
		
	if outcome.bloom_delta < 0:
		return "Event room outcome has a negative Bloom delta"
		
	if outcome.source_node_id != current_node_id:
		return (
			"Event room outcome does not match"
			+ "the current map node"
		)
	var node: MapNodeState = graph.get_map_node(
		outcome.source_node_id
	)
	if node == null:
		return "The Event room map node no longer exists"
	if not node.requires_event_room():
		return(
			"Map node '%s' is not assigned an Event Room"
			% node.node_id
		)
		
	if (
		outcome.inventory_snapshot.size()
		!= SixSlotInventoryState.SLOT_COUNT
		):
		return "Event room outcome has an invalid inventory snapshot"
	var staged_run_inventory := RunInventoryState.new()
	var inventory_error: String = staged_run_inventory.initialize(
		ITEM_CATALOG,
		DEMO_HEROINE_IDS
	)
	if inventory_error.is_empty():
		inventory_error = staged_run_inventory.restore_from_snapshot(
			run_inventory.get_snapshot()
		)
	if inventory_error.is_empty():
		inventory_error = (
			staged_run_inventory.restore_from_snapshot(
				outcome.run_inventory_snapshot
			)
			if not outcome.run_inventory_snapshot.is_empty()
			else staged_run_inventory.restore_item_bar_snapshot(
				outcome.inventory_snapshot
			)
		)
	if not inventory_error.is_empty():
		return inventory_error

	if outcome.party_snapshot.is_empty():
		return (
			"Event-room outcome has no party snapshot."
		)

	var next_narrative_state := NarrativeState.from_snapshot(
		narrative_state.to_snapshot(),
		DIALOGUE_CATALOG
	)
	for dialogue_snapshot: Dictionary in outcome.dialogue_result_snapshots:
		var dialogue_error: String = (
			next_narrative_state.apply_dialogue_result_snapshot(
				dialogue_snapshot,
				DIALOGUE_CATALOG
			)
		)
		if not dialogue_error.is_empty():
			return dialogue_error

	run_inventory = staged_run_inventory
	party_snapshot = outcome.party_snapshot.duplicate(true)
	narrative_state = next_narrative_state
		
	event_room_snapshots[outcome.source_node_id] = (
		outcome.room_state_snapshot.duplicate(true)
	)
	
	bloom += outcome.bloom_delta
	
	if not outcome.clear_node:
		if pending_node_id == node.node_id:
			return retreat_from_pending_event_room(
				node.node_id
			)

		# This covers revisiting an already-cleared Event room.
		run_changed.emit()
		return ""

	if not node.cleared:
		if pending_node_id != node.node_id:
			return (
				"The uncleared Event room is not "
				+ "the pending map node."
			)

		return complete_pending_node(0)

	run_changed.emit()
	return ""

func retreat_from_pending_event_room(
	node_id: StringName
) -> String:
	if pending_node_id != node_id:
		return (
			"The Event room is not the pending map node."
		)

	if pending_origin_node_id == &"":
		return (
			"The Event room has no recorded entrance node."
		)

	if graph.get_map_node(pending_origin_node_id) == null:
		return (
			"The Event room entrance node no longer exists."
		)

	current_node_id = pending_origin_node_id
	selected_node_id = current_node_id

	pending_node_id = &""
	pending_origin_node_id = &""
	pending_node_seed = 0

	run_changed.emit()
	return ""

func complete_pending_node(
	reward_bloom: int = 0,
	mark_reward_claimed: bool = true
) -> String:
	var node: MapNodeState = graph.get_map_node(pending_node_id)
	if node == null:
		return "There is no pending node to complete."
	if (
		mark_reward_claimed
		and not node.reward_claimed
		and node.reward_source_id != &""
	):
		var reward_result: Dictionary = _resolve_and_route_node_reward(node)
		mark_reward_claimed = bool(reward_result.get("claimed", false))
		var reward_error: String = String(reward_result.get("error", ""))
		if not reward_error.is_empty():
			push_warning(reward_error)
	var was_cleared: bool = node.cleared
	node.cleared = true
	if not was_cleared:
		bloom += maxi(reward_bloom, 0)
	if mark_reward_claimed:
		node.reward_claimed = true
	if node.encounter_id != &"":
		completed_encounters[node.encounter_id] = true
	pending_node_id = &""
	pending_origin_node_id = &""
	pending_node_seed = 0
	run_changed.emit()
	return ""


func resolve_pending_node_reward() -> Dictionary:
	var node: MapNodeState = (
		graph.get_map_node(pending_node_id) if graph != null else null
	)
	if node == null:
		return {"error": "There is no pending node reward to resolve.", "claimed": false}
	if node.reward_source_id == &"":
		return {"error": "Pending node has no authored reward source.", "claimed": false}
	return _resolve_and_route_node_reward(node)


func retry_deferred_reward(node_id: StringName) -> Dictionary:
	var node: MapNodeState = graph.get_map_node(node_id) if graph != null else null
	if node == null:
		return {"error": "Deferred reward node does not exist.", "claimed": false}
	if node.reward_claimed:
		return {"error": "", "claimed": true, "already_claimed": true}
	return _resolve_and_route_node_reward(node)


func _resolve_and_route_node_reward(node: MapNodeState) -> Dictionary:
	if node == null or node.reward_source_id == &"":
		return {"error": "Map node has no authored reward source.", "claimed": false}
	var source: RoomLootSourceDefinition = REWARD_SOURCE_CATALOG.get_source(
		node.reward_source_id
	)
	if source == null:
		return {
			"error": "Unknown reward source '%s'." % node.reward_source_id,
			"claimed": false,
		}
	var record_key: String = RewardSourceResolver.make_record_key(
		source.source_id,
		node.node_id
	)
	var record: Dictionary = {}
	if reward_resolutions.has(record_key):
		var stored_value: Variant = reward_resolutions.get(record_key)
		if not (stored_value is Dictionary):
			return {"error": "Stored reward resolution is malformed.", "claimed": false}
		record = (stored_value as Dictionary).duplicate(true)
		var record_error: String = RewardSourceResolver.validate_resolution_record(
			record,
			REWARD_SOURCE_CATALOG,
			ITEM_CATALOG,
			record_key
		)
		if not record_error.is_empty():
			return {"error": record_error, "claimed": false}
		if bool(record.get("claimed", false)):
			node.reward_claimed = true
			return {"error": "", "claimed": true, "record": record}
	else:
		var resolution: Dictionary = RewardSourceResolver.resolve(
			source,
			ITEM_CATALOG,
			graph.layer_number,
			run_seed,
			node.node_id
		)
		var resolution_error: String = String(resolution.get("error", ""))
		if not resolution_error.is_empty():
			return {"error": resolution_error, "claimed": false}
		record = (resolution.get("record", {}) as Dictionary).duplicate(true)
		reward_resolutions[record_key] = record.duplicate(true)
		print(
			"Reward resolved: source=%s channel=%d binding=%s item=%s quantity=%d seed=%d"
			% [
				record.get("source_id", ""),
				record.get("source_channel", -1),
				record.get("binding_id", ""),
				record.get("item_id", ""),
				record.get("quantity", 0),
				record.get("resolution_seed", 0),
			]
		)
	var item_id := StringName(record.get("item_id", ""))
	var quantity: int = int(record.get("quantity", 0))
	var owner_heroine_id := StringName(record.get("owner_heroine_id", ""))
	var route_error: String = run_inventory.route_reward(
		item_id,
		quantity,
		owner_heroine_id
	)
	if not route_error.is_empty():
		record["claimed"] = false
		record["deferred"] = true
		reward_resolutions[record_key] = record.duplicate(true)
		print(
			"Reward deferred: source=%s binding=%s item=%s quantity=%d reason=%s"
			% [source.source_id, node.node_id, item_id, quantity, route_error]
		)
		run_changed.emit()
		return {
			"error": route_error,
			"claimed": false,
			"deferred": true,
			"record": record,
		}
	record["claimed"] = true
	record["deferred"] = false
	reward_resolutions[record_key] = record.duplicate(true)
	node.reward_claimed = true
	print(
		"Reward claimed: source=%s binding=%s item=%s quantity=%d domain=%s"
		% [
			source.source_id,
			node.node_id,
			item_id,
			quantity,
			run_inventory.get_runtime_domain(item_id),
		]
	)
	run_changed.emit()
	return {"error": "", "claimed": true, "record": record}


func get_run_inventory_snapshot() -> Dictionary:
	return run_inventory.get_snapshot()


func make_run_inventory_snapshot_with_item_bar(
	item_bar_snapshot: Array[Dictionary]
) -> Dictionary:
	var snapshot: Dictionary = run_inventory.get_snapshot()
	snapshot["item_bar_slots"] = item_bar_snapshot.duplicate(true)
	return snapshot


func _stage_outcome_run_inventory(
	item_bar_snapshot: Array[Dictionary],
	complete_snapshot: Dictionary = {}
) -> Dictionary:
	var staged := RunInventoryState.new()
	var staged_error: String = staged.initialize(
		ITEM_CATALOG,
		DEMO_HEROINE_IDS
	)
	if staged_error.is_empty():
		staged_error = staged.restore_from_snapshot(
			run_inventory.get_snapshot()
		)
	if staged_error.is_empty():
		staged_error = (
			staged.restore_from_snapshot(complete_snapshot)
			if not complete_snapshot.is_empty()
			else staged.restore_item_bar_snapshot(item_bar_snapshot)
		)
	if not staged_error.is_empty():
		return {"error": staged_error, "state": null}
	return {"error": "", "state": staged}


func make_active_run_snapshot(
	safe_point_kind: String,
	knowledge_state: KnowledgeState
) -> Dictionary:
	if graph == null or graph.layer_id == &"bloom_refuge" or knowledge_state == null:
		return {}
	if safe_point_kind == "pre_node":
		if pending_node_id == &"" or pending_node_seed <= 0:
			return {}
	elif safe_point_kind == "post_node":
		if pending_node_id != &"" or pending_node_seed != 0:
			return {}
	else:
		return {}
	var completed_layers: Array[String] = []
	for layer_id: StringName in completed_layer_ids:
		completed_layers.append(String(layer_id))
	return {
		"safe_point_kind": safe_point_kind,
		"campaign_seed": campaign_lifecycle.campaign_seed,
		"layer_id": String(graph.layer_id),
		"map_snapshot": {
			"graph": graph.to_snapshot(),
			"current_node_id": String(current_node_id),
			"selected_node_id": String(selected_node_id),
			"pending_node_id": String(pending_node_id),
			"pending_origin_node_id": String(pending_origin_node_id),
			"opening_completed": opening_completed,
		},
		"run_snapshot": {
			"run_seed": run_seed,
			"party_snapshot": party_snapshot.duplicate(true),
			"run_inventory": run_inventory.get_snapshot(),
			"run_equipment": run_equipment.get_snapshot(),
			"heroine_progression_snapshot": heroine_progression_snapshot.duplicate(true),
			"bloom": bloom,
			"completed_encounters": completed_encounters.duplicate(true),
			"event_room_snapshots": event_room_snapshots.duplicate(true),
			"generated_room_item_requests": generated_room_item_requests.duplicate(true),
			"reward_resolutions": reward_resolutions.duplicate(true),
			"narrative_state": narrative_state.to_snapshot(),
			"completed_layer_ids": completed_layers,
			"campaign_lifecycle": campaign_lifecycle.to_snapshot(),
			"knowledge_state": knowledge_state.to_snapshot(),
			"refuge_boundary_snapshot": active_run_refuge_boundary_snapshot.duplicate(true),
		},
		"selected_node_id": String(pending_node_id) if safe_point_kind == "pre_node" else null,
		"selected_node_seed": pending_node_seed if safe_point_kind == "pre_node" else null,
	}


func restore_active_run_snapshot(
	snapshot: Dictionary,
	battler_catalog: BattlerCatalogDefinition
) -> String:
	var staged_snapshot: Dictionary = snapshot.duplicate(true)
	var kind: String = String(staged_snapshot.get("safe_point_kind", ""))
	var map_value: Variant = staged_snapshot.get("map_snapshot", null)
	var run_value: Variant = staged_snapshot.get("run_snapshot", null)
	if kind not in ["pre_node", "post_node"]:
		return "Active-run snapshot has an invalid safe_point_kind."
	if not (map_value is Dictionary) or not (run_value is Dictionary):
		return "Active-run snapshot requires map_snapshot and run_snapshot Dictionaries."
	var map_snapshot: Dictionary = map_value as Dictionary
	if typeof(map_snapshot.get("opening_completed", null)) != TYPE_BOOL:
		return "Active-run snapshot contains invalid opening completion state."
	var graph_value: Variant = map_snapshot.get("graph", null)
	if not (graph_value is Dictionary):
		return "Active-run snapshot contains an invalid generated map."
	var graph_result: Dictionary = LayerMapGraph.from_snapshot(graph_value as Dictionary)
	var graph_error: String = String(graph_result.get("error", ""))
	if not graph_error.is_empty():
		return graph_error
	var restored_graph: LayerMapGraph = graph_result.get("graph") as LayerMapGraph
	if StringName(staged_snapshot.get("layer_id", "")) != restored_graph.layer_id:
		return "Active-run snapshot layer_id does not match its map."
	var restored_current := StringName(map_snapshot.get("current_node_id", ""))
	var restored_selected := StringName(map_snapshot.get("selected_node_id", ""))
	var restored_pending := StringName(map_snapshot.get("pending_node_id", ""))
	var restored_origin := StringName(map_snapshot.get("pending_origin_node_id", ""))
	for node_id: StringName in [restored_current, restored_selected]:
		if node_id == &"" or restored_graph.get_map_node(node_id) == null:
			return "Active-run snapshot refers to a missing current or selected node."
	if restored_pending != &"" and restored_graph.get_map_node(restored_pending) == null:
		return "Active-run snapshot refers to a missing pending node."
	if restored_origin != &"" and restored_graph.get_map_node(restored_origin) == null:
		return "Active-run snapshot refers to a missing pending origin."
	var selected_value: Variant = staged_snapshot.get("selected_node_id", null)
	var seed_value: Variant = staged_snapshot.get("selected_node_seed", null)
	if kind == "pre_node":
		if (
			restored_pending == &""
			or restored_origin == &""
			or restored_current != restored_pending
			or restored_selected != restored_pending
			or not (selected_value is String or selected_value is StringName)
			or StringName(selected_value) != restored_pending
			or typeof(seed_value) not in [TYPE_INT, TYPE_FLOAT]
			or float(seed_value) != floorf(float(seed_value))
			or int(seed_value) <= 0
		):
			return "Pre-node snapshot requires matching node and positive content seed."
	else:
		if (
			restored_pending != &""
			or restored_origin != &""
			or selected_value != null
			or seed_value != null
		):
			return "Post-node snapshot cannot retain an unresolved node."

	var run_snapshot: Dictionary = run_value as Dictionary
	var restored_run_seed: int = int(run_snapshot.get("run_seed", 0))
	if restored_run_seed <= 0 or restored_run_seed != restored_graph.run_seed:
		return "Active-run snapshot has an invalid run seed."
	for field_name: String in [
		"party_snapshot", "run_inventory", "run_equipment",
		"heroine_progression_snapshot", "completed_encounters",
		"event_room_snapshots", "generated_room_item_requests",
		"narrative_state", "campaign_lifecycle", "knowledge_state",
		"refuge_boundary_snapshot",
	]:
		if not (run_snapshot.get(field_name, null) is Dictionary):
			return "Active-run snapshot contains invalid %s." % field_name
	var restored_party_snapshot: Dictionary = (
		run_snapshot.get("party_snapshot") as Dictionary
	)
	if restored_party_snapshot.is_empty():
		return "Active-run snapshot requires at least one party member."
	for battler_value: Variant in restored_party_snapshot.values():
		if not (battler_value is Dictionary):
			return "Active-run snapshot contains invalid party state."
	if not (run_snapshot.get("completed_layer_ids", null) is Array):
		return "Active-run snapshot contains invalid completed_layer_ids."
	var restored_lifecycle := CampaignLifecycleState.new()
	var lifecycle_error: String = restored_lifecycle.restore_from_snapshot(
		(run_snapshot.get("campaign_lifecycle") as Dictionary).duplicate(true)
	)
	if not lifecycle_error.is_empty():
		return lifecycle_error
	if (
		int(staged_snapshot.get("campaign_seed", 0)) <= 0
		or int(staged_snapshot.get("campaign_seed")) != restored_lifecycle.campaign_seed
	):
		return "Active-run snapshot campaign_seed does not match its lifecycle."
	var restored_inventory := RunInventoryState.new()
	var inventory_error: String = restored_inventory.initialize(ITEM_CATALOG, DEMO_HEROINE_IDS)
	if inventory_error.is_empty():
		inventory_error = restored_inventory.restore_from_snapshot(
			(run_snapshot.get("run_inventory") as Dictionary).duplicate(true)
		)
	if not inventory_error.is_empty():
		return inventory_error
	var restored_equipment := RunEquipmentState.new()
	var equipment_error: String = restored_equipment.initialize_from_snapshot(
		battler_catalog,
		DEMO_HEROINE_IDS,
		restored_inventory,
		(run_snapshot.get("run_equipment") as Dictionary).duplicate(true)
	)
	if not equipment_error.is_empty():
		return equipment_error
	var restored_narrative := NarrativeState.new()
	var narrative_error: String = restored_narrative.restore_from_snapshot(
		(run_snapshot.get("narrative_state") as Dictionary).duplicate(true),
		DIALOGUE_CATALOG
	)
	if not narrative_error.is_empty():
		return narrative_error
	var boundary_snapshot: Dictionary = (
		run_snapshot.get("refuge_boundary_snapshot") as Dictionary
	).duplicate(true)
	var restored_refuge := RefugeOwnershipState.new()
	if not boundary_snapshot.is_empty():
		var refuge_error: String = restored_refuge.restore_from_snapshot(
			boundary_snapshot, ITEM_CATALOG, battler_catalog, DEMO_HEROINE_IDS
		)
		if not refuge_error.is_empty():
			return refuge_error
		var transfer: Dictionary = restored_refuge.make_run_start_transfer()
		refuge_error = String(transfer.get("error", ""))
		if not refuge_error.is_empty():
			return refuge_error
		restored_refuge = transfer.get("refuge_state") as RefugeOwnershipState
	elif restored_lifecycle.has_refuge() and restored_lifecycle.active_run_seed > 0:
		return "Active Refuge run is missing its ownership boundary."

	var restored_completed: Dictionary = {}
	for entry_key: Variant in (run_snapshot.get("completed_encounters") as Dictionary).keys():
		var entry_value: Variant = (run_snapshot.get("completed_encounters") as Dictionary)[entry_key]
		if typeof(entry_value) != TYPE_BOOL:
			return "Active-run snapshot contains invalid encounter completion state."
		restored_completed[StringName(entry_key)] = bool(entry_value)
	var restored_rooms: Dictionary = {}
	for entry_key: Variant in (run_snapshot.get("event_room_snapshots") as Dictionary).keys():
		var entry_value: Variant = (run_snapshot.get("event_room_snapshots") as Dictionary)[entry_key]
		if not (entry_value is Dictionary):
			return "Active-run snapshot contains invalid Event-room state."
		var room_snapshot: Dictionary = (entry_value as Dictionary).duplicate(true)
		var local_state_value: Variant = room_snapshot.get("local_state", {})
		if not (local_state_value is Dictionary):
			return "Active-run snapshot contains invalid Event-room local state."
		var item_spawns_value: Variant = (local_state_value as Dictionary).get(
			"item_spawns",
			[]
		)
		if not (item_spawns_value is Array):
			return "Active-run snapshot contains invalid Event-room item spawns."
		for assignment_value: Variant in item_spawns_value as Array:
			if not (assignment_value is Dictionary):
				return "Active-run snapshot contains an invalid Event-room item assignment."
			var assignment: Dictionary = assignment_value as Dictionary
			if not assignment.has("resolution_seed"):
				continue
			var assignment_error: String = (
				RewardSourceResolver.validate_resolution_record(
					assignment,
					REWARD_SOURCE_CATALOG,
					ITEM_CATALOG
				)
			)
			if not assignment_error.is_empty():
				return assignment_error
			var room_node_id: String = String(room_snapshot.get("source_node_id", ""))
			var binding_id: String = String(assignment.get("binding_id", ""))
			if binding_id != room_node_id and not binding_id.begins_with(
				"%s:" % room_node_id
			):
				return "Event-room reward resolution does not match its generated node."
			if bool(assignment.get("claimed", false)) != bool(
				assignment.get("collected", false)
			):
				return "Event-room reward claim state does not match collection state."
			var expected_seed_input: int = int(
				room_snapshot.get("generation_seed", 0)
			)
			if binding_id == room_node_id:
				expected_seed_input = restored_run_seed
			if int(assignment.get("resolution_seed", 0)) != (
				RewardSourceResolver.make_seed(
					expected_seed_input,
					StringName(assignment.get("source_id", "")),
					StringName(binding_id)
				)
			):
				return "Event-room reward resolution has an invalid deterministic seed."
		restored_rooms[StringName(entry_key)] = room_snapshot
	var restored_generated_requests: Dictionary = {}
	for node_key: Variant in (run_snapshot.get("generated_room_item_requests") as Dictionary).keys():
		var requests_value: Variant = (
			(run_snapshot.get("generated_room_item_requests") as Dictionary)[node_key]
		)
		if not (requests_value is Array):
			return "Active-run snapshot contains invalid generated item requests."
		var restored_requests: Array = []
		for request_value: Variant in requests_value as Array:
			if not (request_value is Dictionary):
				return "Active-run snapshot contains an invalid generated item request."
			var request: Dictionary = (request_value as Dictionary).duplicate(true)
			if request.has("resolution_seed"):
				var request_error: String = (
					RewardSourceResolver.validate_resolution_record(
						request,
						REWARD_SOURCE_CATALOG,
						ITEM_CATALOG
					)
				)
				if not request_error.is_empty():
					return request_error
				if StringName(request.get("binding_id", "")) != StringName(node_key):
					return "Generated reward resolution does not match its host node."
				if int(request.get("resolution_seed", 0)) != (
					RewardSourceResolver.make_seed(
						restored_run_seed,
						StringName(request.get("source_id", "")),
						StringName(node_key)
					)
				):
					return "Generated reward resolution has an invalid deterministic seed."
			restored_requests.append(request)
		restored_generated_requests[StringName(node_key)] = restored_requests
	var reward_resolutions_value: Variant = run_snapshot.get(
		"reward_resolutions",
		{}
	)
	if not (reward_resolutions_value is Dictionary):
		return "Active-run snapshot contains invalid reward_resolutions."
	var restored_reward_resolutions: Dictionary = {}
	for record_key_value: Variant in (reward_resolutions_value as Dictionary).keys():
		if not (record_key_value is String or record_key_value is StringName):
			return "Active-run snapshot contains an invalid reward resolution key."
		var record_key: String = String(record_key_value)
		var record_value: Variant = (
			(reward_resolutions_value as Dictionary).get(record_key_value)
		)
		if not (record_value is Dictionary):
			return "Active-run snapshot contains an invalid reward resolution record."
		var record: Dictionary = (record_value as Dictionary).duplicate(true)
		var record_error: String = RewardSourceResolver.validate_resolution_record(
			record,
			REWARD_SOURCE_CATALOG,
			ITEM_CATALOG,
			record_key
		)
		if not record_error.is_empty():
			return record_error
		if int(record.get("resolution_seed", 0)) != (
			RewardSourceResolver.make_seed(
				restored_run_seed,
				StringName(record.get("source_id", "")),
				StringName(record.get("binding_id", ""))
			)
		):
			return "Active-run reward resolution has an invalid deterministic seed."
		var reward_node: MapNodeState = restored_graph.get_map_node(
			StringName(record.get("binding_id", ""))
		)
		if (
			reward_node == null
			or reward_node.reward_source_id
			!= StringName(record.get("source_id", ""))
		):
			return "Active-run reward resolution does not match its map node."
		if (
			bool(record.get("claimed", false)) != reward_node.reward_claimed
			or (
				bool(record.get("deferred", false))
				and not reward_node.cleared
			)
		):
			return "Active-run reward claim state does not match its map node."
		restored_reward_resolutions[record_key] = record
	var restored_layers: Array[StringName] = []
	for layer_value: Variant in run_snapshot.get("completed_layer_ids") as Array:
		if not (layer_value is String or layer_value is StringName):
			return "Active-run snapshot contains an invalid completed layer ID."
		var layer_id := StringName(layer_value)
		if layer_id != &"" and not restored_layers.has(layer_id):
			restored_layers.append(layer_id)

	# Commit only after every nested state model validates successfully.
	run_seed = restored_run_seed
	graph = restored_graph
	current_node_id = restored_current
	selected_node_id = restored_selected
	pending_node_id = restored_pending
	pending_origin_node_id = restored_origin
	pending_node_seed = int(seed_value) if kind == "pre_node" else 0
	party_snapshot = restored_party_snapshot.duplicate(true)
	run_inventory = restored_inventory
	run_equipment = restored_equipment
	heroine_progression_snapshot = (
		run_snapshot.get("heroine_progression_snapshot") as Dictionary
	).duplicate(true)
	bloom = maxi(int(run_snapshot.get("bloom", 0)), 0)
	completed_encounters = restored_completed
	event_room_snapshots = restored_rooms
	generated_room_item_requests = restored_generated_requests
	reward_resolutions = restored_reward_resolutions
	opening_completed = bool(map_snapshot.get("opening_completed", false))
	narrative_state = restored_narrative
	completed_layer_ids = restored_layers
	campaign_lifecycle = restored_lifecycle
	refuge_ownership = restored_refuge
	active_run_refuge_boundary_snapshot = boundary_snapshot
	archived_layer_graphs.clear()
	run_changed.emit()
	return ""


func get_progress_text() -> String:
	var visited_count: int = 0
	var cleared_count: int = 0
	for value: Variant in graph.nodes.values():
		var node: MapNodeState = value as MapNodeState
		visited_count += 1 if node.visited else 0
		cleared_count += 1 if node.cleared else 0
	var opening_text: String = (
		"Opening cleared"
		if opening_completed
		else "Opening battle pending"
	)
	return "Layer %d  |  %s  |  Map seed %d  |  %s  |  Visited %d/%d  |  Cleared %d  |  Bloom %d" % [
		graph.layer_number,
		get_campaign_mode_id(),
		run_seed,
		opening_text,
		visited_count,
		graph.nodes.size(),
		cleared_count,
		bloom,
	]
