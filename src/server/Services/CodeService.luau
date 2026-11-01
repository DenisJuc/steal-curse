-- Codes and the group-join reward (Config.Codes, Config.Group). Both are one-time per player and
-- recorded in data.ItemRewards ("Code_<CODE>", "GroupJoin") like the other one-time rewards.
--   RedeemCode(code)    -> message string (typed in Settings)
--   ClaimGroupReward()  -> message string; also checked automatically when the profile loads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local ItemService = require(script.Parent.ItemService)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RedeemCode = Remotes:WaitForChild("RedeemCode") :: RemoteFunction
local ClaimGroupReward = Remotes:WaitForChild("ClaimGroupReward") :: RemoteFunction

local CodeService = {}

local MAX_CODE_LENGTH = 32

local function inGroup(player: Player): boolean
	local groupId = Config.Group.GroupId
	if groupId <= 0 then
		return false
	end
	local ok, result = pcall(player.IsInGroup, player, groupId)
	return ok and result == true
end

local function redeem(player: Player, raw: unknown): string
	if type(raw) ~= "string" then
		return "Type a code first."
	end
	local code = string.upper(string.gsub(string.sub(raw, 1, MAX_CODE_LENGTH), "%s", ""))
	local reward = Config.Codes[code]
	if not reward then
		return "That code doesn't exist."
	end
	local data = DataService.Get(player)
	if not data then
		return "Your data is still loading."
	end
	local key = `Code_{code}`
	if data.ItemRewards[key] then
		return "You already used that code."
	end
	data.ItemRewards[key] = os.time()
	local parts = {}
	if reward.CEMinutes then
		local amount =
			math.max(Config.Bounties.MinCE, math.floor(reward.CEMinutes * 60 * EconomyService.GetRewardIncomePerSec(player)))
		EconomyService.Add(player, amount)
		table.insert(parts, `{Format.ce(amount)} CE`)
	end
	if reward.Potions then
		ItemService.Grant(player, reward.Potions, `code {code}`)
		table.insert(parts, "potions")
	end
	DataService.RequestSave(player)
	return `Code {code}: {table.concat(parts, " + ")}!`
end

local function claimGroup(player: Player): string
	if Config.Group.GroupId <= 0 then
		return "The group reward isn't open yet."
	end
	local data = DataService.Get(player)
	if not data then
		return "Your data is still loading."
	end
	if data.ItemRewards.GroupJoin then
		return "You already claimed the group reward."
	end
	if not inGroup(player) then
		return "Join the group first, then claim."
	end
	data.ItemRewards.GroupJoin = os.time()
	ItemService.Grant(player, Config.Group.Reward, "group reward")
	DataService.RequestSave(player)
	return "Thanks for joining the group!"
end

function CodeService.Init()
	RemoteGuard.Function(RedeemCode, redeem, "Settings")
	RemoteGuard.Function(ClaimGroupReward, claimGroup, "Settings")
	DataService.OnPlayerLoaded(function(player: Player)
		local data = DataService.Get(player)
		if data and not data.ItemRewards.GroupJoin and inGroup(player) then
			claimGroup(player)
		end
	end)
end

return CodeService
