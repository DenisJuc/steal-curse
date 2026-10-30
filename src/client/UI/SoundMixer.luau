-- TEMPORARY Studio-only mixer: every Config.Sounds entry with a Play button and a 0-100 volume
-- knob (Volume = knob/100 in Config). Dump prints paste-ready lines to the Output window.
-- Remove this file and its Main.client require when volumes are locked in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(script.Parent.Parent.Sounds)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local SoundMixer = {}

-- What each sound is and how to hear it in a normal play session.
local INFO: { [string]: { What: string, How: string } } = {
	RevealSmall = {
		What = "Soft pop for a common/low-tier reveal card",
		How = "Roll until a Small reveal plays (common finds)",
	},
	RevealMedium = {
		What = "Stronger reveal sting for Medium presentation",
		How = "Roll an uncommon/rarer find that uses Medium reveal",
	},
	RevealLarge = {
		What = "Big reveal sting for Large / legendary-style cards",
		How = "Roll a high-tier find that uses Large reveal",
	},
	Mutation = {
		What = "Mutation flash on a mutated relic reveal",
		How = "Get a mutated find (Mutation Resonance unlocked) and watch the reveal",
	},
	Hover = {
		What = "UI hover tick",
		How = "Move the mouse over any juiced HUD button",
	},
	Click = {
		What = "UI click / press",
		How = "Click a button or change a setting",
	},
	MenuOpen = {
		What = "Panel open whoosh",
		How = "Open Pedestals, Backpack, Settings, etc.",
	},
	MenuClose = {
		What = "Panel close whoosh",
		How = "Close any modal panel",
	},
	Upgrade = {
		What = "Purchase / upgrade success",
		How = "Buy a pedestal level or skill rank",
	},
	Error = {
		What = "Denied / error buzz",
		How = "Press a CE button you can't afford",
	},
	Coin = {
		What = "CE coin land / payout tick",
		How = "Earn a CE windfall (sell, claim) and watch coins fly in",
	},
	Shine = {
		What = "Generic sparkle / reward shine",
		How = "Claim codex rewards, use a potion, cleanse shrine, rare reel land",
	},
	Seal = {
		What = "Seal stamp / bind seal hit",
		How = "Finish a bind, cleanse a shrine, or land a legendary reel",
	},
	Collect = {
		What = "Pickup / collect chime",
		How = "Capture animation finish or open an offering (fallback)",
	},
	ReelTick = {
		What = "Reel tick while the strip spins",
		How = "Roll with roll animation On (not Off)",
	},
	ReelLand = {
		What = "Reel stop / land",
		How = "Same as ReelTick — end of a roll reel",
	},
	SightOn = {
		What = "Spirit Sight activate",
		How = "Enter the wild and press Spirit Sight (F)",
	},
	SightOff = {
		What = "Spirit Sight deactivate",
		How = "Leave Spirit Sight (F again) or leave the wild",
	},
	SightAmbience = {
		What = "Looping ambience while Sight is on",
		How = "Stay in Spirit Sight for a few seconds (loop)",
	},
	Pulse = {
		What = "Spirit pulse blast",
		How = "In the wild with Sight, press Pulse (Q) when ready",
	},
	SignalPing = {
		What = "3D ping when a signal appears / is seen",
		How = "Spirit Sight near a signal in the wild",
	},
	SignalHum = {
		What = "3D loop near an active signal",
		How = "Stand by a signal in Spirit Sight",
	},
	SignalWhisper = {
		What = "Close-range whisper on a signal",
		How = "Get very close to a signal in Sight",
	},
	Lock = {
		What = "Bind lock engage",
		How = "Start binding a spirit (hold E on a signal)",
	},
	ChainRattle = {
		What = "Chains rattling during bind / cleanse hold",
		How = "Hold bind, or hold cleanse on a Cursed Shrine",
	},
	ChainTighten = {
		What = "Chains snap tight at a bind beat",
		How = "Progress through a bind, or finish a shrine cleanse",
	},
	BindRiser = {
		What = "Tension riser while binding / cleansing",
		How = "Hold bind or shrine cleanse (loop / riser)",
	},
	SealSuck = {
		What = "Seal suck-in at bind climax",
		How = "Complete a bind capture",
	},
	Cancel = {
		What = "Cancel / fail sting",
		How = "Cancel a bind, fail a cleanse, or cancel hunt actions",
	},
	StreakUp = {
		What = "Hunt streak multiplier went up",
		How = "Capture 2+ spirits in a row in the wild",
	},
	EventStart = {
		What = "Zone event begins (banner)",
		How = "Wait for a wild zone event (or trigger one in Studio)",
	},
	OfferingChime = {
		What = "Hidden offering box periodic chime (3D, far)",
		How = "Wander Deep/Heart until you hear a chime; follow it",
	},
	OfferingOpen = {
		What = "Opening an offering box (empty id = silent for now)",
		How = "Open a Lost Offering; falls back to Collect if empty",
	},
	SpiritGift = {
		What = "Lost One leaves a gift",
		How = "Find and approach a Lost One (kneeling figure)",
	},
	FalseWatcher = {
		What = "False Watcher jump-scare fallback",
		How = "Trigger a False Watcher encounter (Lost One fake)",
	},
	WatcherStinger = {
		What = "False Watcher face-scream (empty id = uses FalseWatcher)",
		How = "Same as False Watcher when stinger asset is set",
	},
	WatcherBreath = {
		What = "False Watcher breathing before lunge (empty = whisper)",
		How = "False Watcher encounter — breathing phase",
	},
	CrowCaw = {
		What = "Crow call in the wild (3D)",
		How = "Wait in the wild for flock crows",
	},
	CrowFlap = {
		What = "Crow wing flap (3D)",
		How = "Same as CrowCaw when they take off",
	},
	FigureVanish = {
		What = "Distant figure dissolving (3D)",
		How = "Spot a vanishing silhouette in the wild fog",
	},
	Thunder = {
		What = "Thunder crack during storm ambience",
		How = "Be in the wild during stormy weather / lightning",
	},
	BellToll = {
		What = "Distant bell (Abandoned Village fog)",
		How = "Idle in Abandoned Village wild; random distant sound",
	},
	DistantWhisper = {
		What = "Distant whisper in the fog",
		How = "Idle in any wild area; also Watcher breath fallback",
	},
	BranchSnap = {
		What = "Distant branch snap",
		How = "Idle in Forest or Village wild",
	},
	StoneGrind = {
		What = "Distant stone grind (Ruins)",
		How = "Idle in Ancient Ruins wild",
	},
	DistantHowl = {
		What = "Distant howl",
		How = "Idle in Forest or Ruins wild",
	},
}

