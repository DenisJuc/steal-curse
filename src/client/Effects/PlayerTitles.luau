-- Earned titles (zone mastery, purified zones) shown over every player's head: the "Title"
-- attribute set by MasteryService. Made on this client for every character.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerTitles = {}

local NAME = "PlayerTitle"
local COLOR = Color3.fromRGB(255, 215, 120)

local function make(head: BasePart): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = NAME
	gui.Size = UDim2.fromOffset(200, 22)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = COLOR
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Adornee = head
	gui.Parent = head
	return gui, label
end

function PlayerTitles.Start()
	local shown: { [Player]: { Gui: BillboardGui, Label: TextLabel } } = {}
	Players.PlayerRemoving:Connect(function(player)
		shown[player] = nil
	end)
	local check = 0
	RunService.Heartbeat:Connect(function(dt)
		check += dt
		if check < 0.5 then
			return
		end
		check = 0
		for _, player in Players:GetPlayers() do
			local title = player:GetAttribute("Title")
			local character = player.Character
			local head = character and character:FindFirstChild("Head")
			local entry = shown[player]
			if type(title) ~= "string" or title == "" or not (head and head:IsA("BasePart")) then
				if entry then
					entry.Gui:Destroy()
					shown[player] = nil
				end
				continue
			end
			if not entry or entry.Gui.Parent ~= head then
				if entry then
					entry.Gui:Destroy()
				end
				local gui, label = make(head)
				entry = { Gui = gui, Label = label }
				shown[player] = entry
			end
			assert(entry, "title entry")
			if entry.Label.Text ~= title then
				entry.Label.Text = title
			end
		end
	end)
end

return PlayerTitles
