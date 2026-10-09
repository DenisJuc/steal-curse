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
	{ Name = "autosell", Tests = require("./specs/autosell_spec") },
	{ Name = "codex", Tests = require("./specs/codex_spec") },
	{ Name = "presentation", Tests = require("./specs/presentation_spec") },
	{ Name = "settings", Tests = require("./specs/settings_spec") },
	{ Name = "afk", Tests = require("./specs/afk_spec") },
	{ Name = "world", Tests = require("./specs/world_spec") },
	{ Name = "skills", Tests = require("./specs/skills_spec") },
	{ Name = "showcase", Tests = require("./specs/showcase_spec") },
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
