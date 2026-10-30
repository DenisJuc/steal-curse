--!strict
--[[
	Studio plugin: dump ServerStorage.PlaytestExport (or ReplicatedStorage.PlaytestExportClient)
	to docs/playtest via the local receiver.

	Install:
	1. In Studio: Plugins → Plugins Folder
	2. Create a folder PlaytestExport.plugin, put this file as init.server.luau
	   (or paste into a Script under a .rbxm plugin).
	3. Run: python tools/playtest_export_server.py
	4. Click the toolbar button "Export Playtest"

	Preferred path during playtest: use the in-game Stop & Export HUD (auto-posts).
	This plugin is a fallback when HttpService from the play session failed.
]]

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Toolbar = plugin:CreateToolbar("Playtest Analytics")
local Button = Toolbar:CreateButton("Export Playtest", "POST latest PlaytestExport to localhost:19283", "")

local EXPORT_URL = "http://127.0.0.1:19283/export"

local function collectFrom(folder: Instance): ({ [string]: string }, string?)
	local files: { [string]: string } = {}
	local sessionId: string? = folder.Name
	for _, child in folder:GetChildren() do
		if child:IsA("StringValue") and not string.find(child.Name, "%.part", 1, true) then
			local body = child.Value
			-- Reassemble chunks Name.part2, Name.part3...
			local i = 2
			while true do
				local chunk = folder:FindFirstChild(`{child.Name}.part{i}`)
				if not chunk or not chunk:IsA("StringValue") then
					break
				end
				body ..= chunk.Value
				i += 1
			end
			files[child.Name] = body
		end
	end
	return files, sessionId
end

local function latestBag(): (Instance?, string?)
	local root = ServerStorage:FindFirstChild("PlaytestExport")
	if root then
		local best: Instance? = nil
		for _, child in root:GetChildren() do
			if child:IsA("Folder") then
				best = child
			end
		end
		if best then
			return best, best.Name
		end
	end
	local client = ReplicatedStorage:FindFirstChild("PlaytestExportClient")
	if client then
		return client, "client_copy"
	end
	return nil, nil
end

Button.Click:Connect(function()
	local bag, sessionId = latestBag()
	if not bag or not sessionId then
		warn("[PlaytestExportPlugin] No ServerStorage.PlaytestExport session found. Stop & Export in Play first.")
		return
	end
	local files = collectFrom(bag)
	if next(files) == nil then
		warn("[PlaytestExportPlugin] Export folder empty.")
		return
	end
	local ok, err = pcall(function()
		HttpService:PostAsync(
			EXPORT_URL,
			HttpService:JSONEncode({
				SessionId = sessionId,
				Files = files,
			}),
			Enum.HttpContentType.ApplicationJson,
			false
		)
	end)
	if ok then
		print(`[PlaytestExportPlugin] Posted {sessionId} → docs/playtest/`)
	else
		warn(`[PlaytestExportPlugin] POST failed: {err}. Is python tools/playtest_export_server.py running?`)
	end
end)

print("[PlaytestExportPlugin] Ready — run export server, then click Export Playtest.")
