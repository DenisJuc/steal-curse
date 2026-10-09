-- Shared capture animation families (GDD 4.3 "Animation production"): every relic's ObjectType
-- maps to one of five families, so 5 animations cover the whole roster instead of one per relic.
-- The relic is only known after a validated capture, so the family plays at the seal, never
-- during the bind (the bind itself must not hint at rarity). Pure, so Lune can test it.

local CaptureFamilies = {}

export type Family = {
	Id: string,
	Label: string,
	-- Length of the family motion before the relic flies into the player.
	Seconds: number,
}

CaptureFamilies.Families = {
	Weapons = { Id = "Weapons", Label = "Weapons", Seconds = 1.5 },
	Books = { Id = "Books", Label = "Books / Scrolls", Seconds = 1.6 },
	Masks = { Id = "Masks", Label = "Masks / Vessels", Seconds = 1.5 },
	Crystals = { Id = "Crystals", Label = "Crystals / Fragments", Seconds = 1.4 },
	Special = { Id = "Special", Label = "Special / Legendary artifacts", Seconds = 1.8 },
} :: { [string]: Family }

CaptureFamilies.ByObjectType = {
	Weapon = "Weapons",
	Book = "Books",
	Mask = "Masks",
	Crystal = "Crystals",
	Special = "Special",
} :: { [string]: string }

-- Time the relic takes to fly into the player after the family motion.
CaptureFamilies.CollectSeconds = 0.45

function CaptureFamilies.forObjectType(objectType: string?): Family
	local id = objectType and CaptureFamilies.ByObjectType[objectType]
	return CaptureFamilies.Families[id or "Special"]
end

function CaptureFamilies.totalSeconds(family: Family): number
	return family.Seconds + CaptureFamilies.CollectSeconds
end

return CaptureFamilies
