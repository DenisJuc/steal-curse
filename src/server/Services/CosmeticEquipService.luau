-- Carry one relic for show (GDD 9.1): floating beside the player or held in the right hand.
-- Display only: no stats, and the relic stays in the inventory (and on a pedestal if placed).
-- Saved as data.Cosmetic { Key = "<relicId>|<mutation>", Mode = "Float" | "Hand" }. The model is
-- built on the server so everyone sees it, and is removed when the last copy is gone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicShapes = require(ReplicatedStorage.Shared.RelicShapes)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)

local CosmeticEquipService = {}

local MODEL_NAME = "CarriedRelic"
local NEON_FROM_TIER = RarityConfig.IndexById.Epic
local MODES = { Float = true, Hand = true }

function CosmeticEquipService.Key(relicId: string, mutationId: string?): string
	return `{relicId}|{mutationId or ""}`
end

local function parse(key: string): (string?, string?)
	local relicId, mutationId = string.match(key, "^([^|]+)|(.*)$")
	if not relicId then
		return nil, nil
	end
	return relicId, if mutationId == "" then nil else mutationId
end

local function owns(data: any, relicId: string, mutationId: string?): boolean
	for _, item in data.Inventory do
		if item.Id == relicId and item.Mutation == mutationId then
			return true
		end
	end
	return false
end

local function build(character: Model, relicId: string, mutationId: string?, mode: string)
	local relic = RelicConfig.ById[relicId]
	local root = character:FindFirstChild("HumanoidRootPart")
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local anchor = if mode == "Hand" then hand else root
	if not relic or not anchor or not anchor:IsA("BasePart") then
		return
	end
	local at = if mode == "Hand"
		then anchor.CFrame * CFrame.new(0, -anchor.Size.Y / 2 - 0.2, -0.5)
		else anchor.CFrame * CFrame.new(2.4, 1.8, 0.6)
	local scale = if mode == "Hand" then 0.45 else 0.55
	local props = RelicShapes.props(relic.ObjectType, at, scale)
	local part = Instance.new("Part")
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Size = props.Size
	part.Name = MODEL_NAME
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local tier = RarityConfig.Get(relic.Tier)
	part.Color = if tier then Color3.fromHex(tier.Color) else Color3.new(1, 1, 1)
	part.Material = if (RarityConfig.IndexById[relic.Tier] or 1) >= NEON_FROM_TIER
		then Enum.Material.Neon
		else Enum.Material.SmoothPlastic

	local mutation = mutationId and MutationConfig.ById[mutationId]
	if mutation then
		local color = Color3.fromHex(mutation.Color)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.Rate = 6
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		emitter.Parent = part
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	part.Parent = character
end

-- Rebuilds the carried relic on the current character from saved data.
function CosmeticEquipService.Apply(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild(MODEL_NAME)
	if old then
		old:Destroy()
	end
	local data = DataService.Get(player)
	if not data or data.Cosmetic.Key == "" then
		player:SetAttribute("CarryKey", "")
		return
	end
	local relicId, mutationId = parse(data.Cosmetic.Key)
	if not relicId or not owns(data, relicId, mutationId) then
		data.Cosmetic.Key = ""
		player:SetAttribute("CarryKey", "")
		return
	end
	player:SetAttribute("CarryKey", data.Cosmetic.Key)
	player:SetAttribute("CarryMode", data.Cosmetic.Mode)
	build(character, relicId, mutationId, data.Cosmetic.Mode)
end

-- Sets what the player carries. mode "None" stops carrying. Returns a message for the menu.
function CosmeticEquipService.Set(player: Player, relicId: any, mutationId: any, mode: any): string?
	local data = DataService.Get(player)
	if not data or type(relicId) ~= "string" or not RelicConfig.ById[relicId] then
		return nil
	end
	if mutationId ~= nil and (type(mutationId) ~= "string" or not MutationConfig.ById[mutationId]) then
		return nil
	end
	if mode == "None" then
		if data.Cosmetic.Key == CosmeticEquipService.Key(relicId, mutationId) then
			data.Cosmetic.Key = ""
		end
		CosmeticEquipService.Apply(player)
		DataService.RequestSave(player)
		return "You put the relic away."
	end
	if not MODES[mode] or not owns(data, relicId, mutationId) then
		return nil
	end
	data.Cosmetic.Key = CosmeticEquipService.Key(relicId, mutationId)
	data.Cosmetic.Mode = mode
	CosmeticEquipService.Apply(player)
	DataService.RequestSave(player)
	local relic = RelicConfig.ById[relicId]
	local name = if mutationId then `{mutationId} {relic.Name}` else relic.Name
	return if mode == "Hand" then `You hold {name} for everyone to see.` else `{name} floats beside you.`
end

-- Call after copies leave the inventory: stops carrying if the last copy is gone.
function CosmeticEquipService.Validate(player: Player)
	local data = DataService.Get(player)
	if not data or data.Cosmetic.Key == "" then
		return
	end
	local relicId, mutationId = parse(data.Cosmetic.Key)
	if not relicId or not owns(data, relicId, mutationId) then
		CosmeticEquipService.Apply(player)
	end
end

function CosmeticEquipService.Init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.5)
			if player.Character == character then
				CosmeticEquipService.Apply(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	DataService.OnPlayerLoaded(CosmeticEquipService.Apply)
	GameEvents.On("DataReset", CosmeticEquipService.Apply)
end

return CosmeticEquipService
