Goal: the Pedestals menu (`src/client/UI/ShrinePanel.luau`) reads at a glance: fewer words, bigger text, one obvious action per row.

Scope: only edit `src/client/UI/ShrinePanel.luau`. Do NOT change rarity, income, prices, Rebirth, Fusion, Hunt, currency, save data, remotes or any server code. Do not rename instances other code looks up by name.

Do:
- Remove the long help line next to Equip Best ("Hold E at a pedestal to take or place a relic. Padlock: Equip Best skips it."). If the padlock needs explaining, use a short tooltip-free label like "🔒 = keep" on the padlock button itself, or nothing.
- Empty pedestal rows: drop the "Place a relic to earn CE" sub-line; the big PLACE button already says it.
- Upgrade column: show one line "Lv 1 → 2" and the price button; drop the "boost x1 → x1.1" line (keep it only if the value is not shown anywhere else, as a small gold "+10%" next to the arrow).
- Locked pedestal rows: keep "Pedestal N" and the Unlock price button; drop "Shows one more relic".
- Raise the minimum text size of row titles to 20 and of buttons to 18 where they are smaller now. Keep the existing layout and styling helpers (UIKit), tabs and comment density.

Done when: `rojo build -o build/check.rbxl` succeeds and `lune run tests/run` passes. You cannot run shell commands here, so say so instead of claiming they pass.

Report: a short summary of each text you removed or changed, and the diff.
