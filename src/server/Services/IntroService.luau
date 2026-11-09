-- First-minute intro hunt, server side (Config.Intro). A brand new save (no rolls, IntroDone
-- false) gets the "IntroPending" attribute; the client plays its loading screen, then asks to
-- "Start": the character goes to the glade (IntroLayout) and "InIntro" keeps the zone gates off
-- it. "Finish" (the spirit is sealed) and "Skip" both end it the same way: IntroDone is saved, the
-- first seal's relic (Config.Intro.FirstSeal) is granted as a capture, and the player goes home.
-- Respawning mid-intro puts the character back in the glade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local IntroLayout = require(ReplicatedStorage.Shared.IntroLayout)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local DiscoveryPipeline = require(script.Parent.Parent.DiscoveryPipeline)

local IntroEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("IntroEvent") :: RemoteEvent

local IntroService = {}

local function pending(player: Player): boolean
	return player:GetAttribute("IntroPending") == true
end

local function toGlade(player: Player)
	local character = player.Character
	if character then
		character:PivotTo(IntroLayout.frame(IntroLayout.Wake + Vector3.new(0, 3.5, 0)))
	end
end

local function finish(player: Player, sealed: boolean)
	if not pending(player) then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.IntroDone = true
	player:SetAttribute("IntroPending", false)
	player:SetAttribute("InIntro", false)
	local home = PlotService.HomeCFrame(player)
	if home and player.Character then
		player.Character:PivotTo(home)
	end
	-- The sealed spirit becomes the first relic (skipping still gives it, so both paths match).
	DiscoveryPipeline.Grant(player, { Config.Intro.FirstSeal }, if sealed then "Capture" else "Bonus")
	DataService.RequestSave(player)
end

local function onEvent(player: Player, action: unknown)
	if action == "Start" then
		if pending(player) and player:GetAttribute("InIntro") ~= true then
			player:SetAttribute("InIntro", true)
			toGlade(player)
		end
	elseif action == "Finish" or action == "Skip" then
		finish(player, action == "Finish")
	end
end

function IntroService.Init()
	DataService.OnPlayerLoaded(function(player: Player)
		local data = DataService.Get(player)
		local fresh = data ~= nil and not data.IntroDone and (data.TotalScans or 0) == 0
		player:SetAttribute("IntroPending", Config.Intro.Enabled and fresh)
		if data and not fresh and not data.IntroDone then
			-- Older saves never see the intro.
			data.IntroDone = true
		end
		player.CharacterAdded:Connect(function()
			if player:GetAttribute("InIntro") == true then
				task.wait(0.2)
				toGlade(player)
			end
		end)
	end)
	RemoteGuard.Event(IntroEvent, onEvent)
end

return IntroService
