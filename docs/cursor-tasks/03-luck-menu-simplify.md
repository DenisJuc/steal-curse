Goal: the Luck menu (`src/client/UI/FocusPanel.luau`, window "LuckMenu") answers one question at a glance: "how lucky am I and what are my odds?" Less text, bigger numbers.

Scope: only edit `src/client/UI/FocusPanel.luau`. Do NOT change luck math, odds, Focus/Attune/Frequency behaviour, remotes, server code, rarity, income or save data. Keep every button working exactly as now.

Do:
- Top of the menu: one big line, e.g. "Luck x12" (TextSize >= 28, gold). If luck is capped by a Focus, a small second line "Focus: Rare (capped at x5)". Replace the current "Luck 1x | used 1x" line.
- Section headers: short words only. "Rarity Focus (caps luck so that tier keeps appearing)" -> "Focus". "Signal Frequency (favors a family inside each tier)" -> "Family". "Your chance per discovery" -> "Odds". "Attune (Codex soft-lock / collection)" -> "Attune".
- Locked family buttons: show the family name plus a small lock icon/glyph ("🔒 Demonic"); drop the "locked (Codex)" sub-text.
- Odds list: keep it, raise row text to 18+, keep rarity colours.
- The Attune help sentence ("High luck erases Commons — Focus Common or spend an Attune ...") -> remove, or shorten to at most 6 words.
- Mutation line: keep only when unlocked; hide the "locked (...)" text.
- Match existing style (UIKit helpers, tabs, comment density).

Done when: the file still builds (`rojo build`) and `lune run tests/run` passes. You cannot run shell commands here, so say so instead of claiming they pass.

Report: each text you removed or shortened, and the diff.
