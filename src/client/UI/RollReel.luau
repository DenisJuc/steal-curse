-- The roll animation above the bottom bar (Slice 9, restyled). Every reward is already rolled and
-- saved by the server; the animation only plays out to it, in the style picked in Settings
-- ("RollStyle": Omikuji, Flicker or Flame, see UI/RollStyles). Plain scan batches (up to
-- Config.Scan.MaxCatchUpScans finds) roll first and land on the rarest find; big batches skip
-- the roll. A hunt's batch (capture + bonus finds) waits for HuntController, which rolls it on
-- the hunt papers (HuntRolls) after the capture animation.
-- This module owns the DiscoveryResult connection for the feed and the reveals: they receive each
-- batch through RollReel.OnResults once the roll has landed (right away when there is no roll).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local ReelStrip = require(ReplicatedStorage.Shared.ReelStrip)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Settings = require(script.Parent.Parent.Settings)
local RollKit = require(script.Parent.RollStyles.RollKit)
local UIKit = require(script.Parent.UIKit)

local DiscoveryResult = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DiscoveryResult") :: RemoteEvent

local RollReel = {}

local STYLES: { [string]: { new: (GuiObject) -> RollKit.Style } } = {
	Flicker = require(script.Parent.RollStyles.Flicker),
	Flame = require(script.Parent.RollStyles.Flame),
	Omikuji = require(script.Parent.RollStyles.Omikuji),
}
-- How long the result stays up after landing.
local HOLD_SECONDS = 1.8
-- Gap between the roll and the top of the bottom bar (room for the stamina bar, SprintController).
local LIFT = 30

local roster: { ReelStrip.Entry } = {}
for _, relic in RelicConfig.Relics do
	table.insert(roster, { Id = relic.Id, Tier = relic.Tier })
end
local stripOptions = {
	Length = Config.Roll.StripLength,
	LandIndex = Config.Roll.LandIndex,
	TierWeights = Config.Roll.TeaserTierWeights,
}

-- A hunt's batch waits this long for HuntController to take it (after the capture animation)
-- before it is shown the plain way.
local HUNT_WAIT_SECONDS = 20

local listeners: { ({ any }, boolean) -> () } = {}
local rng = Random.new()
local style: RollKit.Style? = nil
local spinning = false
local spinTicket = 0
local enabled = true
local pendingHunt: { any }? = nil

local function nextNumber(): number
	return rng:NextNumber()
end

