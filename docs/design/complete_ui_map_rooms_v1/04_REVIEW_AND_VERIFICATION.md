# Review protocol and combined checks

Each stage is an implementation/review boundary. Complete authorized work within it, including necessary fixes, without repeated routine permission requests. Then stop for Vic's explicit verification/continue instruction. Stage 00 is audit-only. Keep the project runnable; incomplete later services remain disabled/gated. If an existing stage can be verified instead of rebuilt, record that and still give its actual checks.

For each stage report: player-facing change; reused services and source mapping; migration/ownership implications; exact entry path and seed/fixture; commands/results; runtime screenshot or recording where possible; short passed/failed/not-run player checklist; baseline failures, provisional values and precise blockers. Track **implemented**, **tested** and **user-verified** separately in 05_REVIEW_LOG_TEMPLATE.md or the repository's equivalent checkpoint.

Do not implement all stages in one turn, reset unrelated work, weaken tests, push or merge. Do not claim a generated mockup/browser preview demonstrates Godot integration. Use real engine/renderer/input paths and distinguish a debug fixture from normal campaign access. After a correction, fix/reverify the current stage before continuing.

## Cross-system invariants

- Shared Backpack/Ability components retain context permissions. Fifteen personal slots, six shared Item Bar slots and a slot-free shared Key-ring remain distinct; no seventh item slot masquerading as Backpack.
- Same-item merges honor compatibility/caps; full target no-op, overflow at source; complete different-item swaps return to exact source; partial different-item swaps reject; quick transfer merges then first-free and never evicts unrelated items.
- Equipment instances have one owner/location with condition preserved. Refuge equip can use all named Backpack sources; combat uses only the actor's bag for approved weapon/armor/bar mutations at exactly one Action per successful positive transaction.
- Invalid/no-op/cancelled/failed mutations change no wallet, item, Action, materials or source claim; saving a committed transaction cannot leave one side applied.
- Room/container persistence and fight abandonment are tested independently. Partial pickup, full bag, child-menu cancellation, parent closure, revisit and save/load cause no room loss, reroll or duplicate claim.
- Trap identification, disarmed/triggered state and collection are independent. Chosen-heroine effects apply once; party detection/alarm follows its own scope. Particles are presentation only.
- All three recovery contexts are tested independently, including resource bounds, costs, recipient scope, previews, confirmation and saved use counters.
- Refuge/field production use the correct material and output domains. Spent run resources cannot be credited again on return. Permanent recipes survive defeat; first-visit materials do not duplicate.
- Map knowledge, accessibility, Visited, cleared encounter and Solved remain separate; hidden secrets/edges do not leak, and current locks always govern traversal.
- Prep buy/cancel/reopen/load/start has one charge and correct pending/permanent ownership. Memory/Passage never restore loot/used state, revive bosses or grant skipped-room rewards.
- Default Refuge is Bloom-only; run dock remains stable with 1/2/3 heroines. Focus/Escape/nested dialogs and shortcuts cannot bypass grapple/input/ownership permissions.
- Current defeat equipment protection, story prerequisites, key scopes and campaign flow match preserved baseline. Gallery replay is isolated from rewards/unlocks and state changes.

Run the repository's required checks and focused behavioral tests where these rules change. Avoid redundant tests for decorative layout. Use the final combined Stage 24 lifecycle to catch integration failures that individual stages cannot prove.
