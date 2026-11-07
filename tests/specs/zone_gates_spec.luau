-- Zone luck gates (Config.ZoneGates): cells, open/locked, push-back target and drawn borders.

local Config = require("../../src/shared/Config")
local DataTemplate = require("../../src/server/Data/DataTemplate")
local Rebirth = require("../../src/shared/Rebirth")
local WorldLayout = require("../../src/shared/WorldLayout")
local ZoneGates = require("../../src/shared/ZoneGates")
local expect = require("../lib/expect")

local ctx: ZoneGates.Context = {
	Areas = Config.Areas,
	World = Config.World,
	Bands = Config.HuntStreak,
	Gates = Config.ZoneGates,
}

local function areaAngle(id: string): number
	for _, area in Config.Areas do
		if area.Id == id then
			return area.AngleDegrees
		end
	end
	error(id)
end

local function at(id: string, radius: number): (number, number)
	return WorldLayout.polar(areaAngle(id), radius)
end

local EDGE = (Config.World.WildInner + Config.HuntStreak.EdgeUntil) / 2
local DEEP = (Config.HuntStreak.EdgeUntil + Config.HuntStreak.DeepUntil) / 2
local HEART = (Config.HuntStreak.DeepUntil + Config.World.WildOuter) / 2

return {
	{
		Name = "cells: town is open, wild points map to area and band",
		Run = function()
			expect.equal(ZoneGates.cellAt(ctx, 0, 0), nil, "town")
			local area, band = ZoneGates.cellAt(ctx, at("AbandonedVillage", DEEP))
			expect.equal(area, "AbandonedVillage", "area")
			expect.equal(band, "Deep", "band")
			expect.equal(select(2, ZoneGates.cellAt(ctx, at("AncientRuins", Config.World.WildOuter + 30))), "Heart", "past the rim")
		end,
	},
	{
		Name = "a new player (x1) may only stand in the town and Forest Edge",
		Run = function()
			expect.truthy(ZoneGates.allowedAt(ctx, 1, 0, 0), "town")
			expect.truthy(ZoneGates.allowedAt(ctx, 1, at("HauntedForest", EDGE)), "forest edge")
			expect.truthy(not ZoneGates.allowedAt(ctx, 1, at("HauntedForest", DEEP)), "forest deep")
			expect.truthy(not ZoneGates.allowedAt(ctx, 1, at("AbandonedVillage", EDGE)), "village edge")
			expect.truthy(ZoneGates.allowedAt(ctx, 3, at("HauntedForest", DEEP)), "x3 forest deep")
			expect.truthy(ZoneGates.allowedAt(ctx, 600, at("AncientRuins", HEART)), "x600 everywhere")
		end,
	},
	{
		Name = "gates follow the approved table and rise with depth",
		Run = function()
			expect.equal(ZoneGates.required(ctx, "HauntedForest", "Heart"), 10, "forest heart")
			expect.equal(ZoneGates.required(ctx, "AbandonedVillage", "Edge"), 5, "village edge")
			expect.equal(ZoneGates.required(ctx, "AncientRuins", "Heart"), 200, "ruins heart")
			for area, bands in Config.ZoneGates.Required do
				expect.truthy(bands.Edge <= bands.Deep and bands.Deep <= bands.Heart, `{area} rises`)
			end
		end,
	},
	{
		Name = "push-back lands just inside an open cell, close by",
		Run = function()
			local inside = Config.ZoneGates.PushInside
			-- Just past the Forest Edge/Deep line: back over the line.
			local x, z = at("HauntedForest", Config.HuntStreak.EdgeUntil + 3)
			local nx, nz = ZoneGates.nearestAllowed(ctx, 1, x, z, inside)
			expect.truthy(ZoneGates.allowedAt(ctx, 1, nx, nz), "lands open")
			expect.truthy(math.sqrt((nx - x) ^ 2 + (nz - z) ^ 2) < 10, "close by")
			-- Deep inside Village Edge at x1: out to the town or the forest, never staying.
			local vx, vz = at("AbandonedVillage", EDGE)
			local wx, wz = ZoneGates.nearestAllowed(ctx, 1, vx, vz, inside)
			expect.truthy(ZoneGates.allowedAt(ctx, 1, wx, wz), "village edge -> open")
			-- Across the Forest/Ruins side border at Edge depth.
			local center, low = ZoneGates.sliceOf(ctx, "HauntedForest")
			local border = center - low
			local bx, bz = WorldLayout.polar(border - 2, EDGE)
			local cx, cz = ZoneGates.nearestAllowed(ctx, 1, bx, bz, inside)
			expect.truthy(ZoneGates.allowedAt(ctx, 1, cx, cz), "side border -> open")
			expect.truthy(math.sqrt((cx - bx) ^ 2 + (cz - bz) ^ 2) < 20, "side border close by")
			-- Open spots are left where they are.
			local fx, fz = at("HauntedForest", EDGE)
			local gx, gz = ZoneGates.nearestAllowed(ctx, 1, fx, fz, inside)
			expect.near(gx, fx, 1e-6, "x kept")
			expect.near(gz, fz, 1e-6, "z kept")
		end,
	},
	{
		Name = "random wild points never get pushed into another locked cell",
		Run = function()
			local seed = 5
			local function next01(): number
				seed = (seed * 1103515245 + 12345) % 2147483648
				return seed / 2147483648
			end
			for _, luck in { 1, 3, 5, 12, 40, 100 } do
				for _ = 1, 400 do
					local angle = next01() * 360
					local radius = Config.World.WildInner + next01() * (Config.World.WildOuter - Config.World.WildInner)
					local x, z = WorldLayout.polar(angle, radius)
					local nx, nz = ZoneGates.nearestAllowed(ctx, luck, x, z, Config.ZoneGates.PushInside)
					expect.truthy(ZoneGates.allowedAt(ctx, luck, nx, nz), `x{luck} at {angle},{radius}`)
				end
			end
		end,
	},
	{
		Name = "borders: x1 draws forest deep line + village/ruins entrances; x600 draws none",
		Run = function()
			local list = ZoneGates.borders(ctx, 1)
			local found = {}
			for _, border in list do
				found[`{border.Kind}:{border.Area}:{border.Band}`] = border.Required
			end
			expect.equal(found["Arc:HauntedForest:Deep"], 3, "forest deep arc")
			expect.equal(found["Arc:AbandonedVillage:Edge"], 5, "village entrance arc")
			expect.equal(found["Arc:AncientRuins:Edge"], 25, "ruins entrance arc")
			expect.equal(found["Arc:HauntedForest:Heart"], nil, "no line past a locked band")
			expect.truthy(found["Ray:AbandonedVillage:Edge"] ~= nil, "forest/village side line")
			expect.equal(#ZoneGates.borders(ctx, 600), 0, "all open")
		end,
	},
	{
		Name = "PeakLastingLuck: old saves default from current luck, never decreases, survives Rebirth",
		Run = function()
			expect.equal(DataTemplate.Template.PeakLastingLuck, 0, "template: unset")
			-- Old save (no field): set from the current Lasting Luck, at least 1.
			expect.equal(ZoneGates.updatePeak(nil, 12), 12, "old save takes current")
			expect.equal(ZoneGates.updatePeak(0, 0.5), 1, "never below 1")
			-- Rises with luck, never falls.
			expect.equal(ZoneGates.updatePeak(12, 40), 40, "rises")
			expect.equal(ZoneGates.updatePeak(40, 6), 40, "never decreases")
			expect.equal(ZoneGates.gateLuck(6, 40), 40, "gates use the peak")
			expect.equal(ZoneGates.gateLuck(50, 40), 50, "or current when higher")
			-- Rebirth.apply resets skills but keeps the peak.
			local data = {
				Rebirths = 0,
				CE = 100,
				Pedestals = { { Level = 3 } },
				Skills = { CoreLuck = 50 },
				PeakLastingLuck = 40,
			}
			Rebirth.apply(data, "Live")
			expect.equal(data.Skills.CoreLuck, 0, "skills reset")
			expect.equal(data.PeakLastingLuck, 40, "peak kept")
		end,
	},
}