local function tierIndex(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return if relic then RarityConfig.IndexById[relic.Tier] or 0 else 0
end

-- `hunt` marks a hunt's batch that has already been rolled on the papers (HuntRolls).
local function dispatch(results: { any }, hunt: boolean?)
	for _, listener in listeners do
		task.spawn(listener, results, hunt == true)
	end
end

local function isHunt(results: { any }): boolean
	for _, result in results do
		if type(result) == "table" and result.Source == "Capture" then
			return true
		end
	end
	return false
end

local function rollSeconds(): number
	local interval = Players.LocalPlayer:GetAttribute("ScanInterval")
	return ReelStrip.duration(
		tostring(Settings.Get("RollAnimation")),
		if type(interval) == "number" then interval else Config.Scan.BaseIntervalSeconds,
		Config.Roll
	)
end

-- Plays the roll; returns its full length (rare results get a hush before landing).
local function spin(target: { Id: string, Mutation: string? }, seconds: number): number
	local current = style
	if not current then
		return 0
	end
	spinTicket += 1
	local ticket = spinTicket
	spinning = true
	local result = RollKit.info(target.Id, target.Mutation)
	local suspense = RollKit.suspense(result) * (if Settings.Get("RollAnimation") == "Fast" then 0.5 else 1)
	seconds += suspense
	current.Play({
		Result = result,
		Teasers = ReelStrip.strip(target.Id, nextNumber, roster, stripOptions),
		Seconds = seconds,
		Suspense = suspense,
	})
	task.delay(seconds, function()
		if spinTicket ~= ticket then
			return
		end
		spinning = false
		task.delay(HOLD_SECONDS + suspense * 1.5, function()
			if spinTicket == ticket and style then
				style.Hide()
			end
		end)
	end)
	return seconds
end

-- A plain scan batch the roll can play for: returns the rarest find, else nil.
local function rollTarget(results: { any }): any?
	if #results == 0 or #results > Config.Scan.MaxCatchUpScans then
		return nil
	end
	local best = nil
	for _, result in results do
		if type(result) ~= "table" or result.Source ~= "Scan" or type(result.Id) ~= "string" then
			return nil
		end
		if not best or tierIndex(result.Id) > tierIndex(best.Id) then
			best = result
		end
	end
	return best
end

local function onResults(results: any)
	if type(results) ~= "table" then
		return
	end
	if isHunt(results) then
		if pendingHunt then
			dispatch(pendingHunt)
		end
		pendingHunt = results
		task.delay(HUNT_WAIT_SECONDS, function()
			if pendingHunt == results then
				pendingHunt = nil
				dispatch(results)
			end
		end)
		return
	end
	local target = rollTarget(results)
	local seconds = if target and enabled and not spinning and style then rollSeconds() else 0
	if seconds <= 0 then
		dispatch(results)
		return
	end
	task.delay(spin(target, seconds), dispatch, results)
end

-- Spirit Sight turns the roll off (its bind bar uses the same screen space); results then show
-- right away.
function RollReel.SetEnabled(on: boolean)
	enabled = on
	if not on and style then
		spinTicket += 1
		spinning = false
		style.Hide()
	end
end

-- Runs `callback(results, hunt)` for every DiscoveryResult batch, after its roll (if any) has
-- landed. `hunt` is true for a hunt's batch that already rolled on the hunt papers.
function RollReel.OnResults(callback: ({ any }, boolean) -> ())
	table.insert(listeners, callback)
end

-- The last hunt's batch (its capture and bonus finds), waiting up to `seconds` for it to arrive.
-- Taking it means the caller rolls it and hands it back with FinishHunt.
function RollReel.TakeHunt(seconds: number): { any }?
	local deadline = os.clock() + seconds
	while not pendingHunt and os.clock() < deadline do
		task.wait(0.05)
	end
	local results = pendingHunt
	pendingHunt = nil
	return results
end

function RollReel.FinishHunt(results: { any })
	dispatch(results, true)
end

-- Plays a roll for `relicId` without granting anything (Studio /rolldemo).
function RollReel.Demo(relicId: string, mutation: string?)
	local seconds = rollSeconds()
	spin({ Id = relicId, Mutation = mutation }, if seconds > 0 then seconds else Config.Roll.ReelMaxSeconds)
end

-- `anchor` is the bottom bar: the roll sits centered just above it, following its size changes.
function RollReel.Start(screen: ScreenGui, anchor: GuiObject?)
	local holder = UIKit.create("Frame", {
		Name = "RollReel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(340, 180),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = screen,
	})
	UIKit.scaler(holder)
	RollKit.Start(screen)
	if anchor then
		RunService.RenderStepped:Connect(function()
			local offset = anchor.AbsolutePosition - screen.AbsolutePosition
			holder.Position = UDim2.fromOffset(offset.X + anchor.AbsoluteSize.X / 2, offset.Y - LIFT)
		end)
	end

	local styleName = ""
	Settings.Watch("RollStyle", function(value)
		local name = if STYLES[tostring(value)] then tostring(value) else "Omikuji"
		if name == styleName then
			return
		end
		styleName = name
		local build = STYLES[name]
		if style then
			style.Destroy()
		end
		spinTicket += 1
		spinning = false
		style = build.new(holder)
	end)

	DiscoveryResult.OnClientEvent:Connect(onResults)
end

return RollReel
