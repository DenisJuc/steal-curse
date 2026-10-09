-- Client entry point: builds the UI and hunt controls. The client only shows information and sends intents.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HUD = require(script.Parent.UI.HUD)
local AutoSellPanel = require(script.Parent.UI.AutoSellPanel)
local Banner = require(script.Parent.UI.Banner)
local CodexPanel = require(script.Parent.UI.CodexPanel)
local DiscoveryFeed = require(script.Parent.UI.DiscoveryFeed)
local FocusPanel = require(script.Parent.UI.FocusPanel)
local InventoryPanel = require(script.Parent.UI.InventoryPanel)
local ShrinePanel = require(script.Parent.UI.ShrinePanel)
local Toasts = require(script.Parent.UI.Toasts)
local HuntController = require(script.Parent.Hunt.HuntController)
local StudioCommands = require(script.Parent.StudioCommands)

local screen = Instance.new("ScreenGui")
screen.Name = "RelicCollectorUI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Every menu opens in the screen center; only one is open at a time.
type Menu = { SetVisible: (boolean) -> () }
local menus: { Menu } = {}
local function closeAllExcept(keep: Menu?)
	for _, menu in menus do
		if menu ~= keep then
			menu.SetVisible(false)
		end
	end
end

local autoSellPanel = AutoSellPanel.Start(screen)
local inventoryPanel = InventoryPanel.Start(screen, function()
	closeAllExcept(autoSellPanel)
	autoSellPanel.Open()
end)
local shrinePanel = ShrinePanel.Start(screen, function()
	closeAllExcept(inventoryPanel)
	inventoryPanel.Toggle()
end)
local focusPanel = FocusPanel.Start(screen)
local codexPanel = CodexPanel.Start(screen)
menus = { shrinePanel, focusPanel, inventoryPanel, autoSellPanel, codexPanel }

local function toggleOnly(menu: Menu & { Toggle: () -> () })
	return function()
		closeAllExcept(menu)
		menu.Toggle()
	end
end

local hud = HUD.Start(screen, {
	OnShrine = toggleOnly(shrinePanel),
	OnLuck = toggleOnly(focusPanel),
	OnRelics = toggleOnly(inventoryPanel),
	OnCodex = toggleOnly(codexPanel),
})
DiscoveryFeed.Start(screen)
Toasts.Start(screen)
Banner.Start(screen)
HuntController.Start(screen, {
	-- Spirit Sight hides management UI; scanning itself never stops.
	SetManagementVisible = function(visible: boolean)
		hud.SetVisible(visible)
		if not visible then
			closeAllExcept(nil)
		end
	end,
})

if RunService:IsStudio() then
	StudioCommands.Start()
end
