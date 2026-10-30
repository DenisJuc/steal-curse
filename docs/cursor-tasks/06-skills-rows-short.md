Goal: the Skills menu (`src/client/UI/SkillTreePanel.luau`, window "SkillsMenu", opened by the Upgrades button) shows each skill as: name, rank, "now -> next", Upgrade button. No explanatory sentences.

Scope: only edit `src/client/UI/SkillTreePanel.luau`. Do NOT change skill costs, effects, ranks, SkillConfig data, remotes, server code, rarity, income or save data.

Do:
- Remove the per-skill description sentence line (e.g. "Multiplies your luck: x10 every 10 ranks (rank 100 = 10 billion x)."). The "Now: x1 luck -> x1.21 luck" line already tells the player what the upgrade does; drop the "Now:" prefix there.
- Remove the tab subtitle line under the tabs (e.g. "Luck, scan speed, frequency and mutations").
- Use the freed space: skill name TextSize >= 20, the now -> next line >= 17, rank text >= 16. Shrink the row height to fit (rows were sized for the extra sentence).
- Keep the Upgrade / +10 / Max buttons and their behaviour exactly.
- Match existing style (UIKit helpers, tabs, comment density).

Done when: `rojo build` succeeds and `lune run tests/run` passes. You cannot run shell commands here, so say so instead of claiming they pass.

Report: what you changed and the diff.
