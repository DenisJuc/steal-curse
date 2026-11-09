-- Zone events on the client (ZoneEventService publishes them on workspace attributes):
--   a tall beam of the event's colour over its area, seen from anywhere (also over the town veil),
--   a warning toast and chat line a minute before, a banner when it starts and a line when it ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local ZoneGates = require(ReplicatedStorage.Shared.ZoneGates)
local Format = require(ReplicatedStorage.Shared.Format)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local Sounds = require(script.Parent.Parent.Sounds)
local EventBanner = require(script.Parent.Parent.UI.EventBanner)

local ZoneBeacon = {}

local BEAM_HEIGHT = 900
local BEAM_WIDTH = 26

type Event = typeof(Config.ZoneEvents.Events[1])

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function eventOf(id: any): Event?
	for _, event in Config.ZoneEvents.Events do
		if event.Id == id then
			return event
		end
	end
	return nil
end

local function areaOf(id: string)
	for _, area in Config.Areas do
		if area.Id == id then
			return area
		end
	end
	return nil
end

local function chat(text: string, color: Color3)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general and general:IsA("TextChannel") then
		general:DisplaySystemMessage(`<font color="#{color:ToHex()}"><b>{text}</b></font>`)
	end
end

-- The beam: a billboard column (GUIs ignore the fog, so it reads from far away) plus a soft neon
-- core for when you stand right under it.
local function buildBeam(event: Event): Part?
	local area = areaOf(event.Area)
	if not area then
		return nil
	end
	local x, z = WorldLayout.areaCenter(area, Config.World)
	local color = rgb(event.Color)
	local part = Instance.new("Part")
	part.Name = `ZoneBeacon_{event.Id}`
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(BEAM_HEIGHT, 6, 6)
	part.CFrame = CFrame.new(x, BEAM_HEIGHT / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.55
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(BEAM_WIDTH, BEAM_HEIGHT)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 5000
	billboard.Parent = part
	local sideFade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(0.65, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	local function column(width: number, tint: Color3, transparency: number)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Position = UDim2.fromScale(0.5, 0)
		frame.Size = UDim2.fromScale(width, 1)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = tint
		frame.BackgroundTransparency = transparency
		frame.Parent = billboard
		local fade = Instance.new("UIGradient")
		fade.Transparency = sideFade
		fade.Parent = frame
	end
	column(1, color, 0.35)
	column(0.3, Color3.new(1, 1, 1):Lerp(color, 0.4), 0.2)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 60
	light.Brightness = 2
	light.Parent = part
	part.Parent = workspace
	return part
end

-- " (locked for you: needs x25 LUCK)" when the player's zone gates keep them out of the whole
-- area (its Edge is locked), else "".
local function lockedNote(areaId: string): string
	local luck = Players.LocalPlayer:GetAttribute("GateLuck")
	if type(luck) ~= "number" then
		return ""
	end
	local ctx: ZoneGates.Context = {
		Areas = Config.Areas,
		World = Config.World,
		Bands = Config.HuntStreak,
		Gates = Config.ZoneGates,
	}
	if ZoneGates.allowedCell(ctx, luck, areaId, "Edge") then
		return ""
	end
	return ` (locked for you: needs x{Format.number(ZoneGates.required(ctx, areaId, "Edge"))} LUCK)`
end

function ZoneBeacon.Start()
	local beam: Part? = nil
	local shownId: string? = nil

	local function refresh()
		local id = workspace:GetAttribute("ZoneEvent")
		local event = eventOf(id)
		if (event and event.Id) == shownId then
			return
		end
		if beam then
			beam:Destroy()
			beam = nil
		end
		local previous = eventOf(shownId)
		shownId = if event then event.Id else nil
		if previous and not event then
			chat(`The {previous.Name} fades.`, rgb(previous.Color))
		end
		if not event then
			return
		end
		beam = buildBeam(event)
		local area = areaOf(event.Area)
		local where = if area then area.Name else event.Area
		local color = rgb(event.Color)
		local locked = lockedNote(event.Area)
		local icon = nil
		for _, entry in Config.Shop.Events do
			if entry.Event == event.Id then
				icon = entry.Icon
			end
		end
		if locked ~= "" then
			EventBanner.Show(event.Name, `{where}{locked}`, color, icon)
		else
			EventBanner.Show(event.Name, `{where}  \u{00B7}  {event.Effect}  \u{00B7}  {Format.duration(Config.ZoneEvents.Duration)}`, color, icon)
		end
		chat(`{event.Name} over the {where}! {event.Effect} on captures there.{locked}`, color)
		Sounds.Play("EventStart")
	end

	workspace:GetAttributeChangedSignal("ZoneEvent"):Connect(refresh)
	refresh()

	-- A slow shimmer so the beam reads as alive.
	RunService.Heartbeat:Connect(function()
		if beam then
			beam.Transparency = 0.55 + math.sin(os.clock() * 2) * 0.1
		end
	end)
end

return ZoneBeacon
