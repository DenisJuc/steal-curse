-- Interface icon images, uploaded to Roblox. Paste each image id as "rbxassetid://123". These must
-- be image ids, not the decal ids Creator Hub lists (a decal id shows nothing).
-- Color wins over Gold for the same key; an empty id falls through to the next source, and finally
-- to the frame-drawn placeholder (Icons.luau), or no icon for text buttons.

return {
	-- Full-color, pre-shaded icons (the "3D" look of big simulators: a rendered object with its own
	-- dark outline and highlights, transparent background, 512 px square). Shown as they are,
	-- larger than the gold ones, with a soft drop shadow.
	Color = {
		Shrine = "",
		Luck = "",
		Rebirth = "",
		Codex = "",
		Journal = "",
		Settings = "",
		Backpack = "",
		Upgrades = "",
	},
	-- White-on-transparent 512 px PNGs from game-icons.net (CC BY 3.0: credit the authors in the game
	-- description). The code tints them gold, so the PNGs must be plain white.
	Gold = {
		-- Big square buttons (left column and bottom bar)
		Shrine = "rbxassetid://137076554638121",
		Luck = "rbxassetid://85966102987859",
		Codex = "rbxassetid://87269601535998",
		Journal = "rbxassetid://118194837572175",
		Settings = "rbxassetid://113821178669410",
		Backpack = "rbxassetid://86450381904245",
		Upgrades = "rbxassetid://106607239407890",
		Rebirth = "",
		-- Hunt buttons
		SpiritSight = "rbxassetid://109721927815846",
		Pulse = "rbxassetid://84197729566806",
		Bind = "rbxassetid://90286145367095",
		-- Travel buttons
		Home = "rbxassetid://101317161757280",
		Hub = "rbxassetid://121911139663673",
		Wild = "rbxassetid://104325337356600",
	},
} :: { Color: { [string]: string }, Gold: { [string]: string } }
