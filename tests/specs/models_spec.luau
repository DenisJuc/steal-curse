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
}
