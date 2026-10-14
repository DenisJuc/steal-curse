-- Rebirth (Shared/Rebirth, Config.Rebirth). Remote "Rebirth" (RemoteFunction): "Get" returns the
-- state for the menu; "Rebirth" re-checks the cost on the server, then resets CE, pedestal levels
-- and skill ranks (Rebirth.apply) and keeps relics, slots, the Codex, titles, showcases, lanterns,
-- mastery and potions. Each Rebirth multiplies luck (the "Rebirth" Luck factor here) and income
-- (EconomyService applies it on top of the additive Income bonuses) for good.
-- Fires GameEvents "Rebirthed" so skills, pedestals and multipliers refresh; mirrors "Rebirths".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local settings = Config.Rebirth

export type State = {
	Rebirths: number,
	Cost: number,
	IncomeMultiplier: number,
	LuckMultiplier: number,
	NextIncomeMultiplier: number,
	NextLuckMultiplier: number,
}

function RebirthService.Count(player: Player): number
	local data = DataService.Get(player)
	return if data then data.Rebirths or 0 else 0
end

function RebirthService.State(player: Player): State
	local n = RebirthService.Count(player)
	return {
		Rebirths = n,
		Cost = Rebirth.cost(settings, n),
		IncomeMultiplier = Rebirth.incomeMultiplier(settings, n),
		LuckMultiplier = Rebirth.luckMultiplier(settings, n),
		NextIncomeMultiplier = Rebirth.incomeMultiplier(settings, n + 1),
		NextLuckMultiplier = Rebirth.luckMultiplier(settings, n + 1),
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
	local cost = Rebirth.cost(settings, data.Rebirths or 0)
	if data.CE + 1e-9 < cost then
		return false, `Rebirth needs {Format.ce(cost)} CE.`
	end
	Rebirth.apply(data)
	mirror(player)
	EconomyService.Mirror(player)
	MultiplierService.Refresh(player)
	GameEvents.Fire("Rebirthed", player)
	DataService.RequestSave(player)
	local n = data.Rebirths
	return true,
		`Rebirth {n}! Income x{Format.multiplier(Rebirth.incomeMultiplier(settings, n))}, luck x{Format.multiplier(
			Rebirth.luckMultiplier(settings, n)
		)}.`
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
		return Rebirth.luckMultiplier(settings, RebirthService.Count(player))
	end)
	RemoteGuard.Function(RebirthRemote, onInvoke, "Shrine")
	DataService.OnPlayerLoaded(mirror)
	GameEvents.On("DataReset", function(player: Player)
		mirror(player)
		MultiplierService.Refresh(player)
	end)
end

return RebirthService
