class_name RecipeProductionProvider
extends RefCounted
## Explicit input/output boundary. A provider must stage and publish atomically;
## the caller owns persistence. Unbound/unsupported contexts fail closed.
var item_catalog: ItemCatalogDefinition
var material_catalog: MaterialCatalogDefinition

func fork() -> RecipeProductionProvider:
	return null

func material_quantity(_id: StringName) -> int:
	return 0

func consume_material(_id: StringName, _quantity: int) -> String:
	return "Production input storage is unavailable."

func store_output(_id: StringName, _quantity: int) -> String:
	return "Production output storage is unavailable."

func publish(_staged: RecipeProductionProvider) -> String:
	return "Production storage is unavailable."
