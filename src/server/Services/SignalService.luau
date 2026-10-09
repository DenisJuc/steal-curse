-- Personal hunt signals (GDD 4.2). Each player has their own 3-5 signals, stored only here and sent
-- only to the owner, so nobody else can see, lock or consume them. Signals carry no rarity: the relic
-- is rolled by BindService only at a validated capture.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local SignalsUpdated = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SignalsUpdated") :: RemoteEvent

local SignalService = {}

export type Signal = {
	Id: number,
	Position: Vector3,
}

type State = {
	Signals: { [number]: Signal },
	NextId: number,
	RegenAt: number?,
	Rng: Random,
}

local spawnPoints: { Vector3 } = {}
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
end

local function updateRegen(state: State, now: number)
	if countOf(state) >= Config.Signals.MaxCount then
		state.RegenAt = nil
	elseif not state.RegenAt then
		state.RegenAt = now + Config.Signals.RegenSeconds
	end
end

local function pickPosition(state: State): Vector3?
	local hover = Vector3.new(0, Config.Signals.HoverHeight, 0)
	local spaced, unused = {}, {}
	for _, point in spawnPoints do
		local position = point + hover
		local taken, tooClose = false, false
		for _, signal in state.Signals do
			local distance = (signal.Position - position).Magnitude
			if distance < 0.5 then
				taken = true
			elseif distance < Config.Signals.MinSpacing then
				tooClose = true
			end
		end
		if not taken then
			table.insert(unused, position)
			if not tooClose then
				table.insert(spaced, position)
			end
		end
	end
	local pool = if #spaced > 0 then spaced else unused
	if #pool == 0 then
		return nil
	end
	return pool[state.Rng:NextInteger(1, #pool)]
end

local function addSignal(state: State, position: Vector3): Signal
	local signal = { Id = state.NextId, Position = position }
	state.NextId += 1
	state.Signals[signal.Id] = signal
	return signal
end

function SignalService.Init(points: { Vector3 })
	spawnPoints = points

	DataService.OnPlayerLoaded(function(player)
		if states[player] or not player.Parent then
			return
		end
		local state: State = { Signals = {}, NextId = 1, RegenAt = nil, Rng = Random.new() }
		states[player] = state
		for _ = 1, Config.Signals.StartCount do
			local position = pickPosition(state)
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
			task.wait(0.5)
			local now = workspace:GetServerTimeNow()
			for player, state in states do
				if state.RegenAt and now >= state.RegenAt then
					state.RegenAt = nil
					local position = pickPosition(state)
					if position then
						addSignal(state, position)
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

-- Debug: refill to the maximum immediately.
function SignalService.FillToMax(player: Player)
	local state = states[player]
	if not state then
		return
	end
	while countOf(state) < Config.Signals.MaxCount do
		local position = pickPosition(state)
		if not position then
			break
		end
		addSignal(state, position)
	end
	updateRegen(state, workspace:GetServerTimeNow())
	push(player, state)
end

return SignalService
