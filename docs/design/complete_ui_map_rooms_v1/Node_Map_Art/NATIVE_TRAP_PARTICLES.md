# Native trap particle direction

This is the approved implementation direction, not an implemented Godot scene.

Use a small native Godot particle effect above the trapped item. Inspect the actual laptop branch's Light Arrow presentation and reuse its effect ownership, rendering and cleanup conventions. The GitHub main inspection located Light Arrow ability/effect resources but did not establish the current laptop's visual implementation. Resolve that locally before choosing the particle node/material or adding another VFX system.

| Trap | Presentation | Placement |
| --- | --- | --- |
| Poison Fog | Brief dirty green cloud, soft wisps rising and dispersing | Just above the collected item's displayed position |
| Corruption | Brief muted violet cloud with a few curling dark wisps | Same local item anchor |
| Alarm | Brief bell marker/pulse, then the existing encounter transition | Item anchor or existing notification area |

Start with a cloud roughly one to two item widths across, lasting about one second. These are visual tuning proposals, not balance values. Keep the cloud local and leave nearby items and room hotspots readable. Animate particle motion and fading in Godot; do not substitute a screen-sized fog image. The rejected Poison/Corruption overlay PNGs are deliberately absent from this revision.

Trigger feedback only when the gameplay transaction actually triggers the trap: committed collection, deliberate Collect despite detection, or failed Disarm. Inspection, Ignore, cancellation and a failed pickup due to Backpack capacity do not emit it. Detection shows the identifying heroine's dialogue and an identified marker; it does not emit a damaging cloud or reveal undetected traps.

Capture the item's displayed anchor before removing its collectible sprite. Own the transient effect at room level so it can finish after the item is collected. Convert coordinates through the actual displayed room rectangle, preserving alignment on resize and different aspect ratios. Clean up on room exit and encounter transitions. Reopening an interface, restoring a save or revisiting must not replay an already committed trap effect or apply its consequences twice.

HP, Resolve and Corruption consequences affect only the chosen interacting heroine. Awareness may be checked by any active party heroine. An alarm starts a party encounter. Keep gameplay consequences in the existing trap transaction; particles only present the committed result. Use live UI/log text for numbers rather than baking them into effects.

Verify in the project's actual Godot target and renderer, including the laptop's GL Compatibility setup: item anchor alignment, brief lifetime, cleanup, single emission, no emission after cancelled/full-Backpack collection, no hidden-trap leak, and no repeat damage after save/load or revisit.
