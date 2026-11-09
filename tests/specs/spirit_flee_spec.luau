-- Skittish spirits (SpiritFlee + Config.Skittish): who bolts, when, and where to.

local Config = require("../../src/shared/Config")
local SpiritFlee = require("../../src/shared/SpiritFlee")
local expect = require("../lib/expect")

local rules = Config.Skittish :: any
local CLOSE = rules.Distance - 1
local RUSHED = rules.CalmSeconds + 5
local CAREFUL = 1

-- Spots on a ring around the spirit at the origin, every 10 degrees, at the middle of the hop band.
local function ring(radius: number): { SpiritFlee.Spot }
	local spots = {}
	for degrees = 0, 350, 10 do
		local angle = math.rad(degrees)
		table.insert(spots, { X = math.cos(angle) * radius, Z = math.sin(angle) * radius })
	end
	return spots
end

return {
	{
		Name = "bolting starts beyond bind range, so a bind can never start first",
		Run = function()
			expect.truthy(rules.Distance > Config.Bind.LockRange + Config.Bind.RangeSlack, "distance vs bind range")
			expect.truthy(rules.Hop[1] > rules.Distance, "hops land out of reach")
		end,
	},
	{
		Name = "wisps never flee; nothing flees before the first real capture or from far away",
		Run = function()
			expect.equal(SpiritFlee.reaction(rules, "Wisp", {}, CLOSE, RUSHED, 10), nil, "wisp")
			expect.equal(SpiritFlee.reaction(rules, "Vengeful", {}, CLOSE, RUSHED, rules.FromCaptures - 1), nil, "too early")
			expect.equal(SpiritFlee.reaction(rules, "Vengeful", {}, rules.Distance + 1, RUSHED, 10), nil, "far")
			expect.equal(SpiritFlee.reaction(rules, nil, {}, CLOSE, RUSHED, 10), nil, "no type")
		end,
	},
	{
		Name = "Restless bolts once when rushed, never after a pulse",
		Run = function()
			local memory = {}
			expect.equal(SpiritFlee.reaction(rules, "Restless", memory, CLOSE, CAREFUL, 10), nil, "careful")
			local first = SpiritFlee.reaction(rules, "Restless", memory, CLOSE, RUSHED, 10)
			expect.equal(first, "Spook", "rushed")
			SpiritFlee.remember(memory, first :: any)
			expect.equal(SpiritFlee.reaction(rules, "Restless", memory, CLOSE, RUSHED, 10), nil, "settled")
		end,
	},
	{
		Name = "Vengeful runs once whatever you do, then once more only if rushed",
		Run = function()
			local memory = {}
			local first = SpiritFlee.reaction(rules, "Vengeful", memory, CLOSE, CAREFUL, 10)
			expect.equal(first, "Chase", "chase even when careful")
			SpiritFlee.remember(memory, first :: any)
			expect.equal(SpiritFlee.reaction(rules, "Vengeful", memory, CLOSE, CAREFUL, 10), nil, "careful after chase")
			local second = SpiritFlee.reaction(rules, "Vengeful", memory, CLOSE, RUSHED, 10)
			expect.equal(second, "Spook", "rushed after chase")
			SpiritFlee.remember(memory, second :: any)
			expect.equal(SpiritFlee.reaction(rules, "Vengeful", memory, CLOSE, RUSHED, 10), nil, "settled")
		end,
	},
	{
		Name = "turned off: nothing flees",
		Run = function()
			local off = table.clone(rules)
			off.Enabled = false
			expect.equal(SpiritFlee.reaction(off, "Vengeful", {}, CLOSE, RUSHED, 10), nil, "off")
		end,
	},
	{
		Name = "it bolts away from the player, within the hop band",
		Run = function()
			local hop = (rules.Hop[1] + rules.Hop[2]) / 2
			local spots = ring(hop)
			-- Player approaching from the west (-X): the spirit must head east (+X).
			for i = 0, 9 do
				local index = SpiritFlee.pickSpot(rules, spots, 0, 0, -CLOSE, 0, i / 10)
				expect.truthy(index ~= nil, "found a spot")
				local spot = spots[index :: number]
				expect.truthy(spot.X > 0, `heads away (x={spot.X})`)
			end
			-- Too near or too far for a hop: no spot.
			expect.equal(SpiritFlee.pickSpot(rules, ring(rules.Hop[1] - 5), 0, 0, -CLOSE, 0, 0.5), nil, "too near")
			expect.equal(SpiritFlee.pickSpot(rules, ring(rules.Hop[2] + 5), 0, 0, -CLOSE, 0, 0.5), nil, "too far")
		end,
	},
	{
		Name = "with only spots behind it, it still bolts (toward the player's side)",
		Run = function()
			local hop = (rules.Hop[1] + rules.Hop[2]) / 2
			local behind = { { X = -hop, Z = 0 } }
			expect.equal(SpiritFlee.pickSpot(rules, behind, 0, 0, -CLOSE, 0, 0.5), 1, "fallback")
		end,
	},
}
