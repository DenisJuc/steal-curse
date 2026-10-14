-- Where you are in the wild: the area and its depth band (The Edge, The Deep, Heart of the Wild,
-- Config.HuntStreak.Bands) with what a capture there is worth, shown at the bottom of the screen
-- while in the wild. Going deeper also shows a banner explaining the band.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local HuntStreak = require(ReplicatedStorage.Shared.HuntStreak)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local Banner = require(script.Parent.Banner)
local UIKit = require(script.Parent.UIKit)

local ZoneLabel = {}

local CHECK_SECONDS = 0.25
-- A band's banner shows at most this often (walking back and forth on the line).
local BANNER_COOLDOWN = 30
local RANK = { Edge = 1, Deep = 2, Heart = 3 }
local BANNER_TEXT = {
	Deep = "Captures here build your Hunt Streak twice as fast and give double mastery XP. Cursed Shrines hide out here.",
	Heart = "The most dangerous ground. Captures here build your streak fastest and give triple mastery XP.",
}

local areaNames: { [string]: string } = {}
for _, area in Config.Areas do
	areaNames[area.Id] = area.Name
end

local function bandColor(band: string): Color3
	local color = Config.HuntStreak.Bands[band].Color
	return Color3.fromRGB(color[1], color[2], color[3])
end

function ZoneLabel.Start(screen: ScreenGui)
	local colors = UIKit.Colors
	local holder = UIKit.create("Frame", {
		Name = "ZoneLabel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -272),
		Size = UDim2.fromOffset(420, 46),
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.35,
		Visible = false,
		Parent = screen,
	}, { UIKit.corner(10) })
	UIKit.scaler(holder)
	local stroke = UIKit.stroke(colors.Trim, 1.5, 0.3)
	stroke.Parent = holder
	local title = UIKit.label({
		Name = "Where",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = holder,
	})
	local detail = UIKit.label({
		Name = "Worth",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = colors.SubText,
		Position = UDim2.fromOffset(0, 25),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = holder,
	})

	local player = Players.LocalPlayer
	local shownKey: string? = nil
	local lastBand: string? = nil
	local bannerAt: { [string]: number } = {}
	local elapsed = 0

	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_SECONDS then
			return
		end
		elapsed = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local position = if root and root:IsA("BasePart") then root.Position else nil
		if not position or not WorldLayout.inWild(Config.World, position.X, position.Z) then
			holder.Visible = false
			lastBand = nil
			return
		end
		local band = HuntStreak.band(position.X, position.Z, Config.HuntStreak :: any)
		local area = WorldLayout.areaAt(Config.Areas, Config.World, position.X, position.Z)
		holder.Visible = true
		local key = `{area}|{band}`
		if key ~= shownKey then
			shownKey = key
			local color = bandColor(band)
			title.Text = `{areaNames[area] or area}  -  {Config.HuntStreak.Bands[band].Name}`
			title.TextColor3 = color
			stroke.Color = color
			detail.Text = `Each capture: +{Config.HuntStreak.Gains[band]} streak, {Config.Mastery.Xp[band]} mastery XP`
		end
		if lastBand and RANK[band] > RANK[lastBand] and BANNER_TEXT[band] then
			local now = os.clock()
			if now - (bannerAt[band] or -math.huge) > BANNER_COOLDOWN then
				bannerAt[band] = now
				Banner.Show(string.upper(Config.HuntStreak.Bands[band].Name), BANNER_TEXT[band], bandColor(band))
			end
		end
		lastBand = band
	end)

end

return ZoneLabel
