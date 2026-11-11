-- Relic models that failed the Nov 10 recognisability pass (docs/MODEL_REVIEW.md) and need a new
-- concept-first model. Every relic NOT listed here counts as approved, so take an id out of this list
-- once its model is good. `/modelreview` in Studio spawns exactly these on spinning stands.
-- `Later` holds weak models the owner chose to keep for now and judge again on the final sweep
-- (`/modelreview later`). They count as approved until then.

local ModelReview = {}

export type Entry = { Id: string, Reason: string }

-- stylua: ignore
ModelReview.Redo = {
	-- Nov 11: all 24 remade from approved concepts (Tripo image-to-3D). Add ids back here if a model fails review.
	-- Owner's Nov 11 review of the new models:
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
