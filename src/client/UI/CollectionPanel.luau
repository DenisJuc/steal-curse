-- Studio Collection UX: fusion-first cards, selectable recipes, progressive Charms.
-- Advanced tools (Attune / Mutation Focus / Resonance) live on a second tab.
-- Server remains the authority via CollectionAction.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionConfig = require(ReplicatedStorage.Shared.CollectionConfig)
local CollectionMath = require(ReplicatedStorage.Shared.CollectionMath)
local Format = require(ReplicatedStorage.Shared.Format)
local ProgressObjective = require(ReplicatedStorage.Shared.ProgressObjective)
local Banner = require(script.Parent.Banner)
local Motion = require(script.Parent.Motion)
local RelicViewport = require(script.Parent.RelicViewport)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CollectionAction = Remotes:WaitForChild("CollectionAction") :: RemoteFunction

local CollectionPanel = {}

local function invoke(action: string, a: any?, b: any?): any
	local ok, result = pcall(function()
		return CollectionAction:InvokeServer(action, a, b)
	end)
	return if ok then result else nil
end

local function pct(owned: number, need: number): number
	if need <= 0 then
		return 1
	end
	return math.clamp(owned / need, 0, 1)
end

function CollectionPanel.Start(screen: ScreenGui): { Open: () -> (), SetVisible: (boolean) -> (), Toggle: () -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local panel, content = UIKit.modal(screen, "CollectionMenu", "COLLECTION", colors.Accent, Vector2.new(640, 720), "Collection")
	panel.Visible = false

	local renders = RelicViewport.cache(16)
	local openOnServer = false
	local selectedId: string? = nil
	local boardSelectedId: string? = nil
	local tab = "Fuse" -- Fuse | Board | Advanced
	local lastSnap: any = nil
	local refresh: (useCached: boolean?) -> ()
	local goToBoardAfterCharm = false

	-- —— Header: Collect → Fuse → Use ——
	local header = UIKit.create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 78),
		Position = UDim2.fromOffset(8, 4),
		Parent = content,
	})
	local goalLabel = UIKit.label({
		Name = "Goal",
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Collect copies → Fuse on Fusion → Use a Charm",
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = UIKit.TitleFont,
		TextColor3 = colors.Gold,
		Parent = header,
	})
	local liftLabel = UIKit.label({
		Name = "Lift",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "Board income ×1.00",
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = colors.Jade,
		Parent = header,
	})
	local essenceLabel = UIKit.label({
		Name = "Essence",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(0.5, -4, 0, 24),
		Text = "Essence: —",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = colors.Accent,
		Parent = header,
	})
	local boardLabel = UIKit.label({
		Name = "Board",
		Position = UDim2.new(0.5, 4, 0, 46),
		Size = UDim2.new(0.5, -4, 0, 24),
		Text = "Board —",
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})

	-- —— Tabs (below header; never covered by Charm picker) ——
	local tabBar = UIKit.create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 86),
		Size = UDim2.new(1, -16, 0, 34),
		ZIndex = 5,
		Parent = content,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local fuseTabBtn: TextButton
	local boardTabBtn: TextButton
	local advancedTabBtn: TextButton
	fuseTabBtn = UIKit.button({
		Name = "TabFuse",
		Size = UDim2.fromOffset(120, 34),
		Text = "Fuse",
		TextSize = 15,
		LayoutOrder = 1,
		ZIndex = 6,
		Parent = tabBar,
	}, function()
		tab = "Fuse"
		refresh()
	end)
	boardTabBtn = UIKit.button({
		Name = "TabBoard",
		Size = UDim2.fromOffset(120, 34),
		Text = "Board / Use",
		TextSize = 15,
		LayoutOrder = 2,
		ZIndex = 6,
		Parent = tabBar,
	}, function()
		tab = "Board"
		refresh()
	end)
	advancedTabBtn = UIKit.button({
		Name = "TabAdvanced",
		Size = UDim2.fromOffset(110, 34),
		Text = "Advanced",
		TextSize = 15,
		LayoutOrder = 3,
		ZIndex = 6,
		Parent = tabBar,
	}, function()
		tab = "Advanced"
		refresh()
	end)

	-- —— Body pages ——
	local fusePage = UIKit.create("Frame", {
		Name = "FusePage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 126),
		Size = UDim2.new(1, -16, 1, -134),
		Parent = content,
	})
	local boardPage = UIKit.create("Frame", {
		Name = "BoardPage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 126),
		Size = UDim2.new(1, -16, 1, -134),
		Visible = false,
		Parent = content,
	})
	local advancedPage = UIKit.create("Frame", {
		Name = "AdvancedPage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 126),
		Size = UDim2.new(1, -16, 1, -134),
		Visible = false,
		Parent = content,
	})

	local boardStatus = UIKit.label({
		Name = "BoardStatus",
		Size = UDim2.new(1, 0, 0, 56),
		Text = "Board / Use — Charms and Board income live here.",
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = colors.SubText,
		Parent = boardPage,
	})
	local boardListHost = UIKit.create("Frame", {
		Name = "BoardListHost",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 1, -216),
		Parent = boardPage,
	})
	local boardScroll = UIKit.scrollList(boardListHost, 8)
	boardScroll.Size = UDim2.fromScale(1, 1)
	local boardDetail = UIKit.create("Frame", {
		Name = "BoardDetail",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 148),
		Parent = boardPage,
	}, { UIKit.corner(12), UIKit.padding(10) })
	UIKit.skinPanel(boardDetail, colors.Accent)
	local boardDetailView = RelicViewport.new("PaladynsNecklace", {
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromOffset(4, 6),
		Parent = boardDetail,
	})
	local boardDetailName = UIKit.label({
		Name = "Name",
		Position = UDim2.fromOffset(70, 2),
		Size = UDim2.new(1, -80, 0, 20),
		Text = "Select a board slot",
		TextSize = 17,
		FontFace = UIKit.TitleFont,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = boardDetail,
	})
	local boardDetailBody = UIKit.label({
		Name = "Body",
		Position = UDim2.fromOffset(70, 24),
		Size = UDim2.new(1, -80, 0, 86),
		Text = "",
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = colors.SubText,
		Parent = boardDetail,
	})
	local statusLabel: TextLabel -- created further down; forward-declared for the board button
	local boardDetailAction: "upgrade" | "gotoFuse" | "pursue" | "retire" = "upgrade"
	local retireConfirmId: string? = nil
	local boardUpgradeBtn = UIKit.button({
		Name = "UpgradeOnBoard",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(160, 36),
		Text = "View upgrade",
		TextSize = 14,
		Parent = boardDetail,
	}, function()
		if boardDetailAction == "pursue" and boardSelectedId then
			local result = invoke("SetBoardFocus", boardSelectedId)
			if type(result) == "table" then
				if result.Ok then
					statusLabel.Text = result.Message or "Prioritized for NEXT."
					statusLabel.TextColor3 = colors.Jade
				else
					statusLabel.Text = result.Message or "Could not set focus."
					statusLabel.TextColor3 = colors.Red
				end
				if result.State then
					lastSnap = result.State
				end
			end
			refresh()
			return
		end
		if boardDetailAction == "gotoFuse" or not boardSelectedId then
			tab = "Fuse"
			refresh()
			return
		end
		selectedId = boardSelectedId
		tab = "Fuse"
		refresh()
	end)
	local boardRetireBtn = UIKit.button({
		Name = "RetireBoard",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.fromOffset(180, 36),
		Text = "Retire…",
		TextSize = 14,
		Visible = false,
		Parent = boardDetail,
	}, function()
		if not boardSelectedId then
			return
		end
		local snap = lastSnap
		local fusion = if snap and type(snap.Fusion) == "table" then snap.Fusion else nil
		local preview = if fusion
			then CollectionMath.previewRetire({ Fusion = fusion } :: any, boardSelectedId)
			else nil
		local cost = if preview then preview.Cost else (CollectionConfig.BoardRetireEssence or 80)
		if retireConfirmId ~= boardSelectedId then
			retireConfirmId = boardSelectedId
			local charmLabel = "no Charm"
			if preview and preview.CharmId and CollectionConfig.Charms[preview.CharmId] then
				charmLabel = CollectionConfig.Charms[preview.CharmId].Name
			elseif preview and preview.CharmId then
				charmLabel = preview.CharmId
			end
			local before = if preview then preview.IncomeBefore else (snap and snap.BoardIncomeMult) or 1
			local after = if preview then preview.IncomeAfter else 1
			local rank = if preview then preview.Rank else "?"
			if preview and preview.IsSoleHighest then
				boardRetireBtn.Text = `Destroy ×{string.format("%.2f", before)}?`
				boardStatus.Text =
					`WARNING: This is your only Rank {rank} lift source. Lose Rank {rank}, {charmLabel}, {cost} Essence. Board income ×{string.format("%.2f", before)} → ×{string.format("%.2f", after)}. Relic/Codex stay. Tap again to confirm.`
				boardStatus.TextColor3 = colors.Red
			elseif preview and preview.DropsBoardLift then
				boardRetireBtn.Text = `Confirm ×{string.format("%.2f", before)}→×{string.format("%.2f", after)}`
				boardStatus.Text =
					`Retire Rank {rank} / {charmLabel} (−{cost} Essence). Board income DROPS ×{string.format("%.2f", before)} → ×{string.format("%.2f", after)}. Relic/Codex stay. Tap again to confirm.`
				boardStatus.TextColor3 = colors.Gold
			else
				boardRetireBtn.Text = `Confirm −{cost} Essence`
				boardStatus.Text =
					`Retire Rank {rank} / {charmLabel} (−{cost} Essence). Board income stays ×{string.format("%.2f", before)}. Frees one slot. Relic/Codex stay. Tap again to confirm.`
				boardStatus.TextColor3 = colors.SubText
			end
			UIKit.skinButton(boardRetireBtn, "Danger")
			return
		end
		local id = boardSelectedId
		retireConfirmId = nil
		local result = invoke("RetireBoard", id)
		if type(result) == "table" then
			if result.Ok then
				boardSelectedId = nil
				boardStatus.Text = result.Message or "Retired."
				boardStatus.TextColor3 = colors.Jade
			else
				boardStatus.Text = result.Message or "Could not retire."
				boardStatus.TextColor3 = colors.Red
			end
			if result.State then
				lastSnap = result.State
				refresh(true)
				return
			end
		end
		refresh()
	end)

	statusLabel = UIKit.label({
		Name = "Status",
		Size = UDim2.new(1, 0, 0, 36),
		Text = "",
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = colors.SubText,
		Parent = fusePage,
	})

	-- Charm picker (full Fuse page until Charm chosen — below tabs/header)
	local charmFrame = UIKit.create("Frame", {
		Name = "CharmPicker",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 1, -8),
		Visible = false,
		ZIndex = 2,
		Parent = fusePage,
	})
	UIKit.label({
		Name = "CharmTitle",
		Size = UDim2.new(1, 0, 0, 26),
		Text = "USE — pick one Charm for this fused relic",
		TextSize = 18,
		FontFace = UIKit.TitleFont,
		TextColor3 = colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = charmFrame,
	})
	local charmRelicLabel = UIKit.label({
		Name = "CharmRelic",
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "",
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = colors.Text,
		Parent = charmFrame,
	})
	local charmRow = UIKit.create("Frame", {
		Name = "CharmRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 168),
		Parent = charmFrame,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	local charmHint = UIKit.label({
		Name = "CharmHint",
		Position = UDim2.fromOffset(0, 250),
		Size = UDim2.new(1, 0, 0, 48),
		Text = "One of each Charm on the Board. Hunt & Shrine need a pedestal; Workshop does not.",
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = charmFrame,
	})

	-- Progress list + detail
	local listHost = UIKit.create("Frame", {
		Name = "ListHost",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -228),
		Parent = fusePage,
	})
	local scroll = UIKit.scrollList(listHost, 8)
	scroll.Size = UDim2.fromScale(1, 1)

	local detail = UIKit.create("Frame", {
		Name = "Detail",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 180),
		Parent = fusePage,
	}, { UIKit.corner(12), UIKit.padding(10) })
	UIKit.skinPanel(detail, colors.Accent)

	local detailViewport = RelicViewport.new("PaladynsNecklace", {
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.fromOffset(4, 8),
		Parent = detail,
	})
	local detailName = UIKit.label({
		Name = "DetailName",
		Position = UDim2.fromOffset(78, 2),
		Size = UDim2.new(1, -90, 0, 22),
		Text = "Select a relic",
		TextSize = 18,
		FontFace = UIKit.TitleFont,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	})
	local detailRank = UIKit.label({
		Name = "DetailRank",
		Position = UDim2.fromOffset(78, 24),
		Size = UDim2.new(1, -90, 0, 18),
		Text = "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	})
	local detailProgress = UIKit.label({
		Name = "DetailProgress",
		Position = UDim2.fromOffset(78, 44),
		Size = UDim2.new(1, -90, 0, 18),
		Text = "",
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	})
	local progressBarBg = UIKit.create("Frame", {
		Name = "BarBg",
		Position = UDim2.fromOffset(78, 66),
		Size = UDim2.new(1, -90, 0, 10),
		BackgroundColor3 = colors.Track,
		Parent = detail,
	}, { UIKit.corner(6) })
	local progressBar = UIKit.create("Frame", {
		Name = "Bar",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = colors.Jade,
		Parent = progressBarBg,
	}, { UIKit.corner(6) })
	local detailReward = UIKit.label({
		Name = "DetailReward",
		Position = UDim2.fromOffset(8, 84),
		Size = UDim2.new(1, -220, 0, 48),
		Text = "",
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = colors.SubText,
		Parent = detail,
	})
	local detailBlock = UIKit.label({
		Name = "DetailBlock",
		Position = UDim2.fromOffset(8, 132),
		Size = UDim2.new(1, -220, 0, 36),
		Text = "",
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = colors.Red,
		Parent = detail,
	})
	local quarryBtn = UIKit.button({
		Name = "HuntQuarry",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -216, 1, -8),
		Size = UDim2.fromOffset(120, 44),
		Text = "Hunt Quarry",
		TextSize = 13,
		Parent = detail,
	}, function()
		if not selectedId then
			statusLabel.Text = "Tap a relic card above first."
			return
		end
		local result = invoke("SetHuntQuarry", selectedId)
		if type(result) == "table" and result.Message then
			statusLabel.Text = result.Message
		end
		refresh()
	end)
	local fuseBtn = UIKit.button({
		Name = "FuseSelected",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(200, 44),
		Text = "Fuse",
		TextSize = 16,
		Parent = detail,
	}, function()
		if not selectedId then
			statusLabel.Text = "Tap a relic card above first."
			return
		end
		local result = invoke("Fuse", selectedId)
		if type(result) == "table" then
			if result.State then
				lastSnap = result.State
			end
			if result.Message then
				statusLabel.Text = result.Message
			end
			if result.Ok then
				boardSelectedId = selectedId
				local needsCharm = type(result.State) == "table"
					and type(result.State.CharmNeededCards) == "table"
					and #result.State.CharmNeededCards > 0
				if needsCharm then
					-- Stay on Fuse so the Charm picker is visible (do not skip to Board).
					tab = "Fuse"
					goToBoardAfterCharm = false
					Banner.Show("FUSED!", "Now pick a Charm below — Hunt / Workshop / Shrine.", colors.Jade)
					refresh(true)
					return
				end
				Banner.Show("FUSED!", (result.Message or "Fused") .. " — see Board / Use.", colors.Jade)
				goToBoardAfterCharm = true
			end
		end
		refresh(result and result.State ~= nil)
	end)

	-- Advanced page
	local advScroll = UIKit.scrollList(advancedPage, 8)
	advScroll.Size = UDim2.fromScale(1, 1)
	local advBody = UIKit.label({
		Name = "AdvBody",
		Size = UDim2.new(1, -12, 0, 420),
		Text = "",
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = advScroll,
	})
	local advButtons = UIKit.create("Frame", {
		Name = "AdvButtons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 120),
		Parent = advScroll,
	})
	UIKit.button({
		Name = "CraftAttune",
		Size = UDim2.fromOffset(160, 36),
		Position = UDim2.fromOffset(0, 0),
		Text = "Craft Attune",
		TextSize = 14,
		Parent = advButtons,
	}, function()
		local result = invoke("CraftAttune")
		if type(result) == "table" and result.Message then
			statusLabel.Text = result.Message
		end
		refresh()
	end)
	UIKit.button({
		Name = "ActivateAttune",
		Size = UDim2.fromOffset(160, 36),
		Position = UDim2.fromOffset(170, 0),
		Text = "Use Attune",
		TextSize = 14,
		Parent = advButtons,
	}, function()
		local result = invoke("ActivateAttune")
		if type(result) == "table" and result.Message then
			statusLabel.Text = result.Message
		end
		refresh()
	end)
	UIKit.button({
		Name = "MutationFocus",
		Size = UDim2.fromOffset(160, 36),
		Position = UDim2.fromOffset(340, 0),
		Text = "Mutation Focus",
		TextSize = 14,
		Parent = advButtons,
	}, function()
		local result = invoke("CraftMutationFocus")
		if type(result) == "table" and result.Message then
			statusLabel.Text = result.Message
		end
		refresh()
	end)
	local selectedPursuit = "FamilyHunt"
	local pursuitIds = { "FamilyHunt", "MutationLedger", "EpicLineage" }
	local pursuitButtons: { [string]: TextButton } = {}
	for i, pid in pursuitIds do
		local row = CollectionConfig.RebirthPursuits and CollectionConfig.RebirthPursuits[pid]
		local label = if row and row.Name then row.Name else pid
		local btn = UIKit.button({
			Name = "Pursuit" .. pid,
			Size = UDim2.fromOffset(160, 36),
			Position = UDim2.fromOffset((i - 1) * 170, 48),
			Text = label,
			TextSize = 13,
			Parent = advButtons,
		}, function()
			if btn:GetAttribute("PursuitLocked") == true then
				statusLabel.Text = "Epic Lineage unlocks after First Bloodmoon."
				return
			end
			selectedPursuit = pid
			statusLabel.Text = if row and row.Summary
				then `{label}: {row.Summary} — now pick Resonance.`
				else `Pursuit selected: {label}. Now pick a Resonance.`
		end)
		pursuitButtons[pid] = btn
	end
	for i, id in { "Collector", "Binder", "Seeker" } do
		UIKit.button({
			Name = "Resonance" .. id,
			Size = UDim2.fromOffset(160, 36),
			Position = UDim2.fromOffset((i - 1) * 170, 96),
			Text = id,
			TextSize = 14,
			Parent = advButtons,
		}, function()
			local result = invoke("ChooseResonance", id, selectedPursuit)
			if type(result) == "table" and result.Message then
				statusLabel.Text = result.Message
			end
			refresh()
		end)
	end

	local function clearScroll()
		renders.DetachAll()
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for _, child in boardScroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function selectBoardEntry(entry: any, snap: any?)
		boardSelectedId = entry.Id
		retireConfirmId = nil
		RelicViewport.show(boardDetailView, entry.Id)
		boardDetailName.Text = entry.Name
		boardDetailName.TextColor3 = UIKit.tierColor(entry.Tier)
		local globalOn = snap and snap.BoardGlobalIncome == true
		local boardMult = if snap and type(snap.BoardIncomeMult) == "number" then snap.BoardIncomeMult else entry.IncomeMult
		local lines = {
			`Rank {entry.Rank}  ·  {entry.Tier}  ·  This entry ×{string.format("%.2f", entry.IncomeMult)}`,
		}
		if globalOn then
			table.insert(lines, `Board income ACTIVE ×{string.format("%.2f", boardMult)} (highest Board rank; does not stack)`)
			table.insert(lines, "Pedestal optional for Fusion income. Hunt Charm still needs a pedestal.")
		else
			table.insert(
				lines,
				if entry.OnPedestal then "On pedestal — income bonus ACTIVE" else "Equip on a pedestal to activate income bonus"
			)
		end
		if entry.CharmName then
			table.insert(lines, `Charm: {entry.CharmName}`)
			local charmCfg = entry.Charm and CollectionConfig.Charms[entry.Charm]
			if charmCfg and charmCfg.Summary then
				table.insert(lines, charmCfg.Summary)
			end
		else
			table.insert(lines, "Charm: not chosen — open Fuse tab if the picker is waiting")
		end
		if entry.BoardFocus then
			table.insert(lines, "NEXT priority for Rank 3 (no drop-rate change)")
		end
		if type(entry.Bonuses) == "table" then
			for _, b in entry.Bonuses do
				table.insert(lines, `• {b}`)
			end
		end
		boardDetailAction = "upgrade"
		if entry.NeedsMutation and entry.Upgrade and not entry.MaxRank then
			local u = entry.Upgrade
			local mutLine = if entry.HasMutated then "Mutated copy: yes" else "Mutated copy: need 1"
			table.insert(
				lines,
				`Rank 3 requires: {u.Owned}/{u.Need} base · {mutLine} · {u.Cost} Essence → ×{string.format("%.2f", u.NextIncomeMult or 1.5)}`
			)
			if entry.Charm == "Hunt" and not entry.OnPedestal then
				table.insert(lines, "Hunt Charm: equip this relic on a pedestal for family bias")
			elseif entry.Charm == "Hunt" then
				table.insert(lines, "Hunt Charm active — hunt this family")
			end
			if entry.CanSetBoardFocus then
				boardDetailAction = "pursue"
				boardUpgradeBtn.Text = "Pursue Rank 3"
				UIKit.skinButton(boardUpgradeBtn, "Gold")
				boardStatus.Text = "Prioritize for NEXT (does not change drop rates)."
			elseif u.Ready then
				boardUpgradeBtn.Text = "Upgrade on Fusion tab"
				UIKit.skinButton(boardUpgradeBtn, "Buy")
			else
				boardUpgradeBtn.Text = "See Rank 3 recipe"
				UIKit.skinButton(boardUpgradeBtn, "Gold")
			end
		elseif entry.Upgrade and not entry.MaxRank then
			local u = entry.Upgrade
			table.insert(
				lines,
				`Next: Rank {u.NextRank} (×{string.format("%.2f", u.NextIncomeMult or u.IncomeMult)}) — {u.Owned}/{u.Need} copies, {u.Cost} Essence`
			)
			if u.Ready then
				boardUpgradeBtn.Text = "Upgrade on Fusion tab"
				UIKit.skinButton(boardUpgradeBtn, "Buy")
			else
				boardUpgradeBtn.Text = "See requirements"
				UIKit.skinButton(boardUpgradeBtn, "Gold")
			end
		elseif entry.MaxRank then
			table.insert(lines, "Max fusion rank.")
			boardUpgradeBtn.Text = "Max rank"
			UIKit.skinButton(boardUpgradeBtn, "Dark")
		else
			boardUpgradeBtn.Text = "View on Fusion"
			UIKit.skinButton(boardUpgradeBtn, "Gold")
		end
		local retireOn = snap and snap.BoardRetireEnabled == true
		boardRetireBtn.Visible = retireOn == true
		if retireOn then
			local cost = snap.BoardRetireEssence or CollectionConfig.BoardRetireEssence or 80
			boardRetireBtn.Text = `Retire (−{cost} Essence)`
			UIKit.skinButton(boardRetireBtn, "Dark")
			if boardDetailAction ~= "pursue" then
				local fusion = if snap and type(snap.Fusion) == "table" then snap.Fusion else nil
				local prev = if fusion and boardSelectedId
					then CollectionMath.previewRetire({ Fusion = fusion } :: any, boardSelectedId)
					else nil
				if prev and prev.IsSoleHighest then
					boardStatus.Text =
						`Retire destroys your ×{string.format("%.2f", prev.IncomeBefore)} Board lift. Tap Retire for a full before/after warning.`
					boardStatus.TextColor3 = colors.Gold
				elseif prev and prev.DropsBoardLift then
					boardStatus.Text =
						`Retire would drop Board income ×{string.format("%.2f", prev.IncomeBefore)} → ×{string.format("%.2f", prev.IncomeAfter)}. Tap Retire to confirm.`
					boardStatus.TextColor3 = colors.SubText
				else
					boardStatus.Text =
						"USE Charms here. Retire frees a slot but clears this Fusion rank/Charm (Relic/Codex stay)."
					boardStatus.TextColor3 = colors.SubText
				end
			end
		elseif boardDetailAction ~= "pursue" then
			boardStatus.Text = "USE: Charms apply from the Board. Hunt/Shrine need this relic on a pedestal."
			boardStatus.TextColor3 = colors.SubText
		end
		boardDetailBody.Text = table.concat(lines, "\n")
	end

	local function renderBoard(snap: any)
		clearScroll()
		local slots = snap.BoardSlots
		if type(slots) ~= "table" or #slots == 0 then
			-- Fallback: show Board array only
			slots = {}
			local board = snap.Board or {}
			for i, occ in board do
				table.insert(slots, { Index = i, Unlocked = true, Occupied = occ })
			end
			local unlocked = snap.FusionSlots or 1
			for i = #board + 1, unlocked do
				table.insert(slots, {
					Index = i,
					Unlocked = true,
					UnlockName = "Empty slot",
					UnlockSummary = "Fuse a new relic on the Fusion tab to fill this slot.",
				})
			end
		end
		goalLabel.Text = `Your Board — {snap.FusedCount or 0}/{snap.FusionSlots or 1} slots used`
		local globalOn = snap.BoardGlobalIncome == true
		local boardMult = snap.BoardIncomeMult or 1
		boardStatus.Text = if globalOn
			then `Board income ACTIVE ×{string.format("%.2f", boardMult)} (best rank; does not stack). Hunt Charm still needs a pedestal.`
			else "Fused relics are HERE. Pedestal income ×rank when that relic is equipped. No unequip from Board."

		local still = false
		for _, slot in slots do
			local order = slot.Index or 0
			local occ = slot.Occupied
			local frame = UIKit.create("TextButton", {
				Name = `Slot{order}`,
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 96),
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = colors.Card,
				Parent = boardScroll,
			}, { UIKit.corner(10) })
			-- Same hover glow / click as every other button (UI pass 2026-11-09).
			Motion.button(frame)
			if occ then
				UIKit.stroke(UIKit.tierColor(occ.Tier), 2, 0.15).Parent = frame
				UIKit.skinCard(frame)
				local thumb = renders.Get(`board:{occ.Id}`, occ.Id)
				thumb.Position = UDim2.fromOffset(8, 12)
				thumb.Size = UDim2.fromOffset(68, 68)
				thumb.Parent = frame
				UIKit.label({
					Text = `Slot {order}  ·  {occ.Name}`,
					TextSize = 17,
					FontFace = UIKit.TitleFont,
					TextColor3 = UIKit.tierColor(occ.Tier),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(88, 8),
					Size = UDim2.new(1, -160, 0, 22),
					Parent = frame,
				})
				UIKit.label({
					Text = `Rank {occ.Rank}  ·  ×{string.format("%.2f", occ.IncomeMult)}  ·  {occ.CharmName or "No Charm"}`,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromOffset(88, 34),
					Size = UDim2.new(1, -160, 0, 20),
					Parent = frame,
				})
				UIKit.label({
					Text = if globalOn
						then (if occ.IncomeMult >= boardMult - 1e-9 then "Contributes Board income" else "On Board (lower rank)")
						elseif occ.OnPedestal then "ACTIVE on pedestal"
						else "Equip on pedestal to activate income",
					TextSize = 13,
					TextColor3 = if globalOn or occ.OnPedestal then colors.Jade else colors.SubText,
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(88, 56),
					Size = UDim2.new(1, -160, 0, 18),
					Parent = frame,
				})
				local badge = UIKit.label({
					Text = `R{occ.Rank}`,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Center,
					BackgroundTransparency = 0,
					BackgroundColor3 = colors.Accent,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -12, 0, 12),
					Size = UDim2.fromOffset(40, 24),
					Parent = frame,
				})
				UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
				frame.Activated:Connect(function()
					selectBoardEntry(occ, snap)
				end)
				if occ.Id == boardSelectedId then
					still = true
					selectBoardEntry(occ, snap)
				end
			elseif slot.Unlocked then
				UIKit.stroke(colors.Trim, 1.5, 0.5).Parent = frame
				UIKit.skinCard(frame)
				UIKit.label({
					Text = `Slot {order} — Empty`,
					TextSize = 18,
					FontFace = UIKit.TitleFont,
					TextColor3 = colors.Gold,
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(16, 16),
					Size = UDim2.new(1, -32, 0, 24),
					Parent = frame,
				})
				UIKit.label({
					Text = "Fuse a new relic on the Fusion tab to fill this slot.",
					TextSize = 14,
					TextColor3 = colors.SubText,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(16, 44),
					Size = UDim2.new(1, -32, 0, 36),
					Parent = frame,
				})
				frame.Activated:Connect(function()
					tab = "Fuse"
					refresh()
				end)
			else
				UIKit.stroke(colors.Trim, 1.5, 0.7).Parent = frame
				frame.BackgroundColor3 = colors.Track
				UIKit.label({
					Text = `Slot {order} — Locked`,
					TextSize = 17,
					FontFace = UIKit.TitleFont,
					TextColor3 = colors.SubText,
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(16, 12),
					Size = UDim2.new(1, -32, 0, 22),
					Parent = frame,
				})
				local prog = ""
				if type(slot.Progress) == "number" and type(slot.Required) == "number" then
					prog = ` ({slot.Progress}/{slot.Required})`
				end
				UIKit.label({
					Text = `Unlock: {slot.UnlockName or "?"}{prog}\n{slot.UnlockSummary or ""}`,
					TextSize = 13,
					TextColor3 = colors.SubText,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Position = UDim2.fromOffset(16, 38),
					Size = UDim2.new(1, -32, 0, 48),
					Parent = frame,
				})
			end
		end
		if not still then
			local firstOcc = nil
			for _, slot in slots do
				if slot.Occupied then
					firstOcc = slot.Occupied
					break
				end
			end
			if firstOcc then
				selectBoardEntry(firstOcc, snap)
			else
				boardSelectedId = nil
				boardDetailAction = "gotoFuse"
				boardRetireBtn.Visible = false
				boardDetailName.Text = "No fused relics yet"
				boardDetailBody.Text = if globalOn
					then "Use the Fusion tab to fuse a relic — it appears here. Board income ×rank (best) applies globally."
					else "Use the Fusion tab to fuse a relic — it appears here and uses one board slot. Income ×rank applies when that relic is on a pedestal."
				boardUpgradeBtn.Text = "Go to Fusion"
				UIKit.skinButton(boardUpgradeBtn, "Gold")
			end
		end
	end

	local function makeCharmCard(
		parent: Frame,
		charmId: string,
		relicId: string,
		order: number,
		locked: boolean,
		lockReason: string?,
		suggested: boolean?,
		unavailableKind: string? -- "taken" | "locked"
	)
		local info = CollectionConfig.Charms[charmId]
		local strokeColor = if locked
			then colors.Trim
			elseif suggested then colors.Jade
			else colors.Gold
		local card = UIKit.create("TextButton", {
			Name = charmId,
			LayoutOrder = order,
			Size = UDim2.fromOffset(186, 160),
			Text = "",
			AutoButtonColor = not locked,
			Active = not locked,
			Parent = parent,
		}, {
			UIKit.corner(10),
			UIKit.stroke(strokeColor, if suggested and not locked then 2.5 else 2, if locked then 0.45 else 0.15),
		})
		UIKit.skinCard(card)
		if not locked then
			Motion.button(card)
		end
		if locked then
			card.BackgroundColor3 = colors.Track
		end
		local titleSuffix = if locked
			then ""
			elseif suggested then "  ·  suggested"
			else ""
		UIKit.label({
			Text = (if info then info.Name else charmId) .. titleSuffix,
			TextSize = 15,
			FontFace = UIKit.TitleFont,
			TextColor3 = if locked then colors.SubText elseif suggested then colors.Jade else colors.Gold,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		UIKit.label({
			Text = if locked then (lockReason or "Unavailable") else (if info then info.Summary else ""),
			TextSize = 12,
			TextWrapped = true,
			TextColor3 = if locked then colors.Red else colors.Text,
			Position = UDim2.fromOffset(8, 34),
			Size = UDim2.new(1, -16, 0, 72),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = card,
		})
		local btnText = if unavailableKind == "locked"
			then "Locked"
			elseif locked then "In use"
			elseif suggested then "Choose ✓"
			else "Choose"
		local pick = UIKit.button({
			Name = "Pick",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.fromOffset(140, 32),
			Text = btnText,
			TextSize = 15,
			Parent = card,
		}, function()
			if locked then
				charmHint.Text = lockReason or "Charm unavailable."
				charmHint.TextColor3 = colors.Red
				return
			end
			local result = invoke("SetCharm", relicId, charmId)
			if type(result) ~= "table" then
				charmHint.Text = "Could not reach server — try again."
				charmHint.TextColor3 = colors.Red
				return
			end
			if result.State then
				lastSnap = result.State
			end
			local already = result.AlreadyEquipped == true or result.Message == "Charm already equipped."
			if result.Ok and not already then
				Banner.Show("CHARM SET", result.Message or "Charm chosen.", colors.Jade)
				local stillNeeded = type(result.State) == "table"
					and type(result.State.CharmNeededCards) == "table"
					and #result.State.CharmNeededCards > 0
				boardSelectedId = relicId
				if not stillNeeded then
					goToBoardAfterCharm = true
					tab = "Board"
				end
				refresh(true)
				return
			end
			if already then
				charmHint.Text = "Already set — open Board / Use to see it."
				charmHint.TextColor3 = colors.SubText
				refresh(true)
				return
			end
			charmHint.Text = result.Message or "Could not set Charm."
			charmHint.TextColor3 = colors.Red
			refresh(result.State ~= nil)
		end)
		UIKit.skinButton(pick, if locked then "Dark" elseif suggested then "Buy" else "Gold")
		pick.Active = not locked
	end

	local function renderCharmPicker(snap: any)
		for _, child in charmRow:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local cards = snap.CharmNeededCards
		local target = if type(cards) == "table" and cards[1] then cards[1] else nil
		if not target then
			charmFrame.Visible = false
			return
		end
		charmFrame.Visible = true
		listHost.Visible = false
		detail.Visible = false
		statusLabel.Text = ""
		charmRelicLabel.Text =
			`{target.Name} is fused. Next: USE — choose Hunt, Workshop, or Shrine (one of each on the Board).`
		charmHint.Text = "Hunt & Shrine: equip that relic on a pedestal. Workshop: bonus Essence on its dupes."
		charmHint.TextColor3 = colors.SubText
		local hasWorkshop = false
		if type(snap.UnlockedAbilities) == "table" then
			hasWorkshop = table.find(snap.UnlockedAbilities, "WorkshopCharmGlobal") ~= nil
		end
		local occupied = target.BoardCharms or snap.BoardCharms or {}
		local suggested = target.SuggestedCharm
		local function takenReason(charmId: string): (boolean, string?, string?)
			local owner = occupied[charmId]
			if type(owner) == "table" and type(owner.Name) == "string" then
				return true, `Already on {owner.Name} — each Charm is unique.`, "taken"
			end
			if charmId == "Workshop" and not hasWorkshop then
				return true, "Locked — unlock via First Golden mutation goal.", "locked"
			end
			return false, nil, nil
		end
		local huntTaken, huntWhy, huntKind = takenReason("Hunt")
		local workTaken, workWhy, workKind = takenReason("Workshop")
		local shrineTaken, shrineWhy, shrineKind = takenReason("Shrine")
		makeCharmCard(charmRow, "Hunt", target.Id, 1, huntTaken, huntWhy, suggested == "Hunt", huntKind)
		makeCharmCard(charmRow, "Workshop", target.Id, 2, workTaken, workWhy, suggested == "Workshop", workKind)
		makeCharmCard(charmRow, "Shrine", target.Id, 3, shrineTaken, shrineWhy, suggested == "Shrine", shrineKind)
	end

	local function statusLine(card: any): string
		if card.Ready then
			return `{card.Owned}/{card.Need} copies — Ready to fuse`
		end
		if card.BlockKind == "Mutation" or (card.NeedsMutation and not card.HasMutated) then
			return `{card.Owned}/{card.Need} base copies · Missing mutated {card.Name}`
		end
		if card.BlockKind == "Board" then
			return `Board full — unlock another slot for a new fusion`
		end
		if card.Missing > 0 then
			return `{card.Owned}/{card.Need} copies — Need {card.Missing} more`
		end
		return card.BlockReason or `{card.Owned}/{card.Need} copies`
	end

	local function badgeText(card: any): string
		if card.Ready then
			return "READY"
		end
		if card.BlockKind == "Mutation" then
			return "MUTATE"
		end
		if card.BlockKind == "Board" then
			return "NO SLOT"
		end
		if card.SoftPin then
			return "KEEPING"
		end
		if card.OnBoard then
			return `R{card.Rank}`
		end
		return card.Tier
	end

	local function selectCard(card: any)
		selectedId = card.Id
		RelicViewport.show(detailViewport, card.Id)
		detailName.Text = card.Name
		detailName.TextColor3 = UIKit.tierColor(card.Tier)
		local cur = card.CurrentIncomeMult or (if (card.Rank or 0) > 0 then card.IncomeMult else 1)
		local nxt = card.NextIncomeMult or card.IncomeMult or 1
		if (card.Rank or 0) <= 0 then
			detailRank.Text = `New fusion → Rank {card.NextRank}`
		else
			detailRank.Text = `Rank {card.Rank} → {card.NextRank}  ·  Income ×{string.format("%.2f", cur)} → ×{string.format("%.2f", nxt)}`
		end
		detailProgress.Text = statusLine(card)
		detailProgress.TextColor3 = if card.Ready then colors.Jade else colors.Text
		progressBar.Size = UDim2.fromScale(pct(card.Owned, card.Need), 1)
		progressBar.BackgroundColor3 = if card.Ready then colors.Jade else colors.Accent
		-- Own N to qualify; fuse spends fewer (server Consume).
		local costLine =
			`Own {card.Owned}/{card.Need} to qualify · Fuse spends {card.Consume} copies + {card.Cost} Essence`
		if card.NeedsMutation then
			costLine ..= if card.HasMutated
				then ` · Mutated copy: yes`
				else ` · Mutated copy: 0 (required)`
		end
		if card.OnBoard then
			costLine ..= " · Upgrades in place (no extra board slot)"
		end
		if card.SoftPin then
			costLine ..= " · Auto-sell keeps this target"
		end
		detailReward.Text = costLine
		local quarryOn = lastSnap and lastSnap.HuntQuarryEligible == true
		quarryBtn.Visible = quarryOn == true
		if quarryOn then
			local isActive = lastSnap.HuntQuarryId == card.Id
			local isChosen = lastSnap.HuntQuarryChosen == card.Id
			local autoSteer = lastSnap.HuntQuarryAutoSteer == true
			if isActive then
				quarryBtn.Text = if autoSteer then "Chasing (auto)" else "Chasing ✓"
				UIKit.skinButton(quarryBtn, "Gold")
			elseif isChosen and autoSteer then
				quarryBtn.Text = "Pick done"
				UIKit.skinButton(quarryBtn, "Dark")
			else
				quarryBtn.Text = "Hunt Quarry"
				UIKit.skinButton(quarryBtn, "Dark")
			end
			if isActive and type(lastSnap.HuntQuarryNeedDetail) == "string" then
				costLine ..= ` · Active chase: {lastSnap.HuntQuarryNeedDetail}`
				detailReward.Text = costLine
			elseif isChosen and autoSteer then
				costLine ..= " · Your pick (done) — binds chase another relic"
				detailReward.Text = costLine
			end
		end
		if card.Ready then
			detailBlock.Text = ""
			fuseBtn.Text = `Fuse · {card.Cost} Essence`
			UIKit.skinButton(fuseBtn, "Buy")
			fuseBtn.Active = true
			statusLabel.Text = if card.OnBoard
				then "This upgrades your fused relic in its current board slot."
				else "This will occupy one board slot."
		else
			detailBlock.Text = card.BlockReason or "Cannot fuse yet."
			fuseBtn.Text = if card.BlockKind == "Board"
				then "Need board slot"
				elseif card.BlockKind == "Mutation" then "Need mutation"
				elseif card.Missing > 0 then `Need {card.Missing} more`
				else "Can't fuse"
			UIKit.skinButton(fuseBtn, "Dark")
			fuseBtn.Active = false
			statusLabel.Text = card.BlockReason or ""
		end
	end

	local function makeProgressCard(card: any, order: number)
		local tierColor = UIKit.tierColor(card.Tier)
		local selected = selectedId == card.Id
		local frame = UIKit.create("TextButton", {
			Name = card.Id,
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 88),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = colors.Card,
			Parent = scroll,
		}, {
			UIKit.corner(10),
			UIKit.stroke(if selected then colors.Gold else tierColor, if selected then 3 else 1.5, if selected then 0 else 0.25),
		})
		UIKit.skinCard(frame)
		Motion.button(frame)
		local thumb = renders.Get(card.Id, card.Id)
		thumb.Position = UDim2.fromOffset(8, 8)
		thumb.Size = UDim2.fromOffset(64, 64)
		thumb.Parent = frame
		UIKit.label({
			Text = card.Name,
			TextSize = 17,
			FontFace = UIKit.TitleFont,
			TextColor3 = tierColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(84, 6),
			Size = UDim2.new(1, -170, 0, 22),
			Parent = frame,
		})
		UIKit.label({
			Text = statusLine(card),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = if card.Ready then colors.Jade else colors.Text,
			Position = UDim2.fromOffset(84, 30),
			Size = UDim2.new(1, -170, 0, 20),
			Parent = frame,
		})
		local rankBit = if card.OnBoard then `Rank {card.Rank}→{card.NextRank}` else `New → Rank {card.NextRank}`
		UIKit.label({
			Text = `{rankBit} · ×{string.format("%.2f", card.NextIncomeMult or card.IncomeMult)} · {card.Cost} Essence`,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = colors.SubText,
			Position = UDim2.fromOffset(84, 52),
			Size = UDim2.new(1, -170, 0, 18),
			Parent = frame,
		})
		local badge = UIKit.label({
			Text = badgeText(card),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = if card.Ready
				then colors.Jade
				elseif card.BlockKind == "Mutation" or card.BlockKind == "Board" then colors.Red
				elseif card.SoftPin then colors.Accent
				else colors.Track,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(78, 22),
			Parent = frame,
		})
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
		local barBg = UIKit.create("Frame", {
			Position = UDim2.new(1, -90, 1, -22),
			Size = UDim2.fromOffset(72, 8),
			BackgroundColor3 = colors.Track,
			Parent = frame,
		}, { UIKit.corner(4) })
		UIKit.create("Frame", {
			Size = UDim2.fromScale(pct(card.Owned, card.Need), 1),
			BackgroundColor3 = if card.Ready then colors.Jade else tierColor,
			Parent = barBg,
		}, { UIKit.corner(4) })
		frame.Activated:Connect(function()
			selectCard(card)
			refresh()
		end)
	end

	refresh = function(useCached: boolean?)
		local snap = lastSnap
		-- After Fuse/SetCharm/Retire, prefer authoritative result.State (avoid stale Get flicker).
		if not useCached then
			local fresh = invoke("Get")
			if type(fresh) == "table" then
				snap = fresh
				lastSnap = fresh
			end
		end
		if type(snap) ~= "table" or not snap.Enabled then
			goalLabel.Text = "Collection is off in this build."
			essenceLabel.Text = "Essence: —"
			return
		end

		essenceLabel.Text = `Essence {Format.number(snap.Essence or 0)}`
		local slots = snap.FusionSlots or 1
		local used = snap.FusedCount or 0
		boardLabel.Text = `Board {used}/{slots}`
		local obj = snap.NextObjective
		if type(obj) ~= "table" then
			obj = ProgressObjective.pick({
				Enabled = true,
				PendingResonance = snap.PendingResonance == true,
				CharmNeededCount = snap.CharmNeededCount or 0,
				FuseReadyCount = snap.FuseReadyCount or 0,
				BoardIncomeMult = snap.BoardIncomeMult or 1,
				BoardGlobalIncome = snap.BoardGlobalIncome == true,
				FusedCount = used,
				FusionSlots = slots,
				BoardFocusId = snap.BoardFocusId,
				Progress = snap.Progress,
				NextGoals = snap.NextGoals,
				CE = snap.CE,
				RebirthCost = snap.RebirthCost,
				Rebirths = snap.Rebirths,
				IncomePerSec = snap.IncomePerSec,
				AffordableShopBuys = snap.AffordableShopBuys,
				Essence = snap.Essence,
				HasAttuneRecipe = snap.HasAttuneRecipe == true,
				AttuneCharges = snap.AttuneCharges,
				AttuneScansLeft = snap.AttuneScansLeft,
				AttuneTicketCost = CollectionConfig.AttuneTicketEssenceCost,
				AscendHint = snap.AscendHint,
				ActivePursuit = snap.ActivePursuit,
				PursuitName = snap.PursuitName,
				PursuitSummary = snap.PursuitSummary,
				HuntQuarryEligible = snap.HuntQuarryEligible == true,
				HuntQuarryId = snap.HuntQuarryId,
				HuntQuarryName = snap.HuntQuarryName,
				HuntQuarryChosen = snap.HuntQuarryChosen,
				HuntQuarryChosenName = snap.HuntQuarryChosenName,
				HuntQuarryAutoSteer = snap.HuntQuarryAutoSteer == true,
				HuntQuarryNeedDetail = snap.HuntQuarryNeedDetail,
				HuntQuarryUseful = snap.HuntQuarryUseful == true,
			})
		end
		liftLabel.Text = ProgressObjective.boardStatusLine({
			Enabled = true,
			BoardIncomeMult = snap.BoardIncomeMult or 1,
			BoardGlobalIncome = snap.BoardGlobalIncome == true,
			FusedCount = used,
			FusionSlots = slots,
			Progress = snap.Progress or snap.Board,
		})
		if type(obj) == "table" and type(obj.Text) == "string" then
			goalLabel.Text = obj.Text
			if type(obj.Detail) == "string" and obj.Detail ~= "" then
				if tab == "Fuse" then
					local needsCharm = type(snap.CharmNeededCards) == "table" and #snap.CharmNeededCards > 0
					if not needsCharm then
						statusLabel.Text = obj.Detail
						statusLabel.TextColor3 = colors.SubText
					end
				elseif tab == "Board" and retireConfirmId == nil then
					boardStatus.Text = obj.Detail
					boardStatus.TextColor3 = colors.SubText
				end
			end
		end

		if goToBoardAfterCharm then
			goToBoardAfterCharm = false
			tab = "Board"
		end

		-- Early sessions: hide Advanced until Attune / Resonance / Pursuit tools exist.
		local advancedReady = (snap.AttuneCharges or 0) > 0
			or (type(snap.ResonanceStacks) == "table" and (
				(snap.ResonanceStacks.Collector or 0) > 0
				or (snap.ResonanceStacks.Binder or 0) > 0
				or (snap.ResonanceStacks.Seeker or 0) > 0
			))
			or snap.PendingResonance == true
			or snap.ActivePursuit ~= nil
			or snap.HuntQuarryEligible == true
		if type(snap.UnlockedAbilities) == "table" then
			for _, ability in snap.UnlockedAbilities do
				if
					ability == "AttuneTicketRecipe"
					or ability == "TargetedAttune"
					or ability == "MutationFocus"
					or ability == "FamilyAttune"
					or ability == "DailyAttune"
					or ability == "PostRebirthAttune"
				then
					advancedReady = true
					break
				end
			end
		end
		advancedTabBtn.Visible = advancedReady
		if tab == "Advanced" and not advancedReady then
			tab = "Fuse"
		end

		UIKit.skinTab(fuseTabBtn, tab == "Fuse")
		UIKit.skinTab(boardTabBtn, tab == "Board")
		UIKit.skinTab(advancedTabBtn, tab == "Advanced")
		fusePage.Visible = tab == "Fuse"
		boardPage.Visible = tab == "Board"
		advancedPage.Visible = tab == "Advanced"

		if tab == "Board" then
			renderBoard(snap)
			if type(obj) == "table" and type(obj.Text) == "string" then
				goalLabel.Text = obj.Text
			end
			return
		end

		if tab == "Advanced" then
			local lines = {
				"Advanced tools unlock as you play. Fusion is the main loop.",
				"",
				"GOALS:",
			}
			if type(snap.NextGoals) == "table" then
				for _, g in snap.NextGoals do
					table.insert(lines, `• {g.Name} ({g.Progress}/{g.Required}) — {g.Summary}`)
				end
			end
			table.insert(lines, "")
			table.insert(lines, "RESONANCE (after Rebirth):")
			for _, id in { "Collector", "Binder", "Seeker" } do
				local stacks = (snap.ResonanceStacks and snap.ResonanceStacks[id]) or 0
				table.insert(lines, `• {id} ×{stacks}`)
			end
			table.insert(lines, "")
			if snap.ActivePursuit and snap.PursuitName then
				table.insert(lines, `THIS LIFE: {snap.PursuitName}`)
				if snap.PursuitSummary then
					table.insert(lines, snap.PursuitSummary)
				end
			else
				table.insert(lines, "THIS LIFE: (pick Pursuit + Resonance after Rebirth)")
			end
			table.insert(lines, "")
			if snap.HuntQuarryEligible then
				table.insert(lines, "HUNT QUARRY (binds only — go into the wild):")
				if snap.HuntQuarryName then
					local auto = snap.HuntQuarryAutoSteer == true
					table.insert(
						lines,
						if auto
							then `• ACTIVE (auto): {snap.HuntQuarryName} — binds bias this relic`
							else `• ACTIVE: {snap.HuntQuarryName} — binds bias this relic`
					)
					if snap.HuntQuarryNeedDetail then
						table.insert(lines, `• Why: {snap.HuntQuarryNeedDetail}`)
					end
					if auto and type(snap.HuntQuarryChosenName) == "string" then
						table.insert(
							lines,
							`• Your pick {snap.HuntQuarryChosenName} is done (saved, not biasing). Tap Hunt Quarry to change.`
						)
					elseif snap.HuntQuarryUseful ~= true then
						table.insert(lines, "• No useful chase left — pick an undiscovered or unmutated Board relic.")
					end
				else
					table.insert(lines, "• Pick a relic on Fusion → Hunt Quarry (Codex / mut / Ascend goals OK).")
				end
				table.insert(lines, "")
			end
			table.insert(lines, `Attune charges: {snap.AttuneCharges or 0}/{snap.AttuneChargeCap or 3}`)
			if snap.PendingResonance then
				table.insert(lines, "1) Tap a Pursuit row  2) Tap Collector / Binder / Seeker.")
			end
			local lockedEpic = true
			if type(snap.PursuitOptions) == "table" then
				for _, opt in snap.PursuitOptions do
					if opt.Id == "EpicLineage" then
						lockedEpic = opt.Locked == true
						break
					end
				end
			elseif snap.HasEpicCatalyst == true then
				lockedEpic = false
			end
			for pid, pbtn in pursuitButtons do
				local row = CollectionConfig.RebirthPursuits and CollectionConfig.RebirthPursuits[pid]
				local locked = pid == "EpicLineage" and lockedEpic
				pbtn:SetAttribute("PursuitLocked", locked)
				pbtn:SetAttribute("Disabled", locked)
				pbtn.Text = if locked then "Epic Lineage (locked)" else (row and row.Name or pid)
				UIKit.skinButton(pbtn, if selectedPursuit == pid and not locked then "Gold" else "Dark")
			end
			advBody.Text = table.concat(lines, "\n")
			return
		end

		-- Fuse tab
		local needsCharm = type(snap.CharmNeededCards) == "table" and #snap.CharmNeededCards > 0
		if needsCharm then
			clearScroll()
			renderCharmPicker(snap)
			goalLabel.Text = if type(obj) == "table" and obj.Text then obj.Text else "Pick a Charm — this specializes your fused relic."
			return
		end
		charmFrame.Visible = false
		listHost.Visible = true
		detail.Visible = true

		local progress = snap.Progress
		if type(progress) ~= "table" then
			progress = snap.FuseCandidates or {}
		end

		clearScroll()
		if #progress == 0 then
			goalLabel.Text = if type(obj) == "table" and obj.Text
				then obj.Text
				else "COLLECT — get 3 copies of one relic, then Fuse."
			statusLabel.Text = if type(obj) == "table" and obj.Detail
				then obj.Detail
				else "1 Collect copies  ·  2 Fuse on this tab  ·  3 Use a Charm on Board."
			detailName.Text = "No relics yet"
			detailProgress.Text = "Scan or hunt for duplicate finds of the same relic."
			detailReward.Text = "Fuse spends copies + Essence, then you pick a Charm to Use."
			fuseBtn.Text = "Need copies"
			UIKit.skinButton(fuseBtn, "Dark")
			fuseBtn.Active = false
			return
		end

		local readyCount = 0
		for _, c in progress do
			if c.Ready then
				readyCount += 1
			end
		end
		if type(obj) == "table" and type(obj.Text) == "string" then
			goalLabel.Text = obj.Text
			if type(obj.Detail) == "string" and obj.Detail ~= "" then
				statusLabel.Text = obj.Detail
			end
		elseif readyCount > 0 then
			goalLabel.Text = "Tap a READY relic, then press Fuse."
		else
			local top = progress[1]
			if top.BlockReason then
				goalLabel.Text = top.BlockReason
			elseif top.Missing > 0 then
				goalLabel.Text = `{top.Name} — {top.Owned}/{top.Need} — Need {top.Missing} more`
			else
				goalLabel.Text = top.Name
			end
		end

		local stillValid = false
		for i, card in progress do
			makeProgressCard(card, i)
			if card.Id == selectedId then
				stillValid = true
			end
		end
		local pick = if stillValid then nil else progress[1]
		if stillValid then
			for _, card in progress do
				if card.Id == selectedId then
					selectCard(card)
					break
				end
			end
		elseif pick then
			selectCard(pick)
		end

		if type(snap.FuseCandidates) == "table" and #snap.FuseCandidates > 0 then
			invoke("InspectRecipes", snap.FuseCandidates[1].Id)
		end
		-- Board softlock hint only when nothing is Ready (don't drown Ready state).
		if readyCount == 0 and type(snap.BoardHint) == "string" and used >= slots then
			if statusLabel.Text == "" or statusLabel.Text == snap.BoardHint then
				statusLabel.Text = snap.BoardHint
			end
		end
	end

	local function notifyServerOpen()
		if openOnServer then
			refresh()
			return
		end
		openOnServer = true
		local snap = invoke("Open")
		if type(snap) == "table" then
			lastSnap = snap
			tab = "Fuse"
			refresh(true)
			return
		end
		tab = "Fuse"
		refresh()
	end

	local function notifyServerClose()
		if not openOnServer then
			return
		end
		openOnServer = false
		invoke("Close")
	end

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			notifyServerOpen()
		else
			notifyServerClose()
		end
	end)

	local function setVisible(visible: boolean)
		if panel.Visible == visible then
			if visible then
				refresh()
			end
			return
		end
		panel.Visible = visible
	end

	player:GetAttributeChangedSignal("Essence"):Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("FuseReadyCount"):Connect(function()
		if panel.Visible then
			refresh()
		end
	end)

	local introShown = false
	local function maybeIntro()
		if introShown then
			return
		end
		if (player:GetAttribute("FuseReadyCount") or 0) <= 0 then
			return
		end
		introShown = true
		Banner.Show(
			"FUSION READY",
			"Collect done → Fuse the READY relic → Use a Charm (picker stays open until you choose).",
			colors.Accent
		)
	end
	player:GetAttributeChangedSignal("FuseReadyCount"):Connect(maybeIntro)
	task.defer(maybeIntro)

	return {
		Open = function()
			setVisible(true)
		end,
		SetVisible = setVisible,
		Toggle = function()
			setVisible(not panel.Visible)
		end,
	}
end

return CollectionPanel
