class_name ExplorationHUD
extends CanvasLayer


@onready var party_strip: PanelContainer = $PartyStrip
@onready var item_bar: ItemBarView = $ItemBar
@onready var command_bar: ExplorationCommandBarView = $ExplorationCommandBar
@onready var hover_label: Label = $HoverLabel
@onready var dialogue_panel: DialoguePanel = $DialoguePanel

@onready var lysandra_card: HeroineCardView = (
	$PartyStrip/Cards/LysandraCard
)
@onready var mira_card: HeroineCardView = (
	$PartyStrip/Cards/MiraCard
)
@onready var seraphine_card: HeroineCardView = (
	$PartyStrip/Cards/SeraphineCard
)


const PARTY_STRIP_FRAME_MARGIN: float = 16.0
const PARTY_CARD_HEIGHT: float = 112.0
const PARTY_CARD_SEPARATION: float = 6.0


func get_party_card(
	battler_id: StringName
) -> HeroineCardView:
	match battler_id:
		&"lysandra":
			return lysandra_card
		&"mira":
			return mira_card
		&"seraphine":
			return seraphine_card
	return null


func set_active_party_ids(
	active_party_ids: Array[StringName]
) -> void:
	var active_count: int = 0
	for card: HeroineCardView in [
		lysandra_card,
		mira_card,
		seraphine_card,
	]:
		card.visible = active_party_ids.has(card.battler_id)
		if card.visible:
			active_count += 1

	# Keep the authored cards at their readable size, but collapse the frame
	# around the current party. This gives solo, duo, and trio exploration the
	# same bottom-left alignment without reserving an empty heroine slot.
	var content_height: float = (
		PARTY_STRIP_FRAME_MARGIN
		+ float(active_count) * PARTY_CARD_HEIGHT
		+ float(maxi(active_count - 1, 0)) * PARTY_CARD_SEPARATION
	)
	party_strip.offset_top = party_strip.offset_bottom - content_height


func set_dialogue_active(
	active: bool,
	mandatory: bool = false
) -> void:
	dialogue_panel.visible = active
	command_bar.set_dialogue_mode(
		active,
		mandatory
	)

	if not active:
		item_bar.set_locked(false)


func set_item_bar_locked(locked: bool) -> void:
	item_bar.set_locked(locked)
