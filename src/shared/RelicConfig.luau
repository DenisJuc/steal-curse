-- The relic roster (Slice 8a): the 92 GDD section 11 items under altered release names; briefs in
-- docs/ROSTER.md.
-- Weight = relative chance inside its tier (every weight in a tier is different, so every relic
-- has its own base odds); base odds are derived by RollMath, never typed by hand.
-- ObjectType picks the shared capture animation family (Weapon, Book, Mask, Crystal, Special).
-- Vfx = ambient effect profile for pedestals, reveals and carry (applied in Slice 8c).
-- Ids are saved in player data: never rename or remove one (Migrations renames the Slice 0 ids).

local RelicConfig = {}

export type Relic = {
	Id: string,
	Name: string,
	Tier: string,
	Weight: number,
	Family: string,
	ObjectType: string,
	Vfx: string,
	Description: string,
}

RelicConfig.Families = { "Demonic", "Spiritual", "Arcane", "Astral" }
RelicConfig.ObjectTypes = { "Weapon", "Book", "Mask", "Crystal", "Special" }
RelicConfig.VfxProfiles =
	{ "None", "Ember", "Frost", "Storm", "Shadow", "Blood", "Holy", "Spirit", "Bloom", "Void", "Starlight", "Sand", "Toxin" }

-- stylua: ignore
RelicConfig.Relics = {
	-- Common (16)
	{ Id = "PaladynsNecklace", Name = "Liar's Pendant", Tier = "Common", Weight = 100, Family = "Spiritual", ObjectType = "Crystal", Vfx = "Holy", Description = "Tell a lie while wearing it and it tightens." },
	{ Id = "Kunay", Name = "Kunai", Tier = "Common", Weight = 96, Family = "Demonic", ObjectType = "Weapon", Vfx = "Blood", Description = "Every ninja's first blade, and usually their last resort." },
	{ Id = "VivraCard", Name = "Life Card", Tier = "Common", Weight = 92, Family = "Astral", ObjectType = "Book", Vfx = "Starlight", Description = "Crawls toward its owner. Burns away as they grow weaker." },
	{ Id = "SealScroll", Name = "Seal Scroll", Tier = "Common", Weight = 88, Family = "Arcane", ObjectType = "Book", Vfx = "Spirit", Description = "Whatever was sealed inside keeps knocking." },
	{ Id = "StealBall", Name = "Spinning Steel Ball", Tier = "Common", Weight = 84, Family = "Astral", ObjectType = "Crystal", Vfx = "Storm", Description = "It never stops spinning, even in a locked box." },
	{ Id = "QuinsyBangle", Name = "Spirit Bow Bangle", Tier = "Common", Weight = 80, Family = "Spiritual", ObjectType = "Crystal", Vfx = "Holy", Description = "Pull the charm and a bow of light snaps into your hand." },
	{ Id = "HoyPoyCapsule", Name = "Pocket House Capsule", Tier = "Common", Weight = 76, Family = "Arcane", ObjectType = "Crystal", Vfx = "Spirit", Description = "Click, throw, and a whole house pops out." },
	{ Id = "SenzoBean", Name = "Hermit Bean", Tier = "Common", Weight = 72, Family = "Astral", ObjectType = "Special", Vfx = "Bloom", Description = "One bite heals everything. Ten days without food, too." },
	{ Id = "WistariaPoisonVial", Name = "Wisteria Poison Vial", Tier = "Common", Weight = 68, Family = "Spiritual", ObjectType = "Mask", Vfx = "Toxin", Description = "Demons start coughing the moment you uncork it." },
	{ Id = "FoxxMask", Name = "Warding Fox Mask", Tier = "Common", Weight = 64, Family = "Spiritual", ObjectType = "Mask", Vfx = "Spirit", Description = "Carved to keep its wearer safe. It remembers every one of them." },
	{ Id = "HuntarLicense", Name = "Hunter License", Tier = "Common", Weight = 60, Family = "Arcane", ObjectType = "Book", Vfx = "None", Description = "Opens doors that appear on no map." },
	{ Id = "SlaughterDaemon", Name = "Slaughter Demon Knife", Tier = "Common", Weight = 56, Family = "Demonic", ObjectType = "Weapon", Vfx = "Shadow", Description = "A cursed knife that cuts best when it shouldn't." },
	{ Id = "AkatsukoRing", Name = "Red Dawn Ring", Tier = "Common", Weight = 52, Family = "Demonic", ObjectType = "Crystal", Vfx = "Shadow", Description = "Ten were forged. The other nine are watching." },
	{ Id = "BlackNichirenBlade", Name = "Black Sun-Steel Blade", Tier = "Common", Weight = 48, Family = "Demonic", ObjectType = "Weapon", Vfx = "Shadow", Description = "Its color turned black the moment it was drawn. Nobody knows why." },
	{ Id = "MagickStone", Name = "Kingdom Magic Stone", Tier = "Common", Weight = 44, Family = "Arcane", ObjectType = "Crystal", Vfx = "Spirit", Description = "One of the stones that holds the magic of the kingdom." },
	{ Id = "DragonsBone", Name = "Dragon's Bone", Tier = "Common", Weight = 40, Family = "Astral", ObjectType = "Weapon", Vfx = "Storm", Description = "Every blow it takes, it gives back louder." },

	-- Uncommon (15)
	{ Id = "ExplodingTag", Name = "Exploding Tag", Tier = "Uncommon", Weight = 100, Family = "Arcane", ObjectType = "Book", Vfx = "Ember", Description = "The ink smolders when no one is looking." },
	{ Id = "EternalPoze", Name = "Eternal Island Compass", Tier = "Uncommon", Weight = 96, Family = "Spiritual", ObjectType = "Special", Vfx = "Spirit", Description = "Its needle points to one island, forever." },
	{ Id = "YutosRing", Name = "Cursed Promise Ring", Tier = "Uncommon", Weight = 92, Family = "Spiritual", ObjectType = "Crystal", Vfx = "Spirit", Description = "Someone still lives inside the promise." },
	{ Id = "StoneMasque", Name = "Vampire Stone Mask", Tier = "Uncommon", Weight = 88, Family = "Demonic", ObjectType = "Mask", Vfx = "Blood", Description = "Spines slide out of its rim when it tastes blood." },
	{ Id = "Skouter", Name = "Power Scouter", Tier = "Uncommon", Weight = 84, Family = "Astral", ObjectType = "Mask", Vfx = "Starlight", Description = "It tells you exactly how strong someone is. Rudely." },
	{ Id = "DragunRadar", Name = "Wish Orb Radar", Tier = "Uncommon", Weight = 80, Family = "Astral", ObjectType = "Special", Vfx = "Starlight", Description = "Seven blips. Seven wishes waiting." },
	{ Id = "TriLeafGrimoire", Name = "Three-Leaf Grimoire", Tier = "Uncommon", Weight = 76, Family = "Arcane", ObjectType = "Book", Vfx = "Bloom", Description = "Faith, hope and love, pressed into a cover." },
	{ Id = "GreedyIslandBook", Name = "Greed Game Binder", Tier = "Uncommon", Weight = 72, Family = "Arcane", ObjectType = "Book", Vfx = "Spirit", Description = "Every card inside is a door. Most of them are locked." },
	{ Id = "BuraBuraFruit", Name = "Split Fruit", Tier = "Uncommon", Weight = 68, Family = "Arcane", ObjectType = "Special", Vfx = "Bloom", Description = "Eat it and you come apart. In a good way." },
	{ Id = "HannaHannaFruit", Name = "Blossom Fruit", Tier = "Uncommon", Weight = 64, Family = "Spiritual", ObjectType = "Special", Vfx = "Bloom", Description = "Hands bloom wherever you look." },
	{ Id = "SonaSonaFruit", Name = "Sand Fruit", Tier = "Uncommon", Weight = 60, Family = "Astral", ObjectType = "Special", Vfx = "Sand", Description = "Sand runs through it, but never runs out." },
	{ Id = "Zangetzu", Name = "Crescent Moon Cleaver", Tier = "Uncommon", Weight = 56, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Spirit", Description = "Its slash leaves a crescent hanging in the air." },
	{ Id = "PowaPole", Name = "Growing Power Pole", Tier = "Uncommon", Weight = 52, Family = "Astral", ObjectType = "Weapon", Vfx = "Storm", Description = "Say \"extend\" and mean it." },
	{ Id = "ThunderNichirenBlade", Name = "Thunder Sun-Steel Blade", Tier = "Uncommon", Weight = 48, Family = "Demonic", ObjectType = "Weapon", Vfx = "Storm", Description = "One draw, one flash, one strike." },
	{ Id = "SerratedTwinBlades", Name = "Serrated Twin Blades", Tier = "Uncommon", Weight = 44, Family = "Demonic", ObjectType = "Weapon", Vfx = "Blood", Description = "Made for a demon's neck. Two at a time." },

	-- Rare (14)
	{ Id = "HolloBait", Name = "Hollow Lure", Tier = "Rare", Weight = 100, Family = "Demonic", ObjectType = "Special", Vfx = "Shadow", Description = "Crush it and every hungry spirit nearby comes running." },
	{ Id = "BlackenedRope", Name = "Blackened Rope", Tier = "Rare", Weight = 96, Family = "Arcane", ObjectType = "Special", Vfx = "Void", Description = "Any technique it touches comes loose like a bad knot." },
	{ Id = "DeosDiary", Name = "Vampire's Heaven Diary", Tier = "Rare", Weight = 92, Family = "Demonic", ObjectType = "Book", Vfx = "Blood", Description = "The last entry describes a heaven that hasn't happened yet." },
	{ Id = "LokakakaFruit", Name = "Wound-Swap Fruit", Tier = "Rare", Weight = 88, Family = "Spiritual", ObjectType = "Special", Vfx = "Bloom", Description = "It heals one wound by opening another." },
	{ Id = "HiiHiiFruit", Name = "Ice Fruit", Tier = "Rare", Weight = 84, Family = "Arcane", ObjectType = "Crystal", Vfx = "Frost", Description = "Your breath turns to snow around it." },
	{ Id = "MochyMochyFruit", Name = "Dough Fruit", Tier = "Rare", Weight = 80, Family = "Astral", ObjectType = "Special", Vfx = "Starlight", Description = "Soft as dough, sticky as a promise." },
	{ Id = "RiskieDice", Name = "Risky Dice", Tier = "Rare", Weight = 76, Family = "Astral", ObjectType = "Crystal", Vfx = "Void", Description = "Great luck on most faces. On one face, something terrible." },
	{ Id = "Samehadu", Name = "Shark-Skin Greatsword", Tier = "Rare", Weight = 72, Family = "Demonic", ObjectType = "Weapon", Vfx = "Shadow", Description = "It feeds on whatever power you swing at it." },
	{ Id = "Zabimara", Name = "Snake-Tail Blade", Tier = "Rare", Weight = 68, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Spirit", Description = "Its blade comes apart into a striking snake." },
	{ Id = "Benihima", Name = "Crimson Princess Cane", Tier = "Rare", Weight = 64, Family = "Arcane", ObjectType = "Weapon", Vfx = "Blood", Description = "A cane, a hidden blade, and very good manners." },
	{ Id = "FlameNichirenBlade", Name = "Flame Sun-Steel Blade", Tier = "Rare", Weight = 60, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Ember", Description = "Set your heart ablaze." },
	{ Id = "InsectNichirenBlade", Name = "Insect Sun-Steel Blade", Tier = "Rare", Weight = 56, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Toxin", Description = "Too thin to cut. It doesn't need to." },
	{ Id = "DemonDwellingSword", Name = "Demon-Dwelling Sword", Tier = "Rare", Weight = 52, Family = "Demonic", ObjectType = "Weapon", Vfx = "Void", Description = "Cast at it and it swallows the magic." },
	{ Id = "PlayfullCloud", Name = "Thunder Weather Staff", Tier = "Rare", Weight = 48, Family = "Astral", ObjectType = "Weapon", Vfx = "Storm", Description = "Three sections, three thunderclaps." },

	-- Epic (13)
	{ Id = "QuadLeafGrimoire", Name = "Four-Leaf Grimoire", Tier = "Epic", Weight = 100, Family = "Arcane", ObjectType = "Book", Vfx = "Spirit", Description = "The fourth leaf holds luck. Nobody knows whose." },
	{ Id = "MaraMaraFruit", Name = "Magma Fruit", Tier = "Epic", Weight = 96, Family = "Demonic", ObjectType = "Special", Vfx = "Ember", Description = "Hot enough to hurt. Hungry enough to hurt more." },
	{ Id = "GumoGumoFruit", Name = "Rubber Fruit", Tier = "Epic", Weight = 92, Family = "Spiritual", ObjectType = "Special", Vfx = "Bloom", Description = "Press an ear to it: a heartbeat like distant drums." },
	{ Id = "Senbonsakura", Name = "Thousand Petal Blade", Tier = "Epic", Weight = 88, Family = "Spiritual", ObjectType = "Special", Vfx = "Bloom", Description = "Scatter, and a thousand blades fall like petals." },
	{ Id = "StendDisc", Name = "Mysterious Disc", Tier = "Epic", Weight = 84, Family = "Astral", ObjectType = "Crystal", Vfx = "Starlight", Description = "Slide it in and remember a power that was not yours." },
	{ Id = "JudgementChain", Name = "Judgement Chain", Tier = "Epic", Weight = 80, Family = "Arcane", ObjectType = "Special", Vfx = "Spirit", Description = "Break the promise and the chain closes." },
	{ Id = "OniSpineNaginata", Name = "Oni-Spine Naginata", Tier = "Epic", Weight = 76, Family = "Arcane", ObjectType = "Weapon", Vfx = "Void", Description = "Carved from a demon's spine. It still flinches at prayers." },
	{ Id = "MadorasGunbai", Name = "Reflecting War Fan", Tier = "Epic", Weight = 72, Family = "Astral", ObjectType = "Special", Vfx = "Storm", Description = "It once turned an army's charge back on itself." },
	{ Id = "Hyorinmara", Name = "Ice Dragon Blade", Tier = "Epic", Weight = 68, Family = "Astral", ObjectType = "Weapon", Vfx = "Frost", Description = "A dragon of ice uncoils from every swing." },
	{ Id = "PotoraEarrings", Name = "Fusion Earrings", Tier = "Epic", Weight = 64, Family = "Spiritual", ObjectType = "Crystal", Vfx = "Spirit", Description = "Two people wear one each, and walk away as one." },
	{ Id = "DemonSlayingSword", Name = "Demon-Slaying Sword", Tier = "Epic", Weight = 60, Family = "Demonic", ObjectType = "Weapon", Vfx = "Void", Description = "Ugly, heavy, and every spell dies on it." },
	{ Id = "StaffOfJudgement", Name = "Staff of Judgement", Tier = "Epic", Weight = 56, Family = "Arcane", ObjectType = "Weapon", Vfx = "Holy", Description = "It weighs the lie you are about to tell." },
	{ Id = "DemonSlashingKatana", Name = "Demon-Slashing Katana", Tier = "Epic", Weight = 52, Family = "Demonic", ObjectType = "Weapon", Vfx = "Shadow", Description = "Cuts the spell first and the caster second." },

	-- Legendary (12)
	{ Id = "KubikiriCleaver", Name = "Executioner's Cleaver", Tier = "Legendary", Weight = 100, Family = "Demonic", ObjectType = "Weapon", Vfx = "Blood", Description = "Break it, and it drinks blood to make itself whole." },
	{ Id = "StendArrow", Name = "Mysterious Arrow", Tier = "Legendary", Weight = 96, Family = "Spiritual", ObjectType = "Special", Vfx = "Holy", Description = "It chooses who it cuts. The chosen wake up changed." },
	{ Id = "SoulSplitKatana", Name = "Soul Split Katana", Tier = "Legendary", Weight = 92, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Spirit", Description = "Cuts the soul and leaves the body very confused." },
	{ Id = "FourStarDragunBall", Name = "Four-Star Wish Orb", Tier = "Legendary", Weight = 88, Family = "Astral", ObjectType = "Crystal", Vfx = "Starlight", Description = "Gather all seven and the sky starts listening." },
	{ Id = "GoraGoraFruit", Name = "Lightning Fruit", Tier = "Legendary", Weight = 84, Family = "Astral", ObjectType = "Crystal", Vfx = "Storm", Description = "Lightning sleeps inside it. Lightly." },
	{ Id = "PekaPekaFruit", Name = "Light Fruit", Tier = "Legendary", Weight = 80, Family = "Spiritual", ObjectType = "Special", Vfx = "Holy", Description = "Bite it and you're gone at the speed of light." },
	{ Id = "Enmah", Name = "Enma", Tier = "Legendary", Weight = 76, Family = "Arcane", ObjectType = "Weapon", Vfx = "Shadow", Description = "It pulls power out of whoever holds it. Only the strong keep up." },
	{ Id = "BashosanFan", Name = "Bashosen Fan", Tier = "Legendary", Weight = 72, Family = "Astral", ObjectType = "Special", Vfx = "Storm", Description = "Each wave brings a different element." },
	{ Id = "KohakoJar", Name = "Sealing Word Jar", Tier = "Legendary", Weight = 68, Family = "Spiritual", ObjectType = "Mask", Vfx = "Spirit", Description = "Say your favorite word near it and you're inside." },
	{ Id = "QuinsyMedallion", Name = "Power-Stealing Medallion", Tier = "Legendary", Weight = 64, Family = "Arcane", ObjectType = "Crystal", Vfx = "Starlight", Description = "It steals the power you lean on most." },
	{ Id = "DemonDestroyingSword", Name = "Demon-Destroying Sword", Tier = "Legendary", Weight = 60, Family = "Demonic", ObjectType = "Weapon", Vfx = "Blood", Description = "A demon is still screaming somewhere inside the steel." },
	{ Id = "ScarlettEyes", Name = "Scarlet Eyes", Tier = "Legendary", Weight = 56, Family = "Demonic", ObjectType = "Mask", Vfx = "Blood", Description = "Two scarlet eyes float in the jar. They follow you." },

	-- Mythic (10)
	{ Id = "HolloMask", Name = "Hollow Mask", Tier = "Mythic", Weight = 100, Family = "Astral", ObjectType = "Mask", Vfx = "Starlight", Description = "Put it on and something else looks out through your eyes." },
	{ Id = "SukanasFinger", Name = "Cursed King's Finger", Tier = "Mythic", Weight = 96, Family = "Demonic", ObjectType = "Special", Vfx = "Blood", Description = "One of twenty. It still twitches toward its throne." },
	{ Id = "DeathPaintWomb", Name = "Death Paint Womb", Tier = "Mythic", Weight = 92, Family = "Demonic", ObjectType = "Mask", Vfx = "Toxin", Description = "Something unborn floats in the brine. It is growing." },
	{ Id = "InverseSpearOfHeaven", Name = "Inverse Spear of Heaven", Tier = "Mythic", Weight = 88, Family = "Arcane", ObjectType = "Weapon", Vfx = "Void", Description = "Every technique it touches unravels into nothing." },
	{ Id = "OpiOpiFruit", Name = "Operation Fruit", Tier = "Mythic", Weight = 84, Family = "Arcane", ObjectType = "Special", Vfx = "Spirit", Description = "Inside its glowing room, you are the surgeon." },
	{ Id = "YamuYamuFruit", Name = "Darkness Fruit", Tier = "Mythic", Weight = 80, Family = "Astral", ObjectType = "Crystal", Vfx = "Void", Description = "Light falls into it and does not come back out." },
	{ Id = "Yorru", Name = "Black Greatblade", Tier = "Mythic", Weight = 76, Family = "Demonic", ObjectType = "Weapon", Vfx = "Shadow", Description = "It split an iceberg in half, then went back to sleep." },
	{ Id = "SaintsCorpsePiece", Name = "Saint's Corpse Piece", Tier = "Mythic", Weight = 72, Family = "Spiritual", ObjectType = "Special", Vfx = "Holy", Description = "Part of a saint who walked across a continent. It wants to keep walking." },
	{ Id = "ToryToryPhoenixFruit", Name = "Phoenix Fruit", Tier = "Mythic", Weight = 68, Family = "Spiritual", ObjectType = "Special", Vfx = "Ember", Description = "It burns blue, and heals whatever it burns." },
	{ Id = "BenihisagaGourd", Name = "Crimson Calling Gourd", Tier = "Mythic", Weight = 64, Family = "Arcane", ObjectType = "Mask", Vfx = "Spirit", Description = "Answer when it calls your name, and you're sealed inside." },

	-- Celestial (8)
	{ Id = "Hogyuku", Name = "Heart-Wish Jewel", Tier = "Celestial", Weight = 100, Family = "Astral", ObjectType = "Special", Vfx = "Starlight", Description = "It grants what its holder's heart truly wants." },
	{ Id = "SuperDragunBall", Name = "Planet Wish Orb", Tier = "Celestial", Weight = 96, Family = "Arcane", ObjectType = "Crystal", Vfx = "Starlight", Description = "Big as a planet once. Folded small for travel." },
	{ Id = "BeetleStendArrow", Name = "Beetle Arrow", Tier = "Celestial", Weight = 92, Family = "Spiritual", ObjectType = "Special", Vfx = "Holy", Description = "Pierce what you are; become what you will be." },
	{ Id = "Kamutoki", Name = "Sky Thunder Drum", Tier = "Celestial", Weight = 88, Family = "Astral", ObjectType = "Weapon", Vfx = "Storm", Description = "Strike it once: a drum. Strike it twice: the sky answers." },
	{ Id = "PrizonRealm", Name = "Prison Realm Cube", Tier = "Celestial", Weight = 84, Family = "Arcane", ObjectType = "Special", Vfx = "Void", Description = "Bigger inside than the world outside, and much harder to leave." },
	{ Id = "ShichiseiBlade", Name = "Seven-Star Blade", Tier = "Celestial", Weight = 80, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Spirit", Description = "No steel at all: seven stars and a will." },
	{ Id = "UwoUwoDragonFruit", Name = "Azure Dragon Fruit", Tier = "Celestial", Weight = 76, Family = "Astral", ObjectType = "Crystal", Vfx = "Storm", Description = "An azure dragon sleeps curled up inside the rind." },
	{ Id = "BlueSpidderLily", Name = "Blue Spider Lily", Tier = "Celestial", Weight = 72, Family = "Demonic", ObjectType = "Special", Vfx = "Bloom", Description = "Blooms only in daylight. Demons would kill for one." },

	-- Cosmic (4): kept small and nearly flat (GDD 5.2 tradeoff), rarest share 22%.
	{ Id = "RedStoneOfAia", Name = "Red Sun Stone", Tier = "Cosmic", Weight = 28, Family = "Astral", ObjectType = "Crystal", Vfx = "Starlight", Description = "Focus sunlight through it and it pierces anything." },
	{ Id = "GurraGurraFruit", Name = "Quake Fruit", Tier = "Cosmic", Weight = 26, Family = "Arcane", ObjectType = "Special", Vfx = "Storm", Description = "Tap it and the air cracks like glass." },
	{ Id = "PentaLeafGrimoire", Name = "Five-Leaf Grimoire", Tier = "Cosmic", Weight = 24, Family = "Demonic", ObjectType = "Book", Vfx = "Void", Description = "A devil lives on its fifth leaf. It is very patient." },
	{ Id = "AncientSunriseBlade", Name = "Ancient Sunrise Blade", Tier = "Cosmic", Weight = 22, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Holy", Description = "The blade that taught demons to fear the morning." },
} :: { Relic }

RelicConfig.ById = {} :: { [string]: Relic }
for _, relic in RelicConfig.Relics do
	RelicConfig.ById[relic.Id] = relic
end

return RelicConfig
