-- Owner-driven base interior (BaseDecor rules): the Seal Shrine plaque (name + seal rank), the
-- owner's garden in the back-left corner (theme from the UserId, grows with seal rank) and the
-- Great Altar showing their best Huge or Titanic relic. Unclaimed shrines are bare: no garden,
-- "Unclaimed" plaque, sealed stone on the altar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseDecor = require(ReplicatedStorage.Shared.BaseDecor)
local Config = require(ReplicatedStorage.Shared.Config)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicModels = require(ReplicatedStorage.Shared.RelicModels)
local SealLadder = require(ReplicatedStorage.Shared.SealLadder)
local SizeConfig = require(ReplicatedStorage.Shared.SizeConfig)
local BuildUtil = require(script.Parent.Parent.World.BuildUtil)
local MapProps = require(script.Parent.Parent.World.MapProps)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)
local PlotService = require(script.Parent.PlotService)

local BaseDecorService = {}

-- Relics on the altar are shown this much bigger than their size scale (pedestals use 1.7).
local ALTAR_SCALE = 2
local PLAQUE_TEXT = Color3.fromRGB(255, 236, 200)

local function tierIndexOf(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return relic and RarityConfig.IndexById[relic.Tier] or 0
end

local function sealTier(player: Player): (number, SealLadder.Tier)
	local luck = player:GetAttribute("LastingLuck")
	return SealLadder.tierFor(Config.SealLadder, if type(luck) == "number" then luck else 1)
end

local function setPlaque(plot: Model, name: string, rank: string, color: Color3)
	local shrine = plot:FindFirstChild("SealShrine")
	local plaque = shrine and shrine:FindFirstChild("Plaque")
	local gui = plaque and plaque:FindFirstChild("PlaqueGui")
	if not gui then
		return
	end
	local owner = gui:FindFirstChild("OwnerName")
	local seal = gui:FindFirstChild("SealRank")
	if owner and owner:IsA("TextLabel") then
		owner.Text = name
	end
	if seal and seal:IsA("TextLabel") then
		seal.Text = rank
		seal.TextColor3 = color
	end
end

local function clearGarden(plot: Model)
	local old = plot:FindFirstChild("Garden")
	if old then
		old:Destroy()
	end
	plot:SetAttribute("GardenId", nil)
	plot:SetAttribute("GardenStage", nil)
end

local function buildGarden(plot: Model, garden: BaseDecor.Garden, stage: number)
	if plot:GetAttribute("GardenId") == garden.Id and plot:GetAttribute("GardenStage") == stage then
		return
	end
	local anchor = plot:FindFirstChild("GardenAnchor", true)
	if not (anchor and anchor:IsA("BasePart")) then
		return
	end
	local old = plot:FindFirstChild("Garden")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "Garden"
	for _, piece in BaseDecor.piecesAt(garden, stage) do
		local base = anchor.CFrame * CFrame.new(piece.At[1], 0, piece.At[2]) * CFrame.Angles(0, math.rad(piece.Turn or 0), 0)
		MapProps.build(folder, piece.Prop, base, piece.Scale)
	end
	folder.Parent = plot
	plot:SetAttribute("GardenId", garden.Id)
	plot:SetAttribute("GardenStage", stage)
end

local function takenGardens(except: Model): { [string]: boolean }
	local taken = {}
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	for _, plot in if plots then plots:GetChildren() else {} do
		local id = plot ~= except and plot:GetAttribute("GardenId")
		if type(id) == "string" then
			taken[id] = true
		end
	end
	return taken
end

local function refreshAltar(player: Player, plot: Model)
	local altar = plot:FindFirstChild("GreatAltar")
	local anchor = altar and altar:FindFirstChild("AltarAnchor")
	if not (anchor and anchor:IsA("BasePart")) then
		return
	end
	local data = DataService.Get(player)
	local item = data and BaseDecor.altarPick(data.Inventory, tierIndexOf)
	local key = if item then `{item.Id}|{item.Size or ""}|{item.Mutation or ""}` else ""
	if altar:GetAttribute("ShownKey") == key then
		return
	end
	altar:SetAttribute("ShownKey", key)
	local old = altar:FindFirstChild("RelicDisplay")
	if old then
		old:Destroy()
	end
	local stone = altar:FindFirstChild("SealedStone")
	if stone and stone:IsA("BasePart") then
		stone.Transparency = if item then 1 else 0
	end
	local label = anchor:FindFirstChildOfClass("BillboardGui")
	if label then
		label.Enabled = item == nil
	end
	if not item then
		return
	end
	local scale = SizeConfig.scaleOf(item.Size) * ALTAR_SCALE
	local lift = 2.4 + (scale - 1) * 0.9
	local part = RelicModels.build(item.Id, CFrame.new(anchor.Position + Vector3.new(0, lift, 0)), scale)
	if not part then
		return
	end
	part.Name = "RelicDisplay"
	-- Read by the client's PedestalAuras (auras escalate for Huge and Titanic).
	part:SetAttribute("RelicId", item.Id)
	part:SetAttribute("Size", SizeConfig.normalize(item.Size))
	local relic = RelicConfig.ById[item.Id]
	local tier = relic and RarityConfig.Get(relic.Tier)
	local color = if tier then Color3.fromHex(tier.Color) else Color3.new(1, 1, 1)
	BuildUtil.light(part, color, 18, 3)
	local titanic = SizeConfig.normalize(item.Size) == "Titanic"
	BuildUtil.sparkles(part, if titanic then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(180, 220, 255), if titanic then 16 else 10)
	local mutation = item.Mutation and MutationConfig.ById[item.Mutation]
	if mutation then
		BuildUtil.sparkles(part, Color3.fromHex(mutation.Color), 10)
	end
	part.Parent = altar
end

local function resetAltar(plot: Model)
	local altar = plot:FindFirstChild("GreatAltar")
	if not altar then
		return
	end
	altar:SetAttribute("ShownKey", "")
	local old = altar:FindFirstChild("RelicDisplay")
	if old then
		old:Destroy()
	end
	local stone = altar:FindFirstChild("SealedStone")
	if stone and stone:IsA("BasePart") then
		stone.Transparency = 0
	end
	local anchor = altar:FindFirstChild("AltarAnchor")
	local label = anchor and anchor:FindFirstChildOfClass("BillboardGui")
	if label then
		label.Enabled = true
	end
end

-- Plaque and garden from the owner's seal rank (runs on claim and whenever Lasting Luck changes).
local function refreshRank(player: Player, plot: Model)
	local index, tier = sealTier(player)
	setPlaque(plot, player.DisplayName, tier.Name, Color3.fromRGB(tier.Color[1], tier.Color[2], tier.Color[3]))
	local current = plot:GetAttribute("GardenId")
	local garden = nil
	for _, candidate in BaseDecor.Gardens do
		if candidate.Id == current then
			garden = candidate
		end
	end
	garden = garden or BaseDecor.gardenFor(player.UserId, takenGardens(plot))
	buildGarden(plot, garden, BaseDecor.stageFor(index))
end

local watching: { [Player]: { RBXScriptConnection } } = {}
local pendingAltar: { [Player]: boolean } = {}

-- New relics land in the backpack without touching the pedestals, so the altar also follows the
-- InventoryCount attribute (batched: a burst of finds refreshes once).
local function queueAltar(player: Player)
	if pendingAltar[player] then
		return
	end
	pendingAltar[player] = true
	task.delay(0.5, function()
		pendingAltar[player] = nil
		local plot = PlotService.GetPlot(player)
		if plot and player.Parent then
			refreshAltar(player, plot)
		end
	end)
end

local function unwatch(player: Player)
	for _, connection in watching[player] or {} do
		connection:Disconnect()
	end
	watching[player] = nil
end

function BaseDecorService.Init()
	GameEvents.On("PlotAssigned", function(player: Player, plot: Model)
		refreshRank(player, plot)
		refreshAltar(player, plot)
		unwatch(player)
		watching[player] = {
			player:GetAttributeChangedSignal("LastingLuck"):Connect(function()
				local current = PlotService.GetPlot(player)
				if current then
					refreshRank(player, current)
				end
			end),
			player:GetAttributeChangedSignal("InventoryCount"):Connect(function()
				queueAltar(player)
			end),
		}
	end)
	-- The save may finish loading after the plot was assigned.
	DataService.OnPlayerLoaded(function(player: Player)
		queueAltar(player)
	end)
	GameEvents.On("PlotReleased", function(player: Player, plot: Model)
		unwatch(player)
		clearGarden(plot)
		resetAltar(plot)
		setPlaque(plot, "Unclaimed", "", PLAQUE_TEXT)
	end)
	GameEvents.On("CollectionChanged", function(player: Player)
		local plot = PlotService.GetPlot(player)
		if plot then
			refreshAltar(player, plot)
		end
	end)
end

return BaseDecorService
