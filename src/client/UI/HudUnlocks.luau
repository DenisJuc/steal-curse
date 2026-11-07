-- Roll-only start: a brand-new player first sees only ROLL, Auto Roll, Backpack, Upgrades, the CE
-- counter and Settings. Every other HUD entry stays hidden until a natural milestone, then
-- appears with one short banner. Purely client-side display: no new save fields. It reads stats
-- the server already saves and mirrors (TotalScans, DiscoveredCount, Rebirths, Skill_CoreLuck)
-- plus this session's play time, so veterans (75+ lifetime rolls, a rebirth, or the tutorial
-- finished/skipped) see everything as before, with no banners.
-- An entry the tutorial points at (the "TutorialTarget" attribute Onboarding sets locally)
-- unlocks right then, so an arrow never points at nothing. Unlocks never re-lock in a session.
-- Other code keeps toggling these entries' Visible (Spirit Sight hiding the HUD, the Collection
-- slot only in some modes...): while locked an entry is held hidden and the value the other code
-- wanted is remembered and put back when it unlocks.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.Settings)
local Banner = require(script.Parent.Banner)

local HudUnlocks = {}

-- Everything unlocks at this many lifetime rolls (~5 minutes of Auto Roll at 4 s a roll) or
-- after this long in one session, whichever comes first.
local ALL_SCANS = 75
local ALL_SECONDS = 5 * 60
local BANNER_COLOR = Color3.fromRGB(255, 215, 120)

type Stats = { Scans: number, Discovered: number, CoreLuck: number }

type Gate = {
	Id: string,
	Title: string,
	Text: string,
	-- Descendant names under the main screen to hold hidden while locked.
	Names: { string },
	-- Tutorial targets that unlock this entry when the tutorial reaches them.
	Targets: { string },
	When: (Stats) -> boolean,
}

local GATES: { Gate } = {
	{
		Id = "Pedestals",
		Title = "PEDESTALS UNLOCKED",
		Text = "Upgrade pedestals to earn more CE",
		Names = { "ShrineButtonSlot" },
		Targets = { "ShrineButton", "ShrineMenu/Upgrade" },
		When = function(s)
			return s.Scans >= 10
		end,
	},
	{
		Id = "Gifts",
		Title = "GIFTS UNLOCKED",
		Text = "Free gifts while you play",
		Names = { "GiftButton", "ShopButton" },
		Targets = { "GiftButton" },
		When = function(s)
			return s.Scans >= 25
		end,
	},
	{
		Id = "Codex",
		Title = "CODEX UNLOCKED",
		Text = "Every relic you find, with milestone rewards",
		Names = { "CodexButtonSlot", "CollectionButtonSlot" },
		Targets = { "CodexButton", "CollectionButton" },
		When = function(s)
			return s.Discovered >= 8
		end,
	},
	{
		Id = "Luck",
		Title = "LUCK UNLOCKED",
		Text = "See every boost to your luck",
		Names = { "LuckButtonSlot" },
		Targets = {},
		When = function(s)
			return s.CoreLuck >= 1 or s.Scans >= 40
		end,
	},
	{
		Id = "Hunt",
		Title = "SPIRIT SIGHT UNLOCKED",
		Text = "Hunt signals in the wild",
		Names = { "SpiritSightSlot", "HubSlot", "ShrinesSlot" },
		Targets = { "SpiritSight" },
		When = function(s)
			return s.Scans >= 50
		end,
	},
	{
		Id = "Journal",
		Title = "JOURNAL UNLOCKED",
		Text = "Your best finds and records",
		Names = { "JournalButtonSlot", "RebirthButtonSlot" },
		Targets = {},
		When = function(s)
			return s.Scans >= 60
		end,
	},
}

local function number(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

-- True once the server has sent this player's saved stats.
local function loaded(player: Player): boolean
	return player:GetAttribute("TotalScans") ~= nil and player:GetAttribute("Setting_Hints") ~= nil
end

local function isVeteran(player: Player): boolean
	return number(player, "TotalScans") >= ALL_SCANS
		or number(player, "Rebirths") > 0
		or Settings.Get("Hints") == "Off"
end

function HudUnlocks.Start(screen: ScreenGui)
	local player = Players.LocalPlayer
	local started = os.clock()
	local unlocked: { [string]: boolean } = {}
	-- Per held object: the Visible other code wants (restored on unlock).
	local wanted: { [GuiObject]: boolean } = {}
	local holding: { [GuiObject]: string } = {}
	local muting = false

	local function hold(object: GuiObject, gateId: string)
		if holding[object] or unlocked[gateId] then
			return
		end
		holding[object] = gateId
		wanted[object] = object.Visible
		object:GetPropertyChangedSignal("Visible"):Connect(function()
			if muting or not holding[object] then
				return
			end
			if unlocked[holding[object]] then
				return
			end
			wanted[object] = object.Visible
			if object.Visible then
				muting = true
				object.Visible = false
				muting = false
			end
		end)
		muting = true
		object.Visible = false
		muting = false
	end

	local byName: { [string]: Gate } = {}
	for _, gate in GATES do
		for _, name in gate.Names do
			byName[name] = gate
		end
	end
	local function consider(object: Instance)
		local gate = byName[object.Name]
		if gate and object:IsA("GuiObject") then
			hold(object, gate.Id)
		end
	end
	for _, object in screen:GetDescendants() do
		consider(object)
	end
	screen.DescendantAdded:Connect(consider)

	local function unlock(gate: Gate, announce: boolean)
		if unlocked[gate.Id] then
			return
		end
		unlocked[gate.Id] = true
		for object, gateId in holding do
			if gateId == gate.Id then
				holding[object] = nil
				muting = true
				object.Visible = wanted[object] ~= false
				muting = false
				wanted[object] = nil
			end
		end
		if announce then
			Banner.Show(gate.Title, gate.Text, BANNER_COLOR)
		end
	end

	local ready = false
	local check = 0
	RunService.Heartbeat:Connect(function(dt)
		check += dt
		if check < 0.5 then
			return
		end
		check = 0
		if not loaded(player) then
			return
		end
		-- The first look after load is silent: returning players get their entries without banners.
		local announce = ready
		ready = true
		local all = isVeteran(player) or os.clock() - started >= ALL_SECONDS
		local stats: Stats = {
			Scans = number(player, "TotalScans"),
			Discovered = number(player, "DiscoveredCount"),
			CoreLuck = number(player, "Skill_CoreLuck"),
		}
		local target = player:GetAttribute("TutorialTarget")
		local rest = 0
		for _, gate in GATES do
			if unlocked[gate.Id] then
				continue
			end
			local pointed = table.find(gate.Targets, target) ~= nil
			if pointed or gate.When(stats) then
				unlock(gate, announce)
			elseif all then
				-- Time's up or tutorial done: open the rest with one banner, not a burst of them.
				unlock(gate, false)
				rest += 1
			end
		end
		if rest > 0 and announce then
			Banner.Show("EVERYTHING UNLOCKED", "Every menu is open now", BANNER_COLOR)
		end
	end)
end

return HudUnlocks
