-- Hub kiosks (GDD 4.1): triggering a kiosk's proximity prompt opens the menu named by its
-- OpensMenu attribute, the same as pressing that HUD button. The Bounty Board also floats a
-- "ready" badge while finished bounties wait to be claimed (BountiesReady attribute).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local KioskController = {}

local BADGE_COLOR = Color3.fromRGB(255, 150, 90)

local function makeBadge(prompt: ProximityPrompt)
	local part = prompt.Parent
	if not (part and part:IsA("BasePart")) or part:FindFirstChild("ReadyBadge") then
		return
	end
	local player = Players.LocalPlayer
	local gui = Instance.new("BillboardGui")
	gui.Name = "ReadyBadge"
	gui.Size = UDim2.fromOffset(150, 44)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = BADGE_COLOR
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	gui.Parent = part
	local function refresh()
		local ready = player:GetAttribute("BountiesReady")
		ready = if type(ready) == "number" then ready else 0
		gui.Enabled = ready > 0
		label.Text = `! {ready} ready`
	end
	player:GetAttributeChangedSignal("BountiesReady"):Connect(refresh)
	refresh()
end

local function watchPrompt(item: Instance)
	if item:IsA("ProximityPrompt") and item:GetAttribute("OpensMenu") == "Bounties" then
		makeBadge(item)
	end
end

function KioskController.Start(openers: { [string]: () -> () })
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local menu = prompt:GetAttribute("OpensMenu")
		local open = type(menu) == "string" and openers[menu]
		if open then
			open()
		end
	end)
	for _, item in workspace:GetDescendants() do
		watchPrompt(item)
	end
	workspace.DescendantAdded:Connect(watchPrompt)
end

return KioskController
