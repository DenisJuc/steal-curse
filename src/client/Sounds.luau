-- Plays the client sounds from Config.Sounds at the player's volume. Each play uses its own
-- short-lived copy so overlapping reveals never cut each other off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(script.Parent.Settings)

local Sounds = {}

-- Same sound at most this often (stops fast scans from stacking ticks).
local MIN_GAP_SECONDS = 0.15

local lastPlayed: { [string]: number } = {}

function Sounds.Play(name: string)
	local entry = (Config.Sounds :: any)[name]
	local volume = Settings.Volume()
	if not entry or entry.Id == "" or volume <= 0 then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or -math.huge) < MIN_GAP_SECONDS then
		return
	end
	lastPlayed[name] = now
	local sound = Instance.new("Sound")
	sound.SoundId = entry.Id
	sound.Volume = entry.Volume * volume
	sound.PlaybackSpeed = entry.Speed or 1
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

return Sounds
