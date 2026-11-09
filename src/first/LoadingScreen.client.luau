-- Loading screen (2026-11-09; looks are a first pass). Replaces Roblox's default one, plays the
-- loading track (Config.Music.Loading), and preloads the game's images, meshes and textures (menus,
-- relic models, the hub and the wild) so the Shop and the wild don't pop in on first use. A bar
-- shows progress; Skip (after a moment) closes it at once while preloading carries on behind.
-- When it closes it sets the LocalPlayer attribute "LoadingDone" (Music and the intro hunt wait for it).

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LOADING_TRACK = "rbxassetid://100971756298760" -- same as Config.Music.Loading
local SKIP_AFTER = 2
local MAX_SECONDS = 30
local BATCH = 40

local VIOLET = Color3.fromRGB(28, 18, 44)
local GOLD = Color3.fromRGB(255, 205, 120)

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.Parent = playerGui

local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 1)
-- White so the gradient's colours show as they are.
back.BackgroundColor3 = Color3.new(1, 1, 1)
back.BorderSizePixel = 0
back.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new(VIOLET, Color3.fromRGB(6, 4, 10))
gradient.Parent = back

local function label(text: string, size: number, y: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Position = UDim2.fromScale(0.5, y)
	item.Size = UDim2.new(0.9, 0, 0, size + 8)
	item.Font = Enum.Font.FredokaOne
	item.Text = text
	item.TextSize = size
	item.TextColor3 = color
	item.TextStrokeTransparency = 0.6
	item.Parent = back
	return item
end

-- A slowly turning seal behind the title: a ring of glowing dots and an inner ring turning the
-- other way (no image assets needed).
local function sealRing(count: number, radius: number, dot: number, color: Color3): Frame
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.38)
	ring.Size = UDim2.fromOffset(radius * 2, radius * 2)
	ring.BackgroundTransparency = 1
	ring.Parent = back
	for i = 1, count do
		local a = i / count * math.pi * 2
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Position = UDim2.new(0.5, math.cos(a) * radius, 0.5, math.sin(a) * radius)
		d.Size = UDim2.fromOffset(dot, if i % 3 == 0 then dot * 2.4 else dot)
		d.Rotation = math.deg(a) + 90
		d.BackgroundColor3 = color
		d.BackgroundTransparency = if i % 3 == 0 then 0.1 else 0.45
		d.BorderSizePixel = 0
		d.Parent = ring
		Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
	end
	return ring
end
local outerRing = sealRing(36, 150, 6, Color3.fromRGB(190, 150, 255))
local innerRing = sealRing(18, 112, 5, GOLD)
local title = label("SEAL A CURSE", 54, 0.38, GOLD)
title.ZIndex = 2
local tip = label("The spirits are stirring...", 20, 0.56, Color3.fromRGB(210, 200, 235))

local track = Instance.new("Frame")
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.fromScale(0.5, 0.62)
track.Size = UDim2.new(0.5, 0, 0, 14)
track.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
track.BorderSizePixel = 0
track.Parent = back
Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = GOLD
fill.BorderSizePixel = 0
fill.Parent = track
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
local percent = label("Loading 0%", 18, 0.67, Color3.fromRGB(190, 180, 215))

local skip = Instance.new("TextButton")
skip.AnchorPoint = Vector2.new(1, 1)
skip.Position = UDim2.new(1, -24, 1, -24)
skip.Size = UDim2.fromOffset(140, 48)
skip.BackgroundColor3 = Color3.fromRGB(50, 36, 74)
skip.Font = Enum.Font.FredokaOne
skip.Text = "Skip"
skip.TextSize = 22
skip.TextColor3 = Color3.new(1, 1, 1)
skip.Visible = false
skip.Parent = back
Instance.new("UICorner", skip).CornerRadius = UDim.new(0, 10)

