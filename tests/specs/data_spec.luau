-- Saved data template and migrations (pure parts of persistence; the ProfileStore paths are
-- covered by /runtests in Studio).

local Config = require("../../src/shared/Config")
local RarityConfig = require("../../src/shared/RarityConfig")
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
			expect.equal(data.Discovered.CrackedPrayerBead, 1000, "first find time kept")
			expect.equal(data.Discovered.InkboundSigilTome, 1100, "epic discovered")
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
