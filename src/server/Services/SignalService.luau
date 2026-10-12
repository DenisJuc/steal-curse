-- Personal hunt signals (GDD 4.2). Each player has their own 3-5 signals, stored only here and sent
-- only to the owner, so nobody else can see, lock or consume them. Signals carry no rarity: the relic
-- is rolled by BindService only at a validated capture.
-- Signals appear anywhere in the wild ring, on spawn-grid points NearMin..NearMax studs from the
-- player (from the nearest wild edge while the player is in the town). Walking RelocateDistance away
-- from all of them moves them near the player again (keeping ids; a signal being bound stays put).
-- The SignalArea attribute tells the HUD which area they are in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local DataService = require(script.Parent.DataService)

local SignalsUpdated = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SignalsUpdated") :: RemoteEvent

local SignalService = {}

export type Signal = {
	Id: number,
	Position: Vector3,
}

export type SpawnPoint = { Position: Vector3, Area: string }

type State = {
	Signals: { [number]: Signal },
	NextId: number,
	RegenAt: number?,
	Rng: Random,
	Area: string,
}

local spawnPoints: { SpawnPoint } = {}
local states: { [Player]: State } = {}

local function countOf(state: State): number
	local count = 0
	for _ in state.Signals do
		count += 1
	end
	return count
end

