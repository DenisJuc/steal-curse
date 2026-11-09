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
local Ambience = require(script.Parent.Parent.Effects.Ambience)
local BindEffects = require(script.Parent.Parent.Effects.BindEffects)
local CaptureAnimation = require(script.Parent.Parent.Effects.CaptureAnimation)
local CursedShrines = require(script.Parent.Parent.Effects.CursedShrines)
local HuntFX = require(script.Parent.Parent.Effects.HuntFX)
local SealBurst = require(script.Parent.Parent.Effects.SealBurst)
local SpiritSight = require(script.Parent.Parent.Effects.SpiritSight)
local SpiritTags = require(script.Parent.SpiritTags)
local HudUnlocks = require(script.Parent.Parent.UI.HudUnlocks)
local HuntHUD = require(script.Parent.Parent.UI.HuntHUD)
local HuntRolls = require(script.Parent.Parent.UI.HuntRolls)
local RollReel = require(script.Parent.Parent.UI.RollReel)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SignalsUpdated = Remotes:WaitForChild("SignalsUpdated") :: RemoteEvent
local BeginBind = Remotes:WaitForChild("BeginBind") :: RemoteEvent
local CancelBind = Remotes:WaitForChild("CancelBind") :: RemoteEvent
local CompleteBind = Remotes:WaitForChild("CompleteBind") :: RemoteEvent
local BindResult = Remotes:WaitForChild("BindResult") :: RemoteEvent
local SpiritPulse = Remotes:WaitForChild("SpiritPulse") :: RemoteEvent

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

-- Skittish spirits (Config.Skittish): what the hint says when one bolts. The first of each kind in a
-- session explains the rule; later ones just call it out.
local BOLT_TEXT = {
	Spook = { First = "It saw you coming! Pulse before you get close and it won't run.", Again = "It bolted! Pulse, then sneak up." },
	Chase = { First = "A Vengeful spirit always runs once. After it!", Again = "It's running! After it!" },
}
local boltExplained: { [string]: boolean } = {}

local player = Players.LocalPlayer
local signals: { [number]: Vector3 } = {}
-- Signal id -> spirit type (Config.Spirits), for the orb tags.
local spiritTypes: { [number]: string } = {}
-- Signal id -> exact total rolls its capture gives now (server preview), and struck-until times.
local spiritRolls: { [number]: number } = {}
local struckUntil: { [number]: number } = {}
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
-- Longest the hunt papers may keep rare-find reveals waiting (they release them when done).
local HUNT_ROLLS_HOLD = 60
-- A struck capture has no jar to watch: the Lightning Luck card follows the flash.
local LIGHTNING_LEAD = 0.9
local LIGHTNING_COLOR = Color3.fromRGB(255, 228, 120)
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
local function holdSealView(seconds: number)
	sealViewToken += 1
	local token = sealViewToken
	sealViewUntil = os.clock() + seconds
	lockMovement()
	options.SetSealing(true)
	task.delay(seconds, function()
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
	if CursedShrines.PromptShown() then
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
	-- Still locked by the roll-only start (F works even while its button is hidden): explain instead.
	if on and (not HudUnlocks.IsReady() or not HudUnlocks.IsUnlocked("Hunt")) then
		if HudUnlocks.IsReady() then
			HudUnlocks.Explain("Hunt")
		end
		return
	end
	SpiritSight.SetEnabled(on)
	hud.SetSightMode(on)
	options.SetManagementVisible(not on)
	-- The spirit hunt tutorial says the same thing in its own bubble.
	if on and player:GetAttribute("HuntTutorial") ~= true then
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
	-- The server counts a pulse as a careful approach for skittish spirits.
	SpiritPulse:FireServer()
end

-- os.clock() of the last pulse (0 if none yet), for the spirit hunt tutorial.
function HuntController.LastPulse(): number
	return lastPulse
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

-- The jar seal, the family animation rising out of it, then the hunt's finds roll on papers
-- (HuntRolls); reveals for new finds wait until the papers are done (or skipped).
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
	RevealController.Hold(lead + HUNT_ROLLS_HOLD)
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
		local results = RollReel.TakeHunt(1.5)
		if not results then
			release()
			return
		end
		HuntRolls.Play(results, if type(summary) == "table" then summary else nil, function()
			RollReel.FinishHunt(results)
			release()
		end)
	end)
end

