-- Tiny assertion helpers for Lune tests.

local expect = {}

function expect.truthy(value: any, message: string)
	if not value then
		error(message, 2)
	end
end

function expect.equal(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(`{message or "values differ"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function expect.near(actual: number, expected: number, tolerance: number, message: string?)
	if math.abs(actual - expected) > tolerance then
		error(`{message or "not close enough"}: expected {expected} +/- {tolerance}, got {actual}`, 2)
	end
end

return expect