local ORDER = {
	"RevealSmall",
	"RevealMedium",
	"RevealLarge",
	"Mutation",
	"Hover",
	"Click",
	"MenuOpen",
	"MenuClose",
	"Upgrade",
	"Error",
	"Coin",
	"Shine",
	"Seal",
	"Collect",
	"ReelTick",
	"ReelLand",
	"SightOn",
	"SightOff",
	"SightAmbience",
	"Pulse",
	"SignalPing",
	"SignalHum",
	"SignalWhisper",
	"Lock",
	"ChainRattle",
	"ChainTighten",
	"BindRiser",
	"SealSuck",
	"Cancel",
	"StreakUp",
	"EventStart",
	"OfferingChime",
	"OfferingOpen",
	"SpiritGift",
	"FalseWatcher",
	"WatcherStinger",
	"WatcherBreath",
	"CrowCaw",
	"CrowFlap",
	"FigureVanish",
	"Thunder",
	"BellToll",
	"DistantWhisper",
	"BranchSnap",
	"StoneGrind",
	"DistantHowl",
}

local ROW_HEIGHT = 72
local SLIDER_WIDTH = 200

local function entryOf(name: string): { Id: string, Volume: number }?
	return (Config.Sounds :: any)[name]
end

local function knobOf(name: string): number
	local entry = entryOf(name)
	return if entry then math.clamp(math.floor(entry.Volume * 100 + 0.5), 0, 100) else 0
end

local function setKnob(name: string, knob: number)
	local entry = entryOf(name)
	if not entry then
		return
	end
	entry.Volume = math.clamp(knob, 0, 100) / 100
end

