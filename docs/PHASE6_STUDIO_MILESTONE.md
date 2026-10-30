# Phase 6 Studio gameplay milestone (~8 min)

**Goal:** Confirm Rank 2→3 feels intentional: mutated copies stick, NEXT/Board show real requirements, hunt feedback fires, B+ keeps Fusion.  
**Not claimed until you run it.** Lune covers math; `/p6smoke` covers server paths on mock ProfileStore; this table is the short playtest.

## Preconditions

- Studio Solo, SoftCap_P4 active (`CollectionPrototype=true`, B+ Rebirth).
- Mock ProfileStore isolation (same as `/p41smoke`).

## Seeded checks (commands)

| Step | Command / action | Pass if |
|------|------------------|---------|
| 0 | `/p6smoke` | Output `ALL PASS` (mut reserve, sell-all keep-1, BoardFocus, Rank3 ×1.50). |
| 1 | `/p41smoke` (optional) | Still green — Phase 4.1 Rank2 path unchanged. |

## Play loop (manual, ~5–8 min)

| Step | Do this | Pass if |
|------|---------|---------|
| 1 | Fuse a Common to Rank 1; pick **Hunt** Charm; equip that relic on a pedestal. | Board shows Rank 1; NEXT points at Rank 2 copies (keep 5). |
| 2 | Stock / hunt until Rank 2 fuse. | Board Lift → **×1.28**; AutoSell keeps Rank2 base stockpile. |
| 3 | Open Board on the Rank 2 relic. | Shows Rank 3 needs: base copies, **mutated yes/no**, Essence, ×1.50. With one Rank2 candidate, no Pursue button required. |
| 4 | Get a **mutated** copy of that same relic (hunt or grant). Sell-all / AutoSell. | At least one mutated copy remains; NEXT says mutation secured / ready when recipe met. |
| 5 | Finish a hunt that includes that mutated Board relic. | Hunt papers footer: **Rank 3 mutation secured** (not spam on unrelated dupes). |
| 6 | Fuse Rank 3. | Board Lift → **×1.50**; BoardFocus clears. |
| 7 | Rebirth (B+) when affordable. | Fusion Rank 3 + Charm + Essence kept; CE reset only. |

## Out of scope

No drop-rate changes, new shops, or economy retunes. If Rank 3 feels slow, that is expected exact-id mutation rarity — not a failed smoke.
