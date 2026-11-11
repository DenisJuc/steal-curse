-- The relic roster: 99 anime items shown under the names players know them by (relic list v2,
-- docs/RELIC_AUDIT.md); briefs in docs/ROSTER.md.
-- Relic list v2 kept the ids of the 10 swapped relics so saves carry over untouched: PaladynsNecklace
-- = Gon's Fishing Rod, SlaughterDaemon = Nobara's Hammer & Nails, MagickStone = Leaf Village Headband,
-- DragonsBone = Inosuke's Boar Mask, GreedyIslandBook = Killua's Yo-yos, HolloBait = Substitute Soul
-- Reaper Badge, BlackenedRope = Gojo's Blindfold, RiskieDice = Hisoka's Cards, OniSpineNaginata =
-- Gaara's Gourd, StaffOfJudgement = Nezuko's Box.
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
	-- Common (17)
	{ Id = "PaladynsNecklace", Name = "Gon's Fishing Rod", Tier = "Common", Weight = 100, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Spirit", Description = "A plain rod from a quiet island. It has hooked far more than fish." },
	{ Id = "Kunay", Name = "Kunai", Tier = "Common", Weight = 96, Family = "Demonic", ObjectType = "Weapon", Vfx = "Blood", Description = "Every ninja's first blade, and usually their last resort." },
	{ Id = "VivraCard", Name = "Vivre Card", Tier = "Common", Weight = 92, Family = "Astral", ObjectType = "Book", Vfx = "Starlight", Description = "Crawls toward its owner. Burns away as they grow weaker." },
	{ Id = "SealScroll", Name = "Sealing Scroll", Tier = "Common", Weight = 88, Family = "Arcane", ObjectType = "Book", Vfx = "Spirit", Description = "Whatever was sealed inside keeps knocking." },
	{ Id = "StealBall", Name = "Steel Ball", Tier = "Common", Weight = 84, Family = "Astral", ObjectType = "Crystal", Vfx = "Storm", Description = "It never stops spinning, even in a locked box." },
	{ Id = "QuinsyBangle", Name = "Quincy Bangle", Tier = "Common", Weight = 80, Family = "Spiritual", ObjectType = "Crystal", Vfx = "Holy", Description = "Pull the charm and a bow of light snaps into your hand." },
	{ Id = "HoyPoyCapsule", Name = "Hoi-Poi Capsule", Tier = "Common", Weight = 76, Family = "Arcane", ObjectType = "Crystal", Vfx = "Spirit", Description = "Click, throw, and a whole house pops out." },
	{ Id = "SenzoBean", Name = "Senzu Bean", Tier = "Common", Weight = 72, Family = "Astral", ObjectType = "Special", Vfx = "Bloom", Description = "One bite heals everything. Ten days without food, too." },
	{ Id = "WistariaPoisonVial", Name = "Wisteria Poison", Tier = "Common", Weight = 68, Family = "Spiritual", ObjectType = "Mask", Vfx = "Toxin", Description = "Demons start coughing the moment you uncork it." },
	{ Id = "FoxxMask", Name = "Fox Mask", Tier = "Common", Weight = 64, Family = "Spiritual", ObjectType = "Mask", Vfx = "Spirit", Description = "Carved to keep its wearer safe. It remembers every one of them." },
	{ Id = "HuntarLicense", Name = "Hunter License", Tier = "Common", Weight = 60, Family = "Arcane", ObjectType = "Book", Vfx = "None", Description = "Opens doors that appear on no map." },
	{ Id = "SlaughterDaemon", Name = "Nobara's Hammer & Nails", Tier = "Common", Weight = 56, Family = "Demonic", ObjectType = "Weapon", Vfx = "Shadow", Description = "One nail in the doll, and somewhere far away a curse flinches." },
	{ Id = "AkatsukoRing", Name = "Akatsuki Ring", Tier = "Common", Weight = 52, Family = "Demonic", ObjectType = "Crystal", Vfx = "Shadow", Description = "Ten were forged. The other nine are watching." },
	{ Id = "BlackNichirenBlade", Name = "Tanjiro's Nichirin Blade", Tier = "Common", Weight = 48, Family = "Demonic", ObjectType = "Weapon", Vfx = "Shadow", Description = "Its color turned black the moment it was drawn. Nobody knows why." },
	{ Id = "MagickStone", Name = "Leaf Village Headband", Tier = "Common", Weight = 44, Family = "Arcane", ObjectType = "Special", Vfx = "Spirit", Description = "A steel plate, a cloth band, and a promise to never give up." },
	{ Id = "DragonsBone", Name = "Inosuke's Boar Mask", Tier = "Common", Weight = 40, Family = "Astral", ObjectType = "Mask", Vfx = "Storm", Description = "It still smells like the mountain. Its owner calls that a feature." },
	{ Id = "NezukosMuzzle", Name = "Nezuko's Bamboo Muzzle", Tier = "Common", Weight = 36, Family = "Demonic", ObjectType = "Mask", Vfx = "Bloom", Description = "A bamboo bit that keeps a demon gentle." },

	-- Uncommon (15)
	{ Id = "ExplodingTag", Name = "Explosive Tag", Tier = "Uncommon", Weight = 100, Family = "Arcane", ObjectType = "Book", Vfx = "Ember", Description = "The ink smolders when no one is looking." },
	{ Id = "EternalPoze", Name = "Eternal Pose", Tier = "Uncommon", Weight = 96, Family = "Spiritual", ObjectType = "Special", Vfx = "Spirit", Description = "Its needle points to one island, forever." },
	{ Id = "YutosRing", Name = "Yuta's Ring", Tier = "Uncommon", Weight = 92, Family = "Spiritual", ObjectType = "Crystal", Vfx = "Spirit", Description = "Someone still lives inside the promise." },
	{ Id = "StoneMasque", Name = "Stone Mask", Tier = "Uncommon", Weight = 88, Family = "Demonic", ObjectType = "Mask", Vfx = "Blood", Description = "Spines slide out of its rim when it tastes blood." },
	{ Id = "Skouter", Name = "Scouter", Tier = "Uncommon", Weight = 84, Family = "Astral", ObjectType = "Mask", Vfx = "Starlight", Description = "It tells you exactly how strong someone is. Rudely." },
	{ Id = "DragunRadar", Name = "Dragon Radar", Tier = "Uncommon", Weight = 80, Family = "Astral", ObjectType = "Special", Vfx = "Starlight", Description = "Seven blips. Seven wishes waiting." },
	{ Id = "TriLeafGrimoire", Name = "Three-Leaf Grimoire", Tier = "Uncommon", Weight = 76, Family = "Arcane", ObjectType = "Book", Vfx = "Bloom", Description = "Faith, hope and love, pressed into a cover." },
	{ Id = "GreedyIslandBook", Name = "Killua's Yo-yos", Tier = "Uncommon", Weight = 72, Family = "Arcane", ObjectType = "Special", Vfx = "Storm", Description = "Fifty kilos each. He spins them like toys." },
	{ Id = "BuraBuraFruit", Name = "Bara Bara Fruit", Tier = "Uncommon", Weight = 68, Family = "Arcane", ObjectType = "Special", Vfx = "Bloom", Description = "Eat it and you come apart. In a good way." },
	{ Id = "HannaHannaFruit", Name = "Hana Hana Fruit", Tier = "Uncommon", Weight = 64, Family = "Spiritual", ObjectType = "Special", Vfx = "Bloom", Description = "Hands bloom wherever you look." },
	{ Id = "SonaSonaFruit", Name = "Suna Suna Fruit", Tier = "Uncommon", Weight = 60, Family = "Astral", ObjectType = "Special", Vfx = "Sand", Description = "Sand runs through it, but never runs out." },
	{ Id = "Zangetzu", Name = "Zangetsu", Tier = "Uncommon", Weight = 56, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Spirit", Description = "Its slash leaves a crescent hanging in the air." },
	{ Id = "PowaPole", Name = "Power Pole", Tier = "Uncommon", Weight = 52, Family = "Astral", ObjectType = "Weapon", Vfx = "Storm", Description = "Say \"extend\" and mean it." },
	{ Id = "ThunderNichirenBlade", Name = "Zenitsu's Nichirin Blade", Tier = "Uncommon", Weight = 48, Family = "Demonic", ObjectType = "Weapon", Vfx = "Storm", Description = "One draw, one flash, one strike." },
	{ Id = "SerratedTwinBlades", Name = "Inosuke's Nichirin Blades", Tier = "Uncommon", Weight = 44, Family = "Demonic", ObjectType = "Weapon", Vfx = "Blood", Description = "Two blades chipped jagged on purpose. Their owner charges first." },

	-- Rare (15)
	{ Id = "HolloBait", Name = "Substitute Soul Reaper Badge", Tier = "Rare", Weight = 100, Family = "Demonic", ObjectType = "Special", Vfx = "Shadow", Description = "Press it to your chest and step out of your own body." },
	{ Id = "BlackenedRope", Name = "Gojo's Blindfold", Tier = "Rare", Weight = 96, Family = "Arcane", ObjectType = "Special", Vfx = "Void", Description = "Not to stop him seeing. To stop him seeing everything." },
	{ Id = "DeosDiary", Name = "DIO's Diary", Tier = "Rare", Weight = 92, Family = "Demonic", ObjectType = "Book", Vfx = "Blood", Description = "The last entry describes a heaven that hasn't happened yet." },
	{ Id = "LokakakaFruit", Name = "Rokakaka", Tier = "Rare", Weight = 88, Family = "Spiritual", ObjectType = "Special", Vfx = "Bloom", Description = "It heals one wound by opening another." },
	{ Id = "HiiHiiFruit", Name = "Hie Hie Fruit", Tier = "Rare", Weight = 84, Family = "Arcane", ObjectType = "Crystal", Vfx = "Frost", Description = "Your breath turns to snow around it." },
	{ Id = "MochyMochyFruit", Name = "Mochi Mochi Fruit", Tier = "Rare", Weight = 80, Family = "Astral", ObjectType = "Special", Vfx = "Starlight", Description = "Soft as dough, sticky as a promise." },
	{ Id = "RiskieDice", Name = "Hisoka's Cards", Tier = "Rare", Weight = 76, Family = "Astral", ObjectType = "Book", Vfx = "Void", Description = "Sharp enough to cut stone. He deals them with a smile." },
	{ Id = "Samehadu", Name = "Samehada", Tier = "Rare", Weight = 72, Family = "Demonic", ObjectType = "Weapon", Vfx = "Shadow", Description = "It feeds on whatever power you swing at it." },
	{ Id = "Zabimara", Name = "Zabimaru", Tier = "Rare", Weight = 68, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Spirit", Description = "Its blade comes apart into a striking snake." },
	{ Id = "Benihima", Name = "Benihime", Tier = "Rare", Weight = 64, Family = "Arcane", ObjectType = "Weapon", Vfx = "Blood", Description = "A cane, a hidden blade, and very good manners." },
	{ Id = "FlameNichirenBlade", Name = "Rengoku's Nichirin Blade", Tier = "Rare", Weight = 60, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Ember", Description = "Set your heart ablaze." },
	{ Id = "InsectNichirenBlade", Name = "Shinobu's Nichirin Blade", Tier = "Rare", Weight = 56, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Toxin", Description = "Too thin to cut. It doesn't need to." },
	{ Id = "DemonDwellingSword", Name = "Demon-Dweller Sword", Tier = "Rare", Weight = 52, Family = "Demonic", ObjectType = "Weapon", Vfx = "Void", Description = "Cast at it and it swallows the magic." },
	{ Id = "PlayfullCloud", Name = "Playful Cloud", Tier = "Rare", Weight = 48, Family = "Astral", ObjectType = "Weapon", Vfx = "Storm", Description = "Three red sections on chains. No technique, just a terrible swing." },
	{ Id = "JotarosCap", Name = "Jotaro's Cap", Tier = "Rare", Weight = 44, Family = "Astral", ObjectType = "Mask", Vfx = "Starlight", Description = "The brim melts into his hair. Nobody asks how." },

	-- Epic (13)
	{ Id = "QuadLeafGrimoire", Name = "Four-Leaf Grimoire", Tier = "Epic", Weight = 100, Family = "Arcane", ObjectType = "Book", Vfx = "Spirit", Description = "The fourth leaf holds luck. Nobody knows whose." },
	{ Id = "MaraMaraFruit", Name = "Mera Mera Fruit", Tier = "Epic", Weight = 96, Family = "Demonic", ObjectType = "Special", Vfx = "Ember", Description = "Hot enough to hurt. Hungry enough to hurt more." },
	{ Id = "GumoGumoFruit", Name = "Gomu Gomu Fruit", Tier = "Epic", Weight = 92, Family = "Spiritual", ObjectType = "Special", Vfx = "Bloom", Description = "Press an ear to it: a heartbeat like distant drums." },
	{ Id = "Senbonsakura", Name = "Senbonzakura", Tier = "Epic", Weight = 88, Family = "Spiritual", ObjectType = "Special", Vfx = "Bloom", Description = "Scatter, and a thousand blades fall like petals." },
	{ Id = "StendDisc", Name = "Stand Disc", Tier = "Epic", Weight = 84, Family = "Astral", ObjectType = "Crystal", Vfx = "Starlight", Description = "Slide it in and remember a power that was not yours." },
	{ Id = "JudgementChain", Name = "Judgment Chain", Tier = "Epic", Weight = 80, Family = "Arcane", ObjectType = "Special", Vfx = "Spirit", Description = "Break the promise and the chain closes." },
	{ Id = "OniSpineNaginata", Name = "Gaara's Gourd", Tier = "Epic", Weight = 76, Family = "Arcane", ObjectType = "Mask", Vfx = "Sand", Description = "The sand inside moves before he does." },
	{ Id = "MadorasGunbai", Name = "Madara's Gunbai", Tier = "Epic", Weight = 72, Family = "Astral", ObjectType = "Special", Vfx = "Storm", Description = "It once turned an army's charge back on itself." },
	{ Id = "Hyorinmara", Name = "Hyorinmaru", Tier = "Epic", Weight = 68, Family = "Astral", ObjectType = "Weapon", Vfx = "Frost", Description = "A dragon of ice uncoils from every swing." },
	{ Id = "PotoraEarrings", Name = "Potara Earrings", Tier = "Epic", Weight = 64, Family = "Spiritual", ObjectType = "Crystal", Vfx = "Spirit", Description = "Two people wear one each, and walk away as one." },
	{ Id = "DemonSlayingSword", Name = "Demon-Slayer Sword", Tier = "Epic", Weight = 60, Family = "Demonic", ObjectType = "Weapon", Vfx = "Void", Description = "Ugly, heavy, and every spell dies on it." },
	{ Id = "StaffOfJudgement", Name = "Nezuko's Box", Tier = "Epic", Weight = 56, Family = "Arcane", ObjectType = "Special", Vfx = "Bloom", Description = "Carried up every mountain. Someone small sleeps inside." },
	{ Id = "DemonSlashingKatana", Name = "Demon-Slasher Katana", Tier = "Epic", Weight = 52, Family = "Demonic", ObjectType = "Weapon", Vfx = "Shadow", Description = "Cuts the spell first and the caster second." },

	-- Legendary (13)
	{ Id = "KubikiriCleaver", Name = "Kubikiribocho", Tier = "Legendary", Weight = 100, Family = "Demonic", ObjectType = "Weapon", Vfx = "Blood", Description = "Break it, and it drinks blood to make itself whole." },
	{ Id = "StendArrow", Name = "Stand Arrow", Tier = "Legendary", Weight = 96, Family = "Spiritual", ObjectType = "Special", Vfx = "Holy", Description = "It chooses who it cuts. The chosen wake up changed." },
	{ Id = "SoulSplitKatana", Name = "Split Soul Katana", Tier = "Legendary", Weight = 92, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Spirit", Description = "Cuts the soul and leaves the body very confused." },
	{ Id = "FourStarDragunBall", Name = "Four-Star Dragon Ball", Tier = "Legendary", Weight = 88, Family = "Astral", ObjectType = "Crystal", Vfx = "Starlight", Description = "Gather all seven and the sky starts listening." },
	{ Id = "GoraGoraFruit", Name = "Goro Goro Fruit", Tier = "Legendary", Weight = 84, Family = "Astral", ObjectType = "Crystal", Vfx = "Storm", Description = "Lightning sleeps inside it. Lightly." },
	{ Id = "PekaPekaFruit", Name = "Pika Pika Fruit", Tier = "Legendary", Weight = 80, Family = "Spiritual", ObjectType = "Special", Vfx = "Holy", Description = "Bite it and you're gone at the speed of light." },
	{ Id = "Enmah", Name = "Zoro's Three Swords", Tier = "Legendary", Weight = 76, Family = "Arcane", ObjectType = "Weapon", Vfx = "Shadow", Description = "Wado, Kitetsu and Enma. One goes in the mouth." },
	{ Id = "BashosanFan", Name = "Bashosen", Tier = "Legendary", Weight = 72, Family = "Astral", ObjectType = "Special", Vfx = "Storm", Description = "Each wave brings a different element." },
	{ Id = "KohakoJar", Name = "Amber Purifying Jar", Tier = "Legendary", Weight = 68, Family = "Spiritual", ObjectType = "Mask", Vfx = "Spirit", Description = "Say your favorite word near it and you're inside." },
	{ Id = "QuinsyMedallion", Name = "Quincy Medallion", Tier = "Legendary", Weight = 64, Family = "Arcane", ObjectType = "Crystal", Vfx = "Starlight", Description = "It steals the power you lean on most." },
	{ Id = "DemonDestroyingSword", Name = "Demon-Destroyer Sword", Tier = "Legendary", Weight = 60, Family = "Demonic", ObjectType = "Weapon", Vfx = "Blood", Description = "A demon is still screaming somewhere inside the steel." },
	{ Id = "ScarlettEyes", Name = "Scarlet Eyes", Tier = "Legendary", Weight = 56, Family = "Demonic", ObjectType = "Mask", Vfx = "Blood", Description = "Two scarlet eyes float in the jar. They follow you." },
	{ Id = "HanafudaEarrings", Name = "Tanjiro's Hanafuda Earrings", Tier = "Legendary", Weight = 52, Family = "Spiritual", ObjectType = "Crystal", Vfx = "Ember", Description = "Passed down with a dance, and the dance hides a sun." },

	-- Mythic (11)
	{ Id = "HolloMask", Name = "Hollow Mask", Tier = "Mythic", Weight = 100, Family = "Astral", ObjectType = "Mask", Vfx = "Starlight", Description = "Put it on and something else looks out through your eyes." },
	{ Id = "SukanasFinger", Name = "Sukuna's Finger", Tier = "Mythic", Weight = 96, Family = "Demonic", ObjectType = "Special", Vfx = "Blood", Description = "One of twenty. It still twitches toward its throne." },
	{ Id = "DeathPaintWomb", Name = "Death Painting Womb", Tier = "Mythic", Weight = 92, Family = "Demonic", ObjectType = "Mask", Vfx = "Toxin", Description = "Something unborn floats in the brine. It is growing." },
	{ Id = "InverseSpearOfHeaven", Name = "Inverted Spear of Heaven", Tier = "Mythic", Weight = 88, Family = "Arcane", ObjectType = "Weapon", Vfx = "Void", Description = "Every technique it touches unravels into nothing." },
	{ Id = "OpiOpiFruit", Name = "Ope Ope Fruit", Tier = "Mythic", Weight = 84, Family = "Arcane", ObjectType = "Special", Vfx = "Spirit", Description = "Inside its glowing room, you are the surgeon." },
	{ Id = "YamuYamuFruit", Name = "Yami Yami Fruit", Tier = "Mythic", Weight = 80, Family = "Astral", ObjectType = "Crystal", Vfx = "Void", Description = "Light falls into it and does not come back out." },
	{ Id = "Yorru", Name = "Yoru", Tier = "Mythic", Weight = 76, Family = "Demonic", ObjectType = "Weapon", Vfx = "Shadow", Description = "It split an iceberg in half, then went back to sleep." },
	{ Id = "SaintsCorpsePiece", Name = "Saint's Corpse Part", Tier = "Mythic", Weight = 72, Family = "Spiritual", ObjectType = "Special", Vfx = "Holy", Description = "Part of a saint who walked across a continent. It wants to keep walking." },
	{ Id = "ToryToryPhoenixFruit", Name = "Tori Tori Fruit (Phoenix)", Tier = "Mythic", Weight = 68, Family = "Spiritual", ObjectType = "Special", Vfx = "Ember", Description = "It burns blue, and heals whatever it burns." },
	{ Id = "BenihisagaGourd", Name = "Benihisago", Tier = "Mythic", Weight = 64, Family = "Arcane", ObjectType = "Mask", Vfx = "Spirit", Description = "Answer when it calls your name, and you're sealed inside." },
	{ Id = "HokageHat", Name = "Hokage Hat", Tier = "Mythic", Weight = 60, Family = "Spiritual", ObjectType = "Mask", Vfx = "Ember", Description = "Heavy with every name that wore it before." },

	-- Celestial (11)
	{ Id = "Hogyuku", Name = "Hogyoku", Tier = "Celestial", Weight = 100, Family = "Astral", ObjectType = "Special", Vfx = "Starlight", Description = "It grants what its holder's heart truly wants." },
	{ Id = "SuperDragunBall", Name = "Super Dragon Ball", Tier = "Celestial", Weight = 96, Family = "Arcane", ObjectType = "Crystal", Vfx = "Starlight", Description = "Big as a planet once. Folded small for travel." },
	{ Id = "BeetleStendArrow", Name = "Requiem Arrow", Tier = "Celestial", Weight = 92, Family = "Spiritual", ObjectType = "Special", Vfx = "Holy", Description = "Pierce what you are; become what you will be." },
	{ Id = "Kamutoki", Name = "Kamutoke", Tier = "Celestial", Weight = 88, Family = "Astral", ObjectType = "Weapon", Vfx = "Storm", Description = "Strike it once: a drum. Strike it twice: the sky answers." },
	{ Id = "PrizonRealm", Name = "Prison Realm", Tier = "Celestial", Weight = 84, Family = "Arcane", ObjectType = "Special", Vfx = "Void", Description = "Bigger inside than the world outside, and much harder to leave." },
	{ Id = "ShichiseiBlade", Name = "Shichiseiken", Tier = "Celestial", Weight = 80, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Spirit", Description = "No steel at all: seven stars and a will." },
	{ Id = "UwoUwoDragonFruit", Name = "Uo Uo Fruit (Azure Dragon)", Tier = "Celestial", Weight = 76, Family = "Astral", ObjectType = "Crystal", Vfx = "Storm", Description = "An azure dragon sleeps curled up inside the rind." },
	{ Id = "BlueSpidderLily", Name = "Blue Spider Lily", Tier = "Celestial", Weight = 72, Family = "Demonic", ObjectType = "Special", Vfx = "Bloom", Description = "Blooms only in daylight. Demons would kill for one." },
	{ Id = "FlyingNimbus", Name = "Flying Nimbus", Tier = "Celestial", Weight = 68, Family = "Spiritual", ObjectType = "Special", Vfx = "Holy", Description = "Only the pure of heart can ride it. Most people fall straight through." },
	{ Id = "StrawHat", Name = "Luffy's Straw Hat", Tier = "Celestial", Weight = 64, Family = "Arcane", ObjectType = "Mask", Vfx = "Bloom", Description = "Handed down with a promise: come back a great pirate." },
	{ Id = "MahoragasWheel", Name = "Mahoraga's Wheel", Tier = "Celestial", Weight = 60, Family = "Demonic", ObjectType = "Crystal", Vfx = "Void", Description = "It turns once for every attack. After that, nothing works twice." },

	-- Cosmic (4): kept small and nearly flat (GDD 5.2 tradeoff), rarest share 22%.
	{ Id = "RedStoneOfAia", Name = "Red Stone of Aja", Tier = "Cosmic", Weight = 28, Family = "Astral", ObjectType = "Crystal", Vfx = "Starlight", Description = "Focus sunlight through it and it pierces anything." },
	{ Id = "GurraGurraFruit", Name = "Gura Gura Fruit", Tier = "Cosmic", Weight = 26, Family = "Arcane", ObjectType = "Special", Vfx = "Storm", Description = "Tap it and the air cracks like glass." },
	{ Id = "PentaLeafGrimoire", Name = "Five-Leaf Grimoire", Tier = "Cosmic", Weight = 24, Family = "Demonic", ObjectType = "Book", Vfx = "Void", Description = "A devil lives on its fifth leaf. It is very patient." },
	{ Id = "AncientSunriseBlade", Name = "Yoriichi's Nichirin Blade", Tier = "Cosmic", Weight = 22, Family = "Spiritual", ObjectType = "Weapon", Vfx = "Holy", Description = "The blade that taught demons to fear the morning." },
} :: { Relic }

RelicConfig.ById = {} :: { [string]: Relic }
for _, relic in RelicConfig.Relics do
	RelicConfig.ById[relic.Id] = relic
end

return RelicConfig
