-- Showcases (GDD 6.7, 10). Collect Showcases (CE purchase, a relic discovery, a Codex
-- milestone or zone mastery), upgrade them (levels 1-4, same stats for every Showcase) and pick one as active.
-- Only the active one buffs ("Showcase" Luck factor and Income bonus); switching is free and
-- moves the buff at once. Posing on the podium is optional and cosmetic.
-- Remote: ShowcaseAction ("Get" | "Unlock" id | "Upgrade" id | "Activate" id |
-- "ToggleAccessory" accessoryId) returns { State, Message }.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Codex = require(ReplicatedStorage.Shared.Codex)
local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ShowcaseConfig = require(ReplicatedStorage.Shared.ShowcaseConfig)
local Showcases = require(ReplicatedStorage.Shared.Showcases)
local ZoneMastery = require(ReplicatedStorage.Shared.ZoneMastery)
local ShowcaseVisuals = require(script.Parent.Parent.World.ShowcaseVisuals)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GameEvents = require(script.Parent.GameEvents)
local MultiplierService = require(script.Parent.MultiplierService)
local PlotService = require(script.Parent.PlotService)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShowcaseAction = Remotes:WaitForChild("ShowcaseAction") :: RemoteFunction
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local ShowcaseService = {}

local LEVELS = ShowcaseConfig.Levels

local function progressOf(data: any): Showcases.Progress
	local milestones = table.clone(data.CodexReady)
	for id, at in data.CodexMilestones do
		milestones[id] = at
	end
	local mastery = {}
	for area, xp in data.Mastery do
		mastery[area] = (ZoneMastery.level(xp, Config.Mastery :: any))
	end
	return { Discovered = data.Discovered, Milestones = milestones, Mastery = mastery }
end

local function bonus(player: Player): (number, number)
	local data = DataService.Get(player)
	if not data then
		return 0, 0
	end
	return Showcases.bonus(data.Showcases, LEVELS)
end

local function mirror(player: Player, data: any)
	local level = data.Showcases.Owned[data.Showcases.Active]
	player:SetAttribute("ShowcaseActive", data.Showcases.Active)
	player:SetAttribute("ShowcaseLevel", level or 0)
end

-- While posing, the character carries the "ShowcasePose" attribute (the Showcase id); every
-- client bends the body into that Showcase's own pose (client ShowcasePose).
type Pose = { Character: Model, Since: number, At: Vector3, Seated: boolean }
local posing: { [Player]: Pose } = {}

local function endPose(player: Player)
	local pose = posing[player]
	posing[player] = nil
	if pose and pose.Character.Parent then
		pose.Character:SetAttribute("ShowcasePose", nil)
	end
end

local function pose(player: Player)
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local showcase = data and ShowcaseConfig.ById[data.Showcases.Active]
	if not character or not humanoid or not root or not root:IsA("BasePart") or not showcase then
		return
	end
	if humanoid.Health <= 0 or humanoid.Sit then
		return
	end
	local stand, seat = ShowcaseVisuals.PoseTarget(plot)
	if not stand then
		return
	end
	endPose(player)
	if seat then
		seat.Disabled = false
		seat:Sit(humanoid)
	else
		-- Guardian Showcases are prayed to: face the statue behind the dais centre.
		local facing = if showcase.Style == "Guardian" then CFrame.Angles(0, math.pi, 0) else CFrame.identity
		local height = humanoid.HipHeight + root.Size.Y / 2
		character:PivotTo(stand * CFrame.new(0, height, 0) * facing)
	end
	character:SetAttribute("ShowcasePose", showcase.Id)
	posing[player] = { Character = character, Since = os.clock(), At = root.Position, Seated = seat ~= nil }
end

-- Rebuilds the podium look from the player's data (only when something visible changed).
function ShowcaseService.Render(player: Player)
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if not data or not plot then
		return
	end
	local state = data.Showcases
	local level = state.Owned[state.Active]
	local showcase = ShowcaseConfig.ById[state.Active]
	local view = nil
	if level and showcase then
		view = {
			Id = showcase.Id,
			Level = level,
			Accessories = Showcases.visibleAccessories(state, showcase, progressOf(data)),
		}
	end
	ShowcaseVisuals.Apply(plot, view, player.UserId, function(who: Player)
		if who == player then
			pose(player)
		end
	end)
end

local function changed(player: Player, data: any)
	mirror(player, data)
	MultiplierService.Refresh(player)
	ShowcaseService.Render(player)
	DataService.RequestSave(player)
end

