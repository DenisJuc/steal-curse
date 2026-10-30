Goal: the Codex menu (`src/client/UI/CodexPanel.luau`, window "CodexMenu") reads like a reward track, not a wall of sentences.

Scope: only edit `src/client/UI/CodexPanel.luau`. Do NOT change milestone thresholds, rewards, claiming, remotes, server code, CodexBook/CodexConfig data, rarity, income or save data.

Do:
- Section headers: "Essential milestones (Common-Legendary relics, any mutation counts)" -> "Milestones"; "Signal Frequency unlocks" -> "Family unlocks". Shorten any other long header the same way.
- Summary box at the top: one big line "21 / 92 found" (TextSize >= 24) and one small gold line with the bonus "+0% Luck  +0% CE" (drop "Codex bonus:" and "(permanent)"). Drop the "Essential 21 / 70" part from the big line (keep it only if nothing else shows it; then put it in the small line).
- Milestone rows: replace the sentence "Discover 28 of 70 Common-Legendary relics" with a short title "28 relics" (family rows: "9 Demonic"), keep the reward line ("+10% Luck, +5% CE") and the "21 / 28" progress, and add a thin progress bar under the row (filled share = progress / target, gold when claimable). Claim buttons stay as they are.
- Row title TextSize >= 18, reward line >= 15.
- Match existing style (UIKit helpers, tabs, comment density).

Done when: `rojo build` succeeds and `lune run tests/run` passes. You cannot run shell commands here, so say so instead of claiming they pass.

Report: what you changed and the diff.
