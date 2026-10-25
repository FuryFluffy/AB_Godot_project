# Stage 10 native evidence

Actual Godot 4.7.2 Compatibility rendering and input injection on 2026-10-20, using temporary XDG profiles. No production save was opened. Final full fixture: 488 checks, 0 failures, including 14 live encounter checks and waiting for Log animation completion. The final official headless suite passed all 57 scripts, including the same 488 HUD checks.

55 screenshots were generated in `/tmp/ab-stage10-final-captures`; these eight representative captures are retained:

- `1920x1080_combat_populated.png`: three cards, six canonical item icons, exact ×9999 display stress case, status/Action values, Backpack boundary and four commands.
- `1600x900_struggle_popup.png`: existing Struggle popup above the dock; Submit and Backpack disabled.
- `1280x720_live_combat.png`: actual production encounter after selection, Move/cancellation and closing Log; existing battlefield/camera.
- `1280x720_live_combat_ability.png`: actual selected heroine's Ability definition and costs in the production encounter.
- `1280x720_exploration_return.png`: three-card exploration context after Refuge, using in-memory presentation data.
- `1280x720_dialogue_clearance.png`: dialogue window leaves the dock and Log tab accessible.
- `1280x720_ability.png`: existing learned Forced Blade and its authored costs, disabled in exploration because field execution is unauthored.
- `1024x768_log.png`: exploration Log above the dock at the additional 4:3 check size.

Learned abilities in the fixture use the existing developer-default progression snapshot in memory only; production exploration reads current saved progression. The presentation fixture does not grant the stress-test quantity to inventory or author new narrative. Real live combat uses the existing flow controller with its test-only party-first order override. A full player campaign and physical gamepad acceptance remain pending. Native teardown logs retain the baseline five ObjectDB instances / three resources warnings.
