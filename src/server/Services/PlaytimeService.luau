-- Playtime gifts (Config.PlaytimeGifts): each step of this session's play time unlocks one gift,
-- claimed with ClaimPlaytimeGift(index). Session-only (nothing saved): the clock starts when the
-- profile loads and AFK time counts. Mirrors PlaytimeStart (server time) and PlaytimeClaimed
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

type Session = { Start: number, Claimed: { [number]: boolean } }
local sessions: { [Player]: Session } = {}

local function mirror(player: Player, session: Session)
	local list = {}
	for index in session.Claimed do
		table.insert(list, tostring(index))
	end
	table.sort(list)
	player:SetAttribute("PlaytimeStart", session.Start)
	player:SetAttribute("PlaytimeClaimed", table.concat(list, ","))
end

local function claim(player: Player, index: unknown): string
	local session = sessions[player]
	local gift = type(index) == "number" and Config.PlaytimeGifts[index]
	if not session or not gift then
		return "Try again in a moment."
	end
	local i = index :: number
	if session.Claimed[i] then
		return "Already claimed."
	end
	local left = session.Start + gift.Minutes * 60 - workspace:GetServerTimeNow()
	if left > 0 then
		return `Ready in {Format.duration(math.ceil(left))}.`
	end
	session.Claimed[i] = true
	local parts = {}
	if gift.CEMinutes then
		local amount =
			math.max(Config.Bounties.MinCE, math.floor(gift.CEMinutes * 60 * EconomyService.GetIncomePerSec(player)))
		EconomyService.Add(player, amount)
		table.insert(parts, `{Format.ce(amount)} CE`)
	end
	if gift.Potions then
		ItemService.Grant(player, gift.Potions, "gift")
		table.insert(parts, "potions")
	end
	DataService.RequestSave(player)
	mirror(player, session)
	return `Gift: {table.concat(parts, " + ")}!`
end

function PlaytimeService.Init()
	RemoteGuard.Function(ClaimPlaytimeGift, claim, "Settings")
	DataService.OnPlayerLoaded(function(player: Player)
		if sessions[player] then
			return
		end
		local session = { Start = workspace:GetServerTimeNow(), Claimed = {} }
		sessions[player] = session
		mirror(player, session)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
	end)
end

-- Studio /gifts command: move the session clock back `minutes`.
function PlaytimeService.Skip(player: Player, minutes: number)
	local session = sessions[player]
	if session then
		session.Start -= minutes * 60
		mirror(player, session)
	end
end

return PlaytimeService
