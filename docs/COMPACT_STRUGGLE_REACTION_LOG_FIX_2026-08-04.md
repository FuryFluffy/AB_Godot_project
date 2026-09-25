# Compact Struggle, Reaction, and Log UI Fix

## Runtime changes

- Struggle is a direct choice between Might, Agility, and Endurance.
- Every Attribute button shows `heroine dice vs enemy dice` and resolves immediately.
- The old Struggle confirmation and Back buttons are removed. RMB and Esc cancel.
- Multiple Grapple tracks show a track selector only when one is actually needed.
- Reaction cards use a compact 430x170 frame and remain anchored to the reacting battler.
- Command buttons remain icon-only during targeting, cancellation, phase changes, and Grapple.
- Combat-log entries use 12 px text and explicitly receive mouse hover input, allowing their detail tooltips to appear.

## Manual placement and sizing

Reaction card:

1. Open `reaction_exchange.tscn`.
2. Select the `ReactionExchange` root.
3. Adjust `Compact Frame Size`, `Reaction Offset`, or `Sprite Gap` in the Inspector.

Struggle tray:

1. Open `struggle_panel.tscn`.
2. Select the `StrugglePanel` root.
3. Adjust `Command Offset` or `Command Gap` in the Inspector.
4. Change `Custom Minimum Size` only if the three Attribute buttons also still fit.

The reaction card is positioned at runtime relative to a battler, so dragging its Frame in the scene is not the persistent way to move it. Use `Reaction Offset` instead.

## Focused runtime check

1. Open Struggle and choose each Attribute once across test runs.
2. Confirm each button shows the current pools and resolves in one click.
3. Trigger Attack and Grapple reactions near the left, centre, and right sides of the battlefield.
4. Confirm the card stays compact, remains on-screen, and follows the reacting sprite.
5. Hover several Log summaries and confirm the roll/resource details appear.
6. Start/cancel Attack, Move, and Ability; confirm command icons never become text.
