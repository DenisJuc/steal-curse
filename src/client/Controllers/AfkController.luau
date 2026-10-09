-- Tells the server when this player goes idle and comes back (the AFK log behind Welcome Back),
-- and runs the anti-AFK hop: shortly before Roblox's 20-minute idle kick a banner warns, then the
-- server moves the player to a fresh server so they can keep AFKing. Nothing pops up when the
-- player comes back in the same server; the game just keeps playing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Banner = require(script.Parent.Parent.UI.Banner)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetAfk = Remotes:WaitForChild("SetAfk") :: RemoteEvent
local AfkHop = Remotes:WaitForChild("AfkHop") :: RemoteEvent

local AfkController = {}

local CHECK_SECONDS = 1
local HOP_RETRY_SECONDS = 60

export type Controller = {
	-- Studio test: jump the idle timer to the anti-AFK warning.
	SkipToHopWarning: () -> (),
}

function AfkController.Start(): Controller
	local player = Players.LocalPlayer
	local lastInput = os.clock()
	local awaySent, returnSent, warned = false, false, false
	local nextHopAttempt = 0

	local function onInput()
		lastInput = os.clock()
		awaySent = false
		warned = false
		if player:GetAttribute("Afk") == true and not returnSent then
			returnSent = true
			SetAfk:FireServer(false)
		end
	end
	player:GetAttributeChangedSignal("Afk"):Connect(function()
		returnSent = false
	end)

	UserInputService.InputBegan:Connect(onInput)
	UserInputService.InputChanged:Connect(function(input)
		local kind = input.UserInputType
		local pointer = kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch
		local stick = kind == Enum.UserInputType.Gamepad1 and input.Position.Magnitude > 0.3
		if pointer or stick then
			onInput()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local idle = os.clock() - lastInput
			if idle >= Config.Afk.MarkAfterSeconds and not awaySent then
				awaySent = true
				SetAfk:FireServer(true)
			end
			if idle >= Config.Afk.HopAfterSeconds - Config.Afk.HopWarningSeconds and not warned then
				warned = true
				Banner.Show(
					"ANTI-AFK",
					`Moving you to a fresh server in {Config.Afk.HopWarningSeconds} s so you can keep AFKing. `
						.. "Move to stay here.",
					UIKit.Colors.Gold
				)
			end
			if idle >= Config.Afk.HopAfterSeconds and os.clock() >= nextHopAttempt then
				nextHopAttempt = os.clock() + HOP_RETRY_SECONDS
				AfkHop:FireServer()
			end
		end
	end)

	return {
		SkipToHopWarning = function()
			lastInput = os.clock() - (Config.Afk.HopAfterSeconds - Config.Afk.HopWarningSeconds)
			nextHopAttempt = 0
		end,
	}
end

return AfkController
