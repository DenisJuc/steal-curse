-- Leaderboards. Reads saved data only (never writes it):
--   Player list   leaderstats "Seals" (TotalScans) and "Rarest" (1 in N of the rarest base relic
--                 ever discovered, at base luck) for everyone in the server.
--   Town boards   two stone tablets in the hub, Most Seals and Rarest Find, top 10 from global
--                 OrderedDataStores. Scores are written every WRITE_SECONDS and on leave, the boards
--                 re-read every READ_SECONDS. In Studio (or when the store is unavailable) nothing is
--                 written and the boards rank the players in this server instead.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local RollRules = require(ReplicatedStorage.Shared.RollRules)
local BuildUtil = require(script.Parent.Parent.World.BuildUtil)
local HubBuilder = require(script.Parent.Parent.World.HubBuilder)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)

local LeaderboardService = {}

local WRITE_SECONDS = 300
local STAT_SECONDS = 2
local ROWS = 10
local GOLD = Color3.fromRGB(255, 205, 90)
local SPIRIT = Color3.fromRGB(170, 110, 255)

type Board = { Key: string, Title: string, Store: OrderedDataStore?, Rows: { TextLabel }, Format: (number) -> string }

local live = not RunService:IsStudio()
-- Studio ranks only this server, so it can refresh often.
local READ_SECONDS = if live then 120 else 15
local boards: { Board } = {}
local written: { [Player]: { [string]: number } } = {}
local names: { [number]: string } = {}

-- 1 in N at base luck for one relic (cached; the rules never change mid-server).
local oneInCache: { [string]: number } = {}
local baseContext: RollMath.Context? = nil
local function oneIn(relicId: string): number
	local cached = oneInCache[relicId]
	if cached then
		return cached
	end
	if not baseContext then
		baseContext = RollMath.contextFor(RollRules, {
			FullLuck = 1,
			RarityFocus = "MaxLuck",
			Frequency = "All",
			FrequencyRank = 0,
			MutationRank = 0,
			Sampler = BalanceTrials.raritySampler(),
		})
	end
	local p = RollMath.itemProbability(baseContext :: RollMath.Context, relicId)
	local value = if p > 0 then math.floor(1 / p + 0.5) else 0
	oneInCache[relicId] = value
	return value
end

local function scores(player: Player): { [string]: number }?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local rarest = 0
	for relicId in data.Discovered do
		rarest = math.max(rarest, oneIn(relicId))
	end
	return { Seals = math.floor(data.TotalScans or 0), Rarest = rarest }
end

local function rarestText(n: number): string
	return if n > 0 then `1 in {Format.number(n)}` else "-"
end

local function setupStats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local seals = Instance.new("IntValue")
	seals.Name = "Seals"
	seals.Parent = folder
	local rarest = Instance.new("StringValue")
	rarest.Name = "Rarest"
	rarest.Value = "-"
	rarest.Parent = folder
	folder.Parent = player
end

local function refreshStats(player: Player)
	local folder = player:FindFirstChild("leaderstats")
	local now = scores(player)
	if not folder or not now then
		return
	end
	(folder:FindFirstChild("Seals") :: IntValue).Value = now.Seals;
	(folder:FindFirstChild("Rarest") :: StringValue).Value = rarestText(now.Rarest)
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	local name = if player then player.DisplayName else nil
	if not name then
		local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		name = if ok then result else `Player {userId}`
	end
	names[userId] = name :: string
	return name :: string
end

local function writeScores(player: Player)
	if not live then
		return
	end
	local now = scores(player)
	if not now then
		return
	end
	local last = written[player] or {}
	written[player] = last
	for _, board in boards do
		local value = now[board.Key]
		local store = board.Store
		if store and value > 0 and last[board.Key] ~= value then
			local ok, err = pcall(store.SetAsync, store, tostring(player.UserId), value)
			if ok then
				last[board.Key] = value
			else
				warn(`[LeaderboardService] {board.Key} write failed: {err}`)
			end
		end
	end
end

local function showRows(board: Board, entries: { { Name: string, Value: number } })
	for index, row in board.Rows do
		local entry = entries[index]
		row.Text = if entry then `{index}.  {entry.Name}  ·  {board.Format(entry.Value)}` else ""
	end
end

local function readBoard(board: Board)
	local store = board.Store
	if live and store then
		local ok, pages = pcall(store.GetSortedAsync, store, false, ROWS)
		if ok then
			local entries = {}
			for _, item in pages:GetCurrentPage() do
				local userId = tonumber(item.key)
				if userId then
					table.insert(entries, { Name = nameOf(userId), Value = item.value })
				end
			end
			showRows(board, entries)
			return
		end
		warn(`[LeaderboardService] {board.Key} read failed: {pages}`)
	end
	-- Studio / store down: rank this server's players.
	local entries = {}
	for _, player in Players:GetPlayers() do
		local now = scores(player)
		if now and now[board.Key] > 0 then
			table.insert(entries, { Name = player.DisplayName, Value = now[board.Key] })
		end
	end
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	showRows(board, entries)
end

