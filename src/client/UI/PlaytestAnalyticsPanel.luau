-- Studio-only Start / Stop & Export control for playtest analytics.
-- Kept clear of TravelBar (top-right) so it cannot steal travel clicks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent.UIKit)

local PlaytestAnalyticsPanel = {}

local function remotes(): (RemoteFunction?, RemoteEvent?)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		return nil, nil
	end
	local action = folder:FindFirstChild("AnalyticsAction")
	local status = folder:FindFirstChild("AnalyticsStatus")
	if action and action:IsA("RemoteFunction") and status and status:IsA("RemoteEvent") then
		return action, status
	end
	return nil, nil
end

local function invoke(action: string, a: any?): any
	local rf = remotes()
	if not rf then
		return nil
	end
	local ok, result = pcall(function()
		return rf:InvokeServer(action, a)
	end)
	return if ok then result else nil
end

function PlaytestAnalyticsPanel.Start(screen: ScreenGui)
	if not RunService:IsStudio() then
		return
	end

	local _, statusRemote = remotes()
	if not statusRemote then
		warn("[PlaytestAnalytics] Remotes missing; HUD skipped (gameplay unaffected).")
		return
	end

	local colors = UIKit.Colors
	-- Bottom-left: TravelBar owns top-right; do not overlap it.
	local root = Instance.new("Frame")
	root.Name = "PlaytestAnalyticsHud"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Size = UDim2.fromOffset(280, 120)
	root.Position = UDim2.new(0, 12, 1, -12)
	root.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	root.BackgroundTransparency = 0.15
	root.BorderSizePixel = 0
	root.ZIndex = 20
	root.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = root

	local title = UIKit.label({
		Name = "Title",
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 6),
		Text = "PLAYTEST RECORDING",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = root,
	})

	local status = UIKit.label({
		Name = "Status",
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.fromOffset(8, 28),
		Text = "Waiting…",
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 21,
		Parent = root,
	})

	local function refreshFrom(st: any)
		if type(st) ~= "table" then
			status.Text = "Status unavailable"
			return
		end
		if not st.TrackingAllowed then
			status.Text = "Off (need Studio + collection trial)"
			title.TextColor3 = colors.SubText
			return
		end
		if st.Recording then
			title.Text = "● RECORDING"
			title.TextColor3 = Color3.fromRGB(120, 220, 140)
			status.Text = `{st.Elapsed}  |  {st.EventCount} events  |  {st.PurchaseCount} buys`
		else
			title.Text = "PLAYTEST (stopped)"
			title.TextColor3 = colors.SubText
			status.Text = `Last: {st.Elapsed}  |  {st.EventCount} events`
		end
	end

	UIKit.button({
		Name = "StartBtn",
		Size = UDim2.fromOffset(84, 28),
		Position = UDim2.fromOffset(8, 78),
		Text = "Start",
		TextSize = 13,
		ZIndex = 21,
		Parent = root,
	}, function()
		local result = invoke("Start")
		if type(result) == "table" then
			refreshFrom(result.Status)
			status.Text = result.Message or status.Text
		end
	end)

	UIKit.button({
		Name = "StopBtn",
		Size = UDim2.fromOffset(120, 28),
		Position = UDim2.fromOffset(98, 78),
		Text = "Stop & Export",
		TextSize = 13,
		ZIndex = 21,
		Parent = root,
	}, function()
		local result = invoke("Stop")
		if type(result) == "table" then
			refreshFrom(result.Status)
			status.Text = result.Message or status.Text
			if type(result.Export) == "table" and type(result.Export.Files) == "table" then
				local folder = ReplicatedStorage:FindFirstChild("PlaytestExportClient")
				if not folder then
					folder = Instance.new("Folder")
					folder.Name = "PlaytestExportClient"
					folder.Parent = ReplicatedStorage
				end
				folder:ClearAllChildren()
				for name, body in result.Export.Files do
					local sv = Instance.new("StringValue")
					sv.Name = name
					sv.Value = if type(body) == "string" then string.sub(body, 1, 180000) else ""
					sv.Parent = folder
				end
			end
		end
	end)

	UIKit.button({
		Name = "ExportBtn",
		Size = UDim2.fromOffset(48, 28),
		Position = UDim2.fromOffset(224, 78),
		Text = "Save",
		TextSize = 13,
		ZIndex = 21,
		Parent = root,
	}, function()
		local result = invoke("Export")
		if type(result) == "table" then
			refreshFrom(result.Status)
			status.Text = result.Message or status.Text
		end
	end)

	statusRemote.OnClientEvent:Connect(refreshFrom)
	task.defer(function()
		refreshFrom(invoke("Status"))
	end)
end

return PlaytestAnalyticsPanel