local music = Instance.new("Sound")
music.Name = "LoadingMusic"
music.SoundId = LOADING_TRACK
music.Volume = 0.3
music.Looped = true
music.Parent = SoundService
music:Play()

local TIPS = {
	"The spirits are stirring...",
	"Seal cursed relics and set them on your pedestals.",
	"Walk over the glowing pads to collect your Cursed Energy.",
	"Rarer relics earn far more. Luck finds them.",
	"Spirit Sight reveals what hides in the wild.",
}

local closed = false
local function close()
	if closed then
		return
	end
	closed = true
	player:SetAttribute("LoadingDone", true)
	local fade = TweenInfo.new(0.6)
	TweenService:Create(back, fade, { BackgroundTransparency = 1 }):Play()
	for _, item in back:GetDescendants() do
		if item:IsA("TextLabel") or item:IsA("TextButton") then
			TweenService:Create(item, fade, { TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif item:IsA("Frame") then
			TweenService:Create(item, fade, { BackgroundTransparency = 1 }):Play()
		end
	end
	TweenService:Create(music, TweenInfo.new(2.5), { Volume = 0 }):Play()
	task.delay(2.6, function()
		music:Destroy()
		gui:Destroy()
	end)
end
skip.Activated:Connect(close)
task.delay(SKIP_AFTER, function()
	skip.Visible = not closed
end)
task.delay(MAX_SECONDS, close)
task.spawn(function()
	local t = 0
	while not closed do
		t += task.wait()
		outerRing.Rotation = t * 12
		innerRing.Rotation = -t * 20
		title.TextSize = 54 + math.sin(t * 2) * 2
	end
end)
task.spawn(function()
	local index = 1
	while not closed do
		task.wait(3.5)
		index = index % #TIPS + 1
		tip.Text = TIPS[index]
	end
end)

-- Every content id worth fetching up front (deduplicated), plus instances whose content can't be
-- read from a script (surface appearances, material variants).
local function collect(roots: { Instance }): { any }
	local seen: { [string]: boolean } = {}
	local list: { any } = {}
	local function add(id: any)
		if type(id) == "string" and id ~= "" and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	for _, root in roots do
		for _, item in root:GetDescendants() do
			local ok = pcall(function()
				if item:IsA("ImageLabel") or item:IsA("ImageButton") then
					add(item.Image)
				elseif item:IsA("Decal") or item:IsA("Texture") or item:IsA("ParticleEmitter") or item:IsA("Beam") then
					add((item :: any).Texture)
				elseif item:IsA("MeshPart") then
					add(item.MeshId)
					add(item.TextureID)
				elseif item:IsA("SpecialMesh") then
					add(item.MeshId)
					add(item.TextureId)
				elseif item:IsA("SurfaceAppearance") or item:IsA("MaterialVariant") then
					table.insert(list, item)
				end
			end)
			if not ok then
				continue
			end
		end
	end
	return list
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end
-- The menus are built by the client scripts a moment after load.
playerGui:WaitForChild("RelicCollectorUI", 10)
local roots: { Instance } = { playerGui, game:GetService("MaterialService"), game:GetService("Lighting") }
for _, name in { "RelicModels", "VFX", "HuntModels" } do
	local folder = ReplicatedStorage:FindFirstChild(name)
	if folder then
		table.insert(roots, folder)
	end
end
local map = workspace:WaitForChild("Map", 10)
if map then
	table.insert(roots, map)
end
local list = collect(roots)
local done = 0
for start = 1, #list, BATCH do
	local batch = table.move(list, start, math.min(start + BATCH - 1, #list), 1, {})
	pcall(function()
		ContentProvider:PreloadAsync(batch)
	end)
	done = math.min(#list, start + BATCH - 1)
	if not closed then
		local progress = if #list > 0 then done / #list else 1
		fill.Size = UDim2.fromScale(progress, 1)
		percent.Text = `Loading {math.floor(progress * 100)}%`
	end
end
title.Text = "SEAL A CURSE"
close()
