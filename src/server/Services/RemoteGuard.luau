-- Wraps every client->server remote with a per-player token-bucket rate limit and pcall isolation.
-- Handlers must still validate every argument; this only stops spam and contains errors.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RemoteGuard = {}

type Bucket = { Tokens: number, Last: number }

local buckets: { [Player]: { [string]: Bucket } } = {}

local function allow(player: Player, key: string, limitName: string?): boolean
	local limit = Config.RemoteLimits[limitName or "Default"] or Config.RemoteLimits.Default
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { Tokens = limit.Burst, Last = now }
		playerBuckets[key] = bucket
	end
	bucket.Tokens = math.min(limit.Burst, bucket.Tokens + (now - bucket.Last) * limit.Rate)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

function RemoteGuard.Init()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

function RemoteGuard.Event(remote: RemoteEvent, handler: (Player, ...any) -> (), limitName: string?)
	remote.OnServerEvent:Connect(function(player, ...)
		if not allow(player, remote.Name, limitName) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(`[RemoteGuard] {remote.Name} failed for {player.Name}: {err}`)
		end
	end)
end

function RemoteGuard.Function(remote: RemoteFunction, handler: (Player, ...any) -> any, limitName: string?)
	remote.OnServerInvoke = function(player, ...)
		if not allow(player, remote.Name, limitName) then
			return nil
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(`[RemoteGuard] {remote.Name} failed for {player.Name}: {result}`)
			return nil
		end
		return result
	end
end

return RemoteGuard
