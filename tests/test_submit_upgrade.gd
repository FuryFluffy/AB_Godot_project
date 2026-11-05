extends "res://tests/test_grapple_foundation.gd"
var checks: int = 0

func _init() -> void:
	_test_submit_gates()
	_test_submit_recovery()
	_test_enemy_climax_and_defeated_healing()
	_test_secondary_succession()
	print("Stage 22 Submit upgrade: %d checks, %d failures." % [checks,failures])
	quit(failures)

func check(ok: bool, message: String) -> void:
	checks += 1
	_expect(ok,message)

func _attached() -> Dictionary:
	var fixture: Dictionary = _make_fixture()
	fixture.controller.prepare_initiation(&"hollow_servant",&"lysandra")
	check(fixture.controller.resolve_initiation(false).succeeded,"Real Grapple established")
	return fixture

func _test_submit_gates() -> void:
	var fixture: Dictionary = _attached()
	var controller: GrappleController = fixture.controller
	var heroine: BattlerState = fixture.battlers[&"lysandra"]
	var track: GrappleTrackState = controller.get_main_track_for_heroine(&"lysandra")
	var engine := CombatEngine.new()
	engine.is_initialized = true
	engine.grapple_controller = controller
	engine.battle_runtime = BattleRuntimeState.new()
	engine.battle_runtime.battle_state.encounter_started = true
	engine.battle_runtime.battle_state.phase = BattleState.Phase.HERO
	heroine.set_current_actions(3)
	check(not engine.submit(&"lysandra").succeeded and track.stage_index == 0 and heroine.current_actions == 3,"Locked Submit consumes nothing")
	controller.submit_unlocked = true
	engine.submit_unlocked = true
	check(engine.can_submit(&"lysandra"),"Unlocked eligible heroine may Submit")
	engine.battle_runtime.battle_state.phase = BattleState.Phase.ENEMY
	check(not engine.submit(&"lysandra").succeeded and heroine.current_actions == 3,"Enemy Phase rejects Submit")
	engine.battle_runtime.battle_state.phase = BattleState.Phase.HERO
	engine.battle_runtime.is_selecting_item_target = true
	check(not engine.submit(&"lysandra").succeeded,"Pending targeting blocks Submit")
	engine.battle_runtime.is_selecting_item_target = false
	heroine.set_current_actions(0)
	check(not engine.submit(&"lysandra").succeeded,"Zero Actions reject")
	heroine.set_current_actions(1)
	heroine.active_statuses.append(StatusInstance.new(preload("res://data/statuses/stunned.tres")))
	check(not engine.submit(&"lysandra").succeeded,"Stun rejects")
	heroine.active_statuses.clear()
	heroine.is_defeated = true
	check(not engine.submit(&"lysandra").succeeded,"Defeated heroine cannot Submit")
	heroine.is_defeated = false
	check(not engine.submit(&"mira").succeeded and not engine.submit(&"hollow_servant").succeeded,"No track and non-heroine reject")
	var enemy_actions: int = fixture.battlers[&"hollow_servant"].current_actions
	var result: GrappleActionResult = engine.submit(&"lysandra")
	check(result.succeeded and result.actions_spent == 1 and heroine.current_actions == 0 and track.stage_index == 1,"One remaining Action pays all remaining Actions and advances main track")
	check(fixture.battlers[&"hollow_servant"].current_actions == enemy_actions,"Submit never spends the enemy's Actions")
	check(engine.battle_runtime.battle_state.phase == BattleState.Phase.HERO,"Submit does not end Hero Phase")
	engine.free()

