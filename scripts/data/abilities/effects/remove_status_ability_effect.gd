class_name RemoveStatusAbilityEffect
extends AbilityEffectDefinition


enum RemovalMode {
	ONE_STATUS_KIND,
	ONE_REMOVABLE_MAGIC_EFFECT,
}


@export_group("Removal")
@export var removal_mode: RemovalMode = RemovalMode.ONE_STATUS_KIND
@export var status_kind: StatusDefinition.Kind = StatusDefinition.Kind.POISON

