-- Assigns each player one shrine plot, labels it, and spawns the player there.

local Players = game:GetService("Players")

local PedestalVisuals = require(script.Parent.Parent.World.PedestalVisuals)
local GameEvents = require(script.Parent.GameEvents)

local PlotService = {}

local plots: { Model } = {}
local owners: { [number]: Player } = {}

local function setSignText(plot: Model, text: string)
	local sign = plot:FindFirstChild("OwnerSign", true)
	local label = sign and sign:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function spawnAtPlot(player: Player, character: Model)
	local plot = PlotService.GetPlot(player)
	if not plot then
		return
	end
	local pad = plot:FindFirstChild("SpawnPad")
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if pad and pad:IsA("BasePart") and root then
		-- Face the shrine (away from the hub entrance).
		character:PivotTo(pad.CFrame * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.pi, 0))
	end
end

local function assign(player: Player)
	for index = 1, #plots do
		if not owners[index] then
			owners[index] = player
			local plot = plots[index]
			plot:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotIndex", index)
			setSignText(plot, `{player.DisplayName}'s Shrine`)
			GameEvents.Fire("PlotAssigned", player, plot)
			break
		end
	end
	if not player:GetAttribute("PlotIndex") then
		warn(`[PlotService] No free plot for {player.Name}; set Max Players to {#plots} or fewer.`)
	end

	player.CharacterAdded:Connect(function(character)
		task.defer(spawnAtPlot, player, character)
	end)
	if player.Character then
		task.defer(spawnAtPlot, player, player.Character)
	end
end

local function release(player: Player)
	for index, owner in owners do
		if owner == player then
			owners[index] = nil
			plots[index]:SetAttribute("OwnerUserId", nil)
			setSignText(plots[index], "Unclaimed Shrine")
			PedestalVisuals.Reset(plots[index])
		end
	end
end

function PlotService.Init(builtPlots: { Model })
	plots = builtPlots
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(assign, player)
	end
end

function PlotService.GetPlot(player: Player): Model?
	for index, owner in owners do
		if owner == player then
			return plots[index]
		end
	end
	return nil
end

return PlotService
