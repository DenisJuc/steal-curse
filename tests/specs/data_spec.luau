-- Saved data template and migrations (pure parts of persistence; the ProfileStore paths are
-- covered by /runtests in Studio).

local Config = require("../../src/shared/Config")
local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local DataTemplate = require("../../src/server/Data/DataTemplate")
local Migrations = require("../../src/server/Data/Migrations")
local expect = require("../lib/expect")

local function v0Fixture()
	-- Shape saved by Slice 0/1 (no DataVersion, Discovered, RareHistory, Settings or Skills).
	return {
		TotalScans = 40,
		TotalCaptures = 2,
		NextUid = 4,
		Inventory = {
			{ Uid = 1, Id = "CrackedPrayerBead", At = 1000, Source = "Scan" },
			{ Uid = 2, Id = "InkboundSigilTome", At = 1100, Source = "Capture" },
			{ Uid = 3, Id = "CrackedPrayerBead", At = 1200, Source = "Bonus" },
		},
	}
end

local function reconcile(target: any, template: any)
	for key, value in template do
		if target[key] == nil then
			target[key] = DataTemplate.deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

local function isSaveSafe(value: any, path: string)
	local kind = type(value)
	expect.truthy(kind == "number" or kind == "string" or kind == "boolean" or kind == "table", `{path} is {kind}`)
	if kind == "table" then
		for key, inner in value do
			expect.truthy(type(key) == "string" or type(key) == "number", `{path} has a {type(key)} key`)
			isSaveSafe(inner, `{path}.{key}`)
		end
	end
end

