-- Headless test runner. Run from the repo root: lune run tests/run

local process = require("@lune/process")

local suites = {
	{ Name = "config", Tests = require("./specs/config_spec") },
	{ Name = "rollmath", Tests = require("./specs/rollmath_spec") },
	{ Name = "format", Tests = require("./specs/format_spec") },
	{ Name = "hunt", Tests = require("./specs/hunt_spec") },
	{ Name = "distribution", Tests = require("./specs/distribution_spec") },
	{ Name = "data", Tests = require("./specs/data_spec") },
	{ Name = "rarewait", Tests = require("./specs/rarewait_spec") },
	{ Name = "economy", Tests = require("./specs/economy_spec") },
	{ Name = "income", Tests = require("./specs/income_spec") },
	{ Name = "rebirth", Tests = require("./specs/rebirth_spec") },
	{ Name = "autosell", Tests = require("./specs/autosell_spec") },
	{ Name = "codex", Tests = require("./specs/codex_spec") },
	{ Name = "presentation", Tests = require("./specs/presentation_spec") },
	{ Name = "settings", Tests = require("./specs/settings_spec") },
	{ Name = "afk", Tests = require("./specs/afk_spec") },
	{ Name = "world", Tests = require("./specs/world_spec") },
	{ Name = "skills", Tests = require("./specs/skills_spec") },
	{ Name = "showcase", Tests = require("./specs/showcase_spec") },
	{ Name = "models", Tests = require("./specs/models_spec") },
	{ Name = "roll", Tests = require("./specs/roll_spec") },
	{ Name = "items", Tests = require("./specs/items_spec") },
	{ Name = "sprint", Tests = require("./specs/sprint_spec") },
	{ Name = "terrain", Tests = require("./specs/terrain_spec") },
	{ Name = "streak", Tests = require("./specs/streak_spec") },
	{ Name = "zoneevents", Tests = require("./specs/zoneevents_spec") },
	{ Name = "offerings", Tests = require("./specs/offerings_spec") },
	{ Name = "mastery", Tests = require("./specs/mastery_spec") },
	{ Name = "curse", Tests = require("./specs/curse_spec") },
	{ Name = "bounties", Tests = require("./specs/bounties_spec") },
}

local passed, failed = 0, 0
for _, suite in suites do
	for _, test in suite.Tests do
		local ok, err = pcall(test.Run)
		if ok then
			passed += 1
			print(`  PASS  {suite.Name}: {test.Name}`)
		else
			failed += 1
			print(`  FAIL  {suite.Name}: {test.Name}\n        {err}`)
		end
	end
end

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
