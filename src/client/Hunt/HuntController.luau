-- Client side of Discover -> Hunt -> Capture. Sends intents only (Begin, Cancel, Complete);
-- the server decides everything. Keyboard: F Spirit Sight, Q pulse, hold E to bind.
-- Gamepad: Y Spirit Sight, R1 pulse, hold X to bind. Touch/mouse: on-screen buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local BindEffects = require(script.Parent.Parent.Effects.BindEffects)
local SpiritSight = require(script.Parent.Parent.Effects.SpiritSight)
local HuntHUD = require(script.Parent.Parent.UI.HuntHUD)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SignalsUpdated = Remotes:WaitForChild("SignalsUpdated") :: RemoteEvent
local BeginBind = Remotes:WaitForChild("BeginBind") :: RemoteEvent
local CancelBind = Remotes:WaitForChild("CancelBind") :: RemoteEvent
local CompleteBind = Remotes:WaitForChild("CompleteBind") :: RemoteEvent
local BindResult = Remotes:WaitForChild("BindResult") :: RemoteEvent

local HuntController = {}

type Options = {
	SetManagementVisible: (visible: boolean) -> (),
}

local REASON_TEXT = {
	TooFar = "The signal slipped away - stay close.",
	Released = "Bind released.",
	Interrupted = "The bind was interrupted.",
	Timeout = "The bind faded.",
	Cooldown = "Steady yourself...",
	NoSignal = "That signal is gone.",
	Busy = "You are already binding.",
	NotReady = "You can't bind right now.",
	NotBinding = "No bind in progress.",
}

local player = Players.LocalPlayer
local signals: { [number]: Vector3 } = {}
local state = "Idle" -- Idle | Pending | Binding
local activeId: number? = nil
-- Remembered at bind start: the server removes the signal (and its orb) before the result arrives.
local bindPosition: Vector3? = nil
local pendingSince = 0
local lastCompleteSent = 0
local lastPulse = -math.huge
local savedMovement: { WalkSpeed: number, JumpPower: number, JumpHeight: number, AutoRotate: boolean }? = nil
local hud: HuntHUD.Hud
local options: Options

local function getRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function lockMovement()
	local humanoid = getHumanoid()
	if not humanoid or savedMovement then
		return
	end
	savedMovement = {
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
	}
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
end

local function unlockMovement()
	local saved = savedMovement
	savedMovement = nil
	local humanoid = getHumanoid()
	if not saved or not humanoid then
		return
	end
	humanoid.WalkSpeed = saved.WalkSpeed
	humanoid.JumpPower = saved.JumpPower
	humanoid.JumpHeight = saved.JumpHeight
	humanoid.AutoRotate = saved.AutoRotate
end

local function resetBind()
	state = "Idle"
	activeId = nil
	bindPosition = nil
	BindEffects.Stop()
	unlockMovement()
	hud.SetProgress(nil)
end

local function nearestInRange(): number?
	local rootPart = getRoot()
	if not rootPart then
		return nil
	end
	local bestId, bestDistance = nil, Config.Bind.LockRange
	for id, position in signals do
		local distance = (position - rootPart.Position).Magnitude
		if distance <= bestDistance then
			bestId, bestDistance = id, distance
		end
	end
	return bestId
end

local function startHold()
	if not SpiritSight.IsEnabled() or state ~= "Idle" then
		return
	end
	local id = nearestInRange()
	if not id then
		hud.ShowHint("Get closer to a signal first.", 2)
		return
	end
	state = "Pending"
	activeId = id
	pendingSince = os.clock()
	BeginBind:FireServer(id)
end

local function releaseHold()
	if state == "Idle" then
		return
	end
	if activeId then
		CancelBind:FireServer(activeId)
	end
	resetBind()
	hud.ShowHint("Bind released.", 1.5)
end

local function setSight(on: boolean)
	if not on and state ~= "Idle" then
		releaseHold()
	end
	SpiritSight.SetEnabled(on)
	hud.SetSightMode(on)
	options.SetManagementVisible(not on)
	if on then
		hud.ShowHint("Pulse to sense your signals. Get close, then hold to bind.", 4)
	end
end

local function pulse()
	if not SpiritSight.IsEnabled() then
		return
	end
	local rootPart = getRoot()
	if not rootPart or os.clock() - lastPulse < Config.SpiritSight.PulseCooldownSeconds then
		return
	end
	lastPulse = os.clock()
	SpiritSight.Pulse(rootPart)
end

local function onBindConfirmed()
	if state ~= "Pending" or player:GetAttribute("BindSignalId") ~= activeId then
		return
	end
	local orb = activeId and SpiritSight.GetOrb(activeId)
	if not orb then
		releaseHold()
		return
	end
	state = "Binding"
	bindPosition = orb.Position
	lockMovement()
	BindEffects.Start(orb)
	hud.ShowHint("Keep holding...")
