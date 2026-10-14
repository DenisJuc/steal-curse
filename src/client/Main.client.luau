-- Client entry point: builds the UI and hunt controls. The client only shows information and sends intents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClientSettings = require(ReplicatedStorage.Shared.ClientSettings)
local HUD = require(script.Parent.UI.HUD)
local AutoSellPanel = require(script.Parent.UI.AutoSellPanel)
local Banner = require(script.Parent.UI.Banner)
local BountyPanel = require(script.Parent.UI.BountyPanel)
local BuffTimers = require(script.Parent.UI.BuffTimers)
local CodexPanel = require(script.Parent.UI.CodexPanel)
local DiscoveryFeed = require(script.Parent.UI.DiscoveryFeed)
local FocusPanel = require(script.Parent.UI.FocusPanel)
local InventoryPanel = require(script.Parent.UI.InventoryPanel)
local JournalPanel = require(script.Parent.UI.JournalPanel)
local MenuMotion = require(script.Parent.UI.MenuMotion)
local Onboarding = require(script.Parent.UI.Onboarding)
local RebirthPanel = require(script.Parent.UI.RebirthPanel)
local RollBar = require(script.Parent.UI.RollBar)
local RollReel = require(script.Parent.UI.RollReel)
local HuntRolls = require(script.Parent.UI.HuntRolls)
local TravelBar = require(script.Parent.UI.TravelBar)
local SettingsPanel = require(script.Parent.UI.SettingsPanel)
local ShowcasePanel = require(script.Parent.UI.ShowcasePanel)
local ShrinePanel = require(script.Parent.UI.ShrinePanel)
local SkillTreePanel = require(script.Parent.UI.SkillTreePanel)
local Toasts = require(script.Parent.UI.Toasts)
local UIKit = require(script.Parent.UI.UIKit)
local WardrobePanel = require(script.Parent.UI.WardrobePanel)
local WelcomeBack = require(script.Parent.UI.WelcomeBack)
local ZoneLabel = require(script.Parent.UI.ZoneLabel)
local Announcements = require(script.Parent.Announcements)
local AfkController = require(script.Parent.Controllers.AfkController)
local GamepadController = require(script.Parent.Controllers.GamepadController)
local KioskController = require(script.Parent.Controllers.KioskController)
local PedestalPrompts = require(script.Parent.Controllers.PedestalPrompts)
local SprintController = require(script.Parent.Controllers.SprintController)
local Ambience = require(script.Parent.Effects.Ambience)
local MapLightLOD = require(script.Parent.Effects.MapLightLOD)
local OtherBinds = require(script.Parent.Effects.OtherBinds)
local ShowcaseLOD = require(script.Parent.Effects.ShowcaseLOD)
local SpiritLantern = require(script.Parent.Effects.SpiritLantern)
local WildVeil = require(script.Parent.Effects.WildVeil)
local StreamLanterns = require(script.Parent.Effects.StreamLanterns)
local WildLife = require(script.Parent.Effects.WildLife)
local LowMist = require(script.Parent.Effects.LowMist)
local WildSounds = require(script.Parent.Effects.WildSounds)
local ZoneBeacon = require(script.Parent.Effects.ZoneBeacon)
local WildFinds = require(script.Parent.Effects.WildFinds)
local LightningAura = require(script.Parent.Effects.LightningAura)
local PlayerTitles = require(script.Parent.Effects.PlayerTitles)
local CursedShrines = require(script.Parent.Effects.CursedShrines)
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
local showcasePanel = ShowcasePanel.Start(screen, function()
	closeAllExcept(shrinePanel)
	shrinePanel.Open()
end)
shrinePanel = ShrinePanel.Start(screen, function(slot: number)
	closeAllExcept(inventoryPanel)
	inventoryPanel.Pick(slot)
end, function()
	closeAllExcept(showcasePanel)
	showcasePanel.Open()
end)
local focusPanel = FocusPanel.Start(screen)
local skillPanel = SkillTreePanel.Start(screen)
local codexPanel = CodexPanel.Start(screen)
local journalPanel = JournalPanel.Start(screen)
local bountyPanel = BountyPanel.Start(screen)
local wardrobePanel = WardrobePanel.Start(screen)
local settingsPanel = SettingsPanel.Start(screen)
local rebirthPanel = RebirthPanel.Start(screen)
local welcomeBack = WelcomeBack.Start(screen)
menus = {
	shrinePanel,
	rebirthPanel,
	showcasePanel,
	focusPanel,
	inventoryPanel,
	autoSellPanel,
	skillPanel,
	codexPanel,
	journalPanel,
	bountyPanel,
	wardrobePanel,
	settingsPanel,
	welcomeBack,
}
MenuMotion.Start(screen)

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
	Skills = toggleOnly(skillPanel),
	Codex = toggleOnly(codexPanel),
	Journal = toggleOnly(journalPanel),
	Bounties = toggleOnly(bountyPanel),
	Wardrobe = toggleOnly(wardrobePanel),
	Settings = toggleOnly(settingsPanel),
	Rebirth = toggleOnly(rebirthPanel),
}
local hud = HUD.Start(screen, {
	OnShrine = openers.Shrine,
	OnLuck = openers.Luck,
	OnRebirth = openers.Rebirth,
	OnCodex = openers.Codex,
	OnJournal = openers.Journal,
	OnSettings = openers.Settings,
})
local rollBar = RollBar.Start(screen, {
	OnBackpack = openers.Relics,
	OnUpgrades = openers.Skills,
})
local travelBar = TravelBar.Start(screen)
BuffTimers.Start(screen)
ZoneLabel.Start(screen)
KioskController.Start(openers)
PedestalPrompts.Start()
RollReel.Start(screen, rollBar.Frame)
HuntRolls.Start(screen)
DiscoveryFeed.Start(screen)
RevealController.Start(screen)
Toasts.Start(screen)
Banner.Start(screen)
Announcements.Start()
HuntController.Start(screen, {
	-- Spirit Sight hides management UI; scanning itself never stops.
	SetManagementVisible = function(visible: boolean)
		hud.SetVisible(visible)
		rollBar.SetSideVisible(visible)
		travelBar.SetVisible(visible)
		RollReel.SetEnabled(visible)
		if not visible then
			closeAllExcept(nil)
		end
	end,
	-- Sealing hides this whole screen; the bind bar lives in its own ScreenGui.
	SetSealing = function(sealing: boolean)
		screen.Enabled = not sealing
		if sealing then
			closeAllExcept(nil)
		end
	end,
})
GamepadController.Start(screen, function()
	return screen:FindFirstChild("Buttons", true)
end)
OtherBinds.Start()
ShowcaseLOD.Start()
Ambience.Start()
SpiritLantern.Start()
WildVeil.Start()
StreamLanterns.Start()
WildLife.Start()
LowMist.Start()
WildSounds.Start()
ZoneBeacon.Start()
WildFinds.Start()
LightningAura.Start()
PlayerTitles.Start()
CursedShrines.Start()
MapLightLOD.Start()
SprintController.Start(screen, rollBar.Frame)
Onboarding.Start(screen)
local afk = AfkController.Start()

if RunService:IsStudio() then
	StudioCommands.Start({ SkipToHopWarning = afk.SkipToHopWarning })
end
