-- Client side of Discover -> Hunt -> Capture. Sends intents only (Begin, Cancel, Complete);
-- the server decides everything. Keyboard: F Spirit Sight, Q pulse, hold E to bind.
-- Gamepad: Y Spirit Sight, R1 pulse, hold X to bind. Touch/mouse: on-screen buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CaptureFamilies = require(ReplicatedStorage.Shared.CaptureFamilies)
local Config = require(ReplicatedStorage.Shared.Config)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local RevealController = require(script.Parent.Parent.Controllers.RevealController)
local BindEffects = require(script.Parent.Parent.Effects.BindEffects)
local CaptureAnimation = require(script.Parent.Parent.Effects.CaptureAnimation)
local SealBurst = require(script.Parent.Parent.Effects.SealBurst)
local SpiritSight = require(script.Parent.Parent.Effects.SpiritSight)
local HuntHUD = require(script.Parent.Parent.UI.HuntHUD)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SignalsUpdated = Remotes:WaitForChild("SignalsUpdated") :: RemoteEvent
local BeginBind = Remotes:WaitForChild("BeginBind") :: RemoteEvent
local CancelBind = Remotes:WaitForChild("CancelBind") :: RemoteEvent
local CompleteBind = Remotes:WaitForChild("CompleteBind") :: RemoteEvent
local BindResult = Remotes:WaitForChild("BindResult") :: RemoteEvent

local HuntController = {}

type Options = {
	SetManagementVisible: (visible: boolean) -> (),
	-- While sealing (holding to bind) only the bind bar and hint stay on screen.
	SetSealing: (sealing: boolean) -> (),
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
-- True from the first Complete until the result: rare-find overlays wait for the capture.
local holdingReveals = false
local captureToken = 0
-- Seconds the camera keeps watching the jar seal after a capture.
local SEAL_VIEW_SECONDS = SealBurst.RevealAt + 0.8
local sealViewUntil = 0
local sealViewToken = 0
local hud: HuntHUD.Hud
local options: Options

local AREA_NAMES: { [string]: string } = {}
for _, area in Config.Areas do
	AREA_NAMES[area.Id] = area.Name
end

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
	options.SetSealing(false)
end

-- After a capture: movement stays locked and the UI hidden while the camera watches the seal.
local function holdSealView()
	sealViewToken += 1
	local token = sealViewToken
	sealViewUntil = os.clock() + SEAL_VIEW_SECONDS
	lockMovement()
	options.SetSealing(true)
	task.delay(SEAL_VIEW_SECONDS, function()
		if token ~= sealViewToken or state ~= "Idle" then
			return
		end
		unlockMovement()
		options.SetSealing(false)
	end)
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
	if not SpiritSight.IsEnabled() or state ~= "Idle" or os.clock() < sealViewUntil then
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
	options.SetSealing(true)
	BeginBind:FireServer(id)
end

local function releaseHold()
	if state == "Idle" then
		return
	end
	if activeId then
		CancelBind:FireServer(activeId)
	end
	if state == "Binding" then
		Sounds.Play("Cancel")
	end
	resetBind()
	hud.ShowHint("Bind released.", 1.5)
end

local function setSight(on: boolean)
	-- Spirit Sight can't be left mid-seal (or while the seal plays); letting go comes first.
	if state ~= "Idle" or os.clock() < sealViewUntil then
		return
	end
	SpiritSight.SetEnabled(on)
	hud.SetSightMode(on)
	options.SetManagementVisible(not on)
	if on then
		hud.ShowHint("Pulse to sense your signals. Get close, then hold to bind.", 4)
	end
end

-- Spirit Sight skill rank shortens the pulse cooldown (GDD 6.6).
local function pulseCooldown(): number
	local rank = player:GetAttribute("Skill_SpiritSight")
	return SkillConfig.pulseCooldown(if type(rank) == "number" then rank else 0)
end

local function pulse()
	if not SpiritSight.IsEnabled() or state ~= "Idle" then
		return
	end
	local rootPart = getRoot()
	if not rootPart or os.clock() - lastPulse < pulseCooldown() then
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
	BindEffects.Start(activeId :: number)
	hud.ShowHint("Keep holding...")
end

local function stopHoldingReveals()
	if holdingReveals then
		holdingReveals = false
		RevealController.Release()
	end
end

-- The jar seal, the family animation rising out of it, then the summary card; overlays for rare
-- finds wait until the card closes (tap or timeout).
local function presentCapture(result: { [string]: any }, position: Vector3?)
	local relicId = result.CapturedId
	local relic = type(relicId) == "string" and RelicConfig.ById[relicId]
	local rootPart = getRoot()
	if not relic or not rootPart then
		stopHoldingReveals()
		return
	end
	holdingReveals = false
	captureToken += 1
	local token = captureToken
	local function release()
		if captureToken == token then
			RevealController.Release()
		end
	end
	local mutation = if type(result.CapturedMutation) == "string" then result.CapturedMutation else nil
	local family = CaptureFamilies.forObjectType(relic.ObjectType)
	local lead = if position then SealBurst.RevealAt + CaptureFamilies.totalSeconds(family) else 0
	RevealController.Hold(lead + Config.Hunt.SummarySeconds + 1)
	if position then
		local low = Settings.LowEffects()
		SealBurst.Play(position, relic.Id, { Low = low, Personal = true })
		task.delay(SealBurst.RevealAt, function()
			if rootPart.Parent then
				CaptureAnimation.Play(relic.Id, mutation, position, rootPart, { Low = low, Sound = true })
			end
		end)
	end
	local summary = result.Summary
	task.delay(lead, function()
		if type(summary) == "table" and type(summary.CapturedId) == "string" then
			hud.ShowSummary(summary, release)
		else
			release()
		end
	end)
end

local function onBindResult(result: { [string]: any })
	if type(result) ~= "table" then
		return
	end
	if result.Ok then
		local position = bindPosition
		local capturedId = activeId
		-- The bind camera stays to watch the jar seal until the relic rises out of it; the player
		-- stays put and the UI hidden until then.
		BindEffects.Stop(SEAL_VIEW_SECONDS)
		resetBind()
		holdSealView()
		-- The jar swallows this spirit now; the server's signal update follows.
		if capturedId then
			signals[capturedId] = nil
			SpiritSight.Remove(capturedId)
		end
		hud.ShowHint("")
		presentCapture(result, position)
		return
	end
	-- TooEarly: keep holding, Complete is re-sent. Idle: a late reply to a bind that already ended.
	if result.Reason == "TooEarly" then
		return
	end
	stopHoldingReveals()
	if state == "Idle" then
		return
	end
	if state == "Binding" then
		Sounds.Play("Cancel")
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
	local area = AREA_NAMES[player:GetAttribute("SignalArea") :: string] or "?"
	hud.SetSignalInfo(`{area}: signals {count}/{max}  |  {regen}`)
	hud.SetPulseCooldown(pulseCooldown() - (os.clock() - lastPulse))
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
			if not holdingReveals then
				holdingReveals = true
				RevealController.Hold(3)
			end
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
