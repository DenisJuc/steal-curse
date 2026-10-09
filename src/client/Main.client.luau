-- Client entry point: builds the UI. The client only shows information and sends intents.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HUD = require(script.Parent.UI.HUD)
local DiscoveryFeed = require(script.Parent.UI.DiscoveryFeed)
local Toasts = require(script.Parent.UI.Toasts)
local StudioCommands = require(script.Parent.StudioCommands)

local screen = Instance.new("ScreenGui")
screen.Name = "RelicCollectorUI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

HUD.Start(screen)
DiscoveryFeed.Start(screen)
Toasts.Start(screen)

if RunService:IsStudio() then
	StudioCommands.Start()
end
