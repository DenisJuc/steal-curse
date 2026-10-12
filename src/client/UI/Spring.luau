-- Spring animation for UI properties (numbers, UDim2, Vector2, Color3). Unlike a tween, a spring
-- keeps its speed when the target changes mid-flight and can overshoot, which is what makes
-- presses, pops and bounces feel physical. One RenderStepped loop drives every active spring and
-- stops itself when everything has settled.
--   Frequency: oscillations per second (higher = snappier).
--   Damping:   1 = no overshoot, below 1 = bouncy (0.3 wobbles, 0.6 settles with one small bump).

local RunService = game:GetService("RunService")

local Spring = {}

local MAX_STEP = 1 / 240
local SETTLE = 1e-3

type State = {
	Kind: string,
	Value: { number },
	Velocity: { number },
	Target: { number },
	Frequency: number,
	Damping: number,
}

local active: { [Instance]: { [string]: State } } = {}
local connection: RBXScriptConnection? = nil

local function pack(value: any): (string, { number })
	local kind = typeof(value)
	if kind == "number" then
		return kind, { value }
	elseif kind == "UDim2" then
		return kind, { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	elseif kind == "Vector2" then
		return kind, { value.X, value.Y }
	elseif kind == "Color3" then
		return kind, { value.R, value.G, value.B }
	end
	error(`Spring cannot animate a {kind}`)
end

local function unpackValue(kind: string, values: { number }): any
	if kind == "number" then
		return values[1]
	elseif kind == "UDim2" then
		return UDim2.new(values[1], values[2], values[3], values[4])
	elseif kind == "Vector2" then
		return Vector2.new(values[1], values[2])
	end
	return Color3.new(math.clamp(values[1], 0, 1), math.clamp(values[2], 0, 1), math.clamp(values[3], 0, 1))
end

local function step(dt: number)
	for instance, states in active do
		if not instance.Parent then
			active[instance] = nil
			continue
		end
		for property, state in states do
			local remaining = dt
			while remaining > 0 do
				local h = math.min(remaining, MAX_STEP)
				remaining -= h
				local omega = 2 * math.pi * state.Frequency
				for index, value in state.Value do
					local velocity = state.Velocity[index]
					local accel = omega * omega * (state.Target[index] - value) - 2 * state.Damping * omega * velocity
					velocity += accel * h
					state.Velocity[index] = velocity
					state.Value[index] = value + velocity * h
				end
			end
			local settled = true
			for index, value in state.Value do
				local scale = math.max(1, math.abs(state.Target[index]))
				if
					math.abs(state.Target[index] - value) > SETTLE * scale
					or math.abs(state.Velocity[index]) > SETTLE * scale
				then
					settled = false
					break
				end
			end
			if settled then
				(instance :: any)[property] = unpackValue(state.Kind, state.Target)
				states[property] = nil
			else
				(instance :: any)[property] = unpackValue(state.Kind, state.Value)
			end
		end
		if next(states) == nil then
			active[instance] = nil
		end
	end
	if next(active) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function ensureRunning()
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

local function stateFor(instance: Instance, property: string, frequency: number, damping: number): State
	local states = active[instance]
	if not states then
		states = {}
		active[instance] = states
	end
	local state = states[property]
	if not state then
		local kind, values = pack((instance :: any)[property])
		local velocity = table.create(#values, 0)
		state = {
			Kind = kind,
			Value = values,
			Velocity = velocity,
			Target = table.clone(values),
			Frequency = frequency,
			Damping = damping,
		}
		states[property] = state
	end
	state.Frequency = frequency
	state.Damping = damping
	return state
end

-- Springs each property toward its goal, keeping any speed it already has.
function Spring.target(instance: Instance, frequency: number, damping: number, goals: { [string]: any })
	for property, goal in goals do
		local state = stateFor(instance, property, frequency, damping)
		local _, values = pack(goal)
		state.Target = values
	end
	ensureRunning()
end

-- Kicks properties with extra speed (per second); the spring pulls them back to their target.
function Spring.impulse(instance: Instance, frequency: number, damping: number, velocities: { [string]: any })
	for property, velocity in velocities do
		local state = stateFor(instance, property, frequency, damping)
		local _, values = pack(velocity)
		for index, value in values do
			state.Velocity[index] += value
		end
	end
	ensureRunning()
end

-- Stops animating (the property keeps its current value). Without `property`, stops all of them.
function Spring.stop(instance: Instance, property: string?)
	local states = active[instance]
	if not states then
		return
	end
	if property then
		states[property] = nil
	else
		active[instance] = nil
	end
end

return Spring
