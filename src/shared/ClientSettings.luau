-- Player presentation settings (GDD 12.1 Settings screen). Saved in the profile, validated by the
-- server, mirrored to "Setting_<Key>" attributes. A setting is either a short list of Options the
-- Settings panel cycles through, or a numeric Range shown as a slider.
-- Pure, so Lune can test it.

local ClientSettings = {}

export type Value = string | number

export type Range = { Min: number, Max: number, Step: number }

export type Setting = {
	Key: string,
	Label: string,
	Help: string,
	Options: { Value }?,
	Range: Range?,
	Default: Value,
}

-- Interface size option -> UI scale multiplier.
ClientSettings.InterfaceScale = {
	Small = 0.85,
	Medium = 1,
	Big = 1.15,
} :: { [string]: number }

ClientSettings.Schema = {
	{
		Key = "Effects",
		Label = "Visual effects",
		Help = "Low turns off particles, flashes and small projections (better on slow phones).",
		Options = { "Full", "Low" },
		Default = "Full",
	},
	{
		Key = "Reveals",
		Label = "Rare reveals",
		Help = "Short plays every reveal quickly. Off keeps only the feed and the Journal.",
		Options = { "Full", "Short", "Off" },
		Default = "Full",
	},
	{
		Key = "RollAnimation",
		Label = "Roll animation",
		Help = "The roll above the bottom bar. Fast rolls briefly; Off shows results right away.",
		Options = { "Full", "Fast", "Off" },
		Default = "Full",
	},
	{
		Key = "RollStyle",
		Label = "Roll style",
		Help = "Omikuji draws a fortune slip and flickers relics on it until one is stamped; Flicker cycles relics on a plate; Flame climbs through rarity colors.",
		Options = { "Omikuji", "Flicker", "Flame" },
		Default = "Omikuji",
	},
	{
		Key = "Camera",
		Label = "Camera effects",
		Help = "Reduced removes camera zoom and shake during big reveals.",
		Options = { "On", "Reduced" },
		Default = "On",
	},
	{
		Key = "Sound",
		Label = "Sound volume",
		Help = "Volume of reveal and menu sounds.",
		Range = { Min = 0, Max = 100, Step = 5 },
		Default = 100,
	},
	{
		Key = "InterfaceSize",
		Label = "Interface size",
		Help = "Makes every menu and button bigger or smaller.",
		Options = { "Small", "Medium", "Big" },
		Default = "Medium",
	},
	{
		Key = "AfkReports",
		Label = "Welcome Back summary",
		Help = "When you rejoin, shows the CE you earned and everything you unlocked while AFK.",
		Options = { "On", "Off" },
		Default = "On",
	},
	{
		Key = "Hints",
		Label = "Beginner hints",
		Help = "Turn on to replay the first-minute tips.",
		Options = { "On", "Off" },
		Default = "On",
	},
} :: { Setting }

ClientSettings.ByKey = {} :: { [string]: Setting }
for _, setting in ClientSettings.Schema do
	ClientSettings.ByKey[setting.Key] = setting
end

function ClientSettings.defaults(): { [string]: Value }
	local result = {}
	for _, setting in ClientSettings.Schema do
		result[setting.Key] = setting.Default
	end
	return result
end

-- The value if it is one of the setting's options (a range value is clamped and snapped to its
-- step), else nil.
function ClientSettings.sanitize(key: any, value: any): Value?
	local setting = type(key) == "string" and ClientSettings.ByKey[key]
	if not setting then
		return nil
	end
	local range = setting.Range
	if range then
		if type(value) ~= "number" or value ~= value then
			return nil
		end
		local snapped = math.floor((value - range.Min) / range.Step + 0.5) * range.Step + range.Min
		return math.clamp(snapped, range.Min, range.Max)
	end
	for _, option in setting.Options or {} do
		if option == value then
			return option
		end
	end
	return nil
end

-- A range setting moved by `steps` steps (used by the slider's -/+ buttons).
function ClientSettings.nudge(key: string, current: any, steps: number): Value?
	local setting = ClientSettings.ByKey[key]
	local range = setting and setting.Range
	if not range then
		return nil
	end
	local base = if type(current) == "number" then current else setting.Default :: number
	return ClientSettings.sanitize(key, base + steps * range.Step)
end

-- A full, valid settings table: valid saved values kept, everything else reset to defaults.
function ClientSettings.sanitizeAll(raw: any): { [string]: Value }
	local result = ClientSettings.defaults()
	if type(raw) ~= "table" then
		return result
	end
	for key in result do
		local value = ClientSettings.sanitize(key, raw[key])
		if value ~= nil then
			result[key] = value
		end
	end
	return result
end

-- The option after `current` (wraps around); the default if `current` is not an option.
function ClientSettings.nextOption(key: string, current: any): Value?
	local setting = ClientSettings.ByKey[key]
	local options = setting and setting.Options
	if not options then
		return nil
	end
	for index, option in options do
		if option == current then
			return options[index % #options + 1]
		end
	end
	return setting.Default
end

function ClientSettings.display(key: string, value: Value): string
	if key == "Sound" then
		return `{value}%`
	end
	return tostring(value)
end

return ClientSettings
