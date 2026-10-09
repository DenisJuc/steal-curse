-- Relic definitions. Slice 0 uses 10 ORIGINAL placeholder relics (no anime names).
-- Weight = relative chance inside its tier; base odds are derived by RollMath, never typed by hand.
-- ObjectType matches the shared capture animation families (Weapon, Book, Mask, Crystal, Special).

local RelicConfig = {}

export type Relic = {
	Id: string,
	Name: string,
	Tier: string,
	Weight: number,
	Family: string,
	ObjectType: string,
	Description: string,
}

RelicConfig.Families = { "Demonic", "Spiritual", "Arcane", "Astral" }
RelicConfig.ObjectTypes = { "Weapon", "Book", "Mask", "Crystal", "Special" }

RelicConfig.Relics = {
	{
		Id = "CrackedPrayerBead",
		Name = "Cracked Prayer Bead",
		Tier = "Common",
		Weight = 60,
		Family = "Spiritual",
		ObjectType = "Crystal",
		Description = "Still hums a prayer nobody remembers.",
	},
	{
		Id = "RustedWardNail",
		Name = "Rusted Ward Nail",
		Tier = "Common",
		Weight = 40,
		Family = "Demonic",
		ObjectType = "Weapon",
		Description = "Once pinned something in place. It is gone now.",
	},
	{
		Id = "AshenPaperCharm",
		Name = "Ashen Paper Charm",
		Tier = "Uncommon",
		Weight = 55,
		Family = "Arcane",
		ObjectType = "Book",
		Description = "The ink smolders when no one is looking.",
	},
	{
		Id = "MothWingLantern",
		Name = "Moth-Wing Lantern",
		Tier = "Uncommon",
		Weight = 45,
		Family = "Spiritual",
		ObjectType = "Special",
		Description = "Lights the way for spirits, not for you.",
	},
	{
		Id = "HollowBoneFlute",
		Name = "Hollow Bone Flute",
		Tier = "Rare",
		Weight = 100,
		Family = "Demonic",
		ObjectType = "Special",
		Description = "Plays a note that only the dead can hear.",
	},
	{
		Id = "InkboundSigilTome",
		Name = "Inkbound Sigil Tome",
		Tier = "Epic",
		Weight = 100,
		Family = "Arcane",
		ObjectType = "Book",
		Description = "Its pages rewrite themselves at midnight.",
	},
	{
		Id = "WeepingIronHalberd",
		Name = "Weeping Iron Halberd",
		Tier = "Legendary",
		Weight = 100,
		Family = "Demonic",
		ObjectType = "Weapon",
		Description = "Rust-red tears run down the blade forever.",
	},
	{
		Id = "VeilOfTheNinthMoon",
		Name = "Veil of the Ninth Moon",
		Tier = "Mythic",
		Weight = 100,
		Family = "Astral",
		ObjectType = "Mask",
		Description = "Woven from moonlight that never reached the ground.",
	},
	{
		Id = "StarforgedReliquary",
		Name = "Starforged Reliquary",
		Tier = "Celestial",
		Weight = 100,
		Family = "Astral",
		ObjectType = "Special",
		Description = "A casket hammered from a fallen star.",
	},
	{
		Id = "HeartOfTheLastEclipse",
		Name = "Heart of the Last Eclipse",
		Tier = "Cosmic",
		Weight = 100,
		Family = "Astral",
		ObjectType = "Crystal",
		Description = "Beats once every thousand years. You heard it.",
	},
} :: { Relic }

RelicConfig.ById = {} :: { [string]: Relic }
for _, relic in RelicConfig.Relics do
	RelicConfig.ById[relic.Id] = relic
end

return RelicConfig
