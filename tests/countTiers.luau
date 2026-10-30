local RelicConfig = require("../src/shared/RelicConfig")
local RarityConfig = require("../src/shared/RarityConfig")
local epic, epicPlus = 0, 0
local byTier = {}
for _, r in RelicConfig.Relics do
	byTier[r.Tier] = (byTier[r.Tier] or 0) + 1
	if r.Tier == "Epic" then
		epic += 1
	end
	if (RarityConfig.IndexById[r.Tier] or 0) >= RarityConfig.IndexById.Epic then
		epicPlus += 1
	end
end
print("Epic exact", epic)
print("Epic+", epicPlus)
for _, t in RarityConfig.Tiers do
	print(t.Id, byTier[t.Id] or 0)
end
