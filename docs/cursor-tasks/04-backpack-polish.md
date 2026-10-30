Goal: the Backpack menu (`src/client/UI/InventoryPanel.luau`, window "RelicsMenu") never shows placeholder text and its cards read at a glance.

Scope: only edit `src/client/UI/InventoryPanel.luau`. Do NOT change selling, prices, auto-sell rules, equip logic, remotes, server code, rarity, income or save data.

Bugs to fix:
- With no card selected, the detail pane shows six action buttons that literally read "Button". Hide the action buttons until a card is selected (and hide them again when the selection clears); never show the default "Button"/"Label" text anywhere (a label at the bottom-left also briefly reads "Label").

Polish:
- Detail pane with nothing selected: just the hint "Tap a card to see it here." — remove the second line "Favorite: never auto-sold. Lock: can't be sold." (show that hint only after a card is selected, small, if at all).
- Relic cards: income text (e.g. "+45.6/s") and the count chip ("x1") to at least TextSize 16; relic name at least 16. Keep the card grid size and layout.
- Match existing style (UIKit helpers, tabs, comment density).

Done when: `rojo build` succeeds and `lune run tests/run` passes. You cannot run shell commands here, so say so instead of claiming they pass.

Report: what you changed and the diff.
