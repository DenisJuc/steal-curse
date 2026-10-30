Goal: the Codex relic list (`src/client/UI/CodexPanel.luau`, the "Relics" section at the bottom) works like the index in top RNG games: tabs for Normal / Huge / Titanic, and relics grouped under a heading per rarity.

Scope: edit only `src/client/UI/CodexPanel.luau` and the `snapshot` function in `src/server/Services/CodexService.luau`. Do NOT change milestones, rewards, claiming, odds, rarity data, income, discovery logic, or save data.

Data:
- In `CodexService` `snapshot(player)`, also return `Sizes = data.CodexSizes` (a table relicId -> { [sizeId] = timestamp } of sizes the player has found; sizeIds are "Huge" and "Titanic"; it can be missing/empty). Read-only; don't change how it is written.
- In CodexPanel, read it from the snapshot as `snapshot.Sizes or {}`.

UI:
- Above the relic grid, three tab buttons: "Normal", "Huge", "Titanic" (Normal selected by default). Use `UIKit.button` and the same selected/unselected styling the Skills menu tabs use (`src/client/UI/SkillTreePanel.luau`, read-only reference). Each tab shows a found count, e.g. "Huge 3/92".
- Normal tab: as now (known if `state.Discovered[relicId]`).
- Huge / Titanic tab: a relic counts as known only if `Sizes[relicId][size]` is set; unknown ones use the existing silhouette look. Known cards show the size label (e.g. "HUGE") in the size colour already used elsewhere (Huge `Color3.fromRGB(160, 210, 255)`, Titanic `Color3.fromRGB(255, 210, 90)`).
- Group the cards by rarity: for each tier in `RarityConfig.Tiers` order, a small heading row in the tier colour ("Common 5/12"), then a grid with that tier's relics (`CodexBook.AllIds` filtered by `RelicConfig.ById[id].Tier`). Skip tiers with no relics.
- Switching tabs re-renders only the relic section; keep the existing card builder (`relicCard`) and the render cache so viewports are not rebuilt needlessly.
- Match the file's style (UIKit helpers, tabs, comment density).

Done when: `rojo build` succeeds and `lune run tests/run` passes. You cannot run shell commands here, so say so instead of claiming they pass.

Report: what you changed and the diff.
