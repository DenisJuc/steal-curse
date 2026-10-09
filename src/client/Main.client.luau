-- Client entry point: builds the UI and hunt controls. The client only shows information and sends intents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClientSettings = require(ReplicatedStorage.Shared.ClientSettings)
local HUD = require(script.Parent.UI.HUD)
local AutoSellPanel = require(script.Parent.UI.AutoSellPanel)
local Banner = require(script.Parent.UI.Banner)
local CodexPanel = require(script.Parent.UI.CodexPanel)
local DiscoveryFeed = require(script.Parent.UI.DiscoveryFeed)
local FocusPanel = require(script.Parent.UI.FocusPanel)
local InventoryPanel = require(script.Parent.UI.InventoryPanel)
local JournalPanel = require(script.Parent.UI.JournalPanel)
local Onboarding = require(script.Parent.UI.Onboarding)
local SettingsPanel = require(script.Parent.UI.SettingsPanel)
local ShrinePanel = require(script.Parent.UI.ShrinePanel)
local Toasts = require(script.Parent.UI.Toasts)
local UIKit = require(script.Parent.UI.UIKit)
local WelcomeBack = require(script.Parent.UI.WelcomeBack)
local Announcements = require(script.Parent.Announcements)
local AfkController = require(script.Parent.Controllers.AfkController)
local GamepadController = require(script.Parent.Controllers.GamepadController)
local KioskController = require(script.Parent.Controllers.KioskController)
local OtherBinds = require(script.Parent.Effects.OtherBinds)
local RevealController = require(script.Parent.Controllers.RevealController)
local HuntController = require(script.Parent.Hunt.HuntController)
local Settings = require(script.Parent.Settings)
local StudioCommands = require(script.Parent.StudioCommands)

local screen = Instance.new("ScreenGui")
screen.Name = "RelicCollectorUI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

Settings.Watch("InterfaceSize", function(value)
	UIKit.SetUserScale(ClientSettings.InterfaceScale[value :: string] or 1)
end)

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
local shrinePanel
local inventoryPanel = InventoryPanel.Start(screen, {
	OnOpenAutoSell = function()
		closeAllExcept(autoSellPanel)
		autoSellPanel.Open()
	end,
	OnPickDone = function()
		closeAllExcept(shrinePanel)
		shrinePanel.Open()
	end,
})
shrinePanel = ShrinePanel.Start(screen, function(slot: number)
	closeAllExcept(inventoryPanel)
	inventoryPanel.Pick(slot)
end)
local focusPanel = FocusPanel.Start(screen)
local codexPanel = CodexPanel.Start(screen)
local journalPanel = JournalPanel.Start(screen)
local settingsPanel = SettingsPanel.Start(screen)
local welcomeBack = WelcomeBack.Start(screen)
menus = { shrinePanel, focusPanel, inventoryPanel, autoSellPanel, codexPanel, journalPanel, settingsPanel, welcomeBack }

local function toggleOnly(menu: Menu & { Toggle: () -> () })
	return function()
		closeAllExcept(menu)
		menu.Toggle()
	end
end

local openers = {
	Shrine = toggleOnly(shrinePanel),
	Luck = toggleOnly(focusPanel),
	Relics = toggleOnly(inventoryPanel),
	Codex = toggleOnly(codexPanel),
	Journal = toggleOnly(journalPanel),
	Settings = toggleOnly(settingsPanel),
}
local hud = HUD.Start(screen, {
	OnShrine = openers.Shrine,
	OnLuck = openers.Luck,
	OnRelics = openers.Relics,
	OnCodex = openers.Codex,
	OnJournal = openers.Journal,
	OnSettings = openers.Settings,
})
KioskController.Start(openers)
DiscoveryFeed.Start(screen)
RevealController.Start(screen)
Toasts.Start(screen)
Banner.Start(screen)
Announcements.Start()
HuntController.Start(screen, {
	-- Spirit Sight hides management UI; scanning itself never stops.
	SetManagementVisible = function(visible: boolean)
		hud.SetVisible(visible)
		if not visible then
			closeAllExcept(nil)
		end
	end,
})
GamepadController.Start(screen, function()
	return screen:FindFirstChild("Buttons", true)
end)
OtherBinds.Start()
Onboarding.Start(screen)
local afk = AfkController.Start()

if RunService:IsStudio() then
	StudioCommands.Start({ SkipToHopWarning = afk.SkipToHopWarning })
end
