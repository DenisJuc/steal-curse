-- Lightning Luck: binding a lightning-struck signal rolls nothing. It charges a timed Luck
-- multiplier instead (Config.WildFinds.Strike: Luck for LuckSeconds; more struck captures add
-- time, up to LuckMaxSeconds). It is part of the normal Luck stack (MultiplierService
-- "Lightning"), so every roll gets it while it lasts. Mirrored as:
--   BuffEnds_Lightning   server time it ends (BuffTimers pill)
--   LightningLuck        its factor while active (every client draws the yellow aura)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MultiplierService = require(script.Parent.MultiplierService)

local LightningService = {}

local untilTimes: { [Player]: number } = {}

local function clear(player: Player)
	untilTimes[player] = nil
	player:SetAttribute("BuffEnds_Lightning", nil)
	player:SetAttribute("LightningLuck", nil)
	MultiplierService.Refresh(player)
end

-- Starts or extends Lightning Luck. Returns its factor and the server time it ends.
function LightningService.Charge(player: Player): (number, number)
	local cfg = Config.WildFinds.Strike
	local now = workspace:GetServerTimeNow()
	local from = math.max(untilTimes[player] or now, now)
	local untilTime = math.min(now + cfg.LuckMaxSeconds, from + cfg.LuckSeconds)
	untilTimes[player] = untilTime
	player:SetAttribute("BuffEnds_Lightning", untilTime)
	player:SetAttribute("LightningLuck", cfg.Luck)
	MultiplierService.Refresh(player)
	return cfg.Luck, untilTime
end

function LightningService.Init()
	MultiplierService.Register("Luck", "Lightning", function(player)
		local untilTime = untilTimes[player]
		return if untilTime and workspace:GetServerTimeNow() < untilTime then Config.WildFinds.Strike.Luck else 1
	end)
	Players.PlayerRemoving:Connect(function(player)
		untilTimes[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local now = workspace:GetServerTimeNow()
			for player, untilTime in untilTimes do
				if now >= untilTime then
					clear(player)
				end
			end
		end
	end)
end

return LightningService
