-- The floating relic (GDD 9.1): one backpack copy hovers beside the player for everyone to see.
-- Display only, saved as data.Cosmetic.Uid (0 = none). A player takes a relic off a pedestal with E
-- (PedestalService "Grab") or floats one from the Backpack. A floating copy is never sold or
-- auto-equipped; putting it on a pedestal ends the float, and so does losing the copy.
-- Mirrors "FloatingRelic" (its display name, "" = none) for the client's pedestal prompts.
-- The model is built on the server so everyone sees it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicModels = require(ReplicatedStorage.Shared.RelicModels)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)

local CosmeticEquipService = {}

local MODEL_NAME = "FloatingRelic"

function CosmeticEquipService.DisplayName(item: any): string
	local relic = RelicConfig.ById[item.Id]
	local name = if relic then relic.Name else item.Id
	return if item.Mutation then `{item.Mutation} {name}` else name
end

local function onPedestal(data: any, uid: number): boolean
	for _, pedestal in data.Pedestals do
		if pedestal.Uid == uid then
			return true
		end
	end
	return false
end

local function findItem(data: any, uid: number): any?
	if uid == 0 then
		return nil
	end
	for _, item in data.Inventory do
		if item.Uid == uid then
			return item
		end
	end
	return nil
end

-- The floating copy, if it is still in the backpack.
function CosmeticEquipService.FloatingItem(player: Player): any?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local item = findItem(data, data.Cosmetic.Uid)
	return if item and not onPedestal(data, item.Uid) then item else nil
end

function CosmeticEquipService.IsFloating(player: Player, uid: number): boolean
	local data = DataService.Get(player)
	return data ~= nil and uid ~= 0 and data.Cosmetic.Uid == uid
end

local function build(character: Model, relicId: string, mutationId: string?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local part = RelicModels.build(relicId, root.CFrame * CFrame.new(2.4, 1.8, 0.6), 0.55)
	if not part then
		return
	end
	part.Name = MODEL_NAME
	part.Anchored = false

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
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = character
end

-- Rebuilds the floating relic on the current character from saved data.
function CosmeticEquipService.Apply(player: Player)
	local character = player.Character
	local old = character and character:FindFirstChild(MODEL_NAME)
	if old then
		old:Destroy()
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local item = CosmeticEquipService.FloatingItem(player)
	if not item then
		data.Cosmetic.Uid = 0
		player:SetAttribute("FloatingRelic", "")
		return
	end
	player:SetAttribute("FloatingRelic", CosmeticEquipService.DisplayName(item))
	if character then
		build(character, item.Id, item.Mutation)
	end
end

-- Floats one backpack copy (replacing any other). False if it is gone or on a pedestal.
function CosmeticEquipService.Float(player: Player, uid: number): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local item = findItem(data, uid)
	if not item or onPedestal(data, uid) then
		return false
	end
	data.Cosmetic.Uid = uid
	CosmeticEquipService.Apply(player)
	DataService.RequestSave(player)
	return true
end

function CosmeticEquipService.Stop(player: Player)
	local data = DataService.Get(player)
	if not data or data.Cosmetic.Uid == 0 then
		return
	end
	data.Cosmetic.Uid = 0
	CosmeticEquipService.Apply(player)
	DataService.RequestSave(player)
end

-- From the Backpack: float a copy of a relic + mutation, or put it away. Returns a menu message.
function CosmeticEquipService.FloatGroup(player: Player, relicId: any, mutationId: any, on: any): string?
	local data = DataService.Get(player)
	if not data or type(relicId) ~= "string" or not RelicConfig.ById[relicId] or type(on) ~= "boolean" then
		return nil
	end
	if mutationId ~= nil and (type(mutationId) ~= "string" or not MutationConfig.ById[mutationId]) then
		return nil
	end
	local floating = CosmeticEquipService.FloatingItem(player)
	if not on then
		if floating and floating.Id == relicId and floating.Mutation == mutationId then
			CosmeticEquipService.Stop(player)
			return "You put the relic away."
		end
		return nil
	end
	for _, item in data.Inventory do
		if item.Id == relicId and item.Mutation == mutationId and not onPedestal(data, item.Uid) then
			CosmeticEquipService.Float(player, item.Uid)
			return `{CosmeticEquipService.DisplayName(item)} floats beside you.`
		end
	end
	return "Every copy of that relic is on a pedestal."
end

-- Call after copies leave the backpack (sold, placed): ends the float if its copy is gone.
function CosmeticEquipService.Validate(player: Player)
	local data = DataService.Get(player)
	if data and data.Cosmetic.Uid ~= 0 and not CosmeticEquipService.FloatingItem(player) then
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