end

local function onBindResult(result: { [string]: any })
	if type(result) ~= "table" then
		return
	end
	if result.Ok then
		if bindPosition then
			BindEffects.Seal(bindPosition)
		end
		resetBind()
		hud.ShowHint("")
		if type(result.CapturedId) == "string" then
			hud.ShowCapture(result.CapturedId, tonumber(result.BonusCount) or 0, result.BestBonusId)
		end
		return
	end
	-- TooEarly: keep holding, Complete is re-sent. Idle: a late reply to a bind that already ended.
	if result.Reason == "TooEarly" or state == "Idle" then
		return
	end
	resetBind()
	if result.Reason ~= "Released" then
		hud.ShowHint(REASON_TEXT[result.Reason] or "Bind failed.", 2)
	end
end

local function formatCountdown(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function step(dt: number)
	local rootPart = getRoot()
	SpiritSight.Update(dt, if rootPart then rootPart.Position else nil)

	local count = player:GetAttribute("SignalCount") or 0
	local max = player:GetAttribute("SignalMax") or Config.Signals.MaxCount
	local nextAt = player:GetAttribute("NextSignalAt")
	local regen = if type(nextAt) == "number"
		then `next in {formatCountdown(nextAt - workspace:GetServerTimeNow())}`
		else "full"
	hud.SetSignalInfo(`Signals {count}/{max}  |  {regen}`)
	hud.SetPulseCooldown(Config.SpiritSight.PulseCooldownSeconds - (os.clock() - lastPulse))
	hud.SetBindAvailable(state ~= "Idle" or nearestInRange() ~= nil)

	if state == "Pending" and os.clock() - pendingSince > 2 then
		if activeId then
			CancelBind:FireServer(activeId)
		end
		resetBind()
	elseif state == "Binding" and activeId then
		local startedAt = player:GetAttribute("BindStartedAt")
		local hold = player:GetAttribute("BindHoldSeconds")
		if type(startedAt) ~= "number" or type(hold) ~= "number" then
			return
		end
		local progress = (workspace:GetServerTimeNow() - startedAt) / hold
		hud.SetProgress(progress)
		BindEffects.Update(dt, math.clamp(progress, 0, 1))
		-- Ask the server to finish once the hold is done; it re-checks the time itself.
		if progress >= 1 and os.clock() - lastCompleteSent > 0.2 then
			lastCompleteSent = os.clock()
			CompleteBind:FireServer(activeId)
		end
	end
end

local KEY_SIGHT = { [Enum.KeyCode.F] = true, [Enum.KeyCode.ButtonY] = true }
local KEY_PULSE = { [Enum.KeyCode.Q] = true, [Enum.KeyCode.ButtonR1] = true }
local KEY_BIND = { [Enum.KeyCode.E] = true, [Enum.KeyCode.ButtonX] = true }

function HuntController.Start(screen: ScreenGui, startOptions: Options)
	options = startOptions
	hud = HuntHUD.Start(screen, {
		OnToggleSight = function()
			setSight(not SpiritSight.IsEnabled())
		end,
		OnPulse = pulse,
		OnHoldStart = startHold,
		OnHoldEnd = releaseHold,
	})

	SignalsUpdated.OnClientEvent:Connect(function(list)
		if type(list) ~= "table" then
			return
		end
		table.clear(signals)
		for _, signal in list do
			if type(signal) == "table" and type(signal.Id) == "number" and typeof(signal.Position) == "Vector3" then
				signals[signal.Id] = signal.Position
			end
		end
		SpiritSight.SetSignals(signals)
	end)
	BindResult.OnClientEvent:Connect(onBindResult)
	player:GetAttributeChangedSignal("BindSignalId"):Connect(onBindConfirmed)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if KEY_SIGHT[input.KeyCode] then
			setSight(not SpiritSight.IsEnabled())
		elseif KEY_PULSE[input.KeyCode] then
			pulse()
		elseif KEY_BIND[input.KeyCode] then
			startHold()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if KEY_BIND[input.KeyCode] then
			releaseHold()
		end
	end)

	player.CharacterAdded:Connect(function()
		savedMovement = nil
		if state ~= "Idle" then
			resetBind()
		end
	end)

	RunService.RenderStepped:Connect(step)
end

function HuntController.GetSignalIds(): { number }
	local ids = {}
	for id in signals do
		table.insert(ids, id)
	end
	return ids
end

function HuntController.GetNearestSignalId(): number?
	return nearestInRange()
end

return HuntController
