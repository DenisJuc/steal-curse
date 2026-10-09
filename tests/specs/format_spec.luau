-- Number and odds formatting.

local Format = require("../../src/shared/Format")
local expect = require("../lib/expect")

return {
	{
		Name = "numbers use short suffixes up to quadrillions",
		Run = function()
			expect.equal(Format.number(0), "0")
			expect.equal(Format.number(7), "7")
			expect.equal(Format.number(45), "45")
			expect.equal(Format.number(999), "999")
			expect.equal(Format.number(1500), "1.5K")
			expect.equal(Format.number(25000), "25K")
			expect.equal(Format.number(1e7), "10M")
			expect.equal(Format.number(1e11), "100B")
			expect.equal(Format.number(1.32e15), "1.32Qd")
			expect.equal(Format.number(999999), "1M")
			expect.equal(Format.number(2.2222), "2.22")
		end,
	},
	{
		Name = "odds read as 1 in X",
		Run = function()
			expect.equal(Format.odds(1 / 45), "1 in 45")
			expect.equal(Format.odds(1 / 1.32e15), "1 in 1.32Qd")
			expect.equal(Format.odds(0), "never")
		end,
	},
	{
		Name = "seconds trim trailing zeros",
		Run = function()
			expect.equal(Format.seconds(4), "4s")
			expect.equal(Format.seconds(2.26), "2.3s")
		end,
	},
}
