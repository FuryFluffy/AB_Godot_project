# Log Drawer Authored Animation Restored

The combat Log now uses the interaction model authored in the separate
reusable UI project:

- the drawer remains a visible `Control`;
- its closed position is immediately outside the 1920-wide design canvas;
- `AnimationPlayer` moves it from `(1920, 150)` to `(1460, 150)`;
- the same `Log` button plays the animation forward and backward;
- the Log remains usable while combat commands are locked.

The centralized combat-progression gate and Momentum behavior were not changed.

## Runtime check

1. Enter the Butler battle.
2. Press `Log` before `Begin`; the drawer must slide in from the right.
3. Press `Log` again; the drawer must slide out.
4. Begin combat and repeat during Hero and Enemy phases.
5. Complete the first battle, enter the Knife Footman battle, and repeat.
6. Confirm Footman Momentum still advances normally.
