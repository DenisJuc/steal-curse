-- Friend bonus (Config.Friends): Luck x(1 + LuckPerFriend per Roblox friend in this server, up to
-- MaxFriends). Friendships are checked once per pair when someone joins (IsFriendsWith is a web
-- call) and the count is mirrored as FriendLuckPercent for the HUD chip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MultiplierService = require(script.Parent.MultiplierService)

local FriendService = {}

local friends: { [Player]: { [Player]: boolean } } = {}

local function count(player: Player): number
	local n = 0
	for other in friends[player] or {} do
		if other.Parent then
			n += 1
		end
	end
	return math.min(n, Config.Friends.MaxFriends)
end

local function refresh(player: Player)
	if not player.Parent then
		return
	end
	player:SetAttribute("FriendLuckPercent", math.floor(count(player) * Config.Friends.LuckPerFriend * 100 + 0.5))
	MultiplierService.Refresh(player)
end

local function link(a: Player, b: Player)
	friends[a] = friends[a] or {}
	friends[b] = friends[b] or {}
	friends[a][b] = true
	friends[b][a] = true
	refresh(a)
	refresh(b)
end

local function onJoin(player: Player)
	friends[player] = friends[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(function()
				local ok, result = pcall(player.IsFriendsWith, player, other.UserId)
				if ok and result == true and player.Parent and other.Parent then
					link(player, other)
				end
			end)
		end
	end
	refresh(player)
end

-- Studio /friends command: pretend `n` friends are in the server.
local fakeCount: { [Player]: number } = {}
function FriendService.SetFake(player: Player, n: number)
	fakeCount[player] = if n > 0 then n else nil
	player:SetAttribute(
		"FriendLuckPercent",
		math.floor(math.min(n, Config.Friends.MaxFriends) * Config.Friends.LuckPerFriend * 100 + 0.5)
	)
	MultiplierService.Refresh(player)
end

function FriendService.Init()
	MultiplierService.Register("Luck", "Friends", function(player)
		local n = math.min(fakeCount[player] or count(player), Config.Friends.MaxFriends)
		return 1 + n * Config.Friends.LuckPerFriend
	end)
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local mine = friends[player]
		friends[player] = nil
		fakeCount[player] = nil
		for other in mine or {} do
			if friends[other] then
				friends[other][player] = nil
			end
			refresh(other)
		end
	end)
end

return FriendService
