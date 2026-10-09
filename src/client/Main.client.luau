-- Client entry point: builds the UI and hunt controls. The client only shows information and sends intents.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HUD = require(script.Parent.UI.HUD)
local DiscoveryFeed = require(script.Parent.UI.DiscoveryFeed)
local Toasts = require(script.Parent.UI.Toasts)
local HuntController = require(script.Parent.Hunt.HuntController)
local StudioCommands = require(script.Parent.StudioCommands)

local screen = Instance.new("ScreenGui")
screen.Name = "RelicCollectorUI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local hud = HUD.Start(screen)
DiscoveryFeed.Start(screen)
Toasts.Start(screen)
HuntController.Start(screen, {
	SetManagementVisible = hud.SetVisible,
})

if RunService:IsStudio() then
	StudioCommands.Start()
end
