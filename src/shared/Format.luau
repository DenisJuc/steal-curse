-- Number and odds formatting shared by UI and tests (handles values up to quadrillions and beyond).

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc" }

local function trimZeros(text: string): string
	if string.find(text, ".", 1, true) then
		text = (string.gsub(text, "0+$", ""))
		text = (string.gsub(text, "%.$", ""))
	end
	return text
end

local function shortDecimal(value: number): string
	if value < 10 then
		return trimZeros(string.format("%.2f", value))
	elseif value < 100 then
		return trimZeros(string.format("%.1f", value))
	end
	return string.format("%.0f", value)
end

function Format.number(value: number): string
	if value ~= value then
		return "0"
	end
	if value < 0 then
		return "-" .. Format.number(-value)
	end
	local suffixIndex = 1
	while value >= 1000 and suffixIndex < #SUFFIXES do
		value /= 1000
		suffixIndex += 1
	end
	local text = shortDecimal(value)
	if text == "1000" and suffixIndex < #SUFFIXES then
		text = "1"
		suffixIndex += 1
	end
	return text .. SUFFIXES[suffixIndex]
end

function Format.odds(probability: number): string
	if probability <= 0 then
		return "never"
	end
	return "1 in " .. Format.number(1 / probability)
end

function Format.seconds(seconds: number): string
	return trimZeros(string.format("%.1f", seconds)) .. "s"
end

return Format
