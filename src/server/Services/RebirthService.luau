-- Rebirth (Shared/Rebirth, Config.Rebirth). Remote "Rebirth" (RemoteFunction): "Get" returns the
-- state for the menu; "Rebirth" re-checks the cost on the server, then applies Rebirth.apply.
-- Live (production): resets CE, pedestal levels, skill ranks; keeps relics/Codex/slots/etc.
-- SoftCap_P4 B+: resets CE only; keeps skills, pedestals, Collection/Fusion/Charms.
-- Each Rebirth increments count once (permanent income/luck from formulas — no double-grant).
-- Fires GameEvents "Rebirthed" so skills, pedestals and multipliers refresh; mirrors "Rebirths".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GameEvents = require(script.Parent.GameEvents)
local MultiplierService = require(script.Parent.MultiplierService)
local RemoteGuard = require(script.Parent.RemoteGuard)

local RebirthRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth") :: RemoteFunction

local RebirthService = {}

local function settings()
	return BalanceTrials.rebirthSettings(Config.Rebirth)
end

export type State = {
	Rebirths: number,
	Cost: number,
	IncomeMultiplier: number,
	LuckMultiplier: number,
	NextIncomeMultiplier: number,
	NextLuckMultiplier: number,
	Model: Rebirth.Model,
	Resets: { string },
	Keeps: { string },
}

local function resetsFor(model: Rebirth.Model): { string }
	if model == "BPlus" then
		return { "Current Cursed Energy" }
	end
	return { "Cursed Energy", "Pedestal levels", "Skill ranks" }
end

local function keepsFor(model: Rebirth.Model): { string }
	if model == "BPlus" then
		return {
			"Skill ranks (Core Luck 19–25 & Mastery 3–5 unlock after R1)",
			"Pedestal levels and investments",
			"Relics, slots, and Codex",
			"Fusion Board, Charms, Essence",
			"Showcases, lanterns, zone mastery, potions",
			"Permanent income & luck from prior Rebirths",
		}
	end
	return {
		"Relics and pedestal slots",
		"Codex, titles and bonuses",
		"Showcases and lanterns",
		"Zone mastery and potions",
		"Collection Essence, fusions, Resonance (Studio)",
	}
end

function RebirthService.Count(player: Player): number
	local data = DataService.Get(player)
	return if data then data.Rebirths or 0 else 0
end

function RebirthService.State(player: Player): State
	local n = RebirthService.Count(player)
	local s = settings()
	local model = BalanceTrials.rebirthModel()
	return {
		Rebirths = n,
		Cost = Rebirth.cost(s, n),
		IncomeMultiplier = Rebirth.incomeMultiplier(s, n),
		LuckMultiplier = Rebirth.luckMultiplier(s, n),
		NextIncomeMultiplier = Rebirth.incomeMultiplier(s, n + 1),
		NextLuckMultiplier = Rebirth.luckMultiplier(s, n + 1),
		Model = model,
		Resets = resetsFor(model),
		Keeps = keepsFor(model),
	}
end

local function mirror(player: Player)
	player:SetAttribute("Rebirths", RebirthService.Count(player))
end

-- Does one Rebirth if the player can afford it. Returns a message for the menu.
function RebirthService.TryRebirth(player: Player): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Your data is still loading."
	end
	local s = settings()
	local cost = Rebirth.cost(s, data.Rebirths or 0)
	if data.CE + 1e-9 < cost then
		return false, `Rebirth needs {Format.ce(cost)} CE.`
	end
	local model = BalanceTrials.rebirthModel()
	Rebirth.apply(data, model)
	mirror(player)
	EconomyService.Mirror(player)
	MultiplierService.Refresh(player)
	GameEvents.Fire("Rebirthed", player)
	DataService.RequestSave(player)
	local n = data.Rebirths
	local keepNote = if model == "BPlus"
		then " Skills, pedestals, and Fusion kept. Choose a Resonance in Collection."
		else ""
	local msg =
		`Rebirth {n}! Income x{Format.multiplier(Rebirth.incomeMultiplier(s, n))}, luck x{Format.multiplier(
			Rebirth.luckMultiplier(s, n)
		)}.{keepNote}`
	local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	Notify:FireClient(
		player,
		if model == "BPlus"
			then `Rebirth {n} — skills & Fusion kept. Pick Resonance in Collection.`
			else `Rebirth {n} — permanent income & luck up.`,
		"Milestone"
	)
	return true, msg
end

local function onInvoke(player: Player, action: any)
	if not DataService.Get(player) then
		return nil
	end
	local ok, message = nil, nil
	if action == "Rebirth" then
		ok, message = RebirthService.TryRebirth(player)
	elseif action ~= "Get" then
		return nil
	end
	return { State = RebirthService.State(player), Ok = ok, Message = message }
end

function RebirthService.Init()
	MultiplierService.Register("Luck", "Rebirth", function(player)
		return Rebirth.luckMultiplier(settings(), RebirthService.Count(player))
	end)
	RemoteGuard.Function(RebirthRemote, onInvoke, "Shrine")
	DataService.OnPlayerLoaded(mirror)
	GameEvents.On("DataReset", function(player: Player)
		mirror(player)
		MultiplierService.Refresh(player)
	end)
end

return RebirthService
