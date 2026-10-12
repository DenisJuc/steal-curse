-- Plays the client sounds from Config.Sounds at the player's volume. Each play uses its own
-- short-lived copy so overlapping reveals never cut each other off. Passing `at` (a part or
-- attachment in the workspace) makes the sound 3D, fading out over the entry's Range.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(script.Parent.Settings)

local Sounds = {}

-- Same sound at most this often (stops fast scans from stacking ticks); entries can set their own Gap.
local MIN_GAP_SECONDS = 0.15

type Entry = { Id: string, Volume: number, Speed: number?, Range: number?, Gap: number? }

local lastPlayed: { [string]: number } = {}

local function create(name: string, at: Instance?): Sound?
	local entry = (Config.Sounds :: any)[name] :: Entry?
	local volume = Settings.Volume()
	if not entry or entry.Id == "" or volume <= 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = entry.Id
	sound.Volume = entry.Volume * volume
	sound.PlaybackSpeed = entry.Speed or 1
	if at then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 6
		sound.RollOffMaxDistance = entry.Range or 60
	end
	sound.Parent = at or SoundService
	return sound
end

-- One-shot. `pitch` multiplies the entry's speed (small random spreads keep repeats from sounding
-- robotic). Returns the playing sound (to stop it early), or nil when muted or rate-limited.
function Sounds.Play(name: string, at: Instance?, pitch: number?): Sound?
	local entry = (Config.Sounds :: any)[name] :: Entry?
	local gap = if entry and entry.Gap then entry.Gap else MIN_GAP_SECONDS
	local now = os.clock()
	if now - (lastPlayed[name] or -math.huge) < gap then
		return nil
	end
	local sound = create(name, at)
	if not sound then
		return nil
	end
	if pitch then
		sound.PlaybackSpeed *= pitch
	end
	lastPlayed[name] = now
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(15, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	return sound
end

-- Looping sound that plays until the caller destroys it. Nil when muted.
function Sounds.Loop(name: string, at: Instance?): Sound?
	local sound = create(name, at)
	if sound then
		sound.Looped = true
		sound:Play()
	end
	return sound
end

return Sounds
