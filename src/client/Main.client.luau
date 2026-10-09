-- Client entry point: builds the UI and hunt controls. The client only shows information and sends intents.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HUD = require(script.Parent.UI.HUD)
local DiscoveryFeed = require(script.Parent.UI.DiscoveryFeed)
local FocusPanel = require(script.Parent.UI.FocusPanel)
local ShrinePanel = require(script.Parent.UI.ShrinePanel)
local Toasts = require(script.Parent.UI.Toasts)
local HuntController = require(script.Parent.Hunt.HuntController)
local StudioCommands = require(script.Parent.StudioCommands)

local screen = Instance.new("ScreenGui")
screen.Name = "RelicCollectorUI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Both menus open in the screen center; opening one closes the other.
local focusPanel = FocusPanel.Start(screen)
local shrinePanel = ShrinePanel.Start(screen)
local hud = HUD.Start(screen, function()
	focusPanel.SetVisible(false)
	shrinePanel.Toggle()
end, function()
	shrinePanel.SetVisible(false)
	focusPanel.Toggle()
end)
DiscoveryFeed.Start(screen)
Toasts.Start(screen)
HuntController.Start(screen, {
	-- Spirit Sight hides management UI; scanning itself never stops.
	SetManagementVisible = function(visible: boolean)
		hud.SetVisible(visible)
		focusPanel.SetVisible(visible)
		shrinePanel.SetVisible(visible)
	end,
})

if RunService:IsStudio() then
	StudioCommands.Start()
end
