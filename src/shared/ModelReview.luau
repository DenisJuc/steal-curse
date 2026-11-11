-- Relic models that failed the Nov 10 recognisability pass (docs/MODEL_REVIEW.md) and need a new
-- concept-first model. Every relic NOT listed here counts as approved, so take an id out of this list
-- once its model is good. `/modelreview` in Studio spawns exactly these on spinning stands.
-- `Later` holds weak models the owner chose to keep for now and judge again on the final sweep
-- (`/modelreview later`). They count as approved until then.

local ModelReview = {}

export type Entry = { Id: string, Reason: string }

-- stylua: ignore
ModelReview.Redo = {
	-- Common
	{ Id = "StealBall", Reason = "black bomb with a red band, not a shiny dimpled steel ball" },
	{ Id = "HoyPoyCapsule", Reason = "relic is now Ichiraku Ramen; still the old capsule model" },
	{ Id = "SenzoBean", Reason = "relic is now Den Den Mushi; still the old bean model" },
	{ Id = "BlackNichirenBlade", Reason = "thin purple dagger, not Tanjiro's black katana with the round guard" },
	-- Rare
	{ Id = "DemonDwellingSword", Reason = "spiky dagger, not a thin black katana" },
	-- Epic
	{ Id = "Senbonsakura", Reason = "a square guard and a handle, no blade or petals" },
	{ Id = "MadorasGunbai", Reason = "plain tan disc like a frying pan, no war-fan look or tomoe" },
	{ Id = "DemonSlayingSword", Reason = "realistic rock texture, doesn't read as Asta's sword" },
	-- Legendary
	{ Id = "KubikiriCleaver", Reason = "grey jagged dagger, no huge blade with the round hole" },
	{ Id = "BashosanFan", Reason = "realistic palm leaf" },
	{ Id = "KohakoJar", Reason = "realistic brown pot" },
	{ Id = "QuinsyMedallion", Reason = "realistic grey puck with a plain cross" },
	{ Id = "DemonDestroyingSword", Reason = "generic skull fantasy sword, realistic" },
	{ Id = "ScarlettEyes", Reason = "murky realistic jar, the eye barely shows" },
	-- Mythic
	{ Id = "HolloMask", Reason = "generic skull with yellow eyes, not Ichigo's white mask with red stripes" },
	{ Id = "DeathPaintWomb", Reason = "grimy pickle jar" },
	{ Id = "Yorru", Reason = "thin curved grey sabre, not Mihawk's huge black cross sword" },
	{ Id = "ToryToryPhoenixFruit", Reason = "green pineapple, not a blue-and-gold flame fruit" },
	-- Celestial
	{ Id = "BeetleStendArrow", Reason = "lumpy gold blob, messy realistic texture" },
	{ Id = "PrizonRealm", Reason = "right shape but dark red; the Prison Realm is a pale cube" },
	{ Id = "ShichiseiBlade", Reason = "generic realistic sword with stars" },
	-- Cosmic
	{ Id = "RedStoneOfAia", Reason = "red gem stuck on a realistic rock lump" },
	{ Id = "PentaLeafGrimoire", Reason = "muddy black slab, no five-leaf clover" },
	{ Id = "AncientSunriseBlade", Reason = "plain black katana, no sun guard" },
} :: { Entry }

-- stylua: ignore
ModelReview.Later = {
	{ Id = "QuinsyBangle", Reason = "rough stone band with a plain cross, realistic" },
	{ Id = "FoxxMask", Reason = "realistic weathered wolf head, not a clean flat fox mask" },
	{ Id = "SonaSonaFruit", Reason = "odd lumps stick out of the sides like handles" },
	{ Id = "QuadLeafGrimoire", Reason = "plain dark green book, no four-leaf clover" },
	{ Id = "SukanasFinger", Reason = "red sausage with a bandage, not a withered black-nailed finger" },
	{ Id = "Kamutoki", Reason = "odd dagger-staff, doesn't read as a lightning hammer" },
} :: { Entry }

ModelReview.ById = {} :: { [string]: Entry }
for _, entry in ModelReview.Redo do
	ModelReview.ById[entry.Id] = entry
end
ModelReview.LaterById = {} :: { [string]: Entry }
for _, entry in ModelReview.Later do
	ModelReview.LaterById[entry.Id] = entry
end

return ModelReview
