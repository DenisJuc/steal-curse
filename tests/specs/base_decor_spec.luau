-- Base interior (BaseDecor + Config.Plots offsets): altar pick, owner gardens, and a layout that
-- keeps the aisle, pads, corners and spawn apart inside the plot.

local BaseDecor = require("../../src/shared/BaseDecor")
local Config = require("../../src/shared/Config")
local MapPropConfig = require("../../src/shared/MapPropConfig")
local expect = require("../lib/expect")

local TIERS = { C = 1, R = 3, L = 5, M = 6 }
local function tierOf(id: string): number
	return TIERS[id] or 1
end

local plots = Config.Plots
local half = plots.Size / 2

-- Footprint radius used for spacing checks (studs, plot space).
local function circle(at: { number }, radius: number, name: string)
	return { X = at[1], Z = at[2], R = radius, Name = name }
end

return {
	{
		Name = "altar: Titanic beats Huge, then the rarer tier; nothing without a Huge or Titanic",
		Run = function()
			expect.equal(BaseDecor.altarPick({ { Id = "M" }, { Id = "L" } }, tierOf), nil, "normal sizes never rest on the altar")
			local pick = BaseDecor.altarPick({
				{ Uid = 1, Id = "M", Size = "Huge" },
				{ Uid = 2, Id = "C", Size = "Titanic" },
				{ Uid = 3, Id = "L", Size = "Huge" },
			}, tierOf)
			expect.equal(pick and pick.Uid, 2, "a Titanic first")
			pick = BaseDecor.altarPick({ { Uid = 1, Id = "R", Size = "Huge" }, { Uid = 2, Id = "M", Size = "Huge" } }, tierOf)
			expect.equal(pick and pick.Uid, 2, "then the rarer tier")
		end,
	},
	{
		Name = "gardens: known props, stable per player, neighbours get a different theme, growth adds pieces",
		Run = function()
			expect.truthy(#BaseDecor.Gardens >= 5, "at least five themes")
			for _, garden in BaseDecor.Gardens do
				expect.truthy(#BaseDecor.piecesAt(garden, 1) >= 1, `{garden.Id} shows something at stage 1`)
				expect.truthy(#BaseDecor.piecesAt(garden, 3) > #BaseDecor.piecesAt(garden, 1), `{garden.Id} grows`)
				for _, piece in garden.Pieces do
					expect.truthy(MapPropConfig.Props[piece.Prop] ~= nil, `{garden.Id} uses known prop {piece.Prop}`)
					-- Stays in the back-left corner: clear of the walls, the aisle rows and the terrace.
					local x, z = plots.GardenOffset[1] + piece.At[1], plots.GardenOffset[2] + piece.At[2]
					expect.truthy(x > -half + 4 and x < -20 and z > 16 and z < half - 4, `{garden.Id} {piece.Prop} in its corner`)
				end
			end
			local first = BaseDecor.gardenFor(153530464, {})
			expect.equal(BaseDecor.gardenFor(153530464, {}).Id, first.Id, "same player, same garden")
			local second = BaseDecor.gardenFor(153530464, { [first.Id] = true })
			expect.truthy(second.Id ~= first.Id, "a neighbour with that theme pushes to another")
			local all = {}
			for _, garden in BaseDecor.Gardens do
				all[garden.Id] = true
			end
			expect.truthy(BaseDecor.gardenFor(7, all) ~= nil, "more owners than themes still get one")
			expect.equal(BaseDecor.stageFor(1), 1, "Paper Charm: stage 1")
			expect.equal(BaseDecor.stageFor(5), 2, "Bronze: stage 2")
			expect.equal(BaseDecor.stageFor(12), 3, "Eternal: stage 3")
		end,
	},
	{
		Name = "interior layout: pads on two lanes around the pool, corners and spawn clear of each other",
		Run = function()
			-- Every pad sits on its row's lane, clear of its pedestal and of the pool.
			local padR = plots.PadSize / 2
			for slot, offset in plots.PedestalOffsets do
				local padX = (if offset[1] < 0 then -1 else 1) * plots.PadX
				expect.truthy(padR <= plots.LaneWidth / 2, `pad {slot} fits its lane`)
				expect.truthy(math.abs(offset[1]) - 2.75 > math.abs(padX) + padR, `pad {slot} clear of its pedestal`)
				expect.truthy(math.abs(padX) - plots.LaneWidth / 2 >= plots.PoolHalfWidth, `lane {slot} clear of the pool`)
				expect.truthy(offset[2] > plots.LaneFrontZ and offset[2] < plots.LaneBackZ, `pad {slot} between the lane ends`)
			end
			local spots = {
				circle(plots.ShowcaseOffset, 8, "Showcase"),
				circle(plots.SealShrineOffset, 5.5, "Seal Shrine"),
				circle(plots.AltarOffset, 9.5, "Great Altar"),
				circle(plots.GardenOffset, 9, "Garden"),
				circle(plots.ResonatorOffset, 4, "Resonator"),
				circle(plots.SpawnOffset, 3, "Spawn"),
			}
			for slot, offset in plots.PedestalOffsets do
				table.insert(spots, circle(offset, 3.75, `Pedestal {slot}`))
				table.insert(spots, circle({ (if offset[1] < 0 then -1 else 1) * plots.PadX, offset[2] }, padR, `Pad {slot}`))
			end
			for i, a in spots do
				expect.truthy(math.abs(a.X) + a.R <= half - 1 and math.abs(a.Z) + a.R <= half - 1, `{a.Name} inside the walls`)
				for j = i + 1, #spots do
					local b = spots[j]
					do

						local d = math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
						expect.truthy(d >= a.R + b.R, `{a.Name} overlaps {b.Name} ({d})`)
					end
				end
			end
			-- Front corners sit on the street side, back corners on the far side.
			expect.truthy(plots.ShowcaseOffset[2] < 0 and plots.SealShrineOffset[2] < 0, "showcase and seal shrine face the street")
			expect.truthy(plots.AltarOffset[2] > 0 and plots.GardenOffset[2] > 0, "altar and garden at the back")
		end,
	},
}
