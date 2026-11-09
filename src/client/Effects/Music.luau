-- Soundtrack (Config.Music): one playlist for the town and one for the wild, each on its own
-- looping player in SoundService. Both run at once and crossfade with Ambience.WildWeight (0 in
-- town, 1 deep in the wild), so walking out through the veil slides from the koto tracks into the
-- dark ones. Each playlist plays its tracks in a shuffled order with a short gap between them. The
-- player's Music setting scales everything; 0 pauses both.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(script.Parent.Parent.Settings)
local Ambience = require(script.Parent.Ambience)

local Music = {}

type Deck = { Sound: Sound, Tracks: { string }, Order: { number }, Index: number, Weight: number }

local function shuffled(count: number, avoidFirst: number?): { number }
	local order = {}
	for i = 1, count do
		order[i] = i
	end
	for i = count, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	-- Never the same track twice in a row across a reshuffle.
	if avoidFirst and count > 1 and order[1] == avoidFirst then
		order[1], order[2] = order[2], order[1]
	end
	return order
end

local function newDeck(name: string, tracks: { string }): Deck?
	if #tracks == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = `Music_{name}`
	sound.Volume = 0
	sound.Looped = false
	sound.Parent = SoundService
	local deck: Deck = { Sound = sound, Tracks = tracks, Order = shuffled(#tracks), Index = 0, Weight = 0 }
	local function nextTrack()
		deck.Index += 1
		if deck.Index > #deck.Order then
			deck.Order = shuffled(#tracks, deck.Order[#deck.Order])
			deck.Index = 1
		end
		sound.SoundId = tracks[deck.Order[deck.Index]]
		sound.TimePosition = 0
		sound:Play()
	end
	sound.Ended:Connect(function()
		task.delay(Config.Music.Gap, nextTrack)
	end)
	nextTrack()
	return deck
end

function Music.Start()
	local cfg = Config.Music
	local decks: { [string]: Deck } = {}
	decks.Town = newDeck("Town", cfg.Town) :: Deck
	decks.Wild = newDeck("Wild", cfg.Wild) :: Deck

	RunService.Heartbeat:Connect(function(dt)
		local master = Settings.MusicVolume() * cfg.Volume
		local wild = math.clamp(Ambience.WildWeight(), 0, 1)
		local t = math.clamp(dt / cfg.FadeSeconds * 3, 0, 1)
		for name, deck in decks do
			local goal = master * (if name == "Wild" then wild else 1 - wild)
			deck.Weight += (goal - deck.Weight) * t
			local sound = deck.Sound
			sound.Volume = deck.Weight
			-- Keep both decks running (so a crossfade has music to fade into) unless muted.
			if master <= 0 and sound.IsPlaying then
				sound:Pause()
			elseif master > 0 and sound.IsPaused then
				sound:Resume()
			end
		end
	end)
end

return Music
