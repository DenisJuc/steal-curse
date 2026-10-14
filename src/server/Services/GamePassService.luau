-- Game passes (Config.GamePasses: name -> pass id). Ownership is checked once when a player joins
-- and again after an in-game purchase, mirrored as a "Pass<Name>" attribute for the client and
-- announced with GameEvents "GamePassChanged" (player, name, owned).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameEvents = require(script.Parent.GameEvents)

local GamePassService = {}

local owned: { [Player]: { [string]: boolean } } = {}

function GamePassService.Owns(player: Player, name: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[name] == true
end

-- Purchases and the Studio /gamepass command.
function GamePassService.SetOwned(player: Player, name: string, on: boolean)
	local passes = owned[player]
	if not passes or Config.GamePasses[name] == nil or passes[name] == on then
		return
	end
	passes[name] = on
	player:SetAttribute(`Pass{name}`, on)
	GameEvents.Fire("GamePassChanged", player, name, on)
end

local function check(player: Player)
	owned[player] = {}
	for name, id in Config.GamePasses do
		player:SetAttribute(`Pass{name}`, false)
		if id > 0 then
			task.spawn(function()
				local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
				if not ok then
					warn(`[GamePassService] Could not check pass {name} for {player.Name}: {result}`)
				elseif result == true and player.Parent then
					GamePassService.SetOwned(player, name, true)
				end
			end)
		end
	end
end

function GamePassService.Init()
	Players.PlayerAdded:Connect(check)
	for _, player in Players:GetPlayers() do
		check(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for name, id in Config.GamePasses do
			if id == passId then
				GamePassService.SetOwned(player, name, true)
			end
		end
	end)
end

return GamePassService
