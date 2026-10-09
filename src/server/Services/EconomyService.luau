-- Cursed Energy (GDD 6). One 1-second tick pays every loaded player from their displayed relics:
--   CE/min = IncomeMultiplier x sum(relic income x pedestal multiplier)   (Economy.totalIncome)
-- IncomeMultiplier is the "Income" additive stack (1 + global bonuses). CE stays fractional
-- internally so tiny amounts are never rounded away. All spending goes through TrySpend, which
-- is synchronous: two rapid purchases can never both spend the same CE.
--
-- Offline (GDD 2.2): every tick stores the current CE/min and time in data.Offline. On the next
-- join that snapshot pays Rate x CE/min x min(away time, cap) once. Scanning never runs offline.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local MultiplierService = require(script.Parent.MultiplierService)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local EconomyService = {}

local lastTick: { [Player]: number } = {}
local contributionsOf: (Player) -> { number } = function(_player: Player)
	return {}
end

-- PedestalService provides the per-pedestal income list (avoids a require cycle).
function EconomyService.SetIncomeProvider(provider: (Player) -> { number })
	contributionsOf = provider
end

function EconomyService.GetIncomePerMin(player: Player): number
	return Economy.totalIncome(contributionsOf(player), MultiplierService.Get(player, "Income"))
end

function EconomyService.Mirror(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("CE", data.CE)
	player:SetAttribute("IncomePerMin", EconomyService.GetIncomePerMin(player))
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
	local perMin = EconomyService.GetIncomePerMin(player)
	local earned = perMin * seconds / 60
	data.CE += earned
	data.LifetimeCE += earned
	data.Offline.IncomePerMin = perMin
	data.Offline.At = os.time()
	player:SetAttribute("CE", data.CE)
	player:SetAttribute("IncomePerMin", perMin)
end

-- Pays the stored snapshot once. Returns the CE paid (0 if too short or nothing displayed).
function EconomyService.PayOffline(player: Player): number
	local data = DataService.Get(player)
	if not data or data.Offline.At <= 0 then
		return 0
	end
	local now = os.time()
	local elapsed = now - data.Offline.At
	local amount = Economy.offlineEarnings(Config.Offline, data.Offline.IncomePerMin, elapsed)
	data.Offline.At = now
	if amount > 0 then
		EconomyService.Add(player, amount)
		local paidFor = Format.duration(math.min(elapsed, Config.Offline.CapSeconds))
		Notify:FireClient(
			player,
			`While you were away ({Format.duration(elapsed)}): +{Format.ce(amount)} CE from your shrine ({paidFor} paid)`,
			"Offline"
		)
		DataService.RequestSave(player)
	end
	return amount
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