func _test_submit_recovery() -> void:
	for missing_hp: int in [0,1,2,3]:
		var fixture: Dictionary = _attached()
		var controller: GrappleController = fixture.controller
		controller.submit_unlocked = true
		var heroine: BattlerState = fixture.battlers[&"lysandra"]
		var enemy: BattlerState = fixture.battlers[&"hollow_servant"]
		var track: GrappleTrackState = controller.get_main_track_for_heroine(&"lysandra")
		track.stage_index = 1
		heroine.current_hp = heroine.get_max_hp()-missing_hp
		heroine.current_mp = 0
		heroine.set_current_actions(2)
		var hp: int = heroine.current_hp
		var enemy_hp: int = enemy.current_hp
		var corruption: int = heroine.current_corruption
		var resolve: int = heroine.current_resolve
		var result: GrappleActionResult = controller.submit(&"lysandra")
		check(result.succeeded and result.climax_reached and result.detached and not heroine.is_grappled(),"Submit reaches Climax and releases track")
		check(heroine.current_hp == mini(hp+3,heroine.get_max_hp()) and heroine.current_mp == mini(3-missing_hp,heroine.get_max_mp()),"Separate 1+2 recovery fills HP then MP with exact overflow")
		check(enemy.current_hp == enemy_hp-maxi(ceili(enemy.get_max_hp()*0.25),1),"Approved level-1 Climax applies 25 percent damage")
		check(heroine.current_corruption == corruption+5 and heroine.current_resolve == resolve-5,"Reached main stage effects occur exactly once")
		check(enemy.grapple_cooldown_activations > 0 and heroine.current_actions == 0,"Climax retains cooldown and Action semantics")

func _test_enemy_climax_and_defeated_healing() -> void:
	for upgraded: bool in [false,true]:
		var fixture: Dictionary = _attached()
		var controller: GrappleController = fixture.controller
		controller.submit_unlocked = upgraded
		var heroine: BattlerState = fixture.battlers[&"lysandra"]
		var enemy: BattlerState = fixture.battlers[&"hollow_servant"]
		controller.get_main_track_for_heroine(&"lysandra").stage_index = 1
		heroine.current_hp = 0
		heroine.is_defeated = true
		heroine.current_mp = 0
		enemy.set_current_actions(3)
		var hp: int = enemy.current_hp
		var result: GrappleActionResult = controller.progress_track(&"hollow_servant")
		check(result.climax_reached and enemy.current_hp == hp-maxi(ceili(enemy.get_max_hp()*(0.25 if upgraded else 0.15)),1),"Enemy-driven Climax follows campaign upgrade without requiring Submit")
		check(heroine.current_hp == (2 if upgraded else 0) and heroine.is_defeated,"Upgrade recovery may increase stored HP but never revives")
		check(not controller.can_submit(&"lysandra"),"Recovered defeated heroine cannot act")


func _test_secondary_succession() -> void:
	var fixture: Dictionary = _attached()
	var controller: GrappleController = fixture.controller
	controller.submit_unlocked = true
	var heroine: BattlerState = fixture.battlers[&"lysandra"]
	var main: GrappleTrackState = controller.get_main_track_for_heroine(&"lysandra")
	heroine.change_corruption(30-heroine.current_corruption)
	var attached: GrappleActionResult = controller.attach_secondary(&"knife_footman",&"lysandra",main.template,true)
	check(attached.succeeded,"Secondary authored track attaches")
	var secondary: GrappleTrackState = attached.track
	main.stage_index = 1
	heroine.current_hp = heroine.get_max_hp()
	heroine.current_mp = heroine.get_max_mp()
	heroine.set_current_actions(3)
	var corruption: int = heroine.current_corruption
	var resolve: int = heroine.current_resolve
	var result: GrappleActionResult = controller.submit(&"lysandra")
	check(result.succeeded and result.climax_reached and controller.get_main_track_for_heroine(&"lysandra") == secondary,"Submit resolves only main track and promotes existing successor")
	check(secondary.stage_index == 0 and heroine.is_grappled() and heroine.current_corruption == corruption+5 and heroine.current_resolve == resolve-5,"Successor is not advanced or charged extra stage effects")
	check(heroine.current_hp == heroine.get_max_hp() and heroine.current_mp == heroine.get_max_mp() and result.hp_restored == 0 and result.mp_restored == 0,"Excess recovery is discarded at full HP/MP")
