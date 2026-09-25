class_name CombatEngine
extends Node


signal initialized


@onready var dice_roller: DiceRoller = $DiceRoller

var battler_states: Dictionary = {}
var stable_battler_order: Array[StringName] = []

var battle_bootstrap: BattleBootstrap
var battle_runtime: BattleRuntimeState
var battle_flow_controller: BattleFlowController
var action_controller: BattleActionController
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
var reaction_exchange_controller: ReactionExchangeController

var is_initialized: bool = false


func initialize(
	battler_definitions: Array[BattlerDefinition],
	ordered_battler_ids: Array[StringName],
	battlefield_definition: BattlefieldDefinition,
	enemy_group_rulebook: EnemyGroupRulebookDefinition,
	item_catalog: ItemCatalogDefinition,
	base_seed: int,
	initial_item_ids: Array[StringName],
	initial_item_quantities: Array[int],
	heroine_progression_snapshots: Dictionary = {},
	run_equipment: RunEquipmentState = null
) -> String:
	_reset_systems()

	stable_battler_order = ordered_battler_ids.duplicate()
	battler_states = battle_bootstrap.create_battler_states(
		battler_definitions,
		heroine_progression_snapshots,
		run_equipment
	)

	var spatial_error: String = battlefield_state.initialize(
		battlefield_definition,
		battler_states
	)
	if not spatial_error.is_empty():
		return spatial_error

	battle_flow_controller.initialize(
		battler_states,
		battle_runtime.battle_state,
		dice_roller.resolver,
		base_seed + 1000
	)
	movement_controller.initialize(
		battler_states,
		battlefield_state,
		battle_flow_controller,
		battle_runtime
	)
	targeting_controller.initialize(
		battler_states,
		battlefield_state
	)
	grapple_controller.initialize(
		battler_states,
		battlefield_state,
		targeting_controller,
		dice_roller.resolver,
		base_seed + 4000
	)
	status_controller.initialize(
		battler_states,
		stable_battler_order
	)
	attack_resolver.status_controller = status_controller
	action_controller.initialize(
		battler_states,
		battle_runtime,
		attack_resolver,
		battle_flow_controller,
		base_seed,
		targeting_controller
	)
	aoe_controller.initialize(
		battler_states,
		stable_battler_order,
		battle_runtime,
		battlefield_state,
		battle_flow_controller,
		attack_resolver,
		base_seed + 2000
	)
	ability_controller.initialize(
		battler_states,
		battle_runtime,
		battle_flow_controller,
		battlefield_state,
		targeting_controller,
		attack_resolver,
		status_controller,
		dice_roller.resolver,
		base_seed + 2500
	)
	lifecycle_controller.initialize(
		battler_states,
		stable_battler_order,
		battle_runtime.battle_state,
		battle_runtime,
		battlefield_state,
		status_controller,
		grapple_controller
	)
	enemy_ai_controller.initialize(
		battler_states,
		battle_runtime.battle_state,
		battlefield_state,
		movement_controller,
		targeting_controller,
		grapple_controller,
		enemy_group_rulebook,
		base_seed + 3000
	)

	var inventory_error: String = item_inventory.initialize(item_catalog)
	if inventory_error.is_empty():
		inventory_error = item_inventory.load_items(
			initial_item_ids,
			initial_item_quantities
		)
	if not inventory_error.is_empty():
		return inventory_error

	item_use_controller.initialize(
		battler_states,
		item_inventory,
		battle_runtime,
		battle_flow_controller,
		battlefield_state,
		targeting_controller,
		attack_resolver,
		status_controller,
		grapple_controller,
		lifecycle_controller,
		base_seed + 5000
	)
	dodge_step_controller.initialize(
		battler_states,
		battlefield_state
	)
	reaction_exchange_controller.initialize(
		action_controller,
		battle_runtime
	)

	is_initialized = true
	initialized.emit()
	return ""


func capture_inventory_checkpoint() -> void:
	if item_inventory != null:
		item_inventory.capture_checkpoint()


func get_battler_state(battler_id: StringName) -> BattlerState:
	return battler_states.get(battler_id) as BattlerState


func _reset_systems() -> void:
	is_initialized = false
	if dice_roller != null:
		dice_roller.reset()

	battle_bootstrap = BattleBootstrap.new()
	battle_runtime = BattleRuntimeState.new()
	battle_flow_controller = BattleFlowController.new()
	action_controller = BattleActionController.new()
	attack_resolver = AttackResolver.new()
	battlefield_state = BattlefieldState.new()
	movement_controller = BattleMovementController.new()
	targeting_controller = BattleTargetingController.new()
	enemy_ai_controller = EnemyAIController.new()
	status_controller = StatusController.new()
	aoe_controller = AoeActionController.new()
	ability_controller = AbilityActionController.new()
	lifecycle_controller = BattleLifecycleController.new()
	grapple_controller = GrappleController.new()
	item_inventory = SixSlotInventoryState.new()
	item_use_controller = ItemUseController.new()
	dodge_step_controller = DodgeStepController.new()
	reaction_exchange_controller = ReactionExchangeController.new()
