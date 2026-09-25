class_name DiceRoller
extends Node


## Reusable scene-facing wrapper around the deterministic RAV DiceResolver.
## Combat rules receive the resolver itself; UI and test scenes may use the
## neutral roll_check API without constructing combat controllers.
var resolver: DiceResolver = DiceResolver.new()


func roll_check(
	dice_count: int,
	skill_level: int,
	skill_tier: SkillEntry.Tier,
	seed_value: int,
	forced_rolls: Array[int] = []
) -> RollResult:
	return resolver.roll_check(
		dice_count,
		skill_level,
		skill_tier,
		seed_value,
		forced_rolls
	)


func reset() -> void:
	resolver = DiceResolver.new()
