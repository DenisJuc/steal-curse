Goal: the plot's Showcase podium matches the new sealing-chamber look instead of a bright marble disc with a yellow neon plate.

Scope: only edit `buildShowcasePodium` in `src/server/World/PlotBuilder.luau`. Do NOT change rarity, income, Rebirth, Fusion, Hunt, currency or save data, and do not touch any other file.

Do:
- Dais: keep its name ("Dais"), position, size and billboard, but use `Enum.Material.Basalt` with the existing `WALL_PILLAR` colour constant.
- Replace the full-width neon "Edge" disc with a thin glowing ring: a neon disc (16.4 wide, 0.1 high, `WARM`, Transparency 0.35) just under a dark basalt disc (15.6 wide) on top, so only a 0.4-stud warm rim shows. Keep both `BuildUtil.decor`.
- Match the file's existing style (BuildUtil helpers, tabs, comment density).

Done when: `rojo build -o build/check.rbxl` succeeds and `lune run tests/run` passes.

Report: the diff, and anything you could not verify visually.