local function grant(player: Player, data: any, id: string, announce: boolean)
	if data.Showcases.Owned[id] then
		return
	end
	data.Showcases.Owned[id] = 1
	if data.Showcases.Active == "" then
		data.Showcases.Active = id
	end
	if announce then
		Notify:FireClient(player, `Showcase unlocked: {ShowcaseConfig.ById[id].Name}! Open Shrine > Showcases.`)
	end
end

-- Grants every relic/Codex Showcase whose condition is now met (never CE ones).
function ShowcaseService.CheckFreeUnlocks(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local progress = progressOf(data)
	local any = false
	for _, showcase in ShowcaseConfig.Showcases do
		if not data.Showcases.Owned[showcase.Id] and Showcases.freeUnlockMet(showcase, progress) then
			grant(player, data, showcase.Id, true)
			any = true
		end
	end
	if any then
		changed(player, data)
	end
end

local function state(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local progress = progressOf(data)
	local accessories = {}
	for id, accessory in ShowcaseConfig.AccessoryById do
		accessories[id] = Showcases.accessoryUnlocked(accessory, progress)
	end
	-- How far each locked free-unlock Showcase is (CE ones: the client compares CE to the price).
	local unlockProgress = {}
	local codexState = { Discovered = data.Discovered, Mutations = data.CodexMutations }
	for id, showcase in ShowcaseConfig.ById do
		if not data.Showcases.Owned[id] then
			local unlock = showcase.Unlock
			if unlock.Kind == "Relic" then
				unlockProgress[id] = { Have = if data.Discovered[unlock.RelicId] then 1 else 0, Need = 1 }
			elseif unlock.Kind == "Mastery" and unlock.Area then
				local need = unlock.Level or 1
				unlockProgress[id] = { Have = math.min((progress.Mastery :: any)[unlock.Area] or 0, need), Need = need }
			elseif unlock.Kind == "Codex" and unlock.Milestone then
				local milestone = CodexBook.ById[unlock.Milestone]
				if milestone then
					local have = if progress.Milestones[unlock.Milestone] then milestone.Need else Codex.progress(milestone, codexState)
					unlockProgress[id] = { Have = math.min(have, milestone.Need), Need = milestone.Need }
				end
			end
		end
	end
	return {
		Active = data.Showcases.Active,
		Owned = table.clone(data.Showcases.Owned),
		AccessoriesOff = table.clone(data.Showcases.AccessoriesOff),
		AccessoriesUnlocked = accessories,
		UnlockProgress = unlockProgress,
	}
end

local ACTIONS: { [string]: (Player, any, any) -> string? } = {
	Unlock = function(player, data, id)
		local showcase = type(id) == "string" and ShowcaseConfig.ById[id]
		if not showcase or data.Showcases.Owned[id] then
			return nil
		end
		local price = showcase.Unlock.Price
		if showcase.Unlock.Kind ~= "CE" or not price then
			return "This Showcase can't be bought - see how to unlock it."
		end
		if not EconomyService.TrySpend(player, price) then
			return `{showcase.Name} costs {Format.number(price)} CE.`
		end
		grant(player, data, id, false)
		changed(player, data)
		return `Unlocked {showcase.Name}!`
	end,

	Upgrade = function(player, data, id)
		local showcase = type(id) == "string" and ShowcaseConfig.ById[id]
		local level = showcase and data.Showcases.Owned[id]
		if not showcase or not level then
			return nil
		end
		local cost = Showcases.upgradeCost(LEVELS, level)
		if not cost then
			return `{showcase.Name} is already at max level.`
		end
		if not EconomyService.TrySpend(player, cost) then
			return `Level {level + 1} costs {Format.number(cost)} CE.`
		end
		data.Showcases.Owned[id] = level + 1
		changed(player, data)
		return `{showcase.Name} is now level {level + 1}.`
	end,

	Activate = function(player, data, id)
		local showcase = type(id) == "string" and ShowcaseConfig.ById[id]
		if not showcase or not data.Showcases.Owned[id] then
			return nil
		end
		if data.Showcases.Active ~= id then
			endPose(player)
			data.Showcases.Active = id
			changed(player, data)
		end
		return `{showcase.Name} is now your active Showcase.`
	end,

	ToggleAccessory = function(player, data, accessoryId)
		local accessory = type(accessoryId) == "string" and ShowcaseConfig.AccessoryById[accessoryId]
		if not accessory or not Showcases.accessoryUnlocked(accessory, progressOf(data)) then
			return nil
		end
		local off = data.Showcases.AccessoriesOff
		off[accessoryId] = if off[accessoryId] then nil else true
		changed(player, data)
		return nil
	end,
}

local function onAction(player: Player, action: any, argument: any)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local message = nil
	local rankBefore = 0
	local price = 0
	local id = if type(argument) == "string" then argument else ""
	if action == "Unlock" or action == "Upgrade" then
		local showcase = ShowcaseConfig.ById[id]
		if showcase then
			rankBefore = data.Showcases.Owned[id] or 0
			if action == "Unlock" then
				price = showcase.Unlock.Price or 0
			else
				price = Showcases.upgradeCost(LEVELS, rankBefore) or 0
			end
		end
	end
	if action ~= "Get" then
		local handler = type(action) == "string" and ACTIONS[action]
		if not handler then
			return nil
		end
		message = handler(player, data, argument)
		if (action == "Unlock" or action == "Upgrade") and type(message) == "string" then
			local Analytics = require(script.Parent.PlaytestAnalyticsService)
			local rankAfter = data.Showcases.Owned[id] or rankBefore
			local ok = rankAfter > rankBefore
			Analytics.RecordPurchase(player, {
				System = "Showcase",
				Item = `{action}:{id}`,
				RankBefore = rankBefore,
				RankAfter = rankAfter,
				Price = price,
				Currency = "CE",
				Ok = ok,
				Reason = message,
				Kind = if not ok then "Failed" elseif action == "Unlock" then "Unlock" else "Routine",
			})
		elseif action == "Activate" and type(message) == "string" then
			local Analytics = require(script.Parent.PlaytestAnalyticsService)
			Analytics.RecordUnlockUsed(player, `Showcase:{id}`)
			Analytics.RecordClientActivity(player, "UpgradeUI")
		end
	end
	return { State = state(player), Message = message }
end

-- Debug: grant one Showcase (or every one) at level 1.
function ShowcaseService.Grant(player: Player, id: string): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local ids = {}
	if id == "all" then
		for _, showcase in ShowcaseConfig.Showcases do
			table.insert(ids, showcase.Id)
		end
	elseif ShowcaseConfig.ById[id] then
		ids = { id }
	else
		return false
	end
	for _, each in ids do
		grant(player, data, each, false)
	end
	changed(player, data)
	return true
end

-- Debug: set a level directly (owned Showcases only).
function ShowcaseService.SetLevel(player: Player, id: string, level: number): boolean
	local data = DataService.Get(player)
	if not data or not data.Showcases.Owned[id] then
		return false
	end
	data.Showcases.Owned[id] = math.clamp(math.floor(level), 1, ShowcaseConfig.MaxLevel)
	changed(player, data)
	return true
end

function ShowcaseService.Init()
	MultiplierService.Register("Luck", "Showcase", function(player)
		local _, luck = bonus(player)
		return 1 + luck
	end)
	MultiplierService.Register("Income", "Showcase", function(player)
		local income = bonus(player)
		return income
	end)
	RemoteGuard.Function(ShowcaseAction, onAction, "Shrine")

	local function refresh(player: Player)
		local data = DataService.Get(player)
		if not data then
			return
		end
		endPose(player)
		mirror(player, data)
		ShowcaseService.CheckFreeUnlocks(player)
		ShowcaseService.Render(player)
		MultiplierService.Refresh(player)
	end
	DataService.OnPlayerLoaded(refresh)
	GameEvents.On("DataReset", refresh)
	GameEvents.On("PlotAssigned", function(player: Player)
		ShowcaseService.Render(player)
	end)
	GameEvents.On("CodexChanged", ShowcaseService.CheckFreeUnlocks)
	GameEvents.On("Discovery", function(player: Player, _item: any, first: boolean)
		if first then
			ShowcaseService.CheckFreeUnlocks(player)
			-- A first discovery can also unlock an accessory.
			ShowcaseService.Render(player)
		end
	end)
	Players.PlayerRemoving:Connect(endPose)

	-- Standing poses end as soon as the player moves or jumps; throne poses when they stand up.
	RunService.Heartbeat:Connect(function()
		for player, current in posing do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
				endPose(player)
			elseif current.Seated then
				if os.clock() - current.Since > 0.5 and not humanoid.Sit then
					endPose(player)
				end
			elseif os.clock() - current.Since > 0.3 then
				local moved = (root.Position - current.At).Magnitude > 1.5
				if moved or humanoid.MoveDirection.Magnitude > 0.1 then
					endPose(player)
				end
			end
		end
	end)
end

return ShowcaseService
