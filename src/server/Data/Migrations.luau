-- Ordered, idempotent data migrations. Pure (no Roblox APIs) so Lune tests can run fixtures.
-- Steps[n] upgrades data from version n-1 to n. Runs BEFORE Reconcile on every load.

local Migrations = {}

Migrations.Steps = {
	-- 0 -> 1: pre-ProfileStore Slice 0/1 data had no version, no Discovered map and no history.
	[1] = function(data: any)
		data.Discovered = data.Discovered or {}
		for _, item in data.Inventory or {} do
			if type(item) == "table" and type(item.Id) == "string" and data.Discovered[item.Id] == nil then
				data.Discovered[item.Id] = item.At or 0
			end
		end
		data.RareHistory = data.RareHistory or {}
	end,
} :: { [number]: (any) -> () }

export type Outcome = "Current" | "Migrated" | "Newer"

-- Upgrades data in place to targetVersion. Data from a NEWER game version is left untouched
-- (an old server must never downgrade or overwrite it).
function Migrations.run(data: any, targetVersion: number): Outcome
	local version = if type(data.DataVersion) == "number" then data.DataVersion else 0
	if version > targetVersion then
		return "Newer"
	end
	if version == targetVersion then
		return "Current"
	end
	for step = version + 1, targetVersion do
		local migrate = Migrations.Steps[step]
		if migrate then
			migrate(data)
		end
		data.DataVersion = step
	end
	return "Migrated"
end

return Migrations
