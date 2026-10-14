-- Sprint stamina: drains while running, refills after a rest, winded until ResumeAt.

local Config = require("../../src/shared/Config")
local Stamina = require("../../src/shared/Stamina")
local expect = require("../lib/expect")

local options = Config.Sprint

local function run(state: Stamina.State, seconds: number, wants: boolean, moving: boolean)
	local dt = 1 / 60
	for _ = 1, math.floor(seconds / dt + 0.5) do
		Stamina.step(state, dt, wants, moving, options)
	end
end

return {
	{
		Name = "a full bar lasts StaminaSeconds of running",
		Run = function()
			local state = Stamina.new()
			run(state, options.StaminaSeconds * 0.5, true, true)
			expect.truthy(state.Running, "still running halfway")
			expect.near(state.Value, 0.5, 0.02, "half the bar is gone")
			run(state, options.StaminaSeconds * 0.5 + 0.1, true, true)
			expect.equal(state.Value, 0, "empty")
			expect.equal(state.Running, false, "stops when empty")
			expect.equal(state.Winded, true, "winded")
		end,
	},
	{
		Name = "standing still or not holding sprint never drains",
		Run = function()
			local state = Stamina.new()
			run(state, 2, true, false)
			expect.equal(state.Value, 1, "standing still")
			expect.equal(state.Running, false, "not running in place")
			run(state, 2, false, true)
			expect.equal(state.Value, 1, "walking")
		end,
	},
	{
		Name = "refill waits for the delay, then fills in RefillSeconds",
		Run = function()
			local state = Stamina.new()
			run(state, options.StaminaSeconds * 0.5, true, true)
			local value = state.Value
			run(state, options.RefillDelay * 0.8, false, true)
			expect.near(state.Value, value, 1e-9, "no refill during the delay")
			run(state, options.RefillDelay * 0.2 + options.RefillSeconds, false, true)
			expect.equal(state.Value, 1, "full again")
		end,
	},
	{
		Name = "winded: no sprint until the bar is back to ResumeAt",
		Run = function()
			local state = Stamina.new()
			run(state, options.StaminaSeconds + 0.05, true, true)
			expect.equal(state.Winded, true, "winded")
			run(state, options.RefillDelay + options.RefillSeconds * options.ResumeAt * 0.5, true, true)
			expect.truthy(state.Value < options.ResumeAt, "bar still low")
			expect.equal(state.Running, false, "still winded")
			run(state, options.RefillDelay + options.RefillSeconds * options.ResumeAt, false, true)
			Stamina.step(state, 1 / 60, true, true, options)
			expect.equal(state.Running, true, "running again")
		end,
	},
	{
		Name = "sprint speed multiplies the walk speed, capped, never slower",
		Run = function()
			expect.equal(Stamina.speed(16, false, options.Multiplier, options.MaxSpeed), 16, "walking")
			expect.near(Stamina.speed(16, true, options.Multiplier, options.MaxSpeed), 16 * options.Multiplier, 1e-9, "running")
			expect.equal(Stamina.speed(56, true, options.Multiplier, options.MaxSpeed), options.MaxSpeed, "capped")
			expect.equal(Stamina.speed(80, true, options.Multiplier, options.MaxSpeed), 80, "never slower than walking")
		end,
	},
}
