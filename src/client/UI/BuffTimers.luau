-- Bottom-right buff timers (Slice 12): one pill per active buff with its time left, read from the
-- BuffEnds_<id> attributes: every potion (timers only run while you are online; the server pauses
-- them offline) plus Lightning Luck from capturing lightning-struck spirits. Zone events get a pill
-- too (workspace attributes from ZoneEventService): "<event> in m:ss" during the warning, then
-- "<event> m:ss" while it runs, so players know when to head into the wild.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local BuffTimers = {}

local PILL_WIDTH = 196
local PILL_HEIGHT = 30
-- On touch screens the jump button owns the bottom-right corner (the -56 clears the SFX button).
local TOUCH_LIFT = 150
-- Under this many seconds left the pill bounces every second.
local WARN_SECONDS = 10

local SHORT_NAMES = {
	Luck = "Luck x2",
	Haste = "Haste -25%",
	Fortune = "Fortune +50%",
}

type Buff = { Id: string, Icon: string, Color: Color3, Label: (Player) -> string, Ends: ((Player) -> any)? }

-- A buff's end time: its own Ends reader, else the player's BuffEnds_<id> attribute.
local function endsOf(buff: Buff, player: Player): any
	if buff.Ends then
		return buff.Ends(player)
	end
	return player:GetAttribute(`BuffEnds_{buff.Id}`)
end

local function buffList(): { Buff }
	local list: { Buff } = {}
	for _, item in ItemConfig.Items do
		local label = SHORT_NAMES[item.Effect] or item.Name
		table.insert(list, {
			Id = item.Id,
			Icon = `Potion{item.Effect}`,
			Color = Color3.fromRGB(item.Color[1], item.Color[2], item.Color[3]),
			Label = function()
				return label
			end,
		})
	end
	table.insert(list, {
		Id = "Lightning",
		Icon = "Lightning",
		Color = Color3.fromRGB(255, 228, 120),
		Label = function(player)
			local factor = player:GetAttribute("LightningLuck")
			return `Lightning x{Format.multiplier(if type(factor) == "number" then factor else 1)}`
		end,
	})
	for _, event in Config.ZoneEvents.Events do
		local function soon(): boolean
			return workspace:GetAttribute("ZoneEventSoon") == event.Id
		end
		table.insert(list, {
			Id = `Zone_{event.Id}`,
			Icon = "",
			Color = Color3.fromRGB(event.Color[1], event.Color[2], event.Color[3]),
			Label = function()
				return if soon() then `{event.Name} in` else event.Name
			end,
			Ends = function()
				if workspace:GetAttribute("ZoneEvent") == event.Id then
					return workspace:GetAttribute("ZoneEventEndsAt")
				end
				return if soon() then workspace:GetAttribute("ZoneEventStartsAt") else nil
			end,
		})
	end
	return list
end

function BuffTimers.Start(screen: ScreenGui)
	local player = Players.LocalPlayer
	local lift = if UserInputService.TouchEnabled then TOUCH_LIFT else 0
	local buffs = buffList()

	local holder = UIKit.create("Frame", {
		Name = "BuffTimers",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -56 - lift),
		Size = UDim2.fromOffset(PILL_WIDTH, (PILL_HEIGHT + 6) * #buffs),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UIKit.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
		}),
	})
	UIKit.scaler(holder)

	local pills: { [string]: TextLabel } = {}
	local slots: { [string]: Frame } = {}
	local lastSecond: { [string]: number } = {}
	for index, buff in buffs do
		local slot = UIKit.slot(holder, buff.Id, UDim2.fromOffset(PILL_WIDTH, PILL_HEIGHT), index)
		slot.Visible = false
		local pill = UIKit.label({
			Name = "Pill",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = slot,
		})
		UIKit.fill(pill)
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
		UIKit.create("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingLeft = UDim.new(0, 30), Parent = pill })
		UIKit.skinPanel(pill, buff.Color)
		slots[buff.Id] = slot
		local icon = Icons.image(pill, buff.Icon, 24)
		if icon then
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, -26, 0.5, 0)
		else
			UIKit.create("Frame", {
				Name = "Dot",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, -22, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = buff.Color,
				Parent = pill,
			}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		pills[buff.Id] = pill
	end

	local elapsed = 1
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		for _, buff in buffs do
			local pill = pills[buff.Id]
			local slot = slots[buff.Id]
			local ends = endsOf(buff, player)
			local left = if type(ends) == "number" then ends - now else 0
			local active = left > 0
			if active and not slot.Visible then
				Motion.pop(pill, 0, 0.3)
			end
			slot.Visible = active
			if active then
				pill.Text = `{buff.Label(player)}  {ItemConfig.formatTime(left)}`
				local second = math.ceil(left)
				if left < WARN_SECONDS and second ~= lastSecond[buff.Id] then
					Motion.punch(pill, 1.5)
				end
				lastSecond[buff.Id] = second
			end
		end
	end)
end

return BuffTimers
