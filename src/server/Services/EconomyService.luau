-- Cursed Energy (GDD 6). One 1-second tick pays every loaded player from their displayed relics:
--   CE/sec = IncomeMultiplier x Rebirth x sum(relic income x pedestal multiplier)   (Economy.totalIncome)
-- IncomeMultiplier is the "Income" additive stack (1 + global bonuses); Rebirth multiplies on top
-- (Rebirth.incomeMultiplier). CE stays fractional internally so tiny amounts are never rounded
-- away. All spending goes through TrySpend, which is synchronous: two rapid purchases can never
-- both spend the same CE.
--
-- Offline (GDD 2.2): every tick stores the current CE/sec and time in data.Offline. On the next
-- join that snapshot pays Rate x CE/sec x min(away time, cap) once. Scanning never runs offline.
-- The payout is kept for AfkService's Welcome Back screen (GDD 9.4). SessionIncome counts the
-- shrine CE produced online this session (Journal), and an active AFK log gets the CE too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local DataService = require(script.Parent.DataService)
local MultiplierService = require(script.Parent.MultiplierService)

local EconomyService = {}

export type OfflinePayout = { Amount: number, Seconds: number, PaidSeconds: number }

local lastTick: { [Player]: number } = {}
local sessionIncome: { [Player]: number } = {}
local offlinePayouts: { [Player]: OfflinePayout } = {}
local contributionsOf: (Player) -> { number } = function(_player: Player)
	return {}
end

-- PedestalService provides the per-pedestal income list (avoids a require cycle).
function EconomyService.SetIncomeProvider(provider: (Player) -> { number })
	contributionsOf = provider
end

-- Global income multiplier: the additive bonus stack times the Rebirth multiplier.
function EconomyService.GetIncomeMultiplier(player: Player): number
	local data = DataService.Get(player)
	local rebirths = if data then data.Rebirths or 0 else 0
	return MultiplierService.Get(player, "Income") * Rebirth.incomeMultiplier(Config.Rebirth, rebirths)
end

function EconomyService.GetIncomePerSec(player: Player): number
	return Economy.totalIncome(contributionsOf(player), EconomyService.GetIncomeMultiplier(player))
end

function EconomyService.Mirror(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("CE", data.CE)
	player:SetAttribute("IncomePerSec", EconomyService.GetIncomePerSec(player))
end

function EconomyService.Add(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or not (amount > 0) then
		return
	end
	data.CE += amount
	data.LifetimeCE += amount
	EconomyService.Mirror(player)
end

function EconomyService.TrySpend(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or not (amount >= 0) or data.CE + 1e-9 < amount then
		return false
	end
	data.CE = math.max(0, data.CE - amount)
	EconomyService.Mirror(player)
	return true
end

local function tick(player: Player, seconds: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local perSec = EconomyService.GetIncomePerSec(player)
	local earned = perSec * seconds
	data.CE += earned
	data.LifetimeCE += earned
	data.Offline.IncomePerSec = perSec
	data.Offline.At = os.time()
	sessionIncome[player] = (sessionIncome[player] or 0) + earned
	if data.AfkLog.Active then
		data.AfkLog.CE += earned
		data.AfkLog.Seconds += seconds
	end
	player:SetAttribute("CE", data.CE)
	player:SetAttribute("IncomePerSec", perSec)
	player:SetAttribute("SessionIncome", sessionIncome[player])
end

-- Pays the stored snapshot once. Returns the CE paid (0 if too short or nothing displayed).
function EconomyService.PayOffline(player: Player): number
	local data = DataService.Get(player)
	if not data or data.Offline.At <= 0 then
		return 0
	end
	local now = os.time()
	local elapsed = now - data.Offline.At
	-- Spirit Reservoir extends the cap (GDD 6.6).
	local settings = table.clone(Config.Offline)
	settings.CapSeconds = SkillConfig.offlineCapSeconds(data.Skills.SpiritReservoir or 0)
	local amount = Economy.offlineEarnings(settings, data.Offline.IncomePerSec, elapsed)
	data.Offline.At = now
	if amount > 0 then
		offlinePayouts[player] = {
			Amount = amount,
			Seconds = elapsed,
			PaidSeconds = math.min(elapsed, settings.CapSeconds),
		}
		EconomyService.Add(player, amount)
		DataService.RequestSave(player)
	end
	return amount
end

-- The last offline payout not shown yet (read once by the Welcome Back screen).
function EconomyService.TakeOfflinePayout(player: Player): OfflinePayout?
	local payout = offlinePayouts[player]
	offlinePayouts[player] = nil
	return payout
end

function EconomyService.Init()
	MultiplierService.DefineKind("Income", "Additive")

	DataService.OnPlayerLoaded(function(player)
		EconomyService.PayOffline(player)
		lastTick[player] = os.clock()
		EconomyService.Mirror(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTick[player] = nil
		sessionIncome[player] = nil
		offlinePayouts[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Economy.TickSeconds)
			local now = os.clock()
			for player, last in lastTick do
				local ok, err = pcall(tick, player, math.min(now - last, Config.Economy.MaxTickSeconds))
				if not ok then
					warn(`[EconomyService] Tick failed for {player.Name}: {err}`)
				end
				lastTick[player] = now
			end
		end
	end)
end

return EconomyService
