-- Roll-only start: a brand-new player first sees only ROLL, Auto Roll, Backpack, Upgrades, the CE
-- counter and Settings. Every other HUD entry stays hidden until a natural milestone, then
-- appears with one short banner. Purely client-side display: no new save fields. It reads stats
-- the server already saves and mirrors (TotalScans, DiscoveredCount, Rebirths, Skill_CoreLuck)
-- so veterans (75+ lifetime rolls or a rebirth) see everything as before, with no banners.
-- Finishing or skipping the tutorial does NOT unlock everything: a new player keeps the
-- roll-only start and earns each entry at its milestone.
-- An entry the tutorial points at (the "TutorialTarget" attribute Onboarding sets locally)
-- unlocks right then, so an arrow never points at nothing. Unlocks never re-lock in a session.
-- Other code keeps toggling these entries' Visible (Spirit Sight hiding the HUD, the Collection
-- slot only in some modes...): while locked an entry is held hidden and the value the other code
-- wanted is remembered and put back when it unlocks.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Banner = require(script.Parent.Banner)
local Toasts = require(script.Parent.Toasts)

local HudUnlocks = {}

-- Shared state (set by Start): which gates are open, the latest stats, and a change signal for the
-- chip above ROLL and locked world prompts. Before Start everything counts as unlocked.
local started = false
local unlockedState: { [string]: boolean } = {}
local latest = { Scans = 0, Discovered = 0, CoreLuck = 0 }
local changedEvent = Instance.new("BindableEvent")
HudUnlocks.Changed = changedEvent.Event

-- Everything unlocks at this many lifetime rolls (~5 minutes of Auto Roll at 4 s a roll).
local ALL_SCANS = 75
local BANNER_COLOR = Color3.fromRGB(255, 215, 120)

type Stats = { Scans: number, Discovered: number, CoreLuck: number }

