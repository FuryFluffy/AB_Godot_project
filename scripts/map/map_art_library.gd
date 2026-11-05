extends RefCounted
## Paths, including shared Intel/trap aliases, come from the supplied revision-2 manifest.
const ROOT: String = "res://assets/map/revision_2/"
static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	return _manifest

static func texture(group: String, key: String = "") -> Texture2D:
	var entry: Variant = manifest().get(group)
	var path: String = String(entry.get(key, "")) if entry is Dictionary else String(entry)
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = load(ROOT + path)
	return _textures[path] as Texture2D

static func node_key(node: MapNodeState) -> String:
	if not node.type_known:
		return "unknown"
	return {
		MapNodeState.NodeType.START: "start",
		MapNodeState.NodeType.ROOM: "exploration",
		MapNodeState.NodeType.EVENT: "exploration",
		MapNodeState.NodeType.ITEM: "exploration",
		MapNodeState.NodeType.BATTLE: "normal_combat",
		MapNodeState.NodeType.ELITE: "elite_combat",
		MapNodeState.NodeType.BOSS: "boss_provisional",
		MapNodeState.NodeType.TRAP: "trap",
		MapNodeState.NodeType.TREASURY: "treasury",
		MapNodeState.NodeType.REST: "rest",
		MapNodeState.NodeType.ALCHEMY: "alchemy",
		MapNodeState.NodeType.WORKSHOP: "workshop",
	}.get(node.node_type, "unknown")
