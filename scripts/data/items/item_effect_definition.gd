class_name ItemEffectDefinition
extends Resource


enum Kind {
	HEAL_HP,
	RESTORE_MP,
	RESTORE_ACTIONS,
	CHANGE_RESOLVE,
	CHANGE_CORRUPTION,
	REMOVE_STATUS,
	REVIVE,
	REPAIR_WEAPON,
	REPAIR_ARMOR,
	REPAIR_SHIELD,
	ADD_GUARD,
	DAMAGE_WEAPON,
	DAMAGE_ARMOR,
	DAMAGE_SHIELD,
	GRAPPLE_REDUCE_STAGE,
	GRAPPLE_DETACH,
}


enum Recipient {
	TARGET,
	ACTOR,
}


@export var kind: Kind = Kind.HEAL_HP
@export var recipient: Recipient = Recipient.TARGET
@export_range(-100, 100, 1) var amount: int = 0
@export var status_kind: StatusDefinition.Kind = (
	StatusDefinition.Kind.BLEED
)

