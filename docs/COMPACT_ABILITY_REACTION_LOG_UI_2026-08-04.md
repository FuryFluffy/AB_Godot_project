# Compact Ability, Reaction, and Combat Log UI

## Implemented

- Ability selection is now a compact tray that unfolds left from the Ability
  command icon.
- Each ability is a direct button with its Action/MP cost. Descriptions and
  unavailable reasons are provided by tooltip.
- StrugglePanel is active gameplay code, not an unused remnant. It now unfolds
  from the Struggle icon with the same compact motion and still selects the
  Grapple track and Struggle Attribute.
- Player reaction prompts are compact 480×250 cards positioned above the
  reacting sprite.
- The reacting sprite receives a contextual gold ring and corner focus.
- The reaction card states actor, action, target, incoming successes, remaining
  Actions, and the currently available reaction choices.
- Enemy rulebook reactions resolve without flashing a player-input modal.
- The combat log now supports a short visible summary plus hover details.
- Round/phase entries are reduced to `Round N — Hero/Enemy Phase`; phase-start
  order, refreshed Actions, and status processing are in the tooltip.
- Attack, Grapple, Struggle, movement, item, and ability results use concise
  player-facing summaries. Dice, successes, HP/Action changes, equipment,
  statuses, and other mechanical detail move into hover text.

## Deliberately deferred

The reaction card has no countdown yet. A one- or two-second QTE should be
added only after the untimed card is clear and comfortable in ordinary play.
The future timer can use the same reaction-focus and card-position hooks
without changing combat resolution.

## Runtime checklist

1. Click Ability and confirm the tray unfolds beside the Ability icon.
2. Hover each ability and confirm description/unavailability details appear.
3. Select one self, single-target, and BattleZone ability; confirm existing
   targeting and RMB/Esc cancellation still work.
4. Receive a normal Attack, Grapple attempt, and Move Reaction; confirm the
   correct reacting sprite is gold-focused and the card appears above it.
5. Exercise Dodge, Defend → Armor/Shield, Parry, Skip, and equipment break.
6. Open Log and hover phase, Attack, Grapple, Struggle, Move, item, and ability
   entries to confirm their mechanical breakdown is present.
7. Trigger Struggle and confirm track/Attribute selection still resolves.
