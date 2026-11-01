-- Playtime gifts (Config.PlaytimeGifts): each step of today's play time unlocks one gift, claimed
-- with ClaimPlaytimeGift(index). Saved in data.Playtime (UTC day, seconds played, claimed steps), so
-- rejoining keeps the clock and the claims; a new UTC day starts over. AFK time counts.
-- Mirrors PlaytimeStart (server time the day's play "started", now - seconds) and PlaytimeClaimed
-- ("1,3" = claimed indices) for the HUD button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local ItemService = require(script.Parent.ItemService)
local RemoteGuard = require(script.Parent.RemoteGuard)

local ClaimPlaytimeGift = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimPlaytimeGift") :: RemoteFunction

local PlaytimeService = {}

local TICK_SECONDS = 1
local MIRROR_SECONDS = 15
local SECONDS_PER_DAY = 86400

local function today(): number
	return os.time() // SECONDS_PER_DAY
end

-- Today's playtime record (reset on a new day).
local function record(player: Player): any?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local playtime = data.Playtime
	if playtime.Day ~= today() then
		playtime.Day = today()
		playtime.Seconds = 0
		playtime.Claimed = {}
	end
	return playtime
end

local function mirror(player: Player)
	local playtime = record(player)
	if not playtime then
		return
	end
	local list = {}
	for index in playtime.Claimed do
		table.insert(list, index)
	end
	table.sort(list)
	player:SetAttribute("PlaytimeStart", workspace:GetServerTimeNow() - playtime.Seconds)
	player:SetAttribute("PlaytimeClaimed", table.concat(list, ","))
end

local function claim(player: Player, index: unknown): string
	local playtime = record(player)
	local gift = type(index) == "number" and Config.PlaytimeGifts[index]
	if not playtime or not gift then
		return "Try again in a moment."
	end
	local key = tostring(index)
	if playtime.Claimed[key] then
		return "Already claimed today."
	end
	local left = gift.Minutes * 60 - playtime.Seconds
	if left > 0 then
		return `Ready in {Format.duration(math.ceil(left))}.`
	end
	playtime.Claimed[key] = true
	local parts = {}
	if gift.CEMinutes then
		local amount =
			math.max(Config.Bounties.MinCE, math.floor(gift.CEMinutes * 60 * EconomyService.GetRewardIncomePerSec(player)))
		EconomyService.Add(player, amount)
		table.insert(parts, `{Format.ce(amount)} CE`)
	end
	if gift.Potions then
		-- ItemService names the potions in its own toast.
		ItemService.Grant(player, gift.Potions, "gift")
	end
	DataService.RequestSave(player)
	mirror(player)
	return if #parts > 0 then `Gift: {table.concat(parts, " + ")}!` else "Gift claimed!"
end

function PlaytimeService.Init()
	RemoteGuard.Function(ClaimPlaytimeGift, claim, "Settings")
	DataService.OnPlayerLoaded(mirror)
	task.spawn(function()
		local sinceMirror = 0
		while true do
			task.wait(TICK_SECONDS)
			sinceMirror += TICK_SECONDS
			for _, player in Players:GetPlayers() do
				local playtime = record(player)
				if playtime then
					local day = playtime.Day
					playtime.Seconds += TICK_SECONDS
					if sinceMirror >= MIRROR_SECONDS or day ~= today() then
						mirror(player)
					end
				end
			end
			if sinceMirror >= MIRROR_SECONDS then
				sinceMirror = 0
			end
		end
	end)
end

-- Studio /gifts command: add `minutes` of play time today.
function PlaytimeService.Skip(player: Player, minutes: number)
	local playtime = record(player)
	if playtime then
		playtime.Seconds += minutes * 60
		mirror(player)
	end
end

return PlaytimeService
