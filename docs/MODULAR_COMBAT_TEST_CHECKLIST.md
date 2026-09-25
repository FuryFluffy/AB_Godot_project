# Modular Combat Runtime Checklist

Use Godot 4.7 and run `project.godot`.

## Startup and layout

- Select a connected battle node, press Travel, and confirm combat starts.
- Confirm there is no `test_seed` property error in Output.
- Confirm heroine cards are bottom-left.
- Confirm the six item slots are between heroine cards and command buttons.
- Confirm Item and Command bars match the 229-pixel heroine-card height.
- Confirm all reusable UI buttons are text-only and have no icons.
- Open and close the combat log; it must not resize or displace the bottom
  HUD.
- Confirm the top bar contains only Layer, Room/Phase, and Objective.

## Battlers and selection

- Confirm regular/elite nodes show the Ruined Chapel background.
- Confirm the Blood Nun boss node shows the Processing Chapel background.
- Confirm Output contains no missing spawn-slot or battlefield-composition
  error.
- In the Remote scene tree, confirm `MarkerHost` contains only the active
  party and active enemies—not the entire Layer 1 roster.
- In the Corrupted Butler encounter, confirm his sprite is visible.
- Confirm every active enemy shows a name, HP, and Actions.
- Start Attack targeting with Seraphine overlapping Butler.
- Click Butler through Seraphine's sprite area; Butler must receive the
  target click.
- Cancel targeting and confirm Seraphine's full sprite is selectable again.

## Ordinary reaction exchange

- Trigger and test `Attack`, `Dodge`, `Defend`, `Parry`, and `Skip`.
- Open Defend and test `Armor`, `Shield`, and `Back`.
- Confirm Skip closes and clears the pending reaction.
- Confirm enemy-owned reactions are non-interactive and resolve
  automatically.
- Confirm enemy Dodge chooses and logs its own destination.
- Let Dodge prevent at least one success while damage still reaches armor.
  Choose Destroy at the breaking point; the equipment choice must close
  immediately and the optional Dodge-step prompt must remain usable.
- Click Preserve or Destroy once and confirm the choice cannot submit twice
  or append a stale “No equipment-break confirmation is pending” error.
- Confirm Dodge spends one saved Action, mitigates its rolled successes, and
  offers one optional legal step when it prevents damage. Select a step, then
  repeat and decline with Escape.
- Confirm a successful Parry produces its free counterattack and allows a
  chained exchange.
- Confirm Parry spends one saved Action, uses the defender's weapon skill,
  and applies the current chain penalty (`-1d10`, then `-2d10`, `-3d10`).
- Confirm Parry against zero successes does not create a free attack.

## Grapple

- Trigger Grapple and confirm only legal Grapple reactions appear.
- Confirm Grapple progress is below the enemy HP/Actions HUD and is
  gold/purple rather than gray.
- On a grappled heroine's phase, confirm `Struggle` and `Wait` replace normal
  action labels.
- Test Momentum and confirm it does not leave only Attack available.
- Resolve escape, enemy defeat, heroine defeat, and forced detachment.

## Other systems

- Test Move, threatened movement, Ability, area effects, all six item slots,
  statuses, enemy phases, victory, defeat, map return, and party/inventory
  persistence.
- Run `python3 tools/validate_project.py --allow-generated-cache` in a local
  development worktree. Package validation must omit the option so any
  packaged `.godot/` cache content is rejected.
- If a Godot executable is available, run
  `python3 tools/run_regression_suite.py`.
- The cumulative suite now includes `tests/test_battle_composition.gd`.

The `.godot/` directory is ignored local cache and must never be committed.
Godot-generated `.import` and `.uid` files outside `.godot/` are intended
repository metadata and must not be added to `.gitignore`.
# Latest reaction lifecycle regression checks

- Log opens and closes before combat, during reactions, and while commands are
  locked.
- Preserve/Destroy closes immediately after one click.
- Equipment break followed by optional Dodge movement never leaves two
  simultaneous input modes.
- Chained Parry attacks identify themselves as `PARRY FREE ATTACK`.
- A zero-Action heroine never receives a blocking Grapple prompt.
- A prevented Grapple grants one optional connected-anchor Dodge step.
- In Opening Servant Corridor, move onto each teal-linked Foreground boundary
  Position and confirm that melee/Grapple and Move Reactions cross only that
  exact link. Neighboring unlinked Positions must remain Close.
- Dodge away from a boundary contact and confirm that linked Positions are
  excluded while safe Positions inside the defender's current Anchor remain
  selectable.
## Ability Resource milestone

- [ ] Existing heroine ability names, costs, targeting and outcomes are
  unchanged.
- [ ] Mira's Blight Bomb still uses one AOE roll, individual Defenses and
  applies Poison only after HP damage.
- [ ] A temporary battler loadout containing Regeneration can cast it on an
  injured ally; it restores 1 HP for three phase-start ticks.
- [ ] Dispel Magic removes Regeneration, Bless or Ward from either faction in
  the caster's BattleZone.
- [ ] Slow removes one current Action, lowers maximum Actions by one and
  limits Move to one step after winning its opposed check.
- [ ] Cure restores at least 1 HP and logs its Body/Personality successes.
- [ ] Cure replaces Heal in an upgraded loadout rather than appearing beside
  it as a permanent redundant command.
