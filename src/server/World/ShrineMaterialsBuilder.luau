-- Dresses the town with the shrine MaterialVariants (ShrineMaterials): plot courtyards, walls and
-- paths, the hub plaza, kiosks and Seal Shrines. The variants themselves are built into
-- MaterialService by Rojo (assets/Materials), which replicates to every client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShrineMaterials = require(ReplicatedStorage.Shared.ShrineMaterials)

local ShrineMaterialsBuilder = {}

-- Applies the rules to every part under `root` (the plots folder or the hub). Returns how many
-- parts changed.
function ShrineMaterialsBuilder.Apply(root: Instance): number
	local count = 0
	for _, part in root:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local model = part:FindFirstAncestorWhichIsA("Model")
		local name = ShrineMaterials.forPart(part.Name, part.Material.Name, model and model.Name)
		local base = name and ShrineMaterials.Base[name]
		if name and base then
			part.Material = (Enum.Material :: any)[base]
			part.MaterialVariant = name
			count += 1
		end
	end
	return count
end

return ShrineMaterialsBuilder
