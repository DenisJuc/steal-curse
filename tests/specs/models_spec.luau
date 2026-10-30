-- Imported relic model checks (Slice 8b): size fitting and the /modelcheck warnings.

local ModelCheck = require("../../src/shared/ModelCheck")
local expect = require("../lib/expect")

local function facts(overrides: { [string]: any }): ModelCheck.Facts
	local base = {
		ClassName = "MeshPart",
		Parts = 1,
		HasTexture = true,
		Scripts = 0,
		SizeX = 2,
		SizeY = 4,
		SizeZ = 1,
	}
	for key, value in overrides do
		(base :: any)[key] = value
	end
	return base :: any
end

return {
	{
		Name = "a single textured MeshPart passes with no warnings",
		Run = function()
			expect.equal(#ModelCheck.issues(facts({})), 0, "clean model")
		end,
	},
	{
		Name = "each common import mistake gets its own warning",
		Run = function()
			expect.equal(#ModelCheck.issues(facts({ Parts = 3 })), 1, "several parts")
			expect.equal(#ModelCheck.issues(facts({ HasTexture = false })), 1, "no texture")
			expect.equal(#ModelCheck.issues(facts({ Scripts = 1 })), 1, "scripts inside")
			expect.equal(#ModelCheck.issues(facts({ ClassName = "Part" })), 1, "not a mesh")
			expect.equal(#ModelCheck.issues(facts({ SizeZ = 0.1 })), 1, "paper-thin (aspect 40)")
			expect.equal(#ModelCheck.issues(facts({ SizeZ = 0.2 })), 0, "thin but fine (aspect 20)")
			local empty = ModelCheck.issues(facts({ Parts = 0 }))
			expect.equal(#empty, 1, "empty asset reports only that")
		end,
	},
	{
		Name = "fit factor makes the longest side match the placeholder",
		Run = function()
			expect.near(ModelCheck.fitFactor(40, 4.2), 0.105, 1e-12, "huge import shrinks")
			expect.near(ModelCheck.fitFactor(0.5, 2), 4, 1e-12, "tiny import grows")
			expect.equal(ModelCheck.fitFactor(0, 2), 1, "degenerate size is left alone")
		end,
	},
	{
		Name = "presence factor gives swords and orbs the same pedestal presence",
		Run = function()
			local orb = ModelCheck.presenceFactor({ X = 10, Y = 10, Z = 10 })
			expect.near(orb * 10, ModelCheck.DISPLAY_PRESENCE, 1e-9, "orb presence")
			local book = ModelCheck.presenceFactor({ X = 0.2, Y = 0.8, Z = 0.5 })
			expect.near(book * math.sqrt(0.8 * 0.5), ModelCheck.DISPLAY_PRESENCE, 1e-9, "book presence")
			local sword = ModelCheck.presenceFactor({ X = 0.1, Y = 1, Z = 0.25 })
			expect.near(sword * 1, ModelCheck.DISPLAY_MAX_LONGEST, 1e-9, "long sword capped at max length")
			expect.equal(ModelCheck.presenceFactor({ X = 0, Y = 0, Z = 0 }), 1, "degenerate size is left alone")
		end,
	},
	{
		Name = "stand-up turns lying blades on end and flat books on edge",
		Run = function()
			local blade = ModelCheck.standUp({ X = 4, Y = 0.3, Z = 0.6 }) :: { number }
			expect.equal(blade[3], 90, "x-long blade rolls upright")
			local spear = ModelCheck.standUp({ X = 0.3, Y = 0.4, Z = 4 }) :: { number }
			expect.equal(spear[1], 90, "z-long spear pitches upright")
			local book = ModelCheck.standUp({ X = 2, Y = 0.4, Z = 1.6 }) :: { number }
			expect.equal(book[1], 90, "flat book stands on edge")
			expect.equal(ModelCheck.standUp({ X = 0.3, Y = 4, Z = 0.5 }), nil, "upright sword left alone")
			expect.equal(ModelCheck.standUp({ X = 2, Y = 2, Z = 2 }), nil, "round fruit left alone")
		end,
	},
}
