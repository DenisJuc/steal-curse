# A+C fix matrix — Rebirths 1–3

**Status:** Simulation only. Live balance **not** shipped. `BalanceTrials.Active` remains `nil`.

**Candidate reach path:** E20k_L12_C17_HR full stack (cost growth 1.7 to reach each Rebirth).
**Seeds:** 150. **Window:** 30 minutes after each Rebirth.

## Cost curve feel (first 25 Core Luck ranks after Rebirth)

| Rank | Live 1.7 | Flat 1.75 | Flat 1.80 | Flat 1.85 | Soft k=0.04 | Soft k=0.05 | Soft k=0.06 |
|------|----------|-----------|-----------|-----------|-------------|-------------|-------------|
| 0 | 100 | 100 | 100 | 100 | 100 | 100 | 100 |
| 4 | 836 | 938 | 1.05K | 1.17K | 1.02K | 1.07K | 1.12K |
| 8 | 6.98K | 8.8K | 11K | 13.7K | 10.1K | 11K | 11.8K |
| 12 | 58.3K | 82.5K | 116K | 161K | 98.9K | 110K | 121K |
| 16 | 487K | 774K | 1.21M | 1.88M | 949K | 1.08M | 1.21M |
| 20 | 4.06M | 7.26M | 12.7M | 22.1M | 8.99M | 10.4M | 11.8M |
| 24 | 33.9M | 68.1M | 134M | 258M | 84.2M | 98.4M | 113M |

Soft curve stays near 1.7 for early ranks (no cliff), then pulls away — better post-Rebirth feel than jumping straight to 1.85.

## After Rebirth 1

Control: **67** Epics / 30m (unique Epic ids **15.0**), Leg **2.7** (unique **2.4**), mutations **0.0**, luck end **1.29K**, CoreLuck **32**, sig-buy gap **1.2** min.

| Fix | Epic | %ctrl | Unique Epic | Leg | Unique Leg | Mut | Luck end | CoreLuck | Gap min |
|-----|------|-------|-------------|-----|------------|-----|----------|----------|---------|
| full | 66.9 | 100% | 15.0 | 2.66 | 2.39 | 0.0 | 1.29K | 32 | 1.2 |
| ac_lg125_g175 | 38.5 | 58% | 13.0 | 1.59 | 1.49 | 0.0 | 745 | 30 | 0.8 |
| ac_lg125_g180 | 30.4 | 46% | 12.0 | 1.17 | 1.11 | 0.0 | 563 | 28 | 0.7 |
| ac_lg125_g185 | 23.5 | 35% | 11.0 | 1.01 | 0.97 | 0.0 | 432 | 27 | 0.9 |
| ac_lg125_soft05 | 33.8 | 51% | 12.4 | 1.39 | 1.29 | 0.0 | 620 | 29 | 0.6 |
| ac_lg125_soft04 | 34.1 | 51% | 12.4 | 1.36 | 1.28 | 0.0 | 689 | 29 | 0.7 |
| ac_lg125_soft06 | 31.3 | 47% | 12.1 | 1.26 | 1.19 | 0.0 | 568 | 29 | 0.6 |

## After Rebirth 2

Control: **202** Epics / 30m (unique Epic ids **18.8**), Leg **8.1** (unique **5.8**), mutations **0.0**, luck end **3.76K**, CoreLuck **35**, sig-buy gap **0.5** min.

| Fix | Epic | %ctrl | Unique Epic | Leg | Unique Leg | Mut | Luck end | CoreLuck | Gap min |
|-----|------|-------|-------------|-----|------------|-----|----------|----------|---------|
| full | 201.7 | 100% | 18.8 | 8.11 | 5.79 | 0.0 | 3.76K | 35 | 0.5 |
| ac_lg125_g175 | 98.8 | 49% | 16.1 | 3.87 | 3.21 | 0.0 | 1.73K | 33 | 0.7 |
| ac_lg125_g180 | 72.6 | 36% | 15.2 | 2.74 | 2.39 | 0.0 | 1.25K | 31 | 1.0 |
| ac_lg125_g185 | 56.1 | 28% | 14.5 | 2.31 | 2.09 | 0.0 | 901 | 30 | 0.4 |
| ac_lg125_soft05 | 85.2 | 42% | 15.8 | 3.45 | 2.99 | 0.0 | 1.41K | 32 | 0.9 |
| ac_lg125_soft04 | 90.5 | 45% | 16.0 | 3.60 | 3.10 | 0.0 | 1.53K | 32 | 0.8 |
| ac_lg125_soft06 | 81.1 | 40% | 15.8 | 3.23 | 2.93 | 0.0 | 1.36K | 32 | 1.0 |

## After Rebirth 3

Control: **545** Epics / 30m (unique Epic ids **23.1**), Leg **21.6** (unique **10.1**), mutations **0.0**, luck end **9.54K**, CoreLuck **38**, sig-buy gap **0.8** min.

| Fix | Epic | %ctrl | Unique Epic | Leg | Unique Leg | Mut | Luck end | CoreLuck | Gap min |
|-----|------|-------|-------------|-----|------------|-----|----------|----------|---------|
| full | 545.1 | 100% | 23.1 | 21.57 | 10.15 | 0.0 | 9.54K | 38 | 0.8 |
| ac_lg125_g175 | 223.8 | 41% | 19.1 | 8.89 | 6.06 | 0.0 | 3.74K | 36 | 0.4 |
| ac_lg125_g180 | 163.3 | 30% | 18.0 | 6.33 | 5.00 | 0.0 | 2.41K | 34 | 0.7 |
| ac_lg125_g185 | 124.3 | 23% | 17.1 | 4.95 | 4.12 | 0.0 | 1.96K | 32 | 0.6 |
| ac_lg125_soft05 | 191.1 | 35% | 18.6 | 7.45 | 5.59 | 0.0 | 3.26K | 35 | 0.5 |
| ac_lg125_soft04 | 207.7 | 38% | 18.9 | 8.24 | 5.91 | 0.0 | 3.24K | 35 | 0.4 |
| ac_lg125_soft06 | 181.2 | 33% | 18.6 | 7.64 | 5.61 | 0.0 | 3.12K | 34 | 0.5 |

## Read for Astra

- Duplicate Epic **counts** stay higher than **unique** Epic discoveries — acceptable if Resonance / Charms / mutation goals are the post-R objectives.
- Prefer **LuckGrowth 1.25 + soft cost (k≈0.05)** over flat 1.85 if early post-R ranks should feel rebuildable.
- Flat 1.85 + LuckGrowth 1.25 is the strongest flood cut among flat options; re-check R2/R3 rows before approving.
- **Do not ship** until combined with Collection prototype playtest.

## Reproduce

```bash
lune run tests/acFixMatrix 150
```
