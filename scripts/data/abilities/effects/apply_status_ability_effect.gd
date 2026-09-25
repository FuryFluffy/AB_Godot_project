class_name ApplyStatusAbilityEffect
extends AbilityEffectDefinition


@export_group("Status")
@export var status: StatusDefinition
@export_range(-1, 99, 1) var damage_override: int = -1
@export_range(-1, 10, 1) var tick_override: int = -1
@export var status_is_magical: bool = false
@export var status_is_dispellable: bool = false

@export_group("Hostile Resistance")
@export var requires_opposed_check: bool = false
@export var casting_skill: SkillEntry.Skill = SkillEntry.Skill.EARTH
@export var casting_attribute: AttributeSet.Attribute = (
	AttributeSet.Attribute.PERSONALITY
)
@export_range(-10, 10, 1) var casting_dice_modifier: int = 0
@export var resistance_skill: SkillEntry.Skill = SkillEntry.Skill.ATHLETICS
@export var resistance_attribute: AttributeSet.Attribute = (
	AttributeSet.Attribute.ENDURANCE
)
@export_range(-10, 10, 1) var resistance_dice_modifier: int = 0
