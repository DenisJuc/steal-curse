-- Per-relic aura recipes for relics that have a 3D model. Pure data + a pure function so Lune can
-- test it: every modelled relic gets its own look (base aura, tint, optional second layer) and the
-- look clearly grows with tier and with Huge / Titanic size. Templates are the Aura_* models in
-- ReplicatedStorage.VFX.Auras (assets/VFX/Auras, written by tools/vfx/install_auras.py).

local RelicVfx = {}

export type Layer = {
	Template: string,
	-- Hex colour the layer is pulled toward (nil = keep the pack's colours).
	Tint: string?,
	-- 0..1 how far the colours move toward Tint.
	TintStrength: number,
	-- Multiplies the size-derived aura scale.
	Boost: number,
	-- Multiplies emitter rates (density), capped by RelicAura.
	Density: number,
}

-- Base aura per tier, best last; relics in a tier cycle through their pool so neighbours differ.
RelicVfx.Pools = {
	-- Studio audit 2026-10-30: candidates 05, 12, 13, 14, 17, 28 and 29 render invisible outside
	-- their pack scripts, and 03 / 26 fire sideways, so the pools only use the auras that read.
	Common = { "Aura_Sparkle" },
	Uncommon = { "Aura_Sparkle", "Aura_Wind" },
	Rare = { "Aura_Rise", "Aura_Wind", "Aura_Rare" },
	Epic = { "Aura_Epic", "Aura_Rise", "Aura_Wind" },
	Legendary = { "Aura_Legendary", "Aura_Epic", "Aura_Mythic" },
	Mythic = { "Aura_Mythic", "Aura_Legendary", "Aura_Celestial" },
	Celestial = { "Aura_Celestial", "Aura_Cosmic", "Aura_Mythic" },
	Cosmic = { "Aura_Cosmic", "Aura_Celestial", "Aura_Rays" },
} :: { [string]: { string } }

-- Second layer from Legendary up (sparks around the relic), third from Cosmic.
RelicVfx.Accents = { "Aura_Sparkle", "Aura_Rise", "Aura_Wind" }

-- How strong each tier looks: base size boost, emitter density, how hard the tint is applied.
RelicVfx.TierLook = {
	Common = { Boost = 0.7, Density = 0.5, Tint = 0.75, Layers = 1 },
	Uncommon = { Boost = 0.8, Density = 0.7, Tint = 0.7, Layers = 1 },
	Rare = { Boost = 0.95, Density = 0.85, Tint = 0.6, Layers = 1 },
	Epic = { Boost = 1.0, Density = 1.0, Tint = 0.5, Layers = 1 },
	Legendary = { Boost = 1.05, Density = 1.0, Tint = 0.45, Layers = 2 },
	Mythic = { Boost = 1.1, Density = 1.1, Tint = 0.4, Layers = 2 },
	Celestial = { Boost = 1.15, Density = 1.2, Tint = 0.35, Layers = 2 },
	Cosmic = { Boost = 1.2, Density = 1.3, Tint = 0.3, Layers = 3 },
} :: { [string]: { Boost: number, Density: number, Tint: number, Layers: number } }

-- Colour family per relic Vfx tag (RelicConfig.Vfx).
RelicVfx.Colors = {
	Blood = "#E0243C",
	Bloom = "#FF6FB5",
	Ember = "#FF7A1A",
	Frost = "#7FE3FF",
	Holy = "#FFD866",
	Sand = "#E3B66B",
	Shadow = "#8A4DFF",
	Spirit = "#5CF2C4",
	Starlight = "#9DB8FF",
	Storm = "#4FA8FF",
	Toxin = "#8DF23C",
	Void = "#B03CFF",
} :: { [string]: string }

-- Size variants stack on top: Huge adds a ground ring, Titanic adds the chains as well.
RelicVfx.SizeBoost = { Huge = 1.25, Titanic = 1.5 } :: { [string]: number }
RelicVfx.HugeLayer = "Aura_Ground"
RelicVfx.TitanicLayer = "Aura_TitanicExtra"

-- Small deterministic string hash so a relic always gets the same picks.
local function hash(text: string): number
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 2147483647
	end
	return h
end
RelicVfx.hash = hash

-- Nudges a hex colour's hue by up to +/-0.06 per relic so two relics with the same tag differ.
local function shiftHue(hex: string, seed: number): string
	local r = tonumber(string.sub(hex, 2, 3), 16) / 255
	local g = tonumber(string.sub(hex, 4, 5), 16) / 255
	local b = tonumber(string.sub(hex, 6, 7), 16) / 255
	local maxc, minc = math.max(r, g, b), math.min(r, g, b)
	local delta = maxc - minc
	local h = 0
	if delta > 0 then
		if maxc == r then
			h = ((g - b) / delta) % 6
		elseif maxc == g then
			h = (b - r) / delta + 2
		else
			h = (r - g) / delta + 4
		end
		h /= 6
	end
	local s = if maxc > 0 then delta / maxc else 0
	local v = maxc
	h = (h + ((seed % 1000) / 1000 - 0.5) * 0.12) % 1
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local rgb = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i % 6 + 1]
	return string.format("#%02X%02X%02X", math.floor(rgb[1] * 255 + 0.5), math.floor(rgb[2] * 255 + 0.5), math.floor(rgb[3] * 255 + 0.5))
end
RelicVfx.shiftHue = shiftHue

export type Relic = { Id: string, Tier: string, Vfx: string? }

-- The layers for one relic at one size. `index` is the relic's position among modelled relics of
-- its tier (so a tier's relics walk through the pool in order); nil falls back to the hash.
function RelicVfx.layers(relic: Relic, size: string?, index: number?): { Layer }
	local look = RelicVfx.TierLook[relic.Tier] or RelicVfx.TierLook.Common
	local pool = RelicVfx.Pools[relic.Tier] or RelicVfx.Pools.Common
	local seed = hash(relic.Id)
	local pick = ((index or seed) % #pool) + 1
	local base = RelicVfx.Colors[relic.Vfx or ""]
	local tint = if base then shiftHue(base, seed) else nil
	local boost = RelicVfx.SizeBoost[size or ""] or 1
	local layers: { Layer } = {
		{ Template = pool[pick], Tint = tint, TintStrength = look.Tint, Boost = look.Boost * boost, Density = look.Density },
	}
	for extra = 2, look.Layers do
		local accent = RelicVfx.Accents[((seed // 7 + extra) % #RelicVfx.Accents) + 1]
		if accent ~= layers[1].Template then
			table.insert(layers, {
				Template = accent,
				Tint = tint,
				TintStrength = math.min(1, look.Tint + 0.3),
				Boost = 0.8 * boost,
				Density = 0.6 * look.Density,
			})
		end
	end
	if size == "Huge" or size == "Titanic" then
		table.insert(layers, { Template = RelicVfx.HugeLayer, Tint = tint, TintStrength = 0.5, Boost = boost, Density = 1 })
	end
	if size == "Titanic" then
		table.insert(layers, { Template = RelicVfx.TitanicLayer, Tint = nil, TintStrength = 0, Boost = 1, Density = 1 })
	end
	return layers
end

return RelicVfx