-- One tablet: dark slab on a plinth, gold title, ten rows on a SurfaceGui facing the plaza.
local function buildTablet(parent: Instance, base: CFrame, title: string): { TextLabel }
	BuildUtil.part(parent, {
		Name = "Plinth",
		Size = Vector3.new(11, 1.2, 3),
		CFrame = base * CFrame.new(0, 0.6, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(60, 56, 72),
	})
	local slab = BuildUtil.part(parent, {
		Name = "Tablet",
		Size = Vector3.new(10, 12, 1.2),
		CFrame = base * CFrame.new(0, 7.2, 0),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(30, 26, 40),
	})
	BuildUtil.decor(BuildUtil.part(parent, {
		Name = "Trim",
		Size = Vector3.new(10.4, 0.3, 1.4),
		CFrame = base * CFrame.new(0, 13.3, 0),
		Material = Enum.Material.Neon,
		Color = SPIRIT,
		Transparency = 0.3,
	}))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = slab
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, 0.14)
	titleLabel.Position = UDim2.fromScale(0, 0.03)
	titleLabel.FontFace = Font.fromEnum(Enum.Font.Fantasy)
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = GOLD
	titleLabel.Text = title
	titleLabel.Parent = gui
	local rows = {}
	for index = 1, ROWS do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(0.88, 0.07)
		row.Position = UDim2.fromScale(0.06, 0.2 + (index - 1) * 0.078)
		row.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if index <= 3 then GOLD:Lerp(Color3.new(1, 1, 1), 0.3) else Color3.fromRGB(220, 214, 235)
		row.Text = ""
		row.Parent = gui
		table.insert(rows, row)
	end
	BuildUtil.light(slab, SPIRIT, 14, 0.8)
	return rows
end

local function buildBoards()
	local model = Instance.new("Model")
	model.Name = "Leaderboards"
	-- One tablet each side of the street mouth (Config.Hub.Leaderboards, hub space). Front (-Z)
	-- carries the SurfaceGui and faces down the street, toward everyone walking to the hub.
	local hub = HubBuilder.CFrame()
	local spots = Config.Hub.Leaderboards
	local defs = {
		{ Key = "Seals", Title = "MOST SEALS", Format = Format.number },
		{ Key = "Rarest", Title = "RAREST FIND", Format = rarestText },
	}
	for _, def in defs do
		local store: OrderedDataStore? = nil
		if live then
			local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, `Leaderboard_{def.Key}_v1`)
			store = if ok then result else nil
		end
		local spot = spots[def.Key]
		local at = Vector3.new(spot[1], 1, spot[2])
		local rows = buildTablet(model, hub * CFrame.lookAt(at, at - Vector3.new(0, 0, 1)), def.Title)
		table.insert(boards, { Key = def.Key, Title = def.Title, Store = store, Rows = rows, Format = def.Format })
	end
	model.Parent = workspace
end

function LeaderboardService.Init()
	buildBoards()

	Players.PlayerAdded:Connect(setupStats)
	for _, player in Players:GetPlayers() do
		if not player:FindFirstChild("leaderstats") then
			setupStats(player)
		end
	end
	DataService.OnPlayerLoaded(refreshStats)
	Players.PlayerRemoving:Connect(function(player: Player)
		writeScores(player)
		written[player] = nil
	end)

	-- Scans arrive many times a second with auto roll: refresh the player list on a short timer.
	local dirty: { [Player]: boolean } = {}
	GameEvents.On("Discovery", function(player: Player)
		dirty[player] = true
	end)
	GameEvents.On("DataReset", function(player: Player)
		dirty[player] = true
	end)
	task.spawn(function()
		while true do
			task.wait(STAT_SECONDS)
			for player in dirty do
				dirty[player] = nil
				if player.Parent then
					refreshStats(player)
				end
			end
		end
	end)

	task.spawn(function()
		local sinceWrite = WRITE_SECONDS
		while true do
			if sinceWrite >= WRITE_SECONDS then
				sinceWrite = 0
				for _, player in Players:GetPlayers() do
					writeScores(player)
				end
			end
			for _, board in boards do
				readBoard(board)
			end
			task.wait(READ_SECONDS)
			sinceWrite += READ_SECONDS
		end
	end)
end

return LeaderboardService
