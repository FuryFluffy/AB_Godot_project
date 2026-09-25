class_name HealAbilityEffect
extends AbilityEffectDefinition


@export_group("Healing")
@export_range(0, 99, 1) var fixed_amount: int = 0
@export var uses_check_successes: bool = false
@export_range(0, 99, 1) var minimum_amount: int = 0

@export_group("Healing Check")
@export var skill: SkillEntry.Skill = SkillEntry.Skill.BODY
@export var attribute: AttributeSet.Attribute = (
	AttributeSet.Attribute.PERSONALITY
)
@export_range(-10, 10, 1) var dice_modifier: int = 0