function SoundMixer.Start(screen: ScreenGui)
	local colors = UIKit.Colors
	local panel, content = UIKit.modal(
		screen,
		"SoundMixer",
		"SFX MIXER (TEMP)",
		colors.Gold,
		Vector2.new(720, 640),
		nil
	)
	panel.ZIndex = 55

	local openButton = UIKit.button({
		Name = "SoundMixerButton",
		Text = "SFX",
		TextSize = 14,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(52, 36),
		ZIndex = 50,
		Parent = screen,
	}, function()
		UIKit.toggle(panel)
	end)
	UIKit.skinButton(openButton, "Gold")
	UIKit.scaler(openButton)

	UIKit.label({
		Text = "Knob 0-100 = Config.Sounds Volume (30 → 0.30). Play ignores the rate-limit gap. Dump prints paste-ready lines.",
		TextSize = 13,
		TextColor3 = colors.SubText,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = content,
	})

	local toolbar = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 40),
		Parent = content,
	})
	local dumpButton = UIKit.button({
		Text = "Dump volumes to Output",
		TextSize = 14,
		Size = UDim2.fromOffset(200, 32),
		Parent = toolbar,
	}, function()
		print("---------- SoundMixer dump (paste Volume values into Config.Sounds) ----------")
		for _, name in ORDER do
			local entry = entryOf(name)
			if entry then
				local vol = string.format("%.2f", entry.Volume)
				print("\t" .. name .. ' = { Id = "' .. entry.Id .. '", Volume = ' .. vol .. " },  -- knob " .. tostring(knobOf(name)))
			end
		end
		print("---------- end dump ----------")
	end)
	UIKit.skinButton(dumpButton, "Primary")

	local list = UIKit.create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 1, -84),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		Parent = content,
	}, {
		UIKit.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	for index, name in ORDER do
		local entry = entryOf(name)
		if not entry then
			continue
		end
		local info = INFO[name] or { What = name, How = "—" }
		local hasAsset = entry.Id ~= ""
		local row = UIKit.create("Frame", {
			Name = name,
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			BackgroundColor3 = colors.Card,
			Parent = list,
		}, { UIKit.corner(8), UIKit.padding(8) })
		UIKit.skinCard(row)

		UIKit.label({
			Text = name,
			TextSize = 16,
			TextColor3 = colors.Gold,
			Size = UDim2.new(0.42, 0, 0, 18),
			Parent = row,
		})
		UIKit.label({
			Text = `{info.What}  |  Test: {info.How}`,
			TextSize = 12,
			TextColor3 = colors.SubText,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(0.55, 0, 0, 40),
			Parent = row,
		})

		local play = UIKit.button({
			Text = if hasAsset then "Play" else "No asset",
			TextSize = 13,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(72, 28),
			Parent = row,
		}, function()
			if hasAsset then
				Sounds.Preview(name)
			end
		end)
		UIKit.skinButton(play, if hasAsset then "Gold" else "Dark")
		Motion.setDisabled(play, not hasAsset)

		local valueLabel = UIKit.label({
			Text = tostring(knobOf(name)),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(36, 20),
			Parent = row,
		})

		local track = UIKit.create("Frame", {
			Name = "Track",
			BackgroundColor3 = colors.Panel,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -44, 1, -2),
			Size = UDim2.fromOffset(SLIDER_WIDTH, 10),
			Parent = row,
		}, { UIKit.corner(4) })
		local fill = UIKit.create("Frame", {
			BackgroundColor3 = colors.Accent,
			Size = UDim2.fromScale(knobOf(name) / 100, 1),
			Parent = track,
		}, { UIKit.corner(4) })
		local knob = UIKit.create("Frame", {
			BackgroundColor3 = colors.Gold,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(knobOf(name) / 100, 0.5),
			Size = UDim2.fromOffset(16, 16),
			ZIndex = 2,
			Parent = track,
		}, { UIKit.corner(8) })
		local hit = UIKit.create("TextButton", {
			Text = "",
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Selectable = false,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -8, 0.5, 0),
			Size = UDim2.new(1, 16, 0, 28),
			ZIndex = 3,
			Parent = track,
		})

		local dragging = false
		local function apply(knobValue: number)
			setKnob(name, knobValue)
			local alpha = knobValue / 100
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
			valueLabel.Text = tostring(knobValue)
		end
		local function setFromX(x: number)
			local width = math.max(track.AbsoluteSize.X, 1)
			local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
			apply(math.floor(alpha * 100 + 0.5))
		end
		local function isPress(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end
		hit.InputBegan:Connect(function(input)
			if isPress(input) then
				dragging = true
				list.ScrollingEnabled = false
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if isPress(input) then
				dragging = false
				list.ScrollingEnabled = true
			end
		end)
	end

	return {
		Toggle = function()
			UIKit.toggle(panel)
		end,
	}
end

return SoundMixer
