-- Client view of the saved presentation settings (ClientSettings). Values come from the
-- "Setting_<Key>" attributes the server mirrors; Set applies locally right away and asks the
-- server to save it (the server validates and echoes the same value back). Sends are delayed
-- until a value stops changing, so dragging a slider sends one request, not dozens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientSettings = require(ReplicatedStorage.Shared.ClientSettings)

local SetClientSetting = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetClientSetting") :: RemoteEvent

local Settings = {}

local player = Players.LocalPlayer
local SEND_DELAY = 0.35
local pendingSend: { [string]: number } = {}

function Settings.Get(key: string): ClientSettings.Value
	local value = player:GetAttribute(`Setting_{key}`)
	local clean = ClientSettings.sanitize(key, value)
	if clean ~= nil then
		return clean
	end
	local setting = ClientSettings.ByKey[key]
	return if setting then setting.Default else ""
end

function Settings.Set(key: string, value: ClientSettings.Value)
	local clean = ClientSettings.sanitize(key, value)
	if clean == nil or clean == Settings.Get(key) then
		return
	end
	player:SetAttribute(`Setting_{key}`, clean)
	local ticket = (pendingSend[key] or 0) + 1
	pendingSend[key] = ticket
	task.delay(SEND_DELAY, function()
		if pendingSend[key] == ticket then
			SetClientSetting:FireServer(key, Settings.Get(key))
		end
	end)
end

-- Runs now and on every change.
function Settings.Watch(key: string, callback: (ClientSettings.Value) -> ())
	player:GetAttributeChangedSignal(`Setting_{key}`):Connect(function()
		callback(Settings.Get(key))
	end)
	callback(Settings.Get(key))
end

function Settings.LowEffects(): boolean
	return Settings.Get("Effects") == "Low"
end

function Settings.Volume(): number
	local value = Settings.Get("Sound")
	return (if type(value) == "number" then value else 100) / 100
end

return Settings
