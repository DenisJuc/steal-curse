-- Hold E on your own pedestals (client-side prompts, so only the owner sees them):
--   relic on it, nothing floating -> "Take": it floats beside you and goes back to the backpack
--   relic on it, a relic floating -> "Swap": the floating one goes on, the other one floats
--   empty, a relic floating       -> "Place"
--   empty, nothing floating       -> no prompt
-- Reads the pedestal attributes PedestalVisuals mirrors and the FloatingRelic player attribute;
-- the server (PedestalService "Grab") decides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)

local ShrineAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShrineAction") :: RemoteEvent

local PedestalPrompts = {}

local HOLD_SECONDS = 0.5
local RANGE = 10
local FIND_SECONDS = 1

local function plotsFolder(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Plots")
end

function PedestalPrompts.Start()
	local player = Players.LocalPlayer
	local prompts: { [Model]: ProximityPrompt } = {}
	local plot: Model? = nil

	local function refresh(pedestal: Model, prompt: ProximityPrompt)
		local relic = pedestal:GetAttribute("RelicName") or ""
		local floating = player:GetAttribute("FloatingRelic") or ""
		if pedestal:GetAttribute("Owned") ~= true or (relic == "" and floating == "") then
			prompt.Enabled = false
			return
		end
		prompt.Enabled = true
		if relic ~= "" and floating ~= "" then
			prompt.ActionText = "Swap"
			prompt.ObjectText = `{relic} for {floating}`
		elseif relic ~= "" then
			prompt.ActionText = "Take"
			prompt.ObjectText = `{relic} (-{Format.rate(pedestal:GetAttribute("IncomePerSec") or 0)})`
		else
			prompt.ActionText = "Place"
			prompt.ObjectText = floating
		end
	end

	local function refreshAll()
		for pedestal, prompt in prompts do
			refresh(pedestal, prompt)
		end
	end

	local function attach(pedestal: Instance)
		local slot = tonumber(string.match(pedestal.Name, "^Pedestal(%d+)$"))
		local top = pedestal:FindFirstChild("Top")
		if not slot or not pedestal:IsA("Model") or not top or not top:IsA("BasePart") or prompts[pedestal] then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GrabPrompt"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = HOLD_SECONDS
		prompt.MaxActivationDistance = RANGE
		prompt.RequiresLineOfSight = false
		prompt.Parent = top
		prompt.Triggered:Connect(function()
			ShrineAction:FireServer("Grab", slot)
		end)
		prompts[pedestal] = prompt
		for _, name in { "Owned", "RelicName", "IncomePerSec" } do
			pedestal:GetAttributeChangedSignal(name):Connect(function()
				refresh(pedestal, prompt)
			end)
		end
		refresh(pedestal, prompt)
	end

	local function findPlot()
		local index = player:GetAttribute("PlotIndex")
		local folder = plotsFolder()
		local found = nil
		for _, candidate in if folder and index then folder:GetChildren() else {} do
			if candidate:IsA("Model") and candidate:GetAttribute("PlotIndex") == index then
				found = candidate
			end
		end
		if found == plot then
			return
		end
		for _, prompt in prompts do
			prompt:Destroy()
		end
		table.clear(prompts)
		plot = found
		local pedestals = found and found:FindFirstChild("Pedestals")
		for _, pedestal in if pedestals then pedestals:GetChildren() else {} do
			attach(pedestal)
		end
	end

	player:GetAttributeChangedSignal("FloatingRelic"):Connect(refreshAll)
	player:GetAttributeChangedSignal("PlotIndex"):Connect(findPlot)
	task.spawn(function()
		while true do
			findPlot()
			task.wait(FIND_SECONDS)
		end
	end)
end

return PedestalPrompts
