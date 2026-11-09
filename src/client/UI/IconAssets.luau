-- Interface icon images, uploaded to Roblox. Paste each image id as "rbxassetid://123". These must
-- be image ids, not the decal ids Creator Hub lists (a decal id shows nothing).
-- Color wins over Gold for the same key; an empty id falls through to the next source, and finally
-- to the frame-drawn placeholder (Icons.luau), or no icon for text buttons.

return {
	-- Full-color, pre-shaded icons (the "3D" look of big simulators: an object with its own dark
	-- outline and highlights, transparent background, square). Shown as they are, larger than the
	-- gold ones, with a soft drop shadow.
	-- Most come from gvesster's Free Icon Pack (source PNGs: assets/PackIcons). Its license allows
	-- use as they are but not recolors or edits, so upload those PNGs untouched. The rest are
	-- generated placeholders (assets/Icons, cut out with tools/icon_cutout.py) until a pack has a fit.
	Color = {
		-- Big square buttons (left column and bottom bar)
		Luck = "rbxassetid://133633712186433",
		-- gvesster free pack (CoinsPMetall, BronzeChest), uploaded 2026-11-08.
		Shop = "rbxassetid://114599455575955",
		Gift = "rbxassetid://118679306136275",
		Rebirth = "rbxassetid://123009932980997",
		Codex = "rbxassetid://110657794557639",
		-- Collection reuses Favorite (star) until a dedicated pack icon is uploaded.
		Collection = "rbxassetid://81737674690563",
		Journal = "rbxassetid://119825831421094",
		Settings = "rbxassetid://86511230715801",
		Backpack = "rbxassetid://88950011733907",
		Pedestals = "rbxassetid://110880499516489",
		Upgrades = "rbxassetid://136448324782724",
		-- Cursed Shrine / world shrine art (not the Pedestals HUD button)
		Shrine = "rbxassetid://127615523460883",
		-- Hunt buttons
		SpiritSight = "rbxassetid://113687364744422",
		Pulse = "rbxassetid://94180052402536",
		Bind = "rbxassetid://111791914133594",
		-- Travel buttons
		Home = "rbxassetid://74338014667306",
		Hub = "rbxassetid://97844917767404",
		Wild = "rbxassetid://87600690966822", -- WildPlanet
		-- Small inline icons
		CursedEnergy = "rbxassetid://84180423054234",
		PotionLuck = "rbxassetid://72858991022006",
		PotionHaste = "rbxassetid://114308167326765",
		PotionFortune = "rbxassetid://135191041142420",
		Lock = "rbxassetid://87756482273922",
		Unlock = "rbxassetid://106525697863157",
		Favorite = "rbxassetid://81737674690563",
		Lightning = "rbxassetid://131679729804203",
		Streak = "rbxassetid://104068008612249",
		Warning = "rbxassetid://114610539136625",
		Info = "rbxassetid://106107686530022",
	},
	-- White-on-transparent 512 px PNGs from game-icons.net (CC BY 3.0: credit the authors in the game
	-- description). The code tints them gold, so the PNGs must be plain white.
	Gold = {
		-- Big square buttons (left column and bottom bar)
		Pedestals = "rbxassetid://137076554638121",
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