return {
	{
		Name = "template defaults match config and contain only DataStore-safe values",
		Run = function()
			local template = DataTemplate.Template
			expect.equal(template.DataVersion, DataTemplate.Version, "template version")
			expect.equal(template.Settings.RarityFocus, Config.Focus.Default, "focus default")
			expect.equal(template.Settings.Frequency, Config.Frequency.Default, "frequency default")
			expect.equal(#template.Pedestals, Config.Plots.StartingPedestals, "free starting pedestals")
			expect.equal(template.CE, 0, "starting CE")
			isSaveSafe(template, "Data")
		end,
	},
	{
		Name = "fresh() is an independent deep copy",
		Run = function()
			local data = DataTemplate.fresh()
			table.insert(data.Inventory, { Uid = 1, Id = "X", At = 0, Source = "Scan" })
			data.Settings.RarityFocus = "Epic"
			expect.equal(#DataTemplate.Template.Inventory, 0, "template inventory untouched")
			expect.equal(DataTemplate.Template.Settings.RarityFocus, "MaxLuck", "template settings untouched")
		end,
	},
	{
		Name = "unversioned Slice 0/1 data migrates to the current version without losing relics",
		Run = function()
			local data = v0Fixture()
			expect.equal(Migrations.run(data, DataTemplate.Version), "Migrated", "outcome")
			reconcile(data, DataTemplate.Template)
			expect.equal(data.DataVersion, DataTemplate.Version, "version")
			expect.equal(#data.Inventory, 3, "inventory kept")
			expect.equal(data.TotalScans, 40, "scans kept")
			expect.equal(data.Discovered.PaladynsNecklace, 1000, "first find time kept (renamed)")
			expect.equal(data.Discovered.QuadLeafGrimoire, 1100, "epic discovered (renamed)")
			expect.equal(data.Inventory[1].Id, "PaladynsNecklace", "held relic renamed")
			expect.equal(#data.RareHistory, 0, "history starts empty")
			expect.equal(data.Skills.CoreLuck, 0, "skills reconciled")
		end,
	},
	{
		Name = "migrations are idempotent and never downgrade newer data",
		Run = function()
			local data = v0Fixture()
			Migrations.run(data, DataTemplate.Version)
			expect.equal(Migrations.run(data, DataTemplate.Version), "Current", "second run")
			local newer = { DataVersion = DataTemplate.Version + 3, Inventory = {} }
			expect.equal(Migrations.run(newer, DataTemplate.Version), "Newer", "newer outcome")
			expect.equal(newer.DataVersion, DataTemplate.Version + 3, "newer version untouched")
			expect.equal(newer.Discovered, nil, "newer data not modified")
		end,
	},
	{
		Name = "v1 data gains the seen-mutation Codex record from held relics",
		Run = function()
			local data = {
				DataVersion = 1,
				Discovered = { HeartOfTheLastEclipse = 50, CrackedPrayerBead = 10 },
				Inventory = {
					{ Uid = 1, Id = "HeartOfTheLastEclipse", Mutation = "Abyssal", At = 50, Source = "Scan" },
					{ Uid = 2, Id = "CrackedPrayerBead", At = 10, Source = "Scan" },
					{ Uid = 3, Id = "HeartOfTheLastEclipse", Mutation = "Golden", At = 70, Source = "Bonus" },
				},
			}
			expect.equal(Migrations.run(data, DataTemplate.Version), "Migrated", "outcome")
			reconcile(data, DataTemplate.Template)
			expect.equal(data.CodexMutations.RedStoneOfAia.Abyssal, 50, "abyssal recorded")
			expect.equal(data.CodexMutations.RedStoneOfAia.Golden, 70, "golden recorded")
			expect.equal(data.CodexMutations.PaladynsNecklace, nil, "plain relic has no mutation record")
			expect.equal(#data.Inventory, 3, "inventory kept")
			expect.equal(data.Settings.AutoSell.ProtectFirst, true, "auto-sell settings reconciled")
		end,
	},
	{
		Name = "v2 data drops Auto-Display and the old numeric interface size, keeping everything else",
		Run = function()
			local data = {
				DataVersion = 2,
				CE = 50,
				Inventory = { { Uid = 1, Id = "CrackedPrayerBead", At = 10, Source = "Scan" } },
				Settings = { AutoDisplay = true, RarityFocus = "Epic", Client = { UIScale = 120, Effects = "Low" } },
			}
			expect.equal(Migrations.run(data, DataTemplate.Version), "Migrated", "outcome")
			reconcile(data, DataTemplate.Template)
			expect.equal(data.Settings.AutoDisplay, nil, "auto-display removed")
			expect.equal(data.Settings.Client.UIScale, nil, "old interface size removed")
			expect.equal(data.Settings.Client.InterfaceSize, "Medium", "new interface size added")
			expect.equal(data.Settings.Client.Effects, "Low", "other settings kept")
			expect.equal(data.Settings.RarityFocus, "Epic", "focus kept")
			expect.equal(data.AfkLog.Active, false, "AFK log added")
			expect.equal(#data.Inventory, 1, "inventory kept")
		end,
	},
	{
		Name = "v3 data renames the Slice 0 relic ids everywhere they are saved",
		Run = function()
			local data = {
				DataVersion = 3,
				Inventory = {
					{ Uid = 1, Id = "HollowBoneFlute", Mutation = "Golden", At = 10, Source = "Scan" },
					{ Uid = 2, Id = "SenzoBean", At = 20, Source = "Scan" },
				},
				Discovered = { HollowBoneFlute = 10, SenzoBean = 20 },
				CodexMutations = { HollowBoneFlute = { Golden = 10 } },
				Favorites = { HollowBoneFlute = true, ["HollowBoneFlute|Golden"] = true },
				RareHistory = { { Id = "WeepingIronHalberd", At = 30, Source = "Scan" } },
				Cosmetic = { Key = "HollowBoneFlute|Golden", Mode = "Hand" },
			}
			expect.equal(Migrations.run(data, DataTemplate.Version), "Migrated", "outcome")
			expect.equal(data.Inventory[1].Id, "HolloBait", "inventory id")
			expect.equal(data.Inventory[2].Id, "SenzoBean", "current ids untouched")
			expect.equal(data.Discovered.HolloBait, 10, "Codex entry")
			expect.equal(data.Discovered.HollowBoneFlute, nil, "old Codex entry removed")
			expect.equal(data.CodexMutations.HolloBait.Golden, 10, "mutation record")
			expect.truthy(data.Favorites.HolloBait and data.Favorites["HolloBait|Golden"], "favorites")
			expect.equal(data.RareHistory[1].Id, "KubikiriCleaver", "rare history")
			expect.equal(data.Cosmetic.Uid, 1, "carried relic becomes the floating copy")
			for oldId, newId in Migrations.RenamedRelics do
				expect.truthy(RelicConfig.ById[newId], `{oldId} renames to unknown {newId}`)
				expect.equal(RelicConfig.ById[oldId], nil, `{oldId} is still in the roster`)
			end
		end,
	},
	{
		Name = "v4 data converts the offline snapshot to CE per second and gains Rebirths",
		Run = function()
			local data = { DataVersion = 4, Offline = { IncomePerMin = 600, At = 123 } }
			expect.equal(Migrations.run(data, DataTemplate.Version), "Migrated", "outcome")
			expect.equal(data.Offline.IncomePerSec, 10, "per second")
			expect.equal(data.Offline.IncomePerMin, nil, "old field removed")
			expect.equal(data.Offline.At, 123, "time kept")
			reconcile(data, DataTemplate.Template)
			expect.equal(data.Rebirths, 0, "rebirths reconciled")
			expect.equal(data.Settings.AutoEquip, false, "auto-equip defaults off (game pass)")
		end,
	},
	{
		Name = "v5 data turns the carried relic into one floating copy that isn't on a pedestal",
		Run = function()
			local data = {
				DataVersion = 5,
				Inventory = {
					{ Uid = 4, Id = "SenzoBean", Mutation = "Golden" },
					{ Uid = 7, Id = "SenzoBean", Mutation = "Golden" },
					{ Uid = 9, Id = "SenzoBean" },
				},
				Pedestals = { { Level = 1, Locked = false, Uid = 4 } },
				Cosmetic = { Key = "SenzoBean|Golden", Mode = "Hand" },
			}
			expect.equal(Migrations.run(data, DataTemplate.Version), "Migrated", "outcome")
			expect.equal(data.Cosmetic.Uid, 7, "the copy in the backpack floats")
			expect.equal(data.Cosmetic.Key, nil, "old key removed")
			expect.equal(data.Cosmetic.Mode, nil, "hold mode removed")

			local none = { DataVersion = 5, Inventory = {}, Cosmetic = { Key = "", Mode = "Float" } }
			Migrations.run(none, DataTemplate.Version)
			expect.equal(none.Cosmetic.Uid, 0, "nothing carried, nothing floats")
		end,
	},
	{
		Name = "every migration step up to the current version exists",
		Run = function()
			for step = 1, DataTemplate.Version do
				expect.truthy(Migrations.Steps[step], `missing migration step {step}`)
			end
		end,
	},
	{
		Name = "save rule tiers exist and are ordered sensibly",
		Run = function()
			local save = Config.Save
			for _, key in { "PriorityTier", "PriorityMutatedTier", "RareHistoryTier" } do
				expect.truthy(RarityConfig.IndexById[save[key]], `{key} is not a tier`)
			end
			expect.truthy(
				RarityConfig.IndexById[save.RareHistoryTier] <= RarityConfig.IndexById[save.PriorityTier],
				"rare history must include every priority tier"
			)
			expect.truthy(save.MinSecondsBetweenSaves >= 6, "save throttle respects DataStore write limits")
			expect.truthy(#save.StoreName <= 50, "ProfileStore name length limit")
		end,
	},
}
