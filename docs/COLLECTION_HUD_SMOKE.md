# Studio smoke test — Collection Fusion UX

**Scope:** Fusion-first Collection panel (cards, select, Charms after fuse, Advanced tab).  
**Out of scope:** SoftCap, Attunement 25, B+ Rebirth, Forms, economy retunes.

## 3-minute usability test (success criterion)

A new player should open Collection and understand the first objective within **10 seconds**, then fuse without outside help.

| Step | Do this | Pass if |
|------|---------|---------|
| 1 | Play Solo. Open **Collection** (left HUD). | Clear goal line; Essence left / Board `used/slots` right — no overlapping text. |
| 2 | Look at the list. | Cards show progress; **READY** only when fuse will succeed. Blocked cards show **MUTATE** / **NO SLOT**, not Ready. |
| 3 | Tap a fused relic missing a mutation (rank 2→3). | Shows `Missing mutated <Name>`, rank + income now→next, “Own N/Need · spends Consume”, Fuse disabled. |
| 4 | Tap a **READY** new fuse (board has space). | Fuse works; Charm picker; then **Board** tab shows the fused relic card. |
| 5 | Open **Board** tab. | Occupied slot: art, rank, Charm, pedestal ACTIVE/inactive. Empty/locked slots show unlock text. |
| 6 | Board 1/1 upgrade. | Upgrade does **not** need a free slot; new fusions need First Golden for slot 2. |

## Auto-sell check

With Collection on, stock 1–2 copies of a Common. Auto-sell / Sell-all should **not** drop below 3 copies of your closest fusion target (badge **KEEPING**). Extra copies beyond 3 may sell.

**Phase 4.1:** After a Board Rank 1 fuse, AutoSell must keep **5** copies of that relic (Rank 2 recipe). Run `/p41smoke` in Studio (mock ProfileStore) for reserve → Rank2 → Board ×1.28 → retire → B+ checks.

**Phase 6:** Rank 2→3 mutated reserve + Board Focus. Run `/p6smoke`, then the short playtest in [PHASE6_STUDIO_MILESTONE.md](PHASE6_STUDIO_MILESTONE.md).

## Expected startup

```
[BalanceTrials] ACTIVE=…
[BalanceTrials] CollectionPrototype=true | …
```
