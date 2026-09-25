class_name SkillRules
extends RefCounted

static func get_budget(
	skill_level: int,
	skill_tier: SkillEntry.Tier
) -> int:
	if skill_level <= 0:
		return 0
		
	match skill_tier:
		SkillEntry.Tier.UNTRAINED:
			return 0
			
		SkillEntry.Tier.NOVICE:
			return int(ceil(float(skill_level) / 2.0))
			
		SkillEntry.Tier.EXPERT:
			return skill_level
			
		SkillEntry.Tier.MASTER:
			return skill_level
			
		SkillEntry.Tier.GRAND_MASTER:
			return skill_level
				
	push_error("Unknown Skill tier: %s" % skill_tier)
	return 0
		
static func get_target_limit(
	skill_tier: SkillEntry.Tier
) -> int:
	match skill_tier:
		SkillEntry.Tier.UNTRAINED:
			return 0
			
		SkillEntry.Tier.NOVICE:
			return 1
			
		SkillEntry.Tier.EXPERT:
			return 1
			
		SkillEntry.Tier.MASTER:
			return 2
			
		SkillEntry.Tier.GRAND_MASTER:
			return -1
			
	push_error("Unknown skill tier: %s" % skill_tier)
	return 0
