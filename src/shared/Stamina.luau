-- Sprint stamina math (pure, Lune-tested). Stamina runs 0..1: it drains while you sprint and
-- move, refills after a short rest, and once it hits empty you are winded until it is back up to
-- ResumeAt (so tapping Shift on an empty bar does nothing).

local Stamina = {}

export type Options = {
	StaminaSeconds: number,
	RefillSeconds: number,
	RefillDelay: number,
	ResumeAt: number,
}

export type State = {
	Value: number,
	Running: boolean,
	Winded: boolean,
	-- Seconds since the last sprinting step (refill waits for RefillDelay).
	Rest: number,
}

function Stamina.new(): State
	return { Value = 1, Running = false, Winded = false, Rest = math.huge }
end

-- Advances `state` by dt and returns it. `wants`: the sprint input is held; `moving`: the
-- character is actually walking (standing still never drains).
function Stamina.step(state: State, dt: number, wants: boolean, moving: boolean, options: Options): State
	if state.Winded and state.Value >= options.ResumeAt then
		state.Winded = false
	end
	state.Running = wants and moving and not state.Winded and state.Value > 0
	if state.Running then
		state.Rest = 0
		state.Value = math.max(0, state.Value - dt / options.StaminaSeconds)
		if state.Value <= 0 then
			state.Winded = true
			state.Running = false
		end
	else
		state.Rest += dt
		if state.Rest >= options.RefillDelay then
			state.Value = math.min(1, state.Value + dt / options.RefillSeconds)
		end
	end
	return state
end

-- Walk speed for a base speed while running or not.
function Stamina.speed(base: number, running: boolean, multiplier: number, maxSpeed: number): number
	if not running then
		return base
	end
	return math.max(base, math.min(base * multiplier, maxSpeed))
end

return Stamina