local function push(player: Player, state: State)
	local list = {}
	for _, signal in state.Signals do
		table.insert(list, { Id = signal.Id, Position = signal.Position })
	end
	SignalsUpdated:FireClient(player, list)
	player:SetAttribute("SignalCount", #list)
	player:SetAttribute("SignalMax", Config.Signals.MaxCount)
	player:SetAttribute("NextSignalAt", state.RegenAt)
	player:SetAttribute("SignalArea", state.Area)
end

local function updateRegen(state: State, now: number)
	if countOf(state) >= Config.Signals.MaxCount then
		state.RegenAt = nil
	elseif not state.RegenAt then
		state.RegenAt = now + Config.Signals.RegenSeconds
	end
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- Where new signals gather: the player in the wild, else the nearest wild edge (from the plot
-- before the character exists).
local function homePosition(player: Player): Vector3
	local plotIndex = player:GetAttribute("PlotIndex")
	local x, z = 0, 0
	if type(plotIndex) == "number" then
		x, z = WorldLayout.plotPosition(Config.Plots, plotIndex)
	end
	return Vector3.new(x, 0, z)
end

local function anchorOf(player: Player): Vector3
	local position = rootPosition(player) or homePosition(player)
	if WorldLayout.inWild(Config.World, position.X, position.Z) then
		return Vector3.new(position.X, 0, position.Z)
	end
	local x, z = WorldLayout.wildEntry(Config.World, position.X, position.Z, Config.Travel.WildDepth)
	return Vector3.new(x, 0, z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function pickPosition(state: State, anchor: Vector3): Vector3?
	local hover = Vector3.new(0, Config.Signals.HoverHeight, 0)
	local signals = Config.Signals
	local spaced, inBand = {}, {}
	local closest, closestDistance = nil, math.huge
	for _, point in spawnPoints do
		local distance = flatDistance(point.Position, anchor)
		if distance > signals.NearMax * 2 then
			continue
		end
		local position = point.Position + hover
		local taken, tooClose = false, false
		for _, signal in state.Signals do
			local gap = (signal.Position - position).Magnitude
			if gap < 0.5 then
				taken = true
			elseif gap < signals.MinSpacing then
				tooClose = true
			end
		end
		if taken then
			continue
		end
		if distance >= signals.NearMin and distance <= signals.NearMax then
			table.insert(inBand, position)
			if not tooClose then
				table.insert(spaced, position)
			end
		elseif distance < closestDistance then
			closest, closestDistance = position, distance
		end
	end
	local pool = if #spaced > 0 then spaced else inBand
	if #pool == 0 then
		return closest
	end
	return pool[state.Rng:NextInteger(1, #pool)]
end

local function addSignal(state: State, position: Vector3): Signal
	local signal = { Id = state.NextId, Position = position }
	state.NextId += 1
	state.Signals[signal.Id] = signal
	return signal
end

local function areaOf(position: Vector3): string
	return (WorldLayout.areaAt(Config.Areas, Config.World, position.X, position.Z))
end

-- Moves every signal except the one being bound near the player, keeping ids.
local function relocate(player: Player, state: State)
	local bound = player:GetAttribute("BindSignalId")
	local moving = {}
	for id, signal in state.Signals do
		if id ~= bound then
			table.insert(moving, signal)
			state.Signals[id] = nil
		end
	end
	table.sort(moving, function(a, b)
		return a.Id < b.Id
	end)
	local anchor = anchorOf(player)
	state.Area = areaOf(anchor)
	for _, signal in moving do
		signal.Position = pickPosition(state, anchor) or signal.Position
		state.Signals[signal.Id] = signal
	end
	push(player, state)
end

local function checkDistances()
	for player, state in states do
		local position = rootPosition(player)
		if not position or not WorldLayout.inWild(Config.World, position.X, position.Z) then
			continue
		end
		local bound = player:GetAttribute("BindSignalId")
		local nearest, others = math.huge, 0
		for id, signal in state.Signals do
			if id ~= bound then
				others += 1
				nearest = math.min(nearest, flatDistance(signal.Position, position))
			end
		end
		if others > 0 and nearest > Config.Signals.RelocateDistance then
			relocate(player, state)
		end
	end
end

function SignalService.Init(points: { SpawnPoint })
	spawnPoints = points

	DataService.OnPlayerLoaded(function(player)
		if states[player] or not player.Parent then
			return
		end
		local anchor = anchorOf(player)
		local state: State = {
			Signals = {},
			NextId = 1,
			RegenAt = nil,
			Rng = Random.new(),
			Area = areaOf(anchor),
		}
		states[player] = state
		for _ = 1, Config.Signals.StartCount do
			local position = pickPosition(state, anchor)
			if position then
				addSignal(state, position)
			end
		end
		updateRegen(state, workspace:GetServerTimeNow())
		push(player, state)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Signals.CheckSeconds)
			checkDistances()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = workspace:GetServerTimeNow()
			for player, state in states do
				if state.RegenAt and now >= state.RegenAt then
					state.RegenAt = nil
					local anchor = anchorOf(player)
					local position = pickPosition(state, anchor)
					if position then
						addSignal(state, position)
						state.Area = areaOf(anchor)
					end
					updateRegen(state, now)
					push(player, state)
				end
			end
		end
	end)
end

function SignalService.Get(player: Player, signalId: number): Signal?
	local state = states[player]
	return if state then state.Signals[signalId] else nil
end

-- Removes a signal after a validated capture. Returns false if it was already gone.
function SignalService.Consume(player: Player, signalId: number): boolean
	local state = states[player]
	if not state or not state.Signals[signalId] then
		return false
	end
	state.Signals[signalId] = nil
	updateRegen(state, workspace:GetServerTimeNow())
	push(player, state)
	return true
end

-- Debug: spawn a signal at a given position, ignoring the cap.
function SignalService.SpawnAt(player: Player, position: Vector3): Signal?
	local state = states[player]
	if not state then
		return nil
	end
	local signal = addSignal(state, position)
	updateRegen(state, workspace:GetServerTimeNow())
	push(player, state)
	return signal
end

-- Debug: refill to the maximum immediately, near the player.
function SignalService.FillToMax(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local anchor = anchorOf(player)
	while countOf(state) < Config.Signals.MaxCount do
		local position = pickPosition(state, anchor)
		if not position then
			break
		end
		addSignal(state, position)
	end
	updateRegen(state, workspace:GetServerTimeNow())
	push(player, state)
end

-- Debug: move every signal near the player now.
function SignalService.Relocate(player: Player)
	local state = states[player]
	if state then
		relocate(player, state)
	end
end

return SignalService
