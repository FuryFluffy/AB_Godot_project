# Stage 11 native Backpack evidence

Godot 4.7.2 Compatibility rendering and native input injection, 2026-10-21. Temporary XDG profiles isolate all fixture data from production saves.

Final native run: 50 checks, zero failures. It uses the actual CombatEncounter and EventRoomScreen with the shared BackpackView and existing Item Bar. Tests include native mouse drag, keyboard context/source selection, nested cancel, actor-only costs, other-heroine read-only browsing, blocking background commands, dialogue locks and Grapple access/shortcut rejection.

Six of sixteen captures are retained:

- `1920x1080_combat_backpack.png`: actor's bag, existing equipment condition, 3×5 slots, Key-ring and one HUD Item Bar.
- `1600x900_context_cost.png`: Move/exchange and Split with the one-Action cost before commitment.
- `1280x720_combat_backpack.png`: supported smaller desktop layout.
- `1024x768_readonly_mira.png`: another heroine's bag remains read-only; existing battlefield camera framing remains visible.
- `1024x768_after_transfer.png`: successful split and remaining source quantity.
- `1280x720_exploration_3.png`: current-party selector, free transfers and no Stash. This controller/HUD fixture intentionally has no authored room background.

In-memory stacks and one spare copy of an existing authored weapon are explicitly fixture-only; the spare retains zero condition to exercise broken equipment display. No authored definitions, rewards or production inventories were changed. Production-safe-point checks use the save store's dedicated test directory.

The full official suite passes all 59 scripts, including the same 50 UI checks. The focused transaction log reports 39 checks with zero failures. The native log retains the baseline five ObjectDB/three-resource shutdown diagnostics. Safe-point logs include intentional invalid-JSON/write-failure coverage. Full campaign and physical-gamepad acceptance remain pending; native keyboard input does not constitute a physical-controller test.
