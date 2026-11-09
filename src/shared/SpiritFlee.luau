-- Skittish spirits (Config.Skittish): when the player comes close, stronger spirits bolt to a new
-- hiding spot, like the fox in the intro hunt. Pure (no Roblox APIs) so Lune tests cover it;
-- SignalService runs it on the server and moves the signal, the client draws the flight.
--   Chase: the spirit bolts on its first approaches whatever you do (Vengeful: a short chase).
--   Spook: it bolts if you rush in without a pulse in the last CalmSeconds (Restless, Vengeful).
-- Each signal remembers how often it has bolted, so every spirit settles after a hop or two.

local SpiritFlee = {}

export type TypeRules = { Chase: number?, Spook: number? }

export type Rules = {
	Enabled: boolean,
	-- No spirit flees until the player has this many real captures (the hunt tutorial's stays put).
	FromCaptures: number,
	-- Studs: coming this close sets it off (more than bind range, so it goes before a bind can start).
	Distance: number,
	-- Seconds after a pulse during which an approach counts as careful.
	CalmSeconds: number,
	-- Studs from the old spot to the new one.
	Hop: { number },
	Types: { [string]: TypeRules },
}

export type Memory = { Chased: number?, Spooked: number? }

export type Reaction = "Chase" | "Spook"

-- What a spirit of `spiritType` does when the player is `distance` studs away, `sincePulse`
-- seconds after their last pulse, with `captures` real captures so far. nil = it stays.
function SpiritFlee.reaction(
	rules: Rules,
	spiritType: string?,
	memory: Memory,
	distance: number,
	sincePulse: number,
	captures: number
): Reaction?
	if not rules.Enabled or captures < rules.FromCaptures or distance > rules.Distance then
		return nil
	end
	local typeRules = rules.Types[spiritType or ""]
	if not typeRules then
		return nil
	end
	if (memory.Chased or 0) < (typeRules.Chase or 0) then
		return "Chase"
	end
	if (memory.Spooked or 0) < (typeRules.Spook or 0) and sincePulse > rules.CalmSeconds then
		return "Spook"
	end
	return nil
end

-- Counts the bolt in `memory`.
function SpiritFlee.remember(memory: Memory, reaction: Reaction)
	if reaction == "Chase" then
		memory.Chased = (memory.Chased or 0) + 1
	else
		memory.Spooked = (memory.Spooked or 0) + 1
	end
end

export type Spot = { X: number, Z: number }

-- Index of the spot to bolt to: `Hop` studs from the spirit (sx, sz), leading away from the player
-- (px, pz) and ending farther from them than the trigger distance. Falls back to any spot in the
-- hop band. `roll` in [0, 1) picks among the good ones. nil when nothing fits.
function SpiritFlee.pickSpot(rules: Rules, spots: { Spot }, sx: number, sz: number, px: number, pz: number, roll: number): number?
	local awayX, awayZ = sx - px, sz - pz
	local awayLength = math.sqrt(awayX * awayX + awayZ * awayZ)
	if awayLength > 1e-6 then
		awayX, awayZ = awayX / awayLength, awayZ / awayLength
	else
		awayX, awayZ = 0, 0
	end
	local good, fallback = {}, {}
	for index, spot in spots do
		local dx, dz = spot.X - sx, spot.Z - sz
		local hop = math.sqrt(dx * dx + dz * dz)
		if hop < rules.Hop[1] or hop > rules.Hop[2] then
			continue
		end
		table.insert(fallback, index)
		local fromPlayerX, fromPlayerZ = spot.X - px, spot.Z - pz
		local fromPlayer = math.sqrt(fromPlayerX * fromPlayerX + fromPlayerZ * fromPlayerZ)
		-- Ahead of the player's approach (within ~70 degrees of straight away) and out of reach.
		local ahead = (dx * awayX + dz * awayZ) / hop
		if ahead >= 0.35 and fromPlayer > rules.Distance + 4 then
			table.insert(good, index)
		end
	end
	local pool = if #good > 0 then good else fallback
	if #pool == 0 then
		return nil
	end
	return pool[math.clamp(math.floor(roll * #pool) + 1, 1, #pool)]
end

return SpiritFlee
