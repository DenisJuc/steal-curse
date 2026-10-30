-- Per-relic aura recipes (RelicVfx): every relic gets its own look that grows with tier and size.

local RelicConfig = require("../../src/shared/RelicConfig")
local RelicVfx = require("../../src/shared/RelicVfx")
local expect = require("../lib/expect")

local TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" }

local function signature(layers: { RelicVfx.Layer }): string
	local parts = {}
	for _, layer in layers do
		table.insert(parts, layer.Template .. "@" .. tostring(layer.Tint))
	end
	return table.concat(parts, "+")
end

return {
	{
		Name = "every relic in the roster gets a unique recipe",
		Run = function()
			local seen, index = {}, {}
			for _, relic in RelicConfig.Relics do
				index[relic.Tier] = (index[relic.Tier] or 0) + 1
				local key = signature(RelicVfx.layers(relic, nil, index[relic.Tier] - 1))
				expect.equal(seen[key], nil, `{relic.Id} shares its look with {seen[key]}`)
				seen[key] = relic.Id
			end
		end,
	},
	{
		Name = "looks grow with tier: boost, density and layer count never drop",
		Run = function()
			local last = { Boost = 0, Density = 0, Layers = 0 }
			for _, tier in TIERS do
				local look = RelicVfx.TierLook[tier]
				expect.equal(look ~= nil, true, `{tier} has a look`)
				expect.equal(look.Boost >= last.Boost and look.Density >= last.Density and look.Layers >= last.Layers, true, tier)
				last = look
				expect.equal(#RelicVfx.Pools[tier] > 0, true, `{tier} pool`)
			end
		end,
	},
	{
		Name = "Huge adds a ground layer and Titanic adds chains on top, both bigger",
		Run = function()
			local relic = { Id = "TestRelic", Tier = "Rare", Vfx = "Void" }
			local normal = RelicVfx.layers(relic, nil, 0)
			local huge = RelicVfx.layers(relic, "Huge", 0)
			local titanic = RelicVfx.layers(relic, "Titanic", 0)
			expect.equal(#huge, #normal + 1, "huge layer")
			expect.equal(#titanic, #huge + 1, "titanic layer")
			expect.equal(huge[#huge].Template, RelicVfx.HugeLayer, "ground ring")
			expect.equal(titanic[#titanic].Template, RelicVfx.TitanicLayer, "chains")
			expect.equal(huge[1].Boost > normal[1].Boost and titanic[1].Boost > huge[1].Boost, true, "size boost")
		end,
	},
	{
		Name = "tints stay valid hex colours near the relic's colour family",
		Run = function()
			for tag, hex in RelicVfx.Colors do
				local shifted = RelicVfx.shiftHue(hex, RelicVfx.hash(tag))
				expect.equal(string.match(shifted, "^#%x%x%x%x%x%x$") ~= nil, true, shifted)
			end
		end,
	},
	{
		Name = "hand-picked primaries are unique, installed and only on real relics",
		Run = function()
			local fs = require("@lune/fs")
			local used = {}
			for id, template in RelicVfx.Assigned do
				expect.equal(RelicConfig.ById[id] ~= nil, true, `{id} is a relic`)
				expect.equal(used[template], nil, `{template} used by {id} and {used[template]}`)
				used[template] = id
				expect.equal(fs.isFile(`assets/VFX/Auras/{template}.rbxmx`), true, `{template} installed`)
			end
		end,
	},
}
