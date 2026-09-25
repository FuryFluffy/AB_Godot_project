# Attack Range, Randomness, and AOE Reaction Fix

## Corrected runtime contracts

- Prayer-Rag Novice uses `Dark Prayer` for magical attacks up to two
  BattleZones away. The check is Dark/Personality and costs 1 MP.
- Prayer Staff is a separate physical Reach weapon. It retains the Staff-family
  post-damage Action-loss property only when the staff itself deals HP damage.
- Every committed primary weapon Attack, targeted attack ability, and newly
  committed AOE consumes the next deterministic seed. Repeated Actions no
  longer recreate the same roll.
- One AOE still owns one shared roll across all affected targets.
- BattleZone AOE requests are `DEFENSE_ONLY`: affected targets may Dodge, use
  Armor, use a Shield, or Skip when legal, but may not Counterattack the caster.

## Focused runtime checks

1. Attack six times with Seraphine's Staff and confirm the Log shows advancing,
   non-identical attack dice rather than one roll repeated.
2. Let Prayer-Rag Novice act at Very Far and confirm the source is `Dark Prayer`
   with a non-zero pool, not `Prayer Staff`.
3. Exhaust the Novice's MP and confirm Prayer Staff is only used at Reach.
4. Throw Blight Bomb from Altar Left into Central Nave and confirm Blood Nun
   resolves a defense without Counterattacking Mira.
5. Confirm every Blight Bomb target still receives the same shared attack roll.
