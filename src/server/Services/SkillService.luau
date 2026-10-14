-- Skill tree purchases (GDD 6.6). Every rank is bought with CE; the server checks the node, the
-- rank cap and every intermediate cost before spending (bulk buy = several single ranks in a
-- row, stopping at the first one the player can't afford). Remote: SkillAction ("Get", or
-- "Buy", nodeId, 1 | 10 | "Max") returns { Ranks, Message } so the menu redraws from server truth.
-- Effects are read where they apply (ScanService, BindService, EconomyService, client Spirit
-- Sight); this service registers the Income/Sell bonuses, sets the character's walk speed (Swift
-- Step) and mirrors ranks as Skill_<Id>.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GameEvents = require(script.Parent.GameEvents)
local MultiplierService = require(script.Parent.MultiplierService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local ScanService = require(script.Parent.ScanService)

local SkillAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkillAction") :: RemoteFunction

local SkillService = {}

function SkillService.Rank(player: Player, nodeId: string): number
	local data = DataService.Get(player)
	return if data then data.Skills[nodeId] or 0 else 0
end

local function mirror(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	for _, node in SkillConfig.Nodes do
		player:SetAttribute(`Skill_{node.Id}`, data.Skills[node.Id] or 0)
	end
end

local function applyWalkSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and character then
		local speed = SkillConfig.walkSpeed(SkillService.Rank(player, "SwiftStep"))
		-- The client's SprintController runs on top of this base.
		character:SetAttribute("BaseWalkSpeed", speed)
		humanoid.WalkSpeed = speed
	end
end

-- Everything that depends on a rank refreshes after a change (purchase, debug, data reset).
local function applied(player: Player, nodeId: string)
	mirror(player)
	MultiplierService.Refresh(player)
	if nodeId == "ScanSpeed" then
		ScanService.Restart(player)
	end
	applyWalkSpeed(player)
	EconomyService.Mirror(player)
end

local function state(player: Player)
	local data = DataService.Get(player)
	return if data then { Ranks = table.clone(data.Skills) } else nil
end

local function buy(player: Player, nodeId: any, amount: any): string?
	local data = DataService.Get(player)
	local node = type(nodeId) == "string" and SkillConfig.ById[nodeId]
	if not data or not node then
		return nil
	end
	local limit
	if amount == "Max" then
		limit = node.MaxRank
	elseif amount == 1 or amount == 10 then
		limit = amount
	else
		return nil
	end
	local rank = data.Skills[node.Id] or 0
	if rank >= node.MaxRank then
		return `{node.Name} is already maxed.`
	end
	local ranks, cost = SkillConfig.affordable(node, rank, data.CE, limit)
	if ranks == 0 then
		local nextCost = SkillConfig.cost(node, rank) or 0
		return `{node.Name} rank {rank + 1} costs {Format.number(nextCost)} CE.`
	end
	if not EconomyService.TrySpend(player, cost) then
		return "Not enough CE."
	end
	data.Skills[node.Id] = rank + ranks
	applied(player, node.Id)
	DataService.RequestSave(player)
	local word = if ranks == 1 then "rank" else "ranks"
	return `{node.Name} +{ranks} {word} -> rank {rank + ranks} ({Format.number(cost)} CE)`
end

local function onAction(player: Player, action: any, ...: any)
	if not DataService.Get(player) then
		return nil
	end
	local message = nil
	if action == "Buy" then
		message = buy(player, ...)
	elseif action ~= "Get" then
		return nil
	end
	return { State = state(player), Message = message }
end

-- Debug: set a rank directly (clamped to the node's range).
function SkillService.SetRank(player: Player, nodeId: string, rank: number): number?
	local data = DataService.Get(player)
	local node = SkillConfig.ById[nodeId]
	if not data or not node then
		return nil
	end
	data.Skills[nodeId] = math.clamp(math.floor(rank), 0, node.MaxRank)
	applied(player, nodeId)
	return data.Skills[nodeId]
end

function SkillService.Init()
	MultiplierService.Register("Income", "EnergyConduction", function(player)
		return SkillConfig.incomeBonus(SkillService.Rank(player, "EnergyConduction"))
	end)
	MultiplierService.Register("Sell", "SpiritMerchant", function(player)
		return SkillConfig.sellBonus(SkillService.Rank(player, "SpiritMerchant"))
	end)
	RemoteGuard.Function(SkillAction, onAction, "Shrine")
	DataService.OnPlayerLoaded(function(player)
		mirror(player)
		applyWalkSpeed(player)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			applyWalkSpeed(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	GameEvents.On("DataReset", function(player: Player)
		applied(player, "")
	end)
	-- Rebirth sets every rank to 0, Scan Speed included.
	GameEvents.On("Rebirthed", function(player: Player)
		applied(player, "ScanSpeed")
	end)
end

return SkillService
