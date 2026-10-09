-- Player settings (GDD 12.1) and the Journal's session report (GDD 9.4).

local ClientSettings = require("../../src/shared/ClientSettings")
local DataTemplate = require("../../src/server/Data/DataTemplate")
local SessionReport = require("../../src/shared/SessionReport")
local expect = require("../lib/expect")

return {
	{
		Name = "saved settings template equals the schema defaults",
		Run = function()
			local defaults = ClientSettings.defaults()
			local saved = DataTemplate.Template.Settings.Client
			for key, value in defaults do
				expect.equal(saved[key], value, `template {key}`)
			end
			for key in saved do
				expect.truthy(defaults[key] ~= nil, `template has unknown setting {key}`)
			end
		end,
	},
	{
		Name = "every default is one of its own options",
		Run = function()
			for _, setting in ClientSettings.Schema do
				expect.equal(ClientSettings.sanitize(setting.Key, setting.Default), setting.Default, setting.Key)
			end
		end,
	},
	{
		Name = "sanitize rejects unknown keys, wrong types and off-list values",
		Run = function()
			expect.equal(ClientSettings.sanitize("Effects", "Low"), "Low", "valid")
			expect.equal(ClientSettings.sanitize("Effects", "Ultra"), nil, "off-list")
			expect.equal(ClientSettings.sanitize("Sound", "50"), nil, "string for a number")
			expect.equal(ClientSettings.sanitize("Sound", 0 / 0), nil, "NaN")
			expect.equal(ClientSettings.sanitize("Sound", 51), 50, "slider snaps to its step")
			expect.equal(ClientSettings.sanitize("Sound", 999), 100, "slider clamps high")
			expect.equal(ClientSettings.sanitize("Sound", -20), 0, "slider clamps low")
			expect.equal(ClientSettings.sanitize("InterfaceSize", 120), nil, "old numeric size")
			expect.equal(ClientSettings.sanitize("CE", 1e9), nil, "unknown key")
			expect.equal(ClientSettings.sanitize(5, "Full"), nil, "non-string key")
			local all = ClientSettings.sanitizeAll({ Effects = "Low", Sound = "loud", Junk = true })
			expect.equal(all.Effects, "Low", "kept valid")
			expect.equal(all.Sound, 100, "reset invalid")
			expect.equal(all.Junk, nil, "dropped unknown")
		end,
	},
	{
		Name = "cycling visits every option and wraps; sliders nudge by their step",
		Run = function()
			expect.equal(ClientSettings.nextOption("InterfaceSize", "Big"), "Small", "wraps")
			expect.equal(ClientSettings.nextOption("InterfaceSize", "Small"), "Medium", "next")
			expect.equal(ClientSettings.nextOption("InterfaceSize", 333), "Medium", "invalid goes to default")
			expect.equal(ClientSettings.nextOption("Sound", 50), nil, "sliders do not cycle")
			expect.equal(ClientSettings.nudge("Sound", 50, 2), 60, "nudge up")
			expect.equal(ClientSettings.nudge("Sound", 5, -3), 0, "nudge clamps")
			expect.equal(ClientSettings.nudge("Effects", "Full", 1), nil, "only sliders nudge")
			for _, size in ClientSettings.ByKey.InterfaceSize.Options :: { any } do
				expect.truthy(ClientSettings.InterfaceScale[size] ~= nil, `scale for {size}`)
			end
		end,
	},
	{
		Name = "session report counts finds, new relics, sales and keeps the best",
		Run = function()
			local report = SessionReport.new()
			expect.truthy(SessionReport.isEmpty(report), "starts empty")
			SessionReport.add(report, { Id = "A", First = true }, 2)
			SessionReport.add(report, { Id = "B", Sold = 1.5 }, 4)
			SessionReport.add(report, { Id = "C", Mutation = "Golden", NewVariant = true }, 3)
			SessionReport.add(report, { Id = "D", Sold = 0.5 }, 4)
			expect.equal(report.Discoveries, 4, "discoveries")
			expect.equal(report.NewUnique, 1, "new unique")
			expect.equal(report.NewVariants, 1, "new variants")
			expect.equal(report.SoldCount, 2, "sold count")
			expect.near(report.SoldCE, 2, 1e-9, "sold CE")
			expect.equal(report.Best and report.Best.Id, "B", "best keeps the first of a tie")
			expect.equal(report.BestMutated and report.BestMutated.Mutation, "Golden", "best mutated")
		end,
	},
}