type Gate = {
	Id: string,
	-- Short name for the "next unlock" chip and locked prompts.
	Label: string,
	-- The milestone shown to the player (When may also accept other routes, e.g. a Core Luck buy).
	Rule: { Stat: "Scans" | "Discovered", At: number },
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
		Label = "Pedestals",
		Rule = { Stat = "Scans", At = 10 },
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
		Label = "Gifts",
		Rule = { Stat = "Scans", At = 25 },
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
		Label = "Codex",
		Rule = { Stat = "Discovered", At = 8 },
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
		Label = "Luck",
		Rule = { Stat = "Scans", At = 40 },
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
		Label = "Spirit Sight",
		Rule = { Stat = "Scans", At = 50 },
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
		Label = "Journal",
		Rule = { Stat = "Scans", At = 60 },
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
	return number(player, "TotalScans") >= ALL_SCANS or number(player, "Rebirths") > 0
end

local gateById: { [string]: Gate } = {}
for _, gate in GATES do
	gateById[gate.Id] = gate
end

-- Which gate each menu belongs to (hub kiosks and HUD openers share these names).
HudUnlocks.MenuGate = {
	Shrine = "Pedestals",
	Codex = "Codex",
	Collection = "Codex",
	Luck = "Luck",
	Journal = "Journal",
	Rebirth = "Journal",
} :: { [string]: string }

function HudUnlocks.IsUnlocked(gateId: string?): boolean
	if not started or not gateId or not gateById[gateId] then
		return true
	end
	return unlockedState[gateId] == true
end

local function unitOf(stat: string, count: number): string
	if stat == "Discovered" then
		return if count == 1 then "discovery" else "discoveries"
	end
	return if count == 1 then "roll" else "rolls"
end

-- "Unlocks at 50 rolls" and "(you: 12)" for a locked gate.
function HudUnlocks.Requirement(gateId: string): (string, string)
	local gate = gateById[gateId]
	if not gate then
		return "", ""
	end
	local rule = gate.Rule
	local have = math.floor((latest :: any)[rule.Stat] or 0)
	local noun = if rule.Stat == "Discovered" then "relics found" else "rolls"
	return `Unlocks at {rule.At} {noun}`, `(you: {have})`
end

export type NextUnlock = { Id: string, Label: string, Remaining: number, Unit: string, Progress: number }

-- The locked entry closest to opening (by progress), or nil once everything is open.
function HudUnlocks.Next(): NextUnlock?
	if not started then
		return nil
	end
	local best: NextUnlock? = nil
	for _, gate in GATES do
		if unlockedState[gate.Id] then
			continue
		end
		local rule = gate.Rule
		local have = (latest :: any)[rule.Stat] or 0
		local remaining = math.max(1, math.ceil(rule.At - have))
		local progress = math.clamp(have / rule.At, 0, 1)
		if not best or progress > best.Progress then
			best = { Id = gate.Id, Label = gate.Label, Remaining = remaining, Unit = unitOf(rule.Stat, remaining), Progress = progress }
		end
	end
	return best
end

-- Shows the lock on a world prompt (kiosk, shrine, offering box) while `gateId` is locked:
-- ActionText "Locked", ObjectText "Unlocks at 50 rolls", instant trigger (the owner's handler
-- checks IsUnlocked and calls Explain). Restores the prompt once the gate opens.
function HudUnlocks.WatchPrompt(prompt: ProximityPrompt, gateId: string)
	local original = { Action = prompt.ActionText, Object = prompt.ObjectText, Hold = prompt.HoldDuration }
	local lockedShown = false
	local function apply()
		if not prompt.Parent then
			return
		end
		if HudUnlocks.IsUnlocked(gateId) then
			if lockedShown then
				lockedShown = false
				prompt.ActionText = original.Action
				prompt.ObjectText = original.Object
				prompt.HoldDuration = original.Hold
			end
			return
		end
		if not lockedShown then
			original = { Action = prompt.ActionText, Object = prompt.ObjectText, Hold = prompt.HoldDuration }
			lockedShown = true
		end
		prompt.ActionText = "Locked"
		prompt.ObjectText = (HudUnlocks.Requirement(gateId))
		prompt.HoldDuration = 0
	end
	apply()
	local connection
	connection = HudUnlocks.Changed:Connect(function()
		if not prompt.Parent then
			connection:Disconnect()
			return
		end
		apply()
	end)
end

-- One toast saying why something is locked: "Unlocks at 50 rolls (you: 12)".
function HudUnlocks.Explain(gateId: string)
	local need, have = HudUnlocks.Requirement(gateId)
	Toasts.Show(`{gateById[gateId] and gateById[gateId].Label or "This"}: {need} {have}`)
end

-- Wraps a menu opener so a locked menu explains itself instead of opening.
function HudUnlocks.Guard(menu: string, open: () -> ()): () -> ()
	return function()
		local gateId = HudUnlocks.MenuGate[menu]
		if gateId and not HudUnlocks.IsUnlocked(gateId) then
			HudUnlocks.Explain(gateId)
			return
		end
		open()
	end
end

function HudUnlocks.Start(screen: ScreenGui)
	local player = Players.LocalPlayer
	local unlocked = unlockedState
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
		local all = isVeteran(player)
		local stats: Stats = {
			Scans = number(player, "TotalScans"),
			Discovered = number(player, "DiscoveredCount"),
			CoreLuck = number(player, "Skill_CoreLuck"),
		}
		latest = stats
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
				-- 75 rolls or a rebirth: open the rest with one banner, not a burst of them.
				unlock(gate, false)
				rest += 1
			end
		end
		if rest > 0 and announce then
			Banner.Show("EVERYTHING UNLOCKED", "Every menu is open now", BANNER_COLOR)
		end
		-- Locks only apply once the saved stats have been judged (no flash of "Locked" on join).
		started = true
		changedEvent:Fire()
	end)
end

return HudUnlocks
