class_name AttributeSet
extends Resource

enum Attribute {
	MIGHT,
	AGILITY,
	ENDURANCE,
	INTELLECT,
	PERSONALITY,
}

@export_range(0, 10 ,1) var might: int = 1
@export_range(0, 10 ,1) var agility: int = 1
@export_range(0, 10 ,1) var endurance: int = 1
@export_range(0, 10 ,1) var intellect: int = 1
@export_range(0, 10 ,1) var personality: int = 1

func get_value(attribute: Attribute) -> int:
	match attribute:
		Attribute.MIGHT:
			return might
		Attribute.AGILITY:
			return agility
		Attribute.ENDURANCE:
			return endurance
		Attribute.INTELLECT:
			return intellect
		Attribute.PERSONALITY:
			return personality
		_:
			push_error("Unknown attribute: %s" % attribute)
	return 0