-- A lightning-struck capture rolls nothing: a crack of lightning on the jar, then the Lightning
-- Luck card.
local function presentLightning(result: { [string]: any }, position: Vector3?)
	holdingReveals = false
	captureToken += 1
	local token = captureToken
	local function release()
		if captureToken == token then
			RevealController.Release()
		end
	end
	local factor = if type(result.LuckFactor) == "number" then result.LuckFactor else 1
	local untilTime = if type(result.LuckUntil) == "number" then result.LuckUntil else 0
	local lead = if position then LIGHTNING_LEAD else 0
	RevealController.Hold(lead + Config.Hunt.SummarySeconds + 1)
	if position then
		local low = Settings.LowEffects()
		Ambience.Lightning(15)
		HuntFX.burst(position, LIGHTNING_COLOR, if low then 14 else 50, 18)
		HuntFX.shockwave(position, LIGHTNING_COLOR, 22, 0.7)
		HuntFX.shake(0.5, 0.45)
		Sounds.Play("Shine", nil, 1.15)
	end
	task.delay(lead, function()
		hud.ShowLightning(factor, math.max(0, untilTime - workspace:GetServerTimeNow()), release)
	end)
end

local function onBindResult(result: { [string]: any })
	if type(result) ~= "table" then
		return
	end
	if result.Ok and result.Struck then
		local position = bindPosition
		local capturedId = activeId
		BindEffects.Stop(LIGHTNING_LEAD)
		resetBind()
		holdSealView(LIGHTNING_LEAD)
		if capturedId then
			signals[capturedId] = nil
			SpiritSight.Remove(capturedId)
		end
		hud.ShowHint("")
		presentLightning(result, position)
		return
	end
	if result.Ok then
		local position = bindPosition
		local capturedId = activeId
		-- The bind camera stays to watch the jar seal until the relic rises out of it; the player
		-- stays put and the UI hidden until then.
		BindEffects.Stop(SEAL_VIEW_SECONDS)
		resetBind()
		holdSealView(SEAL_VIEW_SECONDS)
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
	-- Fled: the bolt's own hint (from the signal update just before) already says what happened.
	if result.Reason ~= "Released" and result.Reason ~= "Fled" then
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
	SpiritTags.Update(spiritTypes, spiritRolls, struckUntil)

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
		table.clear(spiritTypes)
		table.clear(spiritRolls)
		table.clear(struckUntil)
		local bolts: { { Id: number, From: Vector3, Kind: string } } = {}
		for _, signal in list do
			if type(signal) == "table" and type(signal.Id) == "number" and typeof(signal.Position) == "Vector3" then
				signals[signal.Id] = signal.Position
				if type(signal.Type) == "string" then
					spiritTypes[signal.Id] = signal.Type
				end
				if type(signal.Rolls) == "number" then
					spiritRolls[signal.Id] = signal.Rolls
				end
				if type(signal.StruckUntil) == "number" then
					struckUntil[signal.Id] = signal.StruckUntil
				end
				if typeof(signal.BoltFrom) == "Vector3" and type(signal.Bolt) == "string" then
					table.insert(bolts, { Id = signal.Id, From = signal.BoltFrom, Kind = signal.Bolt })
				end
			end
		end
		SpiritSight.SetSignals(signals)
		SpiritTags.Sync(spiritTypes, spiritRolls, struckUntil)
		local hinted = false
		for _, boltInfo in bolts do
			SpiritSight.Bolt(boltInfo.Id, boltInfo.From)
			-- One hint per update: two spirits bolting together must not cover the first explanation.
			local text = BOLT_TEXT[boltInfo.Kind]
			if text and not hinted and SpiritSight.IsEnabled() then
				hinted = true
				hud.ShowHint(if boltExplained[boltInfo.Kind] then text.Again else text.First, 3.5)
				boltExplained[boltInfo.Kind] = true
			end
		end
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

function HuntController.GetSignalPosition(id: number): Vector3?
	return signals[id]
end

-- Nearest signal by world distance (no bind LockRange). Used by Shrine Charm pulse.
function HuntController.GetNearestSignalAny(): (number?, Vector3?)
	local rootPart = getRoot()
	if not rootPart then
		return nil, nil
	end
	local bestId: number? = nil
	local bestPos: Vector3? = nil
	local bestDistance = math.huge
	for id, position in signals do
		local distance = (position - rootPart.Position).Magnitude
		if distance < bestDistance then
			bestId = id
			bestPos = position
			bestDistance = distance
		end
	end
	return bestId, bestPos
end

function HuntController.GetNearestSignalId(): number?
	return nearestInRange()
end

return HuntController
