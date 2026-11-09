-- Zone events (ZoneEvents module): runs the server-wide schedule and publishes it on workspace
-- attributes for every client (beacon, ambience, announcements):
--   ZoneEvent / ZoneEventArea / ZoneEventEndsAt   the active event (nil when none)
--   ZoneEventSoon / ZoneEventStartsAt             the next event during its warning
-- BindService asks Factors(area) for every capture.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ZoneEvents = require(ReplicatedStorage.Shared.ZoneEvents)

local ZoneEventService = {}

local options = Config.ZoneEvents :: ZoneEvents.Options
local state: ZoneEvents.State = ZoneEvents.new(0, options)
local rng = Random.new()

local function nextNumber(): number
	return rng:NextNumber()
end

local function publish()
	local event = ZoneEvents.byId(options, state.EventId)
	local active = state.Phase == "Active" and event
	workspace:SetAttribute("ZoneEvent", if active and event then event.Id else nil)
	workspace:SetAttribute("ZoneEventArea", if active and event then event.Area else nil)
	workspace:SetAttribute("ZoneEventEndsAt", if active then state.EndsAt else nil)
	-- No advance notice (2026-11-08): players find out when an event starts. The schedule still has
	-- its warning phase internally, it just isn't published.
	workspace:SetAttribute("ZoneEventSoon", nil)
	workspace:SetAttribute("ZoneEventStartsAt", nil)
end

function ZoneEventService.Factors(area: string): ZoneEvents.Factors
	return ZoneEvents.factors(state, area, options, Config.Luck.MaxEvent)
end

-- The active event (nil when none).
function ZoneEventService.Active(): ZoneEvents.Event?
	return if state.Phase == "Active" then ZoneEvents.byId(options, state.EventId) else nil
end

-- Debug: start `id` now, or end the current event ("off").
function ZoneEventService.Force(id: string): boolean
	local now = workspace:GetServerTimeNow()
	if id == "off" then
		if state.Phase == "Active" then
			state.EndsAt = now
		end
		return true
	end
	if not ZoneEvents.byId(options, id) then
		return false
	end
	ZoneEvents.force(state, id, now, options)
	publish()
	return true
end

-- Bought events (ShopService): start now, or right after the running event ends so nobody's
-- paid event is cut short. Returns "Started" or "Queued".
local queued: { string } = {}
function ZoneEventService.Summon(id: string): string?
	if not ZoneEvents.byId(options, id) then
		return nil
	end
	if state.Phase == "Active" then
		table.insert(queued, id)
		workspace:SetAttribute("ZoneEventQueued", #queued)
		return "Queued"
	end
	ZoneEventService.Force(id)
	return "Started"
end

function ZoneEventService.Init()
	state = ZoneEvents.new(workspace:GetServerTimeNow(), options)
	publish()
	task.spawn(function()
		while true do
			task.wait(1)
			local changed = false
			while ZoneEvents.advance(state, workspace:GetServerTimeNow(), nextNumber, options) do
				changed = true
			end
			if changed then
				publish()
			end
			if state.Phase ~= "Active" and #queued > 0 then
				ZoneEventService.Force(table.remove(queued, 1) :: string)
				workspace:SetAttribute("ZoneEventQueued", if #queued > 0 then #queued else nil)
			end
		end
	end)
end

return ZoneEventService
